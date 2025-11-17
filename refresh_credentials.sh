#!/usr/bin/env bash

# Purpose: Assume an AWS role (based on current caller identity) granting READ & WRITE
# S3 access plus necessary KMS decrypt/encrypt operations, then install temporary
# credentials onto the target Isambard host. Re-run roughly every 12 hours to refresh.
#
# Usage:
#   bash refresh_credentials.sh               # default host
#   bash refresh_credentials.sh a5o.aip2.isambard
#
# Env:
#   ISAMBARD_HOST_ALIAS  Default host alias if no arg provided (defaults to a5o.aip2.isambard)
#
# Idempotency: Only the block between the START/END markers is replaced.

set -euo pipefail

# Source common logging helpers (required)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
source "${SCRIPT_DIR}/lib/isambard_common.sh"

MARKER_START="# >>> ISAMBARD_AWS_CREDS START >>>"
MARKER_END="# <<< ISAMBARD_AWS_CREDS END <<<"
DEFAULT_HOST="${ISAMBARD_HOST_ALIAS:-a5o.aip2.isambard}"
HOST_ALIAS="${1:-$DEFAULT_HOST}"

if ! command -v aws >/dev/null 2>&1; then
  log_error "AWS CLI not found on local machine." || echo "❌ AWS CLI not found on local machine." >&2
  exit 1
fi

log_info "Determining current caller identity to build role ARN..."

# Derive proper IAM role ARN from STS assumed-role ARN form:
# arn:aws:sts::ACCOUNT_ID:assumed-role/ROLE_NAME/SESSION_NAME -> arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
RAW_ARN=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || true)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || true)
ROLE_NAME=""
if [[ -n "$RAW_ARN" ]]; then
  ROLE_NAME=$(echo "$RAW_ARN" | awk -F'/' '/assumed-role\//{print $2}')
fi
if [[ -z "$ACCOUNT_ID" || -z "$ROLE_NAME" ]]; then
  log_error "Could not parse caller identity (ACCOUNT_ID='$ACCOUNT_ID', ROLE_NAME='$ROLE_NAME')." || echo "❌ Could not parse caller identity." >&2
  log_hint "Ensure you have run: aws sso login (or equivalent authentication) on this dev machine." || echo "💡 Ensure you have run: aws sso login" >&2
  exit 1
fi
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
log_info "Using role ARN: $ROLE_ARN"

# Allow optional debug tracing
if [[ "${DEBUG_AWS_CREDS:-0}" == "1" ]]; then
  log_debug "Enabling bash tracing for assume-role call"
  set -x
fi

ASSUME_CMD=$(cat <<EOF
aws sts assume-role \
  --role-arn ${ROLE_ARN} \
  --role-session-name "TEMPORARY-DELEGATED" \
  --policy '{
      "Version":"2012-10-17",
      "Statement":[
        {
          "Effect":"Allow",
          "Action":[
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListAllMyBuckets",
            "s3:GetBucketLocation",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:AbortMultipartUpload",
            "s3:CreateMultipartUpload",
            "s3:UploadPart",
            "s3:CompleteMultipartUpload"
          ],
          "Resource":"*"
        },
        {
          "Effect":"Allow",
          "Action":[
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:GenerateDataKeyWithoutPlaintext",
            "kms:ReEncrypt*"
          ],
          "Resource": "*"
        }
      ]
  }' \
  --duration-seconds 43200 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text
EOF
)

if [[ "${DEBUG_AWS_CREDS:-0}" == "1" ]]; then
  set +x
  log_debug "Built assume-role command (simplified): $ASSUME_CMD"
fi

RAW_OUTPUT=""
if ! RAW_OUTPUT=$(bash -c "$ASSUME_CMD" 2>&1); then
  log_error "Failed to assume role. Full output follows:"
  echo "---------------- BEGIN aws sts output ---------------" >&2
  echo "$RAW_OUTPUT" >&2
  echo "---------------- END aws sts output -----------------" >&2
  log_hint "Common causes: not logged in (run 'aws sso login'), session expired, or insufficient permissions."
  exit 1
fi

ACCESS_KEY_ID=$(echo "$RAW_OUTPUT" | awk '{print $1}')
SECRET_ACCESS_KEY=$(echo "$RAW_OUTPUT" | awk '{print $2}')
SESSION_TOKEN=$(echo "$RAW_OUTPUT" | awk '{print $3}')

if [[ -z "$ACCESS_KEY_ID" || -z "$SECRET_ACCESS_KEY" || -z "$SESSION_TOKEN" ]]; then
  log_error "Could not parse credentials from assume-role output."
  echo "---------------- RAW OUTPUT (for parsing failure) ----" >&2
  echo "$RAW_OUTPUT" >&2
  echo "-----------------------------------------------------" >&2
  exit 1
fi

CREDS=$'export AWS_ACCESS_KEY_ID='"$ACCESS_KEY_ID"$'\n'"export AWS_SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}"$'\n'"export AWS_SESSION_TOKEN=${SESSION_TOKEN}"

FILTERED="$CREDS"

log_step "Retrieved temporary credentials. Installing on $HOST_ALIAS..."

# Escape for single-quoted EOF by replacing any single quotes (unlikely in creds) safely
SAFE_BLOCK=$(printf "%s" "$FILTERED" | sed "s/'/'\\''/g")

REMOTE_CMD=$(cat <<'EOS'
set -euo pipefail
BASHRC="$HOME/.bashrc"
MARKER_START="# >>> ISAMBARD_AWS_CREDS START >>>"
MARKER_END="# <<< ISAMBARD_AWS_CREDS END <<<"
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if [[ ! -f "$BASHRC" ]]; then
  touch "$BASHRC"
fi

# Remove previous block if present
if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
  sed -i "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
fi

cat >> "$BASHRC" <<'BLOCK'
__INJECTED_BLOCK__
BLOCK

# shellcheck disable=SC1090
source "$BASHRC"
echo "[INFO]  $(date +"%Y-%m-%dT%H:%M:%S") Installed new AWS credential block in $BASHRC"
EOS
)

# Build the final injected block with markers
# Append platform bucket export if provided or set a sensible default placeholder
PLATFORM_BUCKET_VALUE="${AISI_PLATFORM_BUCKET:-aisi-data-eu-west-2-prod}"
FILTERED+=$'\n'"export AISI_PLATFORM_BUCKET=${PLATFORM_BUCKET_VALUE}"

FINAL_BLOCK="$MARKER_START"$'\n'"$FILTERED"$'\n'"$MARKER_END"$'\n'

# Inject credentials block into remote command
REMOTE_CMD=${REMOTE_CMD/__INJECTED_BLOCK__/$FINAL_BLOCK}

# Execute remote command on host
ssh -T "$HOST_ALIAS" 'bash -s' <<EOF
$REMOTE_CMD
EOF

log_success "AWS credentials (read/write S3 + KMS) installed & exported on $HOST_ALIAS"
log_hint "Temporary credentials; re-run in ~12h to refresh."