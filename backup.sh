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
LOCKFILE="${TMPDIR:-/tmp}/backup-script.lock"
LOG_DIR="${HOME}/backup-logs"
OUT_LOG="${LOG_DIR}/out.log"
ERR_LOG="${LOG_DIR}/err.log"
# param file lists
PREV_PF="${LOG_DIR}/prev-pf"
CURR_PF="${LOG_DIR}/curr-pf"


########################
# diagnostic functions #
########################

die () {
    printf "%s\n" "ERROR: ${1}." 1>&2  # stderr
    exit 1
}

warn () {
    printf "%s\n" "WARNING: ${1}." 1>&2  # stderr
}

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


#####################
# lockfile handling #
#####################

if [ ! -e "$LOCKFILE" ]; then
    touch "$LOCKFILE"
else
    die "Lockfile exists"
fi

cleanup () {
    rm -f "$LOCKFILE"
}
trap cleanup EXIT


########################
# command availability #
########################

if ! command -v rsync > /dev/null 2>&1; then
    die "Rsync is not available"
fi


##################
# option parsing #
##################

bu_roots_raw=()
server=""
target_dir=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--root)
            bu_roots_raw+=("$2")
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
if [ "${#bu_roots_raw[@]}" -eq 0 ]; then
    die "No backup roots given"
fi
bu_roots=()
for root in "${bu_roots_raw[@]}"; do
    if [ ! -e "$root" ]; then
        die "Backup root '$root' does not exist"
    fi
    if [ ! -d "$root" ]; then
        die "Backup root '$root' is not a directory"
    fi

    # make sure roots with relative paths will work after we cd
    if [ "${root#/}" = "$root" ]; then
        bu_roots+=("${PWD}/${root}")
    else
        bu_roots+=("$root")
    fi
done
if [ -z "$server" ]; then
    die "No server given"
fi


#############
# main body #
#############

mkdir -p "$LOG_DIR"

# not really necessary, but does keep any files we forgot to specify a location
# for in a reasonable place
cd "$LOG_DIR" || die "Can't cd to log dir"

# get directories to back up (including parameter files)
if [ -e "$CURR_PF" ]; then
    mv -f "$CURR_PF" "$PREV_PF"  # overwrite if present
fi
echo "Looking for directories to back up..."
find "${bu_roots[@]}" -depth 2 -type f -name "$PARAM_FILE" | tee "$CURR_PF"
if [ ! -s "$CURR_PF" ]; then
    echo "None found."
fi

# display changes from previous run
if [ -e "$PREV_PF" ]; then
    echo "PREVIOUS PARAM FILES < > CURRENT PARAM FILES"
    set +e  # diff returns 1 if files aren't identical
    # will have false positives if PARAM_FILE has changed
    list_diff=$(diff <(sort "$PREV_PF") <(sort "$CURR_PF"))
    set -e
    if [ -n "$list_diff" ]; then
        printf "%s\n" "$list_diff"
    else
        echo "(no differences)"
    fi
else
    echo "No previous directory list found."
fi

# loop over the directories (param files) to back up;
# see http://mywiki.wooledge.org/BashFAQ/001
cat "$CURR_PF" | while IFS= read -r param_file || [ -n "$param_file" ]; do
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
