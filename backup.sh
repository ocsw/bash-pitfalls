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

# verbosity constants
VERB_SILENT=0
VERB_BASIC=1
VERB_RSYNC=2


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
$0 [-hv] -r BU_ROOT [-r BU_ROOT ...] -s SERVER [-d TARGET_DIR] [-e EXTRA_ARGS]

-h (or --help) prints this message.
-v (or --verbose) makes the script print more details, such as a comparison
    between this run and the previous run.  Multiple -v options increase
    verbosity further:
-vv makes rsync verbose as well.
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
-e (or --extra) EXTRA_ARGS
    Extra arguments to rsync can be passed with -e, as a single string.
    Multiple arguments can be given within the string, and quotes can be
    embedded (with backslashes if necessary).
    By default, this script assumes that the usernames are the same on both
    sides and that SSH keys are already taken care of; -e can be used to
    address this if necessary.  -e can also be used to make rsync verbose
    without making the entire script verbose.

Arguments can be overridden on a per-root basis via the $PARAM_FILE files.
The first line of root's file (if non-empty) must be in the format:
    SERVER|TARGET_DIR|EXTRA_ARGS
This will override both the defaults and the command-line parameters.  All 3
parts of this line are optional, but | characters must still be present to
disambiguate.  For example, "SERVER", "|TARGET_DIR", "||EXTRA_ARGS", and
"SERVER||EXTRA_ARGS" will all work.  Any lines after the first will be ignored.
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
    # if we got to the backup loop at all, tell the user how far we got
    if [ -n "$successes" ]; then
        dir_to_bu=$(wc -l "$CURR_PF" | awk '{print $1}')
        if [ "$verbosity" -ge "$VERB_BASIC" ]; then
            printf "%s\n" "Total directories to back up: $dir_to_bu"
            printf "%s\n" "Successful backups: $successes"
        fi
        failures=$((dir_to_bu - successes))
        if [ "$failures" -ne 0 ]; then
            warn "$failures of $dir_to_bu backups failed"
        fi
    fi

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
verbosity="$VERB_SILENT"
rsync_extra=""
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
        -e|--extra)
            rsync_extra="$2"
            shift
            shift
            ;;
        -v|--verbose)
            verbosity=$((verbosity + 1))
            shift
            ;;
        -vv)
            verbosity=$((verbosity + 2))
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

# set up remaining variables
if [ "$verbosity" -ge "$VERB_RSYNC" ]; then
    rsync_verbose_str="-v"
else
    rsync_verbose_str=""
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
if [ "$verbosity" -ge "$VERB_BASIC" ]; then
    echo "Looking for directories to back up..."
    find "${bu_roots[@]}" -depth 2 -type f -name "$PARAM_FILE" | tee "$CURR_PF"
    if [ ! -s "$CURR_PF" ]; then
        echo "None found."
    fi
else
    find "${bu_roots[@]}" -depth 2 -type f -name "$PARAM_FILE" > "$CURR_PF"
fi

# display changes from previous run
if [ "$verbosity" -ge "$VERB_BASIC" ]; then
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
fi

# process (back up) one directory
process_dir () {
    local param_file="$1"
    local server_override
    local target_dir_override
    local actual_target
    local rsync_extra_override
    local actual_extra

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
    rsync_extra_override=$(awk -F'|' 'NR<=1 {print $3}' "$param_file")
    if [ -n "$rsync_extra_override" ]; then
        actual_extra="$rsync_extra_override"
    elif [ -n "$rsync_extra" ]; then
        actual_extra="$rsync_extra"
    else
        actual_extra=""
    fi

    # run the backup
    # note: no quotes on $actual_extra or $rsync_verbose_str
    # shellcheck disable=SC2086
    rsync -a --delete \
        $actual_extra $rsync_verbose_str "$(dirname "$param_file")" \
        "${server_override:-$server}:${actual_target}" \
        >> "$OUT_LOG" 2>> "$ERR_LOG"
}

# loop over the directories (param files) to back up;
# see http://mywiki.wooledge.org/BashFAQ/001 and
# http://mywiki.wooledge.org/BashFAQ/024
successes=0
while IFS= read -r param_file || [ -n "$param_file" ]; do
    set +e
    process_dir "$param_file"
    rv="$?"
    set -e
    if [ "$rv" -ne 0 ]; then
        msg="rsync failure for $(dirname "$param_file"); "
        msg+="return code was $rv"
        warn "$msg"
    else
        successes=$((successes + 1))
    fi
done < "$CURR_PF"
