#!/usr/bin/env bash
# Waits for a workflow run and prints its result plus any ::error:: annotations.
# Usage: tool/ci_status.sh <run_id>
set -u
repo=spywellinfotech-sys/transwell
run=$1
for _ in $(seq 1 90); do
  s=$(gh api repos/$repo/actions/runs/$run --jq '"\(.status) \(.conclusion)"')
  case "$s" in completed*) break ;; esac
  sleep 20
done
echo "RUN: $s"
gh api repos/$repo/actions/runs/$run/jobs --jq '.jobs[].steps[] | select(.conclusion=="failure") | "FAILED STEP: \(.name)"'
for cr in $(gh api "repos/$repo/commits/$(gh api repos/$repo/actions/runs/$run --jq .head_sha)/check-runs" --jq '.check_runs[].id'); do
  gh api "repos/$repo/check-runs/$cr/annotations?per_page=100" --jq '.[] | select(.annotation_level=="failure") | .message' 2>/dev/null
done | grep -v "^Process completed with exit code" | head -80
