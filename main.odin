package main

import "core:os"
import "core:fmt"

Git_Result :: struct {
	stdout:   string,
	stderr:   string,
	exit_code: int,
	ok:        bool,
}

run_git :: proc(args: []string, allocator := context.allocator) -> Git_Result {
	full_args := make([]string, len(args) + 1, context.temp_allocator)
	full_args[0] = "git"
	for arg, i in args {
		full_args[i + 1] = arg
	}

	desc := os.Process_Desc {
		command = full_args,
	}

	state, stdout, stderr, err := os.process_exec(desc, allocator)
	if err != nil {
		return Git_Result{ok = false}
	}

	return Git_Result{
		stdout    = string(stdout),
		stderr    = string(stderr),
		exit_code = state.exit_code,
		ok        = state.exit_code == 0,
	}
}

print_usage :: proc() {
	fmt.println("gfd - Frictionless Git Sync & Task Manager\n")
	fmt.println("USAGE:")
	fmt.println("  gfd <command> [arguments]\n")
	fmt.println("COMMANDS:")
	fmt.println("  clone <url>        Clone a repo and configure shadow sync refspecs")
	fmt.println("  init               Initialize gfd tracking in an existing Git repo")
	fmt.println("  sync               Perform a manual push/fetch sync of shadow work")
	fmt.println("  watch              Run continuous file watcher daemon in background")
	fmt.println("  status             Show daemon health, uncommitted files, and peer sync")
	fmt.println("  tasks [username]   Scan source files for @username task comments")
	fmt.println("  milestone <msg>    Squash shadow work into a clean main branch commit")
	fmt.println("  rollback           Discard local shadow work and revert to last main milestone\n")
	fmt.println("EXAMPLES:")
	fmt.println("  gfd clone git@github.com:team/game.git")
	fmt.println("  gfd tasks alex")
	fmt.println("  gfd milestone \"Fixed collision detection system\"")
}

main :: proc() {
    args := os.args
    
    if len(args) < 2 {
        print_usage()
        return
    }

    switch args[1] {
        case "clone": exec_clone() 
	case "init": exec_init() 
	case "sync": exec_sync() 
	case "watch": exec_watch()
	case "status": exec_status() 
	case "tasks": exec_tasks()
	case "milestone": exec_milestone() 
	case "rollback": exec_rollback() 
	case: {
	    fmt.printf("Unknown command: %s\n\n", args[1])
	    print_usage()
	}
    }
}
