# Inject

Run collections of makefiles on remote machines.

# Install

Self-contained in the inject.sh file. Optional to use `sshd_checker.config` if desired.

## Usage

Requires a `sshloginfile` with a list of IPs. We assume you have a passwordless root login available via SSH.

Example usage:
```
./inject {1..2} ::: f*
./inject 1 2 ::: f1 f2
./inject 1 ::: f1
./inject --slf another_sshloginfile {1..20} ::: flags ::: default
./inject 1 ::: f2 ::: clean
```

Check answers on local box:
```
./inject -l 1 ::: f2 ::: check
```

Saves results into the `last_run` directory.

## Opinionated files

### sshloginfile
Just a list of IP's which will become the JUMP envvar in the target templates.

### Target
`flag_dir/target` : the template used to generate the file ssh commands.
Examples:
```
192.168.1.1
user@192.168.1.1
ssh -J user@$JUMP another_user@192.168.1.1
```
Env Vars:
`JUMP` : provided via the sshloginfile

### Makefile
`flag_dir/Makefile` : the template used to generate the file ssh commands. `JUMP` is an envvar available, provided via the sshloginfile
Examples:
```
default:
        echo "Placing flag into /tmp/${FLAG} on ${MACHINE}"
        make check > /tmp/${FLAG}

check:
        echo "SOME RANDOM SALT TEXT ${FLAG} ${MACHINE}" | sha256sum | cut -d" " -f1

clean:
        rm /tmp/f2 && echo "Removed /tmp/f2"

```
Env Vars:
`FLAG` : provided by inject
`MACHINE` : provided by inject

## Dependencies

parallel, make, envsubst, gawk

## SSH-based answer checker

Config file at ./sshd_checker.config

### Usage (new)
JUMPID ::: FLAGDIR ::: STRING
Compares the contents of `./inject -l JUMPID ::: FLAGDIR ::: check` with STRING
Attempts to strip .. and force relative path traversal

Example server: `sudo /usr/sbin/sshd -f sshd_checker.config -p 1234`
Example query : `ssh user@localhost -p 1234 1 ::: f1 ::: some_flag_text`

No results directory needed

### Usage (old)
JUMPID ::: FLAGDIR ::: STRING
Compares the contents of last_run/flag/FLAGDIR/target/[JUMP ssh command]/stdout to the STRING
Attempts to strip .. and force relative path traversal

Example server: `sudo /usr/sbin/sshd -f sshd_checker.config -p 1234`
Example query : `ssh user@localhost -p 1234 1 ::: f1 ::: some_flag_text`

Assumes the flags are defined in ~/inject/ and the results are in ~/inject/last_run
Assumes jumphosts are defined in ~/inject/sshloginfile

Results structure:
last_run/flag/<flag>/maketarget/target/ssh -J root@<jumphost> root@<target>/stdout
