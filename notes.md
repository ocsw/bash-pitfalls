# Changelog and Notes

## Diagnostic functions

- So far, we've had to manually print a message and then exit whenever there's an error
    - (Note that we could also just let the script die due to `set -e`, but handling them explicitly allows us to control the output and behavior - for example, setting a different exit value)
- This manual work is error-prone and duplicative; instead, let's factor out some diagnostic functions
- `die()` handles:
    - Printing a message
    - Printing to `stderr` (easy to forget!)
    - Adding an 'ERROR:' prefix so our output is consistent, but we don't have to add it manually every time
    - Exiting with a non-0 value
- `warn()` is extremely similar, but doesn't exit; it's useful for less-catastrophic problems
- We'll replace all of our error-handling code with calls to `die()`
- Note that this makes the check on `cd` much shorter and more readable
- We haven't used `warn()` yet, but it's not a bad idea to have both functions available
- We've used `printf` for printing the diagnostic messages, instead of the more-familiar `echo`:
    - `echo` can't be used portably to print strings that contain variables, due to differences in control-character handling
    - In principle, `printf` should be preferred for everything, but I'm ok with using `echo` for fixed strings
    - The `printf` command is followed by a format string, then one or more input strings to format and print
    - Technically, the format string can be in either single- or double-quotes, but I prefer to use double-quotes to match the usual format of the input string(s)
    - The format string is interpreted by `printf` itself - as far as the shell is concerned, that `\n` is two separate characters!
    - `printf` takes essentially the same format and escape characters as the C function of the same name
    - The format string is typically `%s\n` - a string followed by a newline character
    - Without the `\n`, the string will be output without proceeding to the next line, which is sometimes helpful
    - If there are multiple input strings, `printf` will apply the format string to each of them in turn, so if we want to just print the input string normally, the whole thing must be in quotes
    - It's also possible to have additional text in the format string; this makes it possible to do things like `printf "word: %s\n" word1 word2 word3`, which yields 3 lines:
        - `word: word1`
        - `word: word2`
        - `word: word3`

## Check command availability

- Sometimes it can be a good idea to check if certain commands are available on the system (and in the PATH) before you get too far into a script
- There are several ways you can do this:
    - The `where` command checks the PATH, but isn't portable, and doesn't include shell aliases and functions
    - `hash` is a shell builtin, and is portable
    - `command` is Bash-specific, but has some useful features to know about:
        - `command -v cmd` prints the path to `cmd` if it's in the path, the text of an alias, or the name of a function
        - `command -V cmd` prints more information about `cmd`, including the entire text of functions
        - `command cmd` runs `cmd`, bypassing any aliases with the same name (you can also do `\aliasname`)
- `/dev/null` is a special file that discards any input written to it, and returns `EOF` (End-Of-File) if read
- `> /dev/null` discards the output of `command` on `stdout`
- `2>&1` redirects `stderr` to the same place as `stdout`
- The order of multiple redirects matters; they are processed from left to right
- This means that `stderr` goes to `/dev/null` as well
- In the other order (`2>&1 >/dev/null`), `stdout` would be discarded, but then `stderr` would be redirected to the normal `stdout`, and printed
- `> /dev/null 2>&1` is an extremely common idiom to discard all output from a command, on both `stdout` and `stderr`, and is particularly useful in tests, where we don't want to actually print anything

## Handle relative roots

- Directory paths can be absolute (starting with `/`, the root of the filesystem), or relative (no directory, or starting with `./` (relative to the CWD) or `../` (relative to the CWD's parent directory)
- Because we're no longer in the directory we were started from, any roots given on the command line that are relative paths won't work anymore
- To handle this, we'll use a typical pattern: collect 'raw' data, then use it to populate a 'real' variable
    - These names are somewhat arbitrary, but it's a common programming pattern in many languages
- Instead of collecting `bu_roots`, we'll collect `bu_roots_raw`, populate a separate `bu_roots` array, and use that in the remainder of the script
- For each root, we'll check if it's relative, and if so, turn it into an absolute path relative to the `$PWD` the script is started under
- `"${root#/}"` is replaced with the value of `$root`, after a pattern removal operation
    - If the value starts with `/`, that string is removed from the beginning of the replacement value
    - Otherwise, the full value is used
- Bash has four of these operators; they aren't 100% portable, but are mandated by POSIX
    - The string after the operator can be a glob (containing `*`, `?`, or `[...]`) but not a regex
    - \# and ## work at the beginning of the variable's value (mnemonic: # starts a comment)
    - % and %% work at the end of the variable's value (mnemonic: 100%)
    - The single-character operators take only the minimum match when a glob is used
    - The two-character operators take the maximum match when a glob is used
    - Examples, with `foo=aabbcc`:
        - `"${foo#a}" -> abbcc` (simple pattern, minimal, at the beginning of the value)
        - `"${foo##a}" -> abbcc` (simple pattern, maximal, at the beginning of the value)
        - `"${foo%c}" -> aabbc` (simple pattern, minimal, at the end of the value)
        - `"${foo%%c}" -> aabbc` (simple pattern, maximal, at the end of the value)
        - `"${foo#*b}" -> bcc` (glob pattern, minimal, at the beginning of the value)
        - `"${foo##*b}" -> cc` (glob pattern, maximal, at the beginning of the value)
        - `"${foo%b*}" -> aab` (glob pattern, minimal, at the end of the value)
        - `"${foo%%b*}" -> aa` (glob pattern, maximal, at the end of the value)
- There are more such operators that are Bash-specific, such as for pattern deletion/substitution and (in Bash4) case-modification
    - Pattern deletion looks like `"${foo/PATTERN}"`
    - Pattern substitution looks like `"${foo/PATTERN/STRING}"`
    - All globs are matched maximally
    - Patterns starting with an extra `/` are applied to all matches, otherwise only the first match is deleted/substituted
    - Patterns starting with `#` are applied only at the beginning of the value
    - Patterns starting with `%` are applied only at the end of the value
    - There is no way (AFAICT) to do multiple substitutions at the beginning/end of the value
    - Examples, with `foo=aabbcc`:
        - `"${foo/b}" -> aabcc` (simple pattern, deletion anywhere in the value, first match)
        - `"${foo//b}" -> aacc` (simple pattern, deletion anywhere in the value, all matches)
        - `"${foo/[ab]}" -> abbcc` (glob pattern, deletion anywhere in the value, first match)
        - `"${foo//[ab]}" -> cc` (glob pattern, deletion anywhere in the value, all matches)
        - (We've already seen deletion at the beginning and end of the value)
        - `"${foo/b/q}" -> aaqbcc` (simple pattern, substitution anywhere in the value, first match)
        - `"${foo//b/q}" -> aaqqcc` (simple pattern, substitution anywhere in the value, all matches)
        - `"${foo/[ab]/q}" -> qabbcc` (glob pattern, substitution anywhere in the value, first match)
        - `"${foo//[ab]/q}" -> qqqqcc` (glob pattern, substitution anywhere in the value, all matches)
        - `"${foo/#a/q}" -> qabbcc` (simple pattern, substitution at the beginning of the value)
        - `"${foo/%c/q}" -> aabbcq` (simple pattern, substitution at the end of the value)
        - `"${foo/#*a/q}" -> qbbcc` (glob pattern, substitution at the beginning of the value)
        - `"${foo/%c*/q}" -> aabbq` (glob pattern, substitution at the end of the value)
- Note that strings inside arrays should be quoted according to the same rules as elsewhere

## Change to a catch-all directory

- While it's not really necessary in this case, it can be helpful to switch to a known directory
- `cd` (change directory) changes the current working directory (CWD, also known as the PWD or Present Working Directory)
    - Bash provides the `$PWD` variable (Bash-specific), and POSIX mandates the `pwd` utility, for getting the CWD/PWD
- Any file references that don't include a directory path (absolute or relative) will implicitly refer to the CWD
- Therefore, if we forget a directory on a file path in our code, we'll still be able to find the file
- The `!` here is a logical `NOT` of the return value of the `cd`; it's commonly available, but not strictly portable
    - Constructs like `[ ! -f foo]` are more portable and therefore preferred when possible; the `[` / `test` utility is required to support `!`
- This use of `cd` is also intended to demonstrate an often-forgotten best practice: ALWAYS test if your `cd`s succeed, unless you know for certain that it doesn't matter
    - It's very easy to accidentally wipe out or corrupt files in the wrong place if your `cd` fails and you keep going
    - You can use an `if` / `then`, or a simpler `cd foo || die` construct
- Note that some, but NOT all, possible reasons for `cd` to fail can be addressed by preceding with `[ -d dir ]`, but that introduces a race condition and isn't a strong enough test anyway

## Add a usage message

- Another best practice is to print a usage message when a script is invoked improperly, with no arguments (if relevant), or with `-h` or `--help`
- Typically this is put in a function so it can be printed in a variety of circumstances and error conditions
- (function syntax)
    - The function definition can begin with the `function` keyword, and the spaces around the `()` are optional
    - However, the portable, recommended way is to omit the keyword and include the spaces
- Functions are called like any other command
    - More on this later
- It is best practice to print errors and diagnostics to `stderr`
- `1>&2` is a redirect: it moves (adds) `stdout` (file descriptor 1) to `stderr` (file descriptor 2)
    - This means that anything printed to either `stdout` or `stderr` will actually go to `stderr`
- `cat` prints to its `stdout`, so we redirect it to `stderr`
- `<<EOF` starts a 'here document' (usually abbreviated to 'heredoc'); everything from the beginning of the line following the `EOF` is passed as input to the command (with variable and other substitutions like a double-quoted string)
- This also includes newlines and leading spaces/tabs
- The input stops with a line containing only `EOF`, at the beginning of the line
- Note that `EOF` can actually be any string that won't appear in the text, but `EOF` (End of File) is traditional
- A `-` can be prepended to the first `EOF` to allow skipping leading tabs in the string (but not spaces!)
    - (That is, `<<-EOF`)
- This is a fairly typical format for a usage message, although usually options are listed in more of a tabular format
- `$0` is the name the script was invoked as
    - Note that this isn't always what you'd expect, e.g. if you have a symlink to the script
- `[]` in the usage indicates optional arguments
- `...` indicates that more of the same can be given
- Placeholders for arguments are in all caps (although there are other variants)
- We'll print this message if we get an argument we don't recognize, or `-h` or `--help`

## Allow multiple roots

- Now that we have more flexible argument processing, it's easy to allow specifying multiple root directories to search under
- `()` in an assignment is an empty array
- `declare -a bu_roots` would also work
- This is a numerically-indexed array; the indexes don't have to be contiguous
- Arrays are specified as a space-separated list of strings inside parentheses (e.g., `(a b c)`)
    - Spaces after `(` and before `)` are optional
- Bash4 also has associative arrays (dicts / maps), but:
    - Not all systems have Bash4 still (ahem, MacOS)
    - Needing them is a sign that you're probably pushing the limits of what's reasonable in shell
- `+=` adds the elements of one array to another array (via copying)
- `${#bu_roots[@]}` gives the number of elements in the array
- `-eq` tests for numerical equality
- `${bu_roots[@]}` is substituted with the contents of the array, separated with spaces
- Ordinarily, enclosing that in double-quotes would mean having a single long string of all of the array elements
- The `@` has some special magic: when the variable expression is enclosed in double quotes, it is replaced by the elements of the array, *each quoted separately*
- `"$@"` behaves the same way with the command-line arguments
- Replacing the `@` in these two expressions with `*` does the same thing but without the magic property
- `find` accepts multiple roots to search under

## Add section comments

- Since the script is getting longer, let's add comments to easily navigate among the sections
- These are typical sections, in the typical order
- There are also extra blank lines between sections
- The format is personal preference
- However, the box comments can be useful in editors with minimaps

## Improve argument parsing

- While we're improving the argument handling, let's make it possible to specify them in any order, and clarify which is which
- We start with defaults for the variables, which isn't strictly necessary, as we mentioned before, but is good practice
- The empty strings aren't necessary either, but I find the script easier to read this way
- `$#` is a special variable that contains the number of command-line arguments
- `-gt` does an arithmetical (as opposed to lexical) greater-than test
- (`case` syntax)
    - Multiple cases can be specified together, separated by `|`
    - Cases can actually contain globs, as well
    - If cases don't end with `;;`, they fall through
- This is the indentation style I prefer, but indentation is insignificant in Bash
    - (Overall, I have an indentation style based on the Google Python Style Guide; I have mixed feelings about the Google Bash Style Guide, as mentioned earlier)
- The `shift` command removes the first command-line argument and moves the rest down; `$2` becomes `$1`, etc. (i.e., it pops the list)
- Currently, arguments we don't recognize remain in their variables, but we don't look at them after this
- The last time we specify any given argument overrides the previous times
- This `while` / `case` structure is the general best practice for argument handling, although there are other ways involving the `getopts` Bash builtin or the external `getopt` command
    - The benefit of using `getopts` / `getopt` is that they can handle things like `-abc filename`, where `a`, `b`, and `c` are separate options, one of which takes a filename argument - which is hard with the approach we're using here
    - However, `getopts` / `getopt` can typically only handle short options (e.g., no `--verbose`) unless you have the GNU version of `getopt` installed
    - Also, even though the external `getopt` command is specified by POSIX, there is still a bit of variation beyond just long options, e.g. between different Unix OSes
    - If you're ok with not having long arguments, Bash's `getopts` isn't a bad idea, but `getopt` might require a bit of caution regarding different versions
    - Otherwise, the approach we're using here isn't really hugely different, and is fine for most purposes; `getopts` / `getopt` are left as an exercise for the reader

## Validate the arguments

- Let's make sure the arguments to the script are available and valid before we get too far in
- `echo` prints a string (or strings)
- `exit` ends the script and returns a value to the operating system
    - (In Unix/POSIX, 0 means success and anything else means failure)
- `-e` tests for the existence of a file path, without caring if it's a file, directory, symlink, etc.; it's Bash-specific
- `-d` tests if a path exists and is a directory (or a symlink to one)
- `-z` tests if a string is empty (zero-length)
- Note that we have single-quotes inside double-quotes here; they are treated as regular characters, and variables inside the inner quotes are expanded

## Pull out some strings

- We have some literal strings for filenames buried in the code; if we want to check what they are or change them it will be annoying
- These are constants, so best practice is to name them in all caps
    - Note that variable names are case-sensitive, as with most things in Unix
- They are settings for the script, so we put them near the top, for easy reference
    - (They also have to be set before we can rely on their values, so they have to be before most code)
- In general, it is best practice in most programming languages to make all arbitrary strings variables that are set in one place

## Pull out some variables

- Using `$1`, `$2`, and `$3` for the command-line arguments is confusing and error-prone
- We can copy them to variables with better names and use those instead
- Note the quotes
- Note also that this is a copy operation; Bash does everything by value, not by reference

## Use some awk magic

- `awk` programs can contain, prior to the bracketed commands, a specification of what lines they apply to
- `NR`, in `awk`, is a special variable that stands for 'Number of the Record' - which means line number (as opposed to `NF`, 'Number of the Field')
- This addition tells `awk` to only print the field if we're on the first line
- I used `<=` in case we ever want, say, the first 3 lines; you could also use `==`
- This is now a full solution to getting the per-root settings (assuming they never contain a `|` character)

## Use head

- The `head` command extracts just the top N lines of its input
- Most versions of `head` accept an argument like `-10`, but the portable and modern way is (e.g.) `-n 10`
- `head` can take filenames as arguments
- This does work, but there's actually a way to save running extra commands (and some typing)...

## Go back to awk

- `awk` doesn't have the problem `cut` did with missing delimiters
- `-F` specifies the delimiter
- Space between `-F` and the delimiter is optional, but in this case I find the command more readable without it
- Since `|` is a special character for the shell, we need to escape it
    - We can use single-quotes, which can be around just the `|` (string concatenation) or around the entire argument
    - We could also omit the quotes and add a backslash before the `|`, but I prefer this
        - (If it winds up inside a double-quoted string, backslashes get more complicated)
- We still have one problem - what if the `param_file` has more than one line?

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
