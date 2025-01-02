#!/bin/bash

RELEASE_TAG="$1"

set -euo pipefail
set -x
disk_path="$(readlink ./result/playos-release-disk-$RELEASE_TAG.img.zst)"
target_url="s3://dividat-playos-test-disks/by-tag/playos-release-disk-$RELEASE_TAG.img.zst"
echo "Uploading test disk to: $target_url"
aws s3 cp "$disk_path" "$target_url"
