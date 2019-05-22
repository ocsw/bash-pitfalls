# Changelog and Notes

## Add an MVP

- Use `rsync` to back up directories that are directly under a root (`$1`) which contain a file called `.back_me_up`
- Send them to a server (`$2`) and location on that server (`$3`, or the `rsync` default if not specified)
- (`for` loop syntax)
- Creating / setting variables uses the bare variable name; to use, prefix with `$`
- `$1`, `$2`, `$3` are command-line arguments
    - They default to empty strings; more on this later
- Use `${10}`, etc. for more than 9 arguments (Bash-specific)
- `*` is a glob (like a super-simplified regex) - it expands to all files that contain 0 or more characters in place of the `*`
- `$()` is replaced with what the command inside it prints
    - It can be used in many places - in commands, in strings, in variable assignments...
- `dirname` prints the directory component of a file path, normalized
- You might be used to using `sed` or a variable trimming operator for this, but `dirname` handles things like multiple consecutive slashes, `.` and `..`, and so on
- We need quotes around the `$()` because the result might contain a space; the shell would break it into two arguments to `rsync`
- We also need quotes around the argument to `dirname` for the same reason
- (In this context, we can nest quotes and the shell does what we expect; not so in others)
- Double quotes (`"`) allow variable expansion and other substitutions inside them; single quotes (`'`) don't (they are literal)
- To embed a double-quote or other special characters like `$` in a double-quoted string, prefix it with a backslash (e.g. `\"`); this doesn't work in single-quoted strings (even for a single-quote!)
- When using a variable with characters after the name that are ambiguous, enclose the name (but not the `$`) in curly braces (`{}`)
    - In this case, : is actually an operator
    - Erring on the side of caution may also help readability; I use braces in almost any string that has anything after the variable name but a space
- This code has a fundamental quoting problem: the filename expansion is inside quotes, so the list of files will be treated as a single string, and the loop will be run once on that string

## Fix the shebang line

- Also remove the run line - run it directly
- Needs to be executable (e.g. `chmod 700` or `755`)

## Initial commit - shebang line and run note

- When you run an executable, the OS looks for a shebang line and feeds the script to it
- It must be the first line of the file
- It must start with `#!` (hash bang / shebang)
- It's a comment from the shell's perspective
- No space after `#!` (for portability)
- Program and maximum one argument (for portability)
- `#!/bin/bash` vs `#!/usr/bin/env bash`
    - Fixed path might not be available
    - With env, find `bash` if it's in `$PATH`
    - On MacOS with `brew`'s `bash`:
        - The first one is MacOS `bash` (3.2.x)
        - The second is `brew`'s `bash` (5.0.x)
- `scriptname args` vs `bash scriptname args`
    - The first uses the shebang line including arguments
    - The second uses the `bash` in the `PATH`, with only the arguments you specify
