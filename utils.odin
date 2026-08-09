package main

import "core:os"
import "core:strings"

get_git_root :: proc() -> (string, bool) {
    res := run_git({"rev-parse", "--show-toplevel"})
    if !res.ok {
	return "", false
    }
    return strings.trim_space(res.stdout), true
}

get_active_username :: proc() -> string {
	if res := run_git({"config", "gfd.user"}); res.ok {
		name := strings.trim_space(res.stdout)
		if len(name) > 0 {
			return strings.to_lower(name, context.temp_allocator)
		}
	}

	if res := run_git({"config", "user.name"}); res.ok {
		name := strings.trim_space(res.stdout)
		if len(name) > 0 {
			fields := strings.fields(name, context.temp_allocator)
			if len(fields) > 0 {
				return strings.to_lower(fields[0], context.temp_allocator)
			}
		}
	}

	if os_user := os.get_env("USER", context.temp_allocator); len(os_user) > 0 {
		return strings.to_lower(os_user, context.temp_allocator)
	}
	if os_user := os.get_env("USERNAME", context.temp_allocator); len(os_user) > 0 {
		return strings.to_lower(os_user, context.temp_allocator)
	}

	return "unknown"
}
