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

	run_git({"fetch", "origin"})

	peers := get_active_peer_handles(user)
	my_shadow_ref := fmt.tprintf("refs/sync/%s", user)

	for peer in peers {
		peer_ref := fmt.tprintf("refs/remotes/sync/%s", peer)
		peer_changes := get_changed_files_between("HEAD", peer_ref)

		for file_path in peer_changes {
			merge_file_with_dynamic_base(file_path, peer, my_shadow_ref, peer_ref)
		}
	}

	run_git({"add", "-A"})

	write_tree_res := run_git({"write-tree"})
	if !write_tree_res.ok do return
	tree_hash := strings.trim_space(write_tree_res.stdout)

	parent_args: [dynamic]string
	append(&parent_args, "commit-tree", tree_hash)

	head_res := run_git({"rev-parse", "HEAD"})
	if head_res.ok {
		append(&parent_args, "-p", strings.trim_space(head_res.stdout))
	}

	local_shadow_res := run_git({"rev-parse", my_shadow_ref})
	if local_shadow_res.ok {
		append(&parent_args, "-p", strings.trim_space(local_shadow_res.stdout))
	}

	for peer in peers {
		peer_ref := fmt.tprintf("refs/remotes/sync/%s", peer)
		peer_hash_res := run_git({"rev-parse", peer_ref})
		if peer_hash_res.ok {
			append(&parent_args, "-p", strings.trim_space(peer_hash_res.stdout))
		}
	}

	append(&parent_args, "-m", "gfd-auto-sync")

	commit_res := run_git(parent_args[:])
	if !commit_res.ok {
		fmt.eprintln("Failed to create shadow commit:", commit_res.stderr)
		return
	}
	shadow_commit_hash := strings.trim_space(commit_res.stdout)

	push_ref := fmt.tprintf("%s:refs/sync/%s", shadow_commit_hash, user)
	push_res := run_git({"push", "origin", push_ref, "--force"})
	if !push_res.ok {
		fmt.eprintln("Push failed:", push_res.stderr)
		return
	}

	fmt.println("[gfd sync] Sync complete! Workspace merged into shadow graph.")
}

merge_file_with_dynamic_base :: proc(file_path, peer, my_shadow_ref, peer_ref: string) {
	base_temp := fmt.tprintf(".git/GFD_BASE_%s", filepath.base(file_path))
	peer_temp := fmt.tprintf(".git/GFD_PEER_%s", filepath.base(file_path))

	defer {
		os.remove(base_temp)
		os.remove(peer_temp)
	}

	base_commit := "HEAD"
	mb_res := run_git({"merge-base", my_shadow_ref, peer_ref})
	if mb_res.ok && len(strings.trim_space(mb_res.stdout)) > 0 {
		base_commit = strings.trim_space(mb_res.stdout)
	}

	base_file_ref := fmt.tprintf("%s:%s", base_commit, file_path)
	base_res := run_git({"show", base_file_ref})
	if base_res.ok {
		_ = os.write_entire_file(base_temp, base_res.stdout)
	} else {
		_ = os.write_entire_file(base_temp, "")
	}

	peer_file_ref := fmt.tprintf("%s:%s", peer_ref, file_path)
	peer_res := run_git({"show", peer_file_ref})
	if !peer_res.ok do return
	_ = os.write_entire_file(peer_temp, peer_res.stdout)

	merge_res := run_git({"merge-file", file_path, base_temp, peer_temp})

	if merge_res.exit_code == 0 {
		fmt.printf("Cleanly merged '%s' from @%s\n", file_path, peer)
	} else {
		fmt.printf("Conflict in '%s' with @%s! Generating diff file...\n", file_path, peer)
		create_collision_diff(file_path, peer, peer_ref)
	}
}

create_collision_diff :: proc(file_path, peer, peer_ref: string) {
	diff_res := run_git({"diff", "HEAD", peer_ref, "--", file_path})
	if !diff_res.ok do return

	diff_filename := fmt.tprintf("%s.%s.diff", file_path, peer)
	_ = os.write_entire_file(diff_filename, diff_res.stdout)
}

get_safe_username :: proc() -> string {
	raw_user := get_active_username()
	if len(raw_user) == 0 {
		return "anonymous"
	}
	cleaned := strings.to_lower(raw_user, context.temp_allocator)
	cleaned, _ = strings.replace_all(cleaned, " ", "-", context.temp_allocator)
	return cleaned
}

get_active_peer_handles :: proc(current_user: string) -> [dynamic]string {
	peers := make([dynamic]string, context.temp_allocator)
	res := run_git({"for-each-ref", "--format=%(refname:short)", "refs/remotes/sync/"})
	if !res.ok do return peers

	lines := strings.split_lines(res.stdout, context.temp_allocator)
	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 do continue

		parts := strings.split(trimmed, "/", context.temp_allocator)
		if len(parts) >= 2 {
			peer_handle := parts[len(parts) - 1]
			if peer_handle != current_user {
				append(&peers, peer_handle)
			}
		}
	}
	return peers
}

get_changed_files_between :: proc(ref_a, ref_b: string) -> [dynamic]string {
	files := make([dynamic]string, context.temp_allocator)
	args: [dynamic]string
	append(&args, "diff", "--name-only")
	if len(ref_a) > 0 do append(&args, ref_a)
	if len(ref_b) > 0 do append(&args, ref_b)

	res := run_git(args[:])
	if !res.ok do return files

	lines := strings.split_lines(res.stdout, context.temp_allocator)
	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) > 0 {
			append(&files, trimmed)
		}
	}
	return files
}
