package main

import "core:os"
import "core:fmt"
import "core:path/filepath"
import "core:strings"
import "core:slice"

IGNORED_DIRS : []string = {
	".git", ".gfd", "build", "bin", "out", ".vs", "node_modules", "target",
}

exec_tasks :: proc() {
	name := os.args[2] if len(os.args) > 2 else get_active_username()

	root_dir, ok := get_git_root()
	if !ok {
		fmt.eprintln("error: not inside a git repository")
		return
	}

	fmt.printf("scanning project tasks for user '%s' in: %s\n\n", name, root_dir)

	found: int = 0

	walk_dir(root_dir, name, &found)

	if found == 0 {
		fmt.printf("no tasks found for user: '%s'\n", name)
	} else {
		fmt.printf("\ntasks found: %d\n", found)
	}
}

walk_dir :: proc(path: string, target_name: string, found: ^int) {
	f, err := os.open(path)
	if err != nil do return
	defer os.close(f)

	entries, read_err := os.read_dir(f, -1, context.temp_allocator)
	if read_err != nil do return

	for entry in entries {
		full_path, alloc_err := filepath.join({path, entry.name}, context.temp_allocator)
		if alloc_err != nil do return

		if entry.type == .Directory {
			if !slice.contains(IGNORED_DIRS[:], entry.name) {
				walk_dir(full_path, target_name, found)
			}
		} else {
			scan_tasks(full_path, target_name, found)
		}
	}
}

scan_tasks :: proc(path: string, target_name: string, found: ^int) {
	data, ok := os.read_entire_file(path, context.temp_allocator)
	if ok != nil do return

	content := string(data)
	lines := strings.split_lines(content, context.temp_allocator)

	raw_tag := fmt.tprintf("@%s", target_name)
	tag := strings.to_lower(raw_tag, context.temp_allocator)

	for line, i in lines {
		lower := strings.to_lower(line, context.temp_allocator)
		if idx := strings.index(lower, tag); idx != -1 {
			found^ += 1
			fmt.printf("%s:%d:%d: %s\n", path, i + 1, idx + 1, strings.trim_space(line[idx:]))
		}
	}
}
