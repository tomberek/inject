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
    echo '  -C dir          Set working directory, also applies to relative results'
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
    echo 'Version: 1.0'
    exit 0
}
# Defaults
VERBOSE=
RESULTS=last_run
WORKINGDIR=
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

# Jump to working directory
if [ -n "$WORKINGDIR" ]; then
    pushd "$WORKINGDIR" >/dev/null
fi

# Takes all variations and processes them into:
# id jumphost flag maketarget
# uses the first arg as JUMP
# in FLAG_DIR/target templating
function go(){
    printf "$1\034$4\034$5@"
    printf "$1\034$3\034$5\\n" | tr -d '/'
}
export -f go
function run_parallel(){
    parallel "parallel -I {] go {1] {2] {2/} {2} {3] ::: {1} :::: {2}/target ::: \$([ -z \"{3}\" ] && echo default || echo {3})" "$@"
}

args="$(
    printf $'%s\034%s\034%s\\n' "machine" "flag" "maketarget" ; 
    run_parallel "$@"
)"

function go(){
    local JUMP="$1"
    export JUMP
    printf "@$1\034$3\034$5" | tr -d '/'
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

# The core
echo "$args" | \
parallel --results "$RESULTS" --header : --colsep $'\034' $VERBOSE -M \
    --hgrp -j1 \
    $REMOTE \
    --slf <(printf %s\\n "$slf") \
    make -s -C {flag} {maketarget} FLAG={flag/} MACHINE={machine}

# Restore original directory
if [ -n "$WORKINGDIR" ]; then
    popd >/dev/null
fi
