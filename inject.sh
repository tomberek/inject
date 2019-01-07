#!/usr/bin/env bash

# Defaults
POSITIONAL=()
FLAGS=()
sshloginfile="sshloginfile"
VERBOSE=
RESULTS=last_run
WORKINGDIR=
REMOTE=1
FIRST_OP=":::"
SECOND_OP=":::"
DRY_RUN=

while true; do
    case "$1" in 
    -h|--help)
        echo 'Usage:'
        echo '  inject.sh [options] [--slf sshloginfile] [machine_indices] [::: flag_directories [::: make_targets]]'
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
        echo '  -d|--dry-run    Dry run, use with --verbose to debug CLI parsing'
        echo ''
        echo '    machine_indices: 1-indexed list to use [default: uses entire sshloginfile]'
        echo '    flag_directories: flag directories [default: all in working dir except results_dir]'
        echo '    make_targets: a list of make targets to call [default: default]'
        echo ''
        echo 'Env vars:'
        echo '    MACHINE: the machine index in use [ in flag_dir/Makefile]'
        echo '    FLAG: the flag directory in use [ in flag_dir/Makefile]'
        echo '    JUMP: populated by sshloginfile [ in flag_dir/target]'
        echo ''
        echo 'Examples: inject.sh {1..2} ::: f*'
        echo '          inject.sh {1..2} ::: f* ::: default'
        echo '          inject.sh 1 2 :::+ f1'
        echo 'Version: 0.2'
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
    -d|--dry-run)
        DRY_RUN=1
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
		FIRST_OP="$1"
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

while true; do
    case "$1" in 
    :::|:::+|::::|::::+)
		SECOND_OP="$1"
        shift
        break
        ;;
    "")
        break
        ;;
    *)
        FLAGS+=("$1")
		shift
		;;
    esac
done
args="$@"

# Jump to working directory
if [ -n "$WORKINGDIR" ]; then
    pushd "$WORKINGDIR" >/dev/null
fi

# Default behavior when not specifying machine_ids
if [ ${#POSITIONAL[@]} -eq 0 ]; then
	ids=`wc -l "$sshloginfile" | cut -d' ' -f1`
	ids=`seq 1 $ids`
    echo "Default machines: $(echo $ids | tr '\n' ' ')" >&2
else
	ids="${POSITIONAL[@]}"
fi

# Default behavior when not specifying flags_directories
if [ "${#FLAGS[@]}" -eq 0 ]; then
    flags=`find * -maxdepth 0 -not -path "$RESULTS" -not -path '*/\.*' -type d`
    echo "Default flags: $(echo $flags | tr '\n' ' ')" >&2
else
	flags="${FLAGS[@]}"
fi

# Default behavior when not specifying maketargets
if [ -z "$args" ]; then
	args="default"
fi

variations=`parallel "echo {1}$'\034'{2}$'\034'{3}" ::: $ids $FIRST_OP $flags $SECOND_OP $args`

# Takes all variations and processes them into:
# id jumphost flag maketarget
# reads $sshloginfile in order to convert machine_id's to use as JUMP
# in FLAG_DIR/target templating
processed=`gawk -f \
    <(cat <<"EOF"
BEGIN {
    OFS=FS="\034"
    print "flag","machine","maketarget"
}
FNR==NR{
    jump[NR]=$0
}
FNR!=NR{
    $2 = gensub(/\.\./,"","g",$2)
    getline a < ($2 "/target")
    close($2 "/target")
    ENVIRON["JUMP"]=jump[$1]
    print a |& "envsubst"
    close("envsubst","to")
    "envsubst" |& getline b
    close("envsubst")
    print $2,$1,$3 "@" $2,$1 "\035@" $2,$1 "/1/" b
}
EOF
) $sshloginfile <(printf %s "$variations")`

newargs=`echo "$processed" | cut -d$'\035' -f1`
slf=`echo "$processed" | cut -d$'\035' -f2 | tail -n+2`

[ -n "$VERBOSE" ] && \
	printf %s\\n "$variations" | tr $'\034' '-'
[ -n "$VERBOSE" ] && \
	printf %s\\n "$processed" | tr $'\034' '-'
[ -n "$DRY_RUN" ] && exit

# The core
if [ -z "$REMOTE" ]; then
    echo "$newargs" | \
    cut -d'@' -f1 | \
    parallel --results "$RESULTS" --header : --colsep $'\034' $VERBOSE -M \
        --hgrp -j+0 \
        make -s -C {flag} {maketarget} FLAG={flag} MACHINE={machine}
else
    echo "$newargs" | \
    parallel --results "$RESULTS" --header : --colsep $'\034' $VERBOSE -M \
        --hgrp -j+0 \
        --slf <(printf %s\\n "$slf") --transferfile . --wd ... \
        make -s -C {flag} {maketarget} FLAG={flag} MACHINE={machine}
fi

# Restore original directory
if [ -n "$WORKINGDIR" ]; then
    popd >/dev/null
fi
