package main

import "core:fmt"

exec_init :: proc() {
	_, ok := get_git_root()
	if !ok {
		fmt.eprintln("error: Not inside a Git repository. Run 'git init' first.")
		return
	}

	refspec := "+refs/sync/*:refs/remotes/sync/*"
	res := run_git({"config", "--add", "remote.origin.fetch", refspec})

	if !res.ok {
		fmt.eprintln("failed to configure gfd refspecs:", res.stderr)
		return
	}

	fmt.println("[gfd] workspace configured successfully")
	fmt.println("  gfd sync      # sync to current repo status")
	fmt.println("  gfd tasks     # check open assignments")
	fmt.println("  gfd watch     # start background file sync")
}
