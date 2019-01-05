#!/usr/bin/env bash
POSITIONAL=()
sshloginfile="sshloginfile"
VERBOSE=
RESULTS=last_run
WORKINGDIR=
REMOTE="-S {target} --transferfile {flag} --wd ..." 
while true; do
    case "$1" in 
    -h|--help)
        echo 'Usage:'
        echo '  inject.sh [--slf sshloginfile] [machine_indices] [::: flag_directories [::: make_targets]]'
        echo ''
        echo '    Inject runs make in the [flag_directories] on target machines'
        echo '    uses GNU parallel to ssh onto machines using jump hosts defined in sshloginfile'
        echo '    and to target specified by [flag_directories]/target'
        echo ''
        echo 'Options:'
        echo '  -h|--help       Show this help'
        echo '  -v|--verbose    Show verbose runs of parallel'
        echo '  --slf file      Override sshloginfile [default: ./sshloginfile]'
        echo '  -r results_dir  Set path to store results in'
        echo '  -C dir          Set working directory, also applies to relative results'
        echo '  -l|--local      Run makefile locally, good for checking flags'
        echo ''
        echo '    machine_indices: 1-indexed list to use [default: uses entire sshloginfile]'
        echo '    flag_directories: flag directories [default: all in working dir except results_dir]'
        echo '    make_targets: a list of make targets to call [default: default]'
        echo ''
        echo 'Makefile env vars:'
        echo '    MACHINE: the line from sshloginfile'
        echo '    FLAG: the flag'
        echo ''
        echo 'Example: inject.sh {1..2} ::: f*'
        echo 'Version: 0.1'
        exit
        ;;
    -v|--verbose)
        VERBOSE="-v"
        shift
        ;;
    -r|--results)
        RESULTS="$2"
        shift
        shift
        ;;
    -l|--local)
        REMOTE=
        shift
        ;;
    -C)
        WORKINGDIR="$2"
        shift
        shift
        ;;
    --slf)
        sshloginfile="$2"
        shift
        shift
        ;;
    :::|:::+|::::|::::+)
        shift
        break
        ;;
    "")
        break
        ;;
    *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

if [ -n "$WORKINGDIR" ]; then
    pushd "$WORKINGDIR" >/dev/null
fi
args="$@"
if [ -z "$args" ]; then
    args=`find * -maxdepth 0 -not -path "$RESULTS" -not -path '*/\.*' -type d`
    echo "Using $(echo $args | tr '\n' ' ')" >&2
fi
if [ ${#POSITIONAL[@]} -eq 0 ]; then
    slf="`cat $sshloginfile`"
else
    slf=`echo ${POSITIONAL[@]} | tr ' ' '\n' | sort | join -j1 <(nl $sshloginfile) - | cut -d' ' -f2-`
fi
printf %s\\n "$slf" | \
    ( printf %s\\n target,flag,maketarget  ; parallel -a - "parallel -I {] echo ssh -J root@{1} root@{1],{2},{3} :::: {2}/target" ::: $args ) | \
    parallel -j+0 --header : --results "$RESULTS" -M $VERBOSE -a - --colsep , \
        "parallel $VERBOSE -j1 -n0 -M $REMOTE make -s -C {flag} {maketarget} MACHINE='{target}' FLAG='{flag}' ::: 1"

    # Beginings of attempt to fuse the parallel calls
    #( parallel -a - "parallel -I {] echo ssh -J root@{1} root@{1] :::: {2}/target" ::: $args ) | \
    #parallel --results "$RESULTS" $VERBOSE --header : -M -j0 --onall --transferfile . --slf - --wd ... make -s -C {1} FLAG={1} ::: flag $args

if [ -n "$WORKINGDIR" ]; then
    popd >/dev/null
fi
