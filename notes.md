# Changelog and Notes

## Use a better delimiter

- Let's use a delimiter that's not whitespace, so it will be hard to accidentally duplicate, and also can't be in the input
    - I like to use `|` for this, since it's virtually never in filenames, and makes a nice visual separation
    - Note that this is a literal `|` and not a pipeline
- We can also go back to `cut`, since it's simpler and lighter-weight than `awk`
- There's just one (rather subtle) problem: if the input doesn't contain the delimiter, cut (at least in the version I tested) will return the entire string for *any requested field*
    - This would mean we can't specify only the `SERVER`

## Use awk instead of cut

- `awk` is a powerful text-processing language, but its most common use is as a fancier version of `cut` - to extract fields from strings
- By default, it uses whitespace as the delimiter - but it treats multiple whitespace characters as a single delimiter
    - (This is only the case when using the default)
- Its first argument is the 'program' to run; the main body of the program must be enclosed in curly braces (`{}`)
    - More on this later
- Note that the program is also quoted because it contains a space
- However, these are single-quotes, meaning that `$1` and `$2` here are interpreted literally and passed to `awk`
- They are *not* arguments to the shell; instead they are fields within each line, for which `awk` uses the same syntax
- `awk` can also take filenames as input
- This approach fixes the problem of multiple delimiters, but doesn't take into account that the target directory could also contain spaces

## Use cut instead of read

- No quotes are needed around `$()` on the right side of an assignment; this is a Bash-specific exception
- `cut` selects particular fields (`-f`), separated by a delimiter (`-d`), from its input, line by line
    - It also has options for particular bytes or characters
    - The delimiter defaults to tab
    - Spaces between `-d` and the delimiter, and `-f` and the fields, are optional, but I find the command more readable with them
    - Note that it can take filenames as input; we don't need `cat` here
- However, this will still break if there are multiple spaces between the `SERVER` and `TARGET_DIR`, which could easily happen

## Allow per-root settings

- We want to be able to specify a server and/or target directory on the server within the `.back_me_up` files
- We'll use a syntax of `SERVER TARGET_DIR`
- We'll start by using `read` to populate two variables - this time, with word splitting allowed
- `<` redirects input, here from the `param_file`; it is similar to `cat FILE | command` (the `cat` command prints the contents of a file or files)
- Note that this removes the need to run an extra command (`cat`) and is also shorter; using `cat` anyway in a case like this is called a 'Useless Use of Cat' or 'UUOC' (seriously, it's a thing)
- This is useful with many commands that don't accept filenames as arguments, such as `jq` - but note that some commands that we are used to piping into can also take filenames
- (`if` syntax)
- Note that variables that have not been defined default to showing up as an empty string when used, but still maintain their 'unset' status
- `set -u` (or `-o nounset`) forces a script to error out if an unset variable is referenced; this can be helpful in finding bugs, but can also be more trouble than it's worth because it requires some code changes
- Adding a trailing `/` to the target directory prevents the case in which the target doesn't exist, and the source is copied *as* it instead of *into* it
- The `:-` operator is one of several that change the value substituted depending on the unset/empty status of a variable
    - If the variable is unset or null, the string following the operator is substituted, otherwise the value of the variable is substituted as usual
    - Omitting the colon tests only for unset, not empty
- This approach has the drawback that multiple spaces will cause read to fail to split the input correctly

## Add some logging

- `mkdir` creates a directory (or directories)
- You can give it a full path to the new directory
- `mkdir -p` creates any intermediate directories in the path as well, and also prevents errors if the directory already exists
- `HOME` is a special shell variable that contains the path to the current user's home directory
- You can also use a tilde (`~`) in place of `$HOME`, but not within a string
    - Best practice is to never use it in a script
- `>>` and `2>>` are redirects - they send output to files
    - We'll cover these more later
    - Double arrows (`>>` as opposed to `>`) append to files instead of overwriting them
    - `>>` redirects `stdout` and `2>>` redirects `stderr`
    - Spacing around redirects is somewhat flexible, but I tend to add spaces after plain arrows, and omit them if there are things on both sides of the arrow (which is somewhat idiomatic, and also prevents ambiguous constructs)
- Note that on most Unix systems, `$HOME` won't have spaces in it (although this isn't always true on non-Unix systems)
- Nevertheless, best practice is to quote every usage of a variable unless you explicitly want word splitting

## Set some shell settings

- The `set` command sets shell settings
- `-eo` is a combination of `-e` and `-o`
- `-e` makes the script exit with a failure if any command in it fails
    - This is like a primitive `try`/`fail` and can remove the need for some kinds of error handling
    - I prefer to implement manual error handling so I can control what's printed and so on
- `-o` sets options that have no single-letter abbreviation (`-e` can also be written as `-o errexit`)
- Ordinarily, `-e` only causes an exit if an entire command (which can be a pipeline) fails; with `pipefail`, even intermediate commands in a pipeline will cause a script failure if they fail
    - This may or may not be a good idea, depending on your script and programming style
- `-x` (or `-o xtrace`) makes the shell print every command before executing it, and is useful for debugging
    - Comment it out / in as necessary
    - Or, leave it on, especially for scripts that are run from cron and don't have a lot of diagnostics
- To unset, use `set +e` (or `+o`, etc.)
- These can also be passed as parameters to the shell
- It can be helpful to turn them on/off around particular sections of code
- There are a number of other useful options, and a Bash-specific `shopt` command for optional behavior

## Use a pipeline

- This one contains a *ton* of Bash concepts in a small space!
- A pipe character (`|`) sends the output of one command to the input of another
    - Note that this is only `stdout`, not `stderr`, unless we add a redirect (more later)
- It allows us to pass data without it being substituted into the command itself
- There are some very tricky considerations here, though; getting a construct like this fully correct for all inputs is hard, because of word and line splitting
    - See the link
- A backslash at the end of a line allows a command to span multiple lines - but it *must* be the last character on the line
- The Google Bash Style Guide says to break the line before an operator like the `|`, but doing it after helps prevent nasty bugs caused by accidentally having space after the backslash
    - (Without the continuation, the line is invalid and will break)
- (`while` loop syntax)
- `IFS` is a special shell variable, the 'internal field separator'; it tells the shell how to break up strings into words and defaults to space, tab, and newline
- The `IFS=` is actually a variable assignment; with nothing on the right side, it sets the variable to the empty string
    - I usually prefer to put the quotes in for clarity, but this is an idiom, and is actually easier to read because `" "` (a single space) is valid
- Variable assignments may not have space around the `=`
- Shells have their own variables, and all process on a Unix/POSIX system have environment variables
- The `export` command turns a shell variable into an environment variable
- Only environment variables are passed to child processes (commands)
- They are also visible to anyone on the system using comands like `ps` - don't use them for secrets if you don't have total control of the machine!
- In addition to `export`, you can also prepend a command with environment variable assignments to pass to it
- The `read` command puts its input into one or more variables, one line at a time
- EOL is signaled by a newline character
- Always use it with `-r` which prevents escape characters (`\`) from breaking it
- `read` succeeds until it runs out of input (complete lines)
- (We'll come back to how success and failure are tested)
- `||` is the logical OR operator, and it short-circuits; `A || B` means 'do `B` only if `A` succeeds'
- It's a frequent shorthand for error handling in place of an explicit `if`
- There is also an AND operator (`&&`) used for similar purposes
- You can chain `||`s and `&&`s, but never combine them (they don't work quite as expected together)
- `[ ]` runs various kinds of tests
- Here, `-n` tests that the following string is non-empty
    - That's actually the default if you leave out an operator, but I prefer to put it in for clarity)
    - Note that only one string can be supplied, hence the quotes
- Spaces are required around each bracket
    - This is because `[` is actually a command, also available as `test`!
- There is also a `[[ ]]` operator (double square brackets), which is Bash-specific
    - It mostly has the same operations
    - It allows you to leave quotes off of variables
    - It also has a regex matching operator, `=~`
        - The regex must not be quoted
    - I only use it for `[[ ]]`-specific operations like regex matching, for portability and explicitness of requiring Bash
- Putting this all together:
    - We read lines from the `find` command, one by one
    - We don't break them up into words
    - We assign them to the `param_file` variable and run some code
    - When we read the last line, the `read` will return failure
    - If the last line doesn't end in a newline, `read` will fail but still set the variable, so the extra test will catch that case
- We finally have a complete, correct MVP!

## Fix the backquotes

- This is more standard, but will still break if the filenames have spaces - and we can't just quote the whole `$()`, as we've seen
- Another subtle problem is that shells have command-length limits; if there are a huge number of files, things like this will break

## Switch to find

- Let's use the `find` utility instead - it recursively searches for files (here, under `$1`)
- It has a somewhat unusual and complex syntax involving operators and a chain of Boolean operations
- It also returns files in an arbitrary order (technically, the order in which they're stored inside directory inodes)
- The `-depth` operator limits how far down the recursion goes (but it's not portable)
- The `-type` argument lets us specify file types - directories, symlinks, etc.
- The `-name` argument can also take a glob expression, which always needs to be quoted
    - I generally quote even bare strings like this one so that they show up in syntax highlighting and so that I don't miss the quotes if I add a glob operator later
- The backquotes (or backticks) are an obsolete form of `$()`; I use them from the command line because they're easier to type but they should never be used in scripts
    - Among other things, they're not nestable, but `$()` is

## Quote the parameter

- Quoting in shell isn't processed the way you'd expect in a regular programming language; it's more like a toggle for how to process the following output
- So, quoted strings and unquoted text can be right next to each other
- (This is actually how you embed a single-quote in a single-quoted string: `'...'\''...'`)
- Quoting `$1` removes the danger of spaces in that parameter, but if any of the filenames contain spaces, the loop will still run on the parts separately

## Fix the quotes

- Unfortunately, we now have another problem: if `$1` or any of the filenames contain spaces, the loop will run on the parts separately
- Also, there is a Bash gotcha here: if there are no matching files, the literal string `$1/*/.back_me_up` will be substituted

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
