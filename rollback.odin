package main

import "core:fmt"
import "core:strconv"
import "core:os"

exec_rollback :: proc() {
    args := os.args
    steps := 0

    if len(args) >= 3 {
	parsed_steps, ok := strconv.parse_int(args[2])
	if !ok || parsed_steps < 1 {
	    fmt.eprintln("error: rollback step count must be a positive number (e.g., 'gfd rollback 2').")
	    return
	}
	steps = parsed_steps
    }

    target_ref := "HEAD"
    if steps > 0 {
	target_ref = fmt.tprintf("HEAD~%d", steps)
	fmt.printf("rolling back workspace by %d milestone(s) to %s...\n", steps, target_ref)
    } else {
	fmt.println("discarding uncommitted shadow edits and resetting to current HEAD...")
    }

    reset_res := run_git({"reset", "--hard", target_ref})
    if !reset_res.ok {
	fmt.eprintln("rollback failed:", reset_res.stderr)
	return
    }

    run_git({"clean", "-fd"})

    user := get_active_username()
    shadow_ref := fmt.tprintf("HEAD:refs/sync/%s", user)
    run_git({"push", "origin", shadow_ref, "--force"})

    fmt.println("\n[gfd] rollback complete! Workspace and remote shadow updated.")
}
