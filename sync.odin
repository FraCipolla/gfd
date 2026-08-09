package main

import "core:fmt"
import "core:os"
import "core:strings"

is_ignored_path :: proc(path: string) -> bool {
	if strings.has_prefix(path, ".gfd") || strings.contains(path, "/.gfd") {
		return true
	}
	if strings.has_suffix(path, ".diff") {
		return true
	}
	return false
}

is_file_modified_locally :: proc(file_path, user: string) -> bool {
	user_shadow_ref := fmt.tprintf("refs/sync/%s", user)
	rev_res := run_git({"rev-parse", user_shadow_ref})

	target_ref := "HEAD"
	if rev_res.ok {
		target_ref = user_shadow_ref
	}

	diff_res := run_git({"diff", "--quiet", target_ref, "--", file_path})
	return diff_res.exit_code != 0
}

get_active_peer_handles :: proc(user: string) -> [dynamic]string {
	peers := make([dynamic]string, context.temp_allocator)
	res := run_git({"for-each-ref", "--format=%(refname:short)", "refs/remotes/sync"})
	if !res.ok do return peers

	lines := strings.split_lines(res.stdout, context.temp_allocator)
	prefix := "sync/"
	for line in lines {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, prefix) {
			handle := trimmed[len(prefix):]
			if handle != user {
				append(&peers, handle)
			}
		}
	}
	return peers
}

get_changed_files_between :: proc(ref_a, ref_b: string) -> [dynamic]string {
	files := make([dynamic]string, context.temp_allocator)
	res := run_git({"diff", "--name-only", ref_a, ref_b})
	if !res.ok do return files

	lines := strings.split_lines(res.stdout, context.temp_allocator)
	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) > 0 && !is_ignored_path(trimmed) {
			append(&files, trimmed)
		}
	}
	return files
}

try_clean_auto_merge :: proc(file_path, peer_ref, user: string) -> bool {
	os.make_directory_all(".gfd")

	safe_name, _ := strings.replace_all(file_path, "/", "_", context.temp_allocator)
	safe_name, _ = strings.replace_all(safe_name, "\\", "_", context.temp_allocator)

	temp_merged := fmt.tprintf(".gfd/tmp_merged_%s", safe_name)
	temp_base := fmt.tprintf(".gfd/tmp_base_%s", safe_name)
	temp_theirs := fmt.tprintf(".gfd/tmp_theirs_%s", safe_name)

	working_bytes, err := os.read_entire_file(file_path, context.temp_allocator)
	if err != nil do return false
	_ = os.write_entire_file(temp_merged, working_bytes)

	user_shadow_ref := fmt.tprintf("refs/sync/%s:%s", user, file_path)
	base_res := run_git({"show", user_shadow_ref})
	if base_res.ok {
		_ = os.write_entire_file(temp_base, base_res.stdout)
	} else {
		head_res := run_git({"show", fmt.tprintf("HEAD:%s", file_path)})
		if head_res.ok {
			_ = os.write_entire_file(temp_base, head_res.stdout)
		} else {
			_ = os.write_entire_file(temp_base, "")
		}
	}

	peer_file_ref := fmt.tprintf("%s:%s", peer_ref, file_path)
	theirs_res := run_git({"show", peer_file_ref})
	if theirs_res.ok {
		_ = os.write_entire_file(temp_theirs, theirs_res.stdout)
	} else {
		os.remove(temp_merged)
		os.remove(temp_base)
		return false
	}

	res := run_git({"merge-file", temp_merged, temp_base, temp_theirs})

	if res.exit_code == 0 {
		merged_bytes, read_err := os.read_entire_file(temp_merged, context.temp_allocator)
		if read_err == nil {
			_ = os.write_entire_file(file_path, merged_bytes)
		}
		os.remove(temp_merged)
		os.remove(temp_base)
		os.remove(temp_theirs)
		return true
	}

	os.remove(temp_merged)
	os.remove(temp_base)
	os.remove(temp_theirs)
	return false
}

push_local_shadow_branch :: proc(user: string) {
	run_git({"add", "-A", "--", ":!.gfd"})
	write_tree_res := run_git({"write-tree"})
	if !write_tree_res.ok do return
	tree_hash := strings.trim_space(write_tree_res.stdout)

	head_res := run_git({"rev-parse", "HEAD"})
	if !head_res.ok do return
	head_commit := strings.trim_space(head_res.stdout)

	user_ref := fmt.tprintf("refs/sync/%s", user)
	rev_res := run_git({"rev-parse", user_ref})
	parent_commit := head_commit
	if rev_res.ok {
		parent_commit = strings.trim_space(rev_res.stdout)
	}

	commit_res := run_git({"commit-tree", tree_hash, "-p", parent_commit, "-m", "gfd-auto-sync"})
	if !commit_res.ok do return
	shadow_hash := strings.trim_space(commit_res.stdout)

	_ = run_git({"update-ref", user_ref, shadow_hash})

	push_ref := fmt.tprintf("%s:refs/sync/%s", shadow_hash, user)
	_ = run_git({"push", "origin", push_ref, "--force"})
}

exec_sync :: proc() {
	user := get_active_username()
	_, ok := get_git_root()
	if !ok do return

	run_git({"fetch", "origin", "+refs/sync/*:refs/remotes/sync/*"})

	peers := get_active_peer_handles(user)

	local_shadow_ref := fmt.tprintf("refs/sync/%s", user)
	base_ref := "HEAD"
	rev_res := run_git({"rev-parse", local_shadow_ref})
	if rev_res.ok {
		base_ref = local_shadow_ref
	}

	for peer in peers {
		peer_ref := fmt.tprintf("refs/remotes/sync/%s", peer)
		peer_rev := run_git({"rev-parse", peer_ref})
		if !peer_rev.ok do continue

		changed_files := get_changed_files_between(base_ref, peer_ref)

		for file_path in changed_files {
			is_editing_locally := is_file_modified_locally(file_path, user)

			if !is_editing_locally {
				run_git({"checkout", peer_ref, "--", file_path})
				fmt.printf("[gfd] Updated '%s' from @%s\n", file_path, peer)
			} else {
				if try_clean_auto_merge(file_path, peer_ref, user) {
					fmt.printf("[gfd] Auto-merged @%s's lines into '%s'\n", peer, file_path)
				} else {
					fmt.printf("[gfd] Conflict on '%s' with @%s. Local edits preserved.\n", file_path, peer)
				}
			}
		}
	}

	push_local_shadow_branch(user)
}
