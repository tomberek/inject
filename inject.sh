#!/usr/bin/env bash
function usage(){
    echo 'Usage:'
    echo '  inject.sh [options] ::: machine_indices ::: flag_directories ::: make_targets'
    echo ''
    echo '    Inject runs make in the [flag_directories] on target machines'
    echo '    uses GNU parallel to ssh onto machines using hosts defined in flag_directories/target'
    echo '    and to target specified by [flag_directories]/target'
    echo ''
    echo 'Options:'
    echo '  -h|--help       Show this help'
    echo '  -v|--verbose    Show verbose runs of parallel'
    echo '  -r results_dir  Set path to store results in'
    echo '  -C dir          Set working directory, must be "greatest common directory" of flags'
    echo '  -l|--local      Run makefile locally, good for checking flags'
    echo '  -d|--dry-run    Dry run, use with --verbose to debug CLI parsing'
    echo ''
    echo '    machine_indices: list to use as JUMP variable in the target templates'
    echo '    flag_directories: flag directories [default: all in working dir except results_dir]'
    echo '    make_targets: a list of make targets to call [default: default]'
    echo ''
    echo 'Env vars:'
    echo '    MACHINE: the machine index in use [ in flag_dir/Makefile]'
    echo '    FLAG: the flag directory in use [ in flag_dir/Makefile]'
    echo '    JUMP: populated by the first argument to inject [ in flag_dir/target]'
    echo ''
    echo 'Examples: inject.sh ::: {1..2} ::: f* ::: default'
    echo '          inject.sh ::: {1..2} ::: f* ::: default'
    echo '          inject.sh ::: 1 2 :::+ f1 ::: default'
    echo '          inject.sh -C folder ::: 1 2 ::: folder/f* ::: default'
    echo 'Version: 1.1'
    exit 0
}

# Defaults
VERBOSE=
RESULTS=last_run
export WORKINGDIR=
export REMOTE="--transferfile . --wd ..."
DRY_RUN=
while getopts r:C:hvdl FLAG; do
    case $FLAG in
        v) VERBOSE="-v" ;;
        r) RESULTS="${OPTARG}" ;;
        C) WORKINGDIR="${OPTARG}" ;;
        d) DRY_RUN="--dry-run" ;;
        l) REMOTE="" ;;
        h) usage ;;
        *) echo error ; break ;;
    esac
done
shift $(expr $OPTIND - 1 )

if [ "$#" -lt "6" ]; then
    echo "Not enough arguments" >&2
    usage
fi

# Takes all variations and processes them into:
# id jumphost flag maketarget
# uses the first arg as JUMP
# in FLAG_DIR/target templating

function go(){
    printf "$1\034$3\034$4@"
    printf "$1\034$3\034$4\\n" | tr -d '/.'
}

# Function tries to be smart and detect globing from shell, or directories relative to WORKINGDIR
function get_name(){
    local file
    file="$(realpath "$1" 2>/dev/null)"
    if [ -f "$file" ] ; then
        printf %s "$file"
        return
    fi
    file="$(realpath "$WORKINGDIR"/"$1" 2>/dev/null)"
    if [ -f "$file" ] ; then
        printf %s "$file"
        return
    fi
    echo "Unknown flag folders" >&2
    exit
}
export -f get_name
export -f go
function run_parallel(){
    parallel "parallel -I {] go {1] {2] {2/} {3} ::: {1} :::: \$( get_name {2}/target) " "$@"
}

args="$(
    printf $'%s\034%s\034%s\\n' "machine" "flag" "maketarget" ; 
    run_parallel "$@"
)"

function go(){
    local JUMP="$1"
    export JUMP
    printf "@$1\034$3\034$4" | tr -d '/.'
    if [ -z "$REMOTE" ]; then
        host=":"
    else
        host="$2"
    fi
    printf "/1/$host\\n" | envsubst
}
slf="$(run_parallel "$@")"

[ -n "$VERBOSE" ] && \
	printf "args:\\n%s\\n\\n" "$args" | tr $'\034' '-' >&2
[ -n "$VERBOSE" ] && \
	printf "slf:\\n%s\\n\\n" "$slf" | tr $'\034' '-' | tr $'\035' '_' >&2
[ -n "$DRY_RUN" ] && exit

if [ -n "$WORKINGDIR" ]; then
    pushd "$WORKINGDIR" >/dev/null
fi

# The core
echo "$args" | \
parallel -k --hgrp --results "$RESULTS" --header : --colsep $'\034' \
    $REMOTE $VERBOSE \
    -j4 -M \
    --slf <(printf %s\\n "$slf") \
    make -s -C {flag} {maketarget} FLAG={flag/} MACHINE={machine}

# Restore original directory
if [ -n "$WORKINGDIR" ]; then
    popd >/dev/null
fi
