#!/usr/bin/env bash
# b2-object-lock-test.sh — does restic work on a B2 bucket with Object Lock,
# and does the lock stop a backup key from erasing versions? (AUDIT.md S11)
#
# Setup, in the B2 web UI (the script never needs the master key):
#   1. A scratch bucket: private, Object Lock ON, default retention
#      mode Governance, period 1 day. Not one of the real backup buckets.
#   2. An application key for that bucket only: read and write, WITHOUT
#      bypassGovernance. That is what a backup key would look like.
#
# Run (restic and the AWS CLI come from the nix shell):
#   nix shell nixpkgs#restic nixpkgs#awscli2 -c \
#     env AWS_ACCESS_KEY_ID=<keyID> AWS_SECRET_ACCESS_KEY=<applicationKey> \
#         BUCKET=<scratch-bucket> bash docs/b2-object-lock-test.sh
#
# Optional: ENDPOINT (default s3.eu-central-003.backblazeb2.com, the real
# buckets' region — the scratch bucket must be in the same one).
#
# Tests:
#   A  restic init / backup x2 / forget --prune / check all succeed
#   B  prune's deletes became hide markers (locked versions still stored)
#   C  the key can't permanently delete a locked version (versionId delete)
#   D  nor with --bypass-governance-retention
#   E  the version is still there afterwards
# Exits 0 only if all pass.
#
# Cleanup: locked versions can't be removed until retention ends. After a
# day, delete the bucket's files and the bucket in the web UI, and the key.
set -euo pipefail

: "${AWS_ACCESS_KEY_ID:?set AWS_ACCESS_KEY_ID (B2 keyID)}"
: "${AWS_SECRET_ACCESS_KEY:?set AWS_SECRET_ACCESS_KEY (B2 applicationKey)}"
: "${BUCKET:?set BUCKET (the scratch bucket)}"
endpoint_host="${ENDPOINT:-s3.eu-central-003.backblazeb2.com}"
region="$(cut -d. -f2 <<<"$endpoint_host")"

for tool in restic aws jq; do
  command -v "$tool" >/dev/null || {
    echo "missing $tool — see the Run line in the header" >&2
    exit 2
  }
done

# AWS CLI ≥ 2.23 sends CRC checksums by default, which B2 rejects.
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
export AWS_DEFAULT_REGION="$region"
s3() { aws --endpoint-url "https://$endpoint_host" s3api "$@"; }

prefix="restic-lock-test-$(date +%Y%m%d-%H%M%S)"
export RESTIC_REPOSITORY="s3:$endpoint_host/$BUCKET/$prefix"
RESTIC_PASSWORD="$(head -c 24 /dev/urandom | base64)"
export RESTIC_PASSWORD

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
ok() {
  echo "  PASS  $*"
  pass=$((pass + 1))
}
bad() {
  echo "  FAIL  $*"
  fail=$((fail + 1))
}

echo "== Bucket lock configuration"
if lock="$(s3 get-object-lock-configuration --bucket "$BUCKET" 2>&1)"; then
  jq -r '.ObjectLockConfiguration | "  enabled=\(.ObjectLockEnabled)  default=\(.Rule.DefaultRetention.Mode // "none") \(.Rule.DefaultRetention.Days // .Rule.DefaultRetention.Years // "-") days"' <<<"$lock"
  if ! jq -e '.ObjectLockConfiguration.Rule.DefaultRetention.Mode' >/dev/null <<<"$lock"; then
    echo "  No default retention: uploads won't be locked, so C-E would mean nothing." >&2
    exit 2
  fi
else
  echo "  Can't read it (Object Lock off, or the key lacks readBucketRetentions):" >&2
  echo "  $lock" >&2
  exit 2
fi

echo "== A: restic against the locked bucket ($prefix)"
mkdir -p "$work/src"
head -c 8M /dev/urandom >"$work/src/one.bin"
run() {
  local name="$1"
  shift
  if "$@" >"$work/log" 2>&1; then
    ok "$name"
  else
    bad "$name"
    sed 's/^/        /' "$work/log" | tail -5
  fi
}
run "restic init" restic init
run "restic backup (1)" restic backup --host locktest "$work/src"
# Replace the data, so the first snapshot's pack becomes garbage to prune.
head -c 8M /dev/urandom >"$work/src/one.bin"
run "restic backup (2)" restic backup --host locktest "$work/src"
run "restic forget --keep-last 1 --prune" restic forget --keep-last 1 --prune
run "restic check" restic check

echo "== B: prune's deletes are hide markers, data still stored"
versions="$(s3 list-object-versions --bucket "$BUCKET" --prefix "$prefix/data/")"
markers="$(jq '[.DeleteMarkers // [] | .[]] | length' <<<"$versions")"
stored="$(jq '[.Versions // [] | .[]] | length' <<<"$versions")"
echo "  data/: $stored stored versions, $markers delete markers"
if [[ $markers -gt 0 ]]; then
  ok "prune hid packs instead of erasing them"
else
  bad "no delete markers under data/ — prune removed nothing, or erased outright"
fi

echo "== C/D: try to erase a locked version with this key"
key="$(jq -r '.Versions[0].Key // empty' <<<"$versions")"
vid="$(jq -r '.Versions[0].VersionId // empty' <<<"$versions")"
if [[ -z $key ]]; then
  bad "no stored version to test against"
else
  echo "  target: $key ($vid)"
  if out="$(s3 delete-object --bucket "$BUCKET" --key "$key" --version-id "$vid" 2>&1)"; then
    bad "C: versionId delete SUCCEEDED — the lock does not protect this version"
  else
    ok "C: versionId delete refused ($(grep -oE 'AccessDenied|[A-Za-z]+Denied|InvalidRequest' <<<"$out" | head -1))"
  fi
  if out="$(s3 delete-object --bucket "$BUCKET" --key "$key" --version-id "$vid" --bypass-governance-retention 2>&1)"; then
    bad "D: delete with --bypass-governance-retention SUCCEEDED — the key has bypassGovernance"
  else
    ok "D: governance bypass refused ($(grep -oE 'AccessDenied|[A-Za-z]+Denied|InvalidRequest' <<<"$out" | head -1))"
  fi

  echo "== E: version still present"
  if s3 head-object --bucket "$BUCKET" --key "$key" --version-id "$vid" >/dev/null 2>&1; then
    ok "E: $key ($vid) still stored"
  else
    bad "E: the version is gone"
  fi
fi

echo
echo "== $pass passed, $fail failed"
echo "Test objects stay locked until retention ends; delete the bucket afterwards."
[[ $fail -eq 0 ]]
