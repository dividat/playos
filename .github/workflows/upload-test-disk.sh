#!/bin/bash

RELEASE_TAG="$1"

set -euo pipefail
set -x
disk_path="$(readlink ./result/playos-disk-$RELEASE_TAG.img)"
target_url="s3://dividat-playos-test-disks/by-tag/playos-disk-$RELEASE_TAG.img.zst"
echo "Compressing and uploading test disk to: $target_url"
zstd --stdout "$disk_path" | aws s3 cp - "$target_url"
