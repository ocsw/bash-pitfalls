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


#########
# usage #
#########

usage () {
    cat 1>&2 <<EOF
Usage:
$0 [-h] -r BU_ROOT [-r BU_ROOT ...] -s SERVER [-d TARGET_DIR]

-h (or --help) prints this message.
-r (or --root) BU_ROOT
    BU_ROOT is the top directory to look in for backups.  Can be repeated to
    use multiple roots.
-s (or --server) SERVER
    Directories directly below the root and containing a file called
    $PARAM_FILE will be backed up to SERVER.  This file can be empty, or
    contain per-root overrides; see below.
-d (or --target-dir) TARGET_DIR
    By default, the directories will go to the root of the SERVER.  This can be
    overridden with TARGET_DIR.

Arguments can be overridden on a per-root basis via the $PARAM_FILE files.
The first line of root's file (if non-empty) must be in the format:
    SERVER|TARGET_DIR
This will override both the defaults and the command-line parameters.  Both
parts of this line are optional, but a | character must still be present to
disambiguate.  For example, "SERVER" and "|TARGET_DIR" will both work.  Any
lines after the first will be ignored.

This script assumes that the usernames are the same on both sides of the
transfer and that SSH keys are already taken care of.
EOF
    exit 0
}


##################
# option parsing #
##################

bu_roots=()
server=""
target_dir=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--root)
            bu_roots+=("$2")
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
        -h|--help|*)
            usage
            ;;
    esac
done

# check option validity
if [ "${#bu_roots[@]}" -eq 0 ]; then
    echo "ERROR: No backup roots given."
    exit 1
fi
for root in "${bu_roots[@]}"; do
    if [ ! -e "$root" ]; then
        echo "ERROR: Backup root '$root' does not exist."
        exit 1
    fi
    if [ ! -d "$root" ]; then
        echo "ERROR: Backup root '$root' is not a directory."
        exit 1
    fi
done
if [ -z "$server" ]; then
    echo "ERROR: No server given."
    exit 1
fi


#############
# main body #
#############

mkdir -p "$LOG_DIR"

# not really necessary, but does keep any files we forgot to specify a location
# for in a reasonable place
if ! cd "$LOG_DIR"; then
    echo "ERROR: Can't cd to log dir."
    exit 1
fi

# loop over the directories (param files) to back up;
# see http://mywiki.wooledge.org/BashFAQ/001
find "${bu_roots[@]}" -depth 2 -type f -name "$PARAM_FILE" | \
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
