# Changelog and Notes

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
