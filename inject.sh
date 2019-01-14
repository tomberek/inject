#!/usr/bin/env bash
if [ "$_"x != "$0"x ]; then
    echo "Script is being sourced"
    return
fi
function usage(){
    echo 'Usage:'
    echo '  inject.sh [options] ::: machine_indices :::: flag_targets ::: make_targets'
    echo ''
    echo '    Inject runs make in the [flag_directories] on target machines'
    echo '    uses GNU parallel to ssh onto machines using hosts defined in flag_directories/target'
    echo '    and to target specified by flag_target'
    echo ''
    echo 'Options:'
    echo '  -h              Show this help'
    echo '  -v              Show verbose runs of parallel'
    echo '  -s slf          Write ssshloginfile to slf'
    echo '  -c cmd          Run cmd instead of make'
    echo '  -r results_dir  Set path to store results in'
    echo '  -C dir          Set working directory, must be "greatest common directory" of flags'
    echo '  -l              Run makefile locally, good for checking flags'
    echo '  -d              Dry run, use with --verbose to debug CLI parsing'
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
    echo 'Examples: inject.sh ::: {1..2} :::: f*/target ::: default'
    echo '          inject.sh ::: {1..2} :::: f*/target ::: default'
    echo '          inject.sh ::: 1 2 ::::+ f1/target ::: default'
    echo '          inject.sh -C folder ::: 1 2 :::: folder/f* ::: default'
    echo 'Version: 2.1'
    exit 0
}

# Defaults
VERBOSE=
RESULTS=
export WORKINGDIR=
export REMOTE="--transferfile . --wd ..."
DRY_RUN=
SLF=
CMD="make -s -C {2} {3} FLAG={2/} MACHINE={1}"
while getopts o:n:s:r:C:hvdl FLAG; do
    case $FLAG in
        v) VERBOSE="-v" ;;
        s) SLF="${OPTARG}" ;;
        r) RESULTS="--results ${OPTARG}" ;;
        o) CMD="${OPTARG}" ;;
        n) CMD="-N0 ${OPTARG}" ;;
        C) WORKINGDIR="${OPTARG}" ;;
        d) DRY_RUN="--dry-run" ;;
        l) REMOTE="" ;;
        h) usage ;;
        *) echo error ; break ;;
    esac
done
shift $(expr $OPTIND - 1 )

if [ "$#" -lt "4" ]; then
    echo "Not enough arguments" >&2
    usage
fi

# Takes all variations and processes them into arguments
function go1(){
    local host
    if [ -z "$REMOTE" ]; then
        host=":"
    else
        host=$(printf "$1" | tr -d '/.')
    fi
    printf "$1@$host"
    printf "\t$3@$host"
    printf "\t$4@$host\\n"
}
function go2(){
    local host
    local JUMP="$1"
    export JUMP
    printf "@$1" | tr -d '/.'
    if [ -z "$REMOTE" ]; then
        host=":"
    else
        host="$2"
    fi
    printf "/1/$host\\n" | envsubst
}
function go(){
    # Alternate lines, split them up later, cuts down on calls to parallel
    go1 "$@"
    go2 "$@"
}
export -f go
export -f go1
export -f go2

# Perl magic is to extract the flag's name
res="$( parallel --will-cite --plain go {1} {2} {=2 '$_=::basename(::dirname($opt::a[1]))' =} {3} "$@" )"
args="$( printf %s "$res" | awk 'NR % 2 == 1')"
slf="$( printf %s "$res" | awk 'NR % 2 == 0')"

if [ -n "$SLF" ]; then
    printf %s\\n "$slf" > "$SLF"
fi

[ -n "$VERBOSE" ] && printf "arguments:\\n%s\\n\\n" "$args" >&2
[ -n "$VERBOSE" ] && printf "sshloginfile:\\n%s\\n\\n" "$slf" >&2
[ -n "$DRY_RUN" ] && exit

[ -n "$WORKINGDIR" ] && pushd "$WORKINGDIR" >/dev/null

# The core
arg1=$(echo "$args" | cut -f1)
arg2=$(echo "$args" | cut -f2)
arg3=$(echo "$args" | cut -f3)

parallel --hgrp --slf <(printf %s "$slf") \
    --plain --will-cite -j+0 -k --group -M --sshdelay 0.2 \
    $INJECT_PARALLEL_ARGS $REMOTE $VERBOSE $RESULTS \
    $CMD ::: "$(echo "$arg1")" :::+ "$(echo "$arg2")" :::+ "$(echo "$arg3")"

# Restore original directory
if [ -n "$WORKINGDIR" ]; then
    popd >/dev/null
fi
