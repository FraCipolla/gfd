package main

import "core:fmt"
import "core:os"
import "core:strings"

has_peer_pushed_new_changes :: proc(peer, current_peer_commit: string) -> bool {
	watermark_path := fmt.tprintf(".gfd/watermarks/%s", peer)
	bytes, err := os.read_entire_file(watermark_path, context.temp_allocator)
	if err != nil || len(bytes) == 0 {
		return true
	}
	last_synced_commit := strings.trim_space(string(bytes))
	return current_peer_commit != last_synced_commit
}

update_peer_watermark :: proc(peer, commit_hash: string) {
	os.make_directory_all(".gfd/watermarks")
	watermark_path := fmt.tprintf(".gfd/watermarks/%s", peer)
	_ = os.write_entire_file(watermark_path, transmute([]byte)commit_hash)
}

get_locally_modified_files :: proc() -> [dynamic]string {
	files := make([dynamic]string, context.temp_allocator)
	res := run_git({"status", "--porcelain"})
	if !res.ok do return files

	lines := strings.split_lines(res.stdout, context.temp_allocator)
	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) < 4 do continue
		file_path := strings.trim_space(trimmed[3:])
		append(&files, file_path)
	}
	return files
}

contains_file :: proc(files: [dynamic]string, target: string) -> bool {
	for f in files {
		if f == target do return true
	}
	return false
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
		if len(trimmed) > 0 {
			append(&files, trimmed)
		}
	}
	return files
}

get_changed_files_between_range :: proc(diff_range: string) -> [dynamic]string {
	files := make([dynamic]string, context.temp_allocator)
	res := run_git({"diff", "--name-only", diff_range})
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

try_clean_auto_merge :: proc(file_path, peer_ref: string) -> bool {
	safe_name, _ := strings.replace_all(file_path, "/", "_", context.temp_allocator)
	safe_name, _ = strings.replace_all(safe_name, "\\", "_", context.temp_allocator)
	temp_merged := fmt.tprintf(".gfd/tmp_%s", safe_name)

	working_bytes, err := os.read_entire_file(file_path, context.temp_allocator)
	if err != nil || len(working_bytes) == 0 do return false
	_ = os.write_entire_file(temp_merged, working_bytes)

	peer_file_ref := fmt.tprintf("%s:%s", peer_ref, file_path)
	res := run_git({"merge-file", temp_merged, "HEAD", peer_file_ref})

	if res.exit_code == 0 {
		merged_bytes, _ := os.read_entire_file(temp_merged, context.temp_allocator)
		_ = os.write_entire_file(file_path, merged_bytes)
		os.remove(temp_merged)
		return true
	}

	os.remove(temp_merged)
	return false
}

push_local_shadow_branch :: proc(user: string) {
	run_git({"add", "-A"})
	write_tree_res := run_git({"write-tree"})
	if !write_tree_res.ok do return
	tree_hash := strings.trim_space(write_tree_res.stdout)

	head_res := run_git({"rev-parse", "HEAD"})
	if !head_res.ok do return
	head_commit := strings.trim_space(head_res.stdout)

	commit_res := run_git({"commit-tree", tree_hash, "-p", head_commit, "-m", "gfd-auto-sync"})
	if !commit_res.ok do return
	shadow_hash := strings.trim_space(commit_res.stdout)

	push_ref := fmt.tprintf("%s:refs/sync/%s", shadow_hash, user)
	_ = run_git({"push", "origin", push_ref, "--force"})
}

exec_sync :: proc() {
	user := get_active_username()
	_, ok := get_git_root()
	if !ok do return

	run_git({"fetch", "origin"})

	my_dirty_files := get_locally_modified_files()
	peers := get_active_peer_handles(user)

	for peer in peers {
		peer_ref := fmt.tprintf("refs/remotes/sync/%s", peer)
		rev_res := run_git({"rev-parse", peer_ref})
		if !rev_res.ok do continue
		current_peer_commit := strings.trim_space(rev_res.stdout)

		if !has_peer_pushed_new_changes(peer, current_peer_commit) {
			continue
		}

		watermark_path := fmt.tprintf(".gfd/watermarks/%s", peer)
		last_commit_bytes, read_err := os.read_entire_file(watermark_path, context.temp_allocator)

		newly_changed_files: [dynamic]string
		if read_err == nil && len(last_commit_bytes) > 0 {
			last_commit := strings.trim_space(string(last_commit_bytes))
			diff_range := fmt.tprintf("%s..%s", last_commit, current_peer_commit)
			newly_changed_files = get_changed_files_between_range(diff_range)
		} else {
			newly_changed_files = get_changed_files_between("HEAD", peer_ref)
		}

		for file_path in newly_changed_files {
			is_editing_locally := contains_file(my_dirty_files, file_path)

			if !is_editing_locally {
				run_git({"checkout", peer_ref, "--", file_path})
				fmt.printf("[gfd] Updated '%s' from @%s\n", file_path, peer)
			} else {
				if try_clean_auto_merge(file_path, peer_ref) {
					fmt.printf("[gfd] Auto-merged @%s's lines into '%s'\n", peer, file_path)
				} else {
					fmt.printf("[gfd] Conflict on '%s' with @%s. Local edits preserved.\n", file_path, peer)
				}
			}
		}

		update_peer_watermark(peer, current_peer_commit)
	}

	push_local_shadow_branch(user)
}
