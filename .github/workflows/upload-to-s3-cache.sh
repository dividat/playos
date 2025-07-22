#!/bin/bash
set -euo pipefail
set -f # disable globbing
export IFS=' '

export S3_BUCKET=${S3_BUCKET:-dividat-ci-nix-cache}
export S3_BUCKET_PARAMS=${S3_BUCKET_PARAMS:-compression=zstd&profile=nixcache&region=eu-central-1}
# see https://github.com/NixOS/nix/issues/4902
export PATH=$PATH:/nix/var/nix/profiles/default/bin

# how many uploads to perform in parallel
export TS_SLOTS=10

# max size of single (!) closure dependency
MAX_CLOSURE_DEP_SIZE=$((10 ** 9)) # 1GB

OUT_PATHS_SMALL=""
OUT_PATHS_BIG=""

# sort closures in those that have big dependencies and those that don't
for path in $OUT_PATHS; do
    largest_size_in_closure=$(nix path-info --recursive --size "$path" | cut -f2 | sort -n | tail -1)
    if [[ $largest_size_in_closure -gt $MAX_CLOSURE_DEP_SIZE ]]; then
        OUT_PATHS_BIG="${OUT_PATHS_BIG} ${path}"
    else
        OUT_PATHS_SMALL="${OUT_PATHS_SMALL} ${path}"
    fi
done

if ! [[ -z "$OUT_PATHS_BIG" ]]; then
    echo "Skipping large paths:"
    nix path-info -Sh $OUT_PATHS_BIG
fi

if ! [[ -z "$OUT_PATHS_SMALL" ]]; then
    echo "Queuing cache upload of: $OUT_PATHS_SMALL"
    # Running with `sudo -i` to ensure `tsp` is sharing a single queue owned by root
    sudo -i tsp nix copy --to "s3://${S3_BUCKET}?${S3_BUCKET_PARAMS}" $OUT_PATHS_SMALL
else
    echo "Nothing to upload after filtering!"
fi
