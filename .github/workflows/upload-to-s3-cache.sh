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

# exclude closures larger than 3GB to avoid polluting the cache
SMALL_OUT_PATHS="$(nix path-info -S $OUT_PATHS | awk '{if ($2 < 10 ^ 9 * 3) print $1;}')"
BIG_PATHS=$(comm -23 \
    <(tr ' ' '\n' <<<"$OUT_PATHS" | sort) \
    <(tr ' ' '\n' <<<"$SMALL_OUT_PATHS" | sort) \
        | tr '\n' ' ')

if ! [[ -z "$BIG_PATHS" ]]; then
    echo "Skipping large paths:"
    nix path-info -Sh $BIG_PATHS
fi

if ! [[ -z "$SMALL_OUT_PATHS" ]]; then
    echo "Queuing cache upload of: $SMALL_OUT_PATHS"
    # Running with `sudo -i` to ensure `tsp` is sharing a single queue owned by root
    sudo -i tsp nix copy --to "s3://${S3_BUCKET}?${S3_BUCKET_PARAMS}" $SMALL_OUT_PATHS
else
    echo "Nothing to upload after filtering!"
fi
