package main

import "core:os"
import "core:fmt"
import "core:strings"

get_repo_name :: proc(url: string) -> string {
    clean_url := strings.trim_space(url)
	
    if strings.has_suffix(clean_url, ".git") {
    	clean_url = clean_url[:len(clean_url) - 4]
    }

    last_slash := strings.last_index_byte(clean_url, '/')
    last_colon := strings.last_index_byte(clean_url, ':')
    idx := max(last_slash, last_colon)

    if idx != -1 && idx < len(clean_url) - 1 {
	return clean_url[idx + 1:]
    }

    return "repo"
}

exec_clone :: proc() {
    if len(os.args) < 3 {
	fmt.println("Error: Missing repository URL.")
	fmt.println("Usage: gfd clone <url> [target_directory]")
	return
    }
    repo := os.args[2]
    
    target_dir := os.args[3] if len(os.args) >= 4 else ""

    fmt.printf("Cloning %s,,,\n", repo)

    args : [dynamic]string
    defer delete(args)

    append(&args, "clone", repo)
    if target_dir != "" do append(&args, target_dir)

    res := run_git(args[:])
    if !res.ok {
	fmt.eprintln("clone failed:", res.stderr)
	return
    }
    dir_name := target_dir

    if dir_name == "" {
	dir_name = get_repo_name(repo)
    }

    fmt.println("configuring gfd shadow refspec...")

    refspec := "+refs/sync/*:refs/remotes/sync/*"
    cfg_res := run_git({"-C", dir_name, "config", "--add", "remote.origin.fetch", refspec})

    if !cfg_res.ok {
	fmt.eprintln("failed to configure gfd refspec:", cfg_res.stderr)
	return
    }

    fmt.println("\n[gfd] repository ready")
    fmt.printf("  cd %s\n", dir_name)
    fmt.println("  gfd tasks     # check open assignments")
    fmt.println("  gfd watch     # start background file sync")
}

