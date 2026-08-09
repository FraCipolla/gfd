package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:time"

exec_watch :: proc() {
    root_dir, ok := get_git_root()
    if !ok {
	fmt.eprintln("error: not inside a Git repository.")
	return
    }

    user := get_active_username()
    fmt.printf("[gfd watch] Started foreground sync daemon for @%s\n", user)
    fmt.printf("[gfd watch] Monitoring workspace: %s\n", root_dir)
    fmt.println("[gfd watch] Auto-sync active on save. Press Ctrl+C to stop.\n")

    last_sync := time.now()

    for {
	free_all(context.temp_allocator)

	time.sleep(1000 * time.Millisecond)

	latest_mod := get_latest_mod_time(root_dir)

	if time.diff(last_sync, latest_mod) > 0 {
	    time.sleep(300 * time.Millisecond) // Debounce buffer

	    t := time.now()
	    h, m, s := time.clock_from_time(t)
	    fmt.printf("[%02d:%02d:%02d] File change detected. Auto-syncing...\n", h, m, s)

	    exec_sync()

	    last_sync = time.now()
	    fmt.println("[gfd watch] Resuming watch...\n")
	}
    }
}

get_latest_mod_time :: proc(dir_path: string) -> time.Time {
    latest := time.Time{}
    walk_mod_time(dir_path, &latest)
    return latest
}

walk_mod_time :: proc(dir_path: string, latest: ^time.Time) {
    f, err := os.open(dir_path)
    if err != nil do return
    defer os.close(f)

    infos, read_err := os.read_dir(f, -1, context.temp_allocator)
    if read_err != nil do return

    for info in infos {
	full_path, _ := filepath.join({dir_path, info.name}, context.temp_allocator)

	if info.type == .Directory {
	    skip := false
	    for ignored in IGNORED_DIRS {
		if info.name == ignored {
		    skip = true
		    break
		}
	    }
	    if !skip {
		walk_mod_time(full_path, latest)
	    }
	} else {
	    if time.diff(latest^, info.modification_time) > 0 {
		latest^ = info.modification_time
	    }
	}
    }
}
