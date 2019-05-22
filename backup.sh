#!/usr/bin/env bash

set -eo pipefail
# set -x  # for debugging

# file names / paths
PARAM_FILE=".back_me_up"
LOG_DIR="${HOME}/backup-logs"
OUT_LOG="${LOG_DIR}/out.log"
ERR_LOG="${LOG_DIR}/err.log"

bu_root="$1"
server="$2"
target_dir="$3"

mkdir -p "$LOG_DIR"

# loop over the directories (param files) to back up;
# see http://mywiki.wooledge.org/BashFAQ/001
find "$bu_root" -depth 2 -type f -name "$PARAM_FILE" | \
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
            >> "$OUT_LOG" 2>> "$ERR_LOG"
    done
