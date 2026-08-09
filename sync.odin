package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

exec_sync :: proc() {
	user := get_safe_username()
	fmt.printf("[gfd sync] Syncing active workspace for @%s...\n", user)

	root_dir, ok := get_git_root()
	if !ok do return

	// 1. Fetch latest remote shadow branches first to know peer states
	run_git({"fetch", "origin"})

	// 2. Perform 3-Way Merge for all changed peer files BEFORE creating our new shadow commit
	peers := get_active_peer_handles(user)
	my_shadow_ref := fmt.tprintf("refs/sync/%s", user)

	for peer in peers {
		peer_ref := fmt.tprintf("refs/remotes/sync/%s", peer)
		peer_changes := get_changed_files_between("HEAD", peer_ref)

		for file_path in peer_changes {
			merge_file_with_dynamic_base(file_path, peer, my_shadow_ref, peer_ref)
		}
	}

	// 3. Stage local merged workspace
	run_git({"add", "-A"})

	write_tree_res := run_git({"write-tree"})
	if !write_tree_res.ok do return
	tree_hash := strings.trim_space(write_tree_res.stdout)

	// 4. Construct parent arguments for commit-tree (HEAD + previous local shadow + peer shadows)
	parent_args: [dynamic]string
	append(&parent_args, "commit-tree", tree_hash)

	// Always parent to HEAD
	head_res := run_git({"rev-parse", "HEAD"})
	if head_res.ok {
		append(&parent_args, "-p", strings.trim_space(head_res.stdout))
	}

	// Parent to previous local shadow commit if it exists
	local_shadow_res := run_git({"rev-parse", my_shadow_ref})
	if local_shadow_res.ok {
		append(&parent_args, "-p", strings.trim_space(local_shadow_res.stdout))
	}

	// Parent to fetched peer shadow commits
	for peer in peers {
		peer_ref := fmt.tprintf("refs/remotes/sync/%s", peer)
		peer_hash_res := run_git({"rev-parse", peer_ref})
		if peer_hash_res.ok {
			append(&parent_args, "-p", strings.trim_space(peer_hash_res.stdout))
		}
	}

	append(&parent_args, "-m", "gfd-auto-sync")

	// Create multi-parent shadow commit object
	commit_res := run_git(parent_args[:])
	if !commit_res.ok {
		fmt.eprintln("Failed to create shadow commit:", commit_res.stderr)
		return
	}
	shadow_commit_hash := strings.trim_space(commit_res.stdout)

	// 5. Push updated shadow graph to remote
	push_ref := fmt.tprintf("%s:refs/sync/%s", shadow_commit_hash, user)
	push_res := run_git({"push", "origin", push_ref, "--force"})
	if !push_res.ok {
		fmt.eprintln("Push failed:", push_res.stderr)
		return
	}

	fmt.println("[gfd sync] Sync complete! Workspace cleanly merged into shadow graph.")
}

merge_file_with_dynamic_base :: proc(file_path, peer, my_shadow_ref, peer_ref: string) {
	base_temp := fmt.tprintf(".git/GFD_BASE_%s", filepath.base(file_path))
	peer_temp := fmt.tprintf(".git/GFD_PEER_%s", filepath.base(file_path))

	defer {
		os.remove(base_temp)
		os.remove(peer_temp)
	}

	// Calculate the TRUE common ancestor commit between my shadow and peer's shadow
	base_commit := "HEAD"
	mb_res := run_git({"merge-base", my_shadow_ref, peer_ref})
	if mb_res.ok && len(strings.trim_space(mb_res.stdout)) > 0 {
		base_commit = strings.trim_space(mb_res.stdout)
	}

	// Extract base version from true merge-base
	base_file_ref := fmt.tprintf("%s:%s", base_commit, file_path)
	base_res := run_git({"show", base_file_ref})
	if base_res.ok {
		os.write_entire_file(base_temp, transmute([]byte)base_res.stdout)
	} else {
		os.write_entire_file(base_temp, []byte(""))
	}

	// Extract peer version from peer shadow ref
	peer_file_ref := fmt.tprintf("%s:%s", peer_ref, file_path)
	peer_res := run_git({"show", peer_file_ref})
	if !peer_res.ok do return
	os.write_entire_file(peer_temp, transmute([]byte)peer_res.stdout)

	// Execute 3-way merge using the accurate common ancestor
	merge_res := run_git({"merge-file", file_path, base_temp, peer_temp})

	if merge_res.exit_code == 0 {
		fmt.printf("    Cleanly merged '%s' from @%s\n", file_path, peer)
	} else {
		fmt.printf("  ⚠️ Conflict in '%s' with @%s! Git conflict markers added to file.\n", file_path, peer)
	}
}
