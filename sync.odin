package main

import "core:fmt"

exec_sync :: proc() {
	user := get_active_username()
	fmt.printf("syncing workspace for '%s'...\n", user)

	if res := run_git({"add", "-A"}); !res.ok {
		fmt.eprintln("failed to stage changes:", res.stderr)
		return
	}

	run_git({"commit", "-m", "gfd-auto-sync", "--allow-empty"})

	shadow_ref := fmt.tprintf("HEAD:refs/sync/%s", user)
	push_res := run_git({"push", "origin", shadow_ref, "--force"})
	if !push_res.ok {
		fmt.eprintln("push failed:", push_res.stderr)
		return
	}

	fetch_res := run_git({"fetch", "origin"})
	if !fetch_res.ok {
		fmt.eprintln("fetch failed:", fetch_res.stderr)
		return
	}

	fmt.println("\n[gfd] sync complete! Remote shadow branch updated and peer changes fetched.")
}
