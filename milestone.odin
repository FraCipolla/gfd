package main

import "core:fmt"
import "core:os"

exec_milestone :: proc() {
    args := os.args
    if len(args) < 3 {
	fmt.println("error: missing milestone message.")
	fmt.println("usage: gfd milestone \"<message>\"")
	return
    }

    msg := args[2]
    fmt.printf("recording milestone: \"%s\"...\n", msg)

    if res := run_git({"add", "-A"}); !res.ok {
	fmt.eprintln("failed to stage changes:", res.stderr)
	return
    }

    commit_res := run_git({"commit", "-m", msg})
    if !commit_res.ok {
	fmt.eprintln("commit failed:", commit_res.stderr)
	return
    }

    push_res := run_git({"push", "origin", "HEAD"})
    if !push_res.ok {
	fmt.eprintln("failed to push milestone to remote:", push_res.stderr)
	return
    }

    user := get_active_username()
    shadow_ref := fmt.tprintf("HEAD:refs/sync/%s", user)
    run_git({"push", "origin", shadow_ref, "--force"})

    fmt.println("\n[gfd] milestone committed and pushed to remote main!")
}
