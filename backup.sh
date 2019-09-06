#!/usr/bin/env bash

set -eo pipefail
# set -x  # for debugging

mkdir -p "${HOME}/backup-logs"

# loop over the directories (param files) to back up;
# see http://mywiki.wooledge.org/BashFAQ/001
find "$1" -depth 2 -type f -name ".back_me_up" | \
    while IFS= read -r param_file || [ -n "$param_file" ]; do
        # per-dir settings
        server_override=$(cut -d ' ' -f 1 "$param_file")
        target_dir_override=$(cut -d ' ' -f 2 "$param_file")
        if [ -n "$target_dir_override" ]; then
            actual_target="${target_dir_override}/"
        elif [ -n "$3" ]; then
            actual_target="${3}/"
        else
            actual_target=""
        fi

        # run the backup
        rsync -a --delete "$(dirname "$param_file")" \
            "${server_override:-$2}:${actual_target}" \
            >> "${HOME}/backup-logs/out_log" 2>> "${HOME}/backup-logs/err_log"
    done
