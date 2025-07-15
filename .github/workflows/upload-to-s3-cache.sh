#!/bin/bash
set -euo pipefail
set -f # disable globbing
export IFS=' '

export S3_BUCKET=${S3_BUCKET:-dividat-ci-nix-cache}
export S3_BUCKET_PARAMS=${S3_BUCKET_PARAMS:-compression=zstd&profile=nixcache}
export AWS_SHARED_CREDENTIALS_FILE=/root/.aws/credentials
export AWS_CONFIG_FILE=/root/.aws/config

# how many uploads to perform in parallel
export TS_SLOTS=10

echo "Queuing cache upload of: $OUT_PATHS"
tsp nix copy --to "s3://${S3_BUCKET}?${S3_BUCKET_PARAMS}" $OUT_PATHS
# noop for now
# TODO: how to prevent uploads of large packages?
#tsp echo $OUT_PATHS
