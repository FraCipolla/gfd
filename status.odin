package main

import "core:fmt"
import "core:strings"
import "core:os"
import "core:strconv"
import "core:path/filepath"

exec_status :: proc() {
    root_dir, ok := get_git_root()
    if !ok {
	fmt.eprintln("error: not inside a Git repository.")
	return
    }

    user := get_active_username()

    branch := "HEAD (detached)"
    if res := run_git({"branch", "--show-current"}); res.ok {
	b := strings.trim_space(res.stdout)
	if len(b) > 0 do branch = b
    }
    uncommitted_count := 0
    if status_res := run_git({"status", "--short"}); status_res.ok {
	lines := strings.split_lines(status_res.stdout, context.temp_allocator)
	for line in lines {
	    if len(strings.trim_space(line)) > 0 {
		uncommitted_count += 1
	    }
	}
    }

    shadow_res := run_git({
	"for-each-ref",
	"--format=%(refname:short)|%(committerdate:relative)",
	"refs/remotes/sync/",
    })

    fmt.println("=== GFD WORKSPACE STATUS ===")
    fmt.printf("Repository:   %s\n", root_dir)
    fmt.printf("Branch:       %s\n", branch)
    fmt.printf("Active User:  @%s\n\n", user)
    if uncommitted_count == 0 {
	fmt.println("working tree: clean (no local edits)")
    } else {
	fmt.printf("working tree: %d local file(s) modified/untracked\n", uncommitted_count)
    }

    fmt.println("\npeer shadow branches:")
    peer_found := false

    if shadow_res.ok {
	lines := strings.split_lines(shadow_res.stdout, context.temp_allocator)
	for line in lines {
	    trimmed := strings.trim_space(line)
	    if len(trimmed) == 0 do continue

	    parts := strings.split(trimmed, "|", context.temp_allocator)
	    if len(parts) == 2 {
		ref_name := parts[0]
		last_slash := strings.last_index_byte(ref_name, '/')
		peer_name := ref_name

		if last_slash != -1 && last_slash < len(ref_name)-1 {
		    peer_name = ref_name[last_slash+1:]
		}

		if peer_name != user {
		    peer_found = true
		    fmt.printf("  • @%-12s (synced %s)\n", peer_name, parts[1])
		}
	    }
	}
    }

    if !peer_found {
	fmt.println("  (no teammate shadow branches detected)")
    }

    fmt.println("\nactions:")
    fmt.println("  gfd sync            # push local shadow state & pull peers")
    fmt.println("  gfd tasks           # list assigned @mentions")
    fmt.println("  gfd milestone \"...\" # publish current state to main")
}

