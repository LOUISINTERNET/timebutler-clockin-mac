#!/usr/bin/env bash
# Notarizes a zip or disk image and staples the ticket. Used by .github/workflows/release.yml.
# Reads APPLE_ID, APPLE_APP_PASSWORD and APPLE_TEAM_ID from the environment. A rejected
# submission prints Apple's log, which names every file that failed and why.
# Usage: scripts/notarize.sh <file-to-submit> <path-to-staple>
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <file-to-submit> <path-to-staple>" >&2
    exit 2
fi
submission="$1"
staple_target="$2"
: "${APPLE_ID:?APPLE_ID is not set}"
: "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD is not set}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is not set}"
credentials=(--apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID")

echo "Submitting $submission for notarization"
submit_exit=0
result="$(xcrun notarytool submit "$submission" "${credentials[@]}" --wait --output-format json)" || submit_exit=$?
echo "$result"
status="$(jq -r '.status // "none"' <<<"$result")"
if [ "$status" != "Accepted" ]; then
    echo "::error::Notarization of $submission ended with status $status (notarytool exit $submit_exit)"
    submission_id="$(jq -r '.id // empty' <<<"$result")"
    if [ -n "$submission_id" ]; then
        xcrun notarytool log "$submission_id" "${credentials[@]}"
    fi
    exit 1
fi

xcrun stapler staple "$staple_target"
xcrun stapler validate "$staple_target"
