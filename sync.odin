package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

exec_sync :: proc() {
    user := get_active_username()
    fmt.printf("[gfd sync] syncing active workspace for @%s...\n", user)

    run_git({"add", "-A"})
    run_git({"commit", "-m", "gfd-auto-sync", "--allow-empty"})

    shadow_ref := fmt.tprintf("HEAD:refs/sync/%s", user)
    push_res := run_git({"push", "origin", shadow_ref, "--force"})
    if !push_res.ok {
	fmt.eprintln("failed to push shadow ref:", push_res.stderr)
	return
    }

    fetch_res := run_git({"fetch", "origin"})
    if !fetch_res.ok do return

    peers := get_active_peer_handles(user)

    for peer in peers {
	peer_ref := fmt.tprintf("refs/remotes/sync/%s", peer)

	local_changes := get_changed_files_between("HEAD", "")

	peer_changes := get_changed_files_between("HEAD", peer_ref)

	for peer_file in peer_changes {
	    is_local_dirty := contains_file(local_changes, peer_file)

	    if !is_local_dirty {
		checkout_ref := fmt.tprintf("%s:%s", peer_ref, peer_file)
		fmt.printf("    auto-merging '%s' from @%s\n", peer_file, peer)
		run_git({"checkout", peer_ref, "--", peer_file})
	    } else {
		fmt.printf("  ⚠️ collision detected in '%s' with @%s!\n", peer_file, peer)
		create_collision_diff(peer_file, peer, peer_ref)
	    }
	}
    }

    fmt.println("[gfd sync] workspace sync complete!")
}

create_collision_diff :: proc(file_path, peer, peer_ref: string) {
    diff_res := run_git({"diff", "HEAD", peer_ref, "--", file_path})
    if !diff_res.ok do return

    diff_filename := fmt.tprintf("%s.%s.diff", file_path, peer)

    err := os.write_entire_file(diff_filename, transmute([]byte)diff_res.stdout)
    if err == nil {
	fmt.printf("     ➜ generated collision diff: %s\n", diff_filename)
    }
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

contains_file :: proc(list: [dynamic]string, target: string) -> bool {
    for item in list {
	if item == target do return true
    }
    return false
}

get_active_peer_handles :: proc(current_user: string) -> [dynamic]string {
    peers := make([dynamic]string, context.temp_allocator)

    res := run_git({"for-each-ref", "--format=%(refname:short)", "refs/remotes/sync/"})
    if !res.ok do return peers

    lines := strings.split_lines(res.stdout, context.temp_allocator)
    for line in lines {
	trimmed := strings.trim_space(line)
	if len(trimmed) == 0 do continue

	// Expected format: sync/username
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
