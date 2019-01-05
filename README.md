# Inject

Run collections of makefiles on remote machines.

## Usage

Requires a `sshloginfile` with a list of IPs. We assume you have a passwordless root login available via SSH.

Example usage:
```
./inject {1..2} -- f*
./inject 1 2 -- f1 f2
./inject 1 -- f1
./inject --slf another_sshloginfile {1..20} -- flags*
```

Saves results into the `last_run` directory.

## Dependencies

parallel, make, envsubst
