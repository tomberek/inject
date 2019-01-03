#!/usr/bin/env bash
POSITIONAL=()
sshloginfile="sshloginfile"
while true; do
    case "$1" in 
    -h|--help|-v)
        echo 'Usage: inject.sh [--slf sshloginfile] [machine_indices] [-- [flag_indices]]'
        echo '    runs make in [flag_indices] directories'
        echo '    uses parallel to ssh onto machines defined in sshloginfile'
        echo '    make target is flag name, envvar MACHINE is the line from sshloginfile'
        echo '    ommiting the machine_indices uses the entire file'
        echo 'Example: inject.sh {1..2} -- f*'
        echo 'Version: 0.1'
        exit
        ;;
    --slf)
        sshloginfile="$1"
        shift
        ;;
    --)
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
args="$@"
if [ -z "$args" ]; then
    args='f*'
fi
if [ ${#POSITIONAL[@]} -eq 0 ]; then
    slf=": $sshloginfile"
else
    output="$(IFS=$'\n' ; echo "${POSITIONAL[*]}")"
    slf=" $(awk 'FNR==NR{a[NR]=$0;next}{print a[$0]}' \
        "$sshloginfile" <(printf "%s\n" "$output"))"
fi
parallel --results last_run parallel -I {] --arg-sep ,, --tag -j1 --tagstr {1} --controlmaster \
    -S root@{1} --wd ...  \
    --transferfile {1] \
    make -s -C {1] {1] MACHINE={1} ,, $args :::$slf


