#!/usr/bin/env bash

set -eo pipefail
# set -x  # for debugging

# loop over the directories (param files) to back up;
# see http://mywiki.wooledge.org/BashFAQ/001
find "$1" -depth 2 -type f -name ".back_me_up" | \
    while IFS= read -r param_file || [ -n "$param_file" ]; do
        rsync -a --delete "$(dirname "$param_file")" "${2}:${3}"
    done
