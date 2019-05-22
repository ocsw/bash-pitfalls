#!/usr/bin/env bash

set -eo pipefail
# set -x  # for debugging

bu_root="$1"
server="$2"
target_dir="$3"

mkdir -p "${HOME}/backup-logs"

# loop over the directories (param files) to back up;
# see http://mywiki.wooledge.org/BashFAQ/001
find "$bu_root" -depth 2 -type f -name ".back_me_up" | \
    while IFS= read -r param_file || [ -n "$param_file" ]; do
        # per-dir settings
        server_override=$(awk -F'|' 'NR<=1 {print $1}' "$param_file")
        target_dir_override=$(awk -F'|' 'NR<=1 {print $2}' "$param_file")
        if [ -n "$target_dir_override" ]; then
            actual_target="${target_dir_override}/"
        elif [ -n "$target_dir" ]; then
            actual_target="${target_dir}/"
        else
            actual_target=""
        fi

        # run the backup
        rsync -a --delete "$(dirname "$param_file")" \
            "${server_override:-$server}:${actual_target}" \
            >> "${HOME}/backup-logs/out_log" 2>> "${HOME}/backup-logs/err_log"
    done
