#!/bin/bash
set -euo pipefail

RELEASE_TAG="$1"

# find the previous "proper" release (i.e. not VALIDATION) tag
prev_tag="$(git tag \
    | sort \
    | grep -B10000 "$RELEASE_TAG" \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | head -n -1 \
    | tail -1)" || echo ""

if [[ -z "$prev_tag" ]]; then
    echo "Error: failed to determine previous release tag, are you sure input tag $RELEASE_TAG exists?"
    exit 1
else
    echo "Previous proper release tag is: $prev_tag" >&2
fi

echo -e "
# Release $RELEASE_TAG

## Artifacts

- Test disk: [https://dividat-playos-test-disks.s3.amazonaws.com/by-tag/playos-disk-$RELEASE_TAG.img.zst](https://dividat-playos-test-disks.s3.amazonaws.com/by-tag/playos-disk-$RELEASE_TAG.img.zst)

## Changelog

"

# print changelog since $prev_tag (exclusive)
grep -E -B10000 "^# \[$prev_tag\]" ./Changelog.md \
    | head -n -1 \
    | sed -E 's/#+/\0#/'
