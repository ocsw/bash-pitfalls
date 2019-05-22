#!/usr/bin/env bash

for param_file in $1/*/.back_me_up; do
    rsync -a --delete "$(dirname "$param_file")" "${2}:${3}"
done
