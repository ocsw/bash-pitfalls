#!/usr/bin/env bash

###############
# shell setup #
###############

set -eo pipefail
# set -x  # for debugging


##########################
# settings and constants #
##########################

# file names / paths
PARAM_FILE=".back_me_up"
LOG_DIR="${HOME}/backup-logs"
OUT_LOG="${LOG_DIR}/out.log"
ERR_LOG="${LOG_DIR}/err.log"


##################
# option parsing #
##################

bu_root=""
server=""
target_dir=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--root)
            bu_root="$2"
            shift
            shift
            ;;
        -s|--server)
            server="$2"
            shift
            shift
            ;;
        -d|--target_dir)
            target_dir="$2"
            shift
            shift
            ;;
    esac
done

# check option validity
if [ -n "$bu_root" ]; then
    echo "ERROR: No backup root given."
    exit 1
fi
if [ ! -e "$bu_root" ]; then
    echo "ERROR: Backup root '$bu_root' does not exist."
    exit 1
fi
if [ ! -d "$bu_root" ]; then
    echo "ERROR: Backup root '$bu_root' is not a directory."
    exit 1
fi
if [ -z "$server" ]; then
    echo "ERROR: No server given."
    exit 1
fi


#############
# main body #
#############

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
