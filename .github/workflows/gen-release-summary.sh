#!/bin/bash
set -euo pipefail

RELEASE_TAG="$1"

echo -e "
# Release $RELEASE_TAG

## Artifacts

- Test disk: [https://dividat-playos-test-disks.s3.amazonaws.com/by-tag/playos-disk-$RELEASE_TAG.img.zst](https://dividat-playos-test-disks.s3.amazonaws.com/by-tag/playos-disk-$RELEASE_TAG.img.zst)

## Changelog

"

earlier_rels=3 # include VALIDATION changelog in final release

if [[ "$RELEASE_TAG" == *"-VALIDATION" ]]; then
    earlier_rels=2
fi

# get changelogs up to previous $earlier_rels-1
grep -m ${earlier_rels} -B10000 '^# ' ./Changelog.md | head -n -1 | sed -E 's/#+/\0#/'
