#!/usr/bin/env bash

for param_file in $(find "$1" -depth 2 -type f -name ".back_me_up"); do
    rsync -a --delete "$(dirname "$param_file")" "${2}:${3}"
done
