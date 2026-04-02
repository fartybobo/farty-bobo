#!/bin/bash
# ============================================================
# AWS Access Key Rotation Script
#
# This script reads your current key from ~/.aws/credentials,
# creates a new key, updates the credentials file in-place,
# verifies the new key, and deactivates the old one.
#
# USAGE:
#   bash rotate-aws-keys.sh [PROFILE]
#   (defaults to "default" profile if not specified)
#
# EXAMPLE:
#   bash rotate-aws-keys.sh         # rotates [default] profile
#   bash rotate-aws-keys.sh dev     # rotates [dev] profile
#
# ENVIRONMENT VARIABLES:
#   IAM_USER   IAM username whose keys will be rotated (required)
# ============================================================

set -euo pipefail
export AWS_PAGER=""

IAM_USER="${IAM_USER:-}"
PROFILE="${1:-default}"
CREDS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

if [ -z "$IAM_USER" ]; then
  echo "  ERROR: IAM_USER is not set."
  echo "  Run: IAM_USER=your-username bash rotate-aws-keys.sh [PROFILE]"
  exit 1
fi

echo "=== AWS Key Rotation for user: $IAM_USER (profile: $PROFILE) ==="
echo ""

# ─── Pre-flight: backup credentials file ─────────────────────
if [ -f "$CREDS_FILE" ]; then
  BACKUP="${CREDS_FILE}.bak.$(date +%s)"
  cp "$CREDS_FILE" "$BACKUP"
  echo "  Backed up credentials to $BACKUP"
  echo ""
fi

# ─── Step 1: Read current key ────────────────────────────────
echo "[1/6] Reading current access key for profile [$PROFILE]..."
OLD_KEY_ID=$(aws configure get aws_access_key_id --profile "$PROFILE" 2>/dev/null || true)
if [ -z "$OLD_KEY_ID" ]; then
  echo "  ERROR: Could not read aws_access_key_id from profile [$PROFILE]."
  echo "  Make sure ~/.aws/credentials has a [$PROFILE] section."
  exit 1
fi
echo "  Current Access Key ID: $OLD_KEY_ID"
echo ""

# ─── Step 2: Verify current credentials work ─────────────────
echo "[2/6] Verifying current credentials..."
AWS_PROFILE="$PROFILE" aws sts get-caller-identity --no-cli-pager || {
  echo "  ERROR: Current credentials are not working. Aborting."
  exit 1
}
echo ""

# ─── Pre-flight: check two-key limit ─────────────────────────
echo "  Checking active key count for $IAM_USER..."
ACTIVE_KEY_COUNT=$(AWS_PROFILE="$PROFILE" aws iam list-access-keys \
  --user-name "$IAM_USER" \
  --query 'AccessKeyMetadata[?Status==`Active`] | length(@)' \
  --output text --no-cli-pager)
if [ "$ACTIVE_KEY_COUNT" -ge 2 ]; then
  echo "  ERROR: $IAM_USER already has 2 active keys — AWS does not allow a third."
  echo "  Delete an existing key first:"
  echo "    aws iam list-access-keys --user-name $IAM_USER"
  exit 1
fi
echo ""

# ─── Confirm before proceeding ───────────────────────────────
read -r -p "Proceed with rotating key $OLD_KEY_ID for user $IAM_USER? [y/N] " CONFIRM
case "$CONFIRM" in
  [yY][eE][sS]|[yY]) ;;
  *) echo "Aborted."; exit 0 ;;
esac
echo ""

# ─── Step 3: Create a new access key ─────────────────────────
echo "[3/6] Creating new access key..."
NEW_ACCESS_KEY_ID=$(AWS_PROFILE="$PROFILE" aws iam create-access-key \
  --user-name "$IAM_USER" \
  --query 'AccessKey.AccessKeyId' \
  --output text \
  --no-cli-pager)
NEW_SECRET_ACCESS_KEY=$(AWS_PROFILE="$PROFILE" aws iam create-access-key \
  --user-name "$IAM_USER" \
  --query 'AccessKey.SecretAccessKey' \
  --output text \
  --no-cli-pager)
echo "  New Access Key ID: $NEW_ACCESS_KEY_ID"
echo ""

# ─── Step 4: Update ~/.aws/credentials in-place ──────────────
echo "[4/6] Updating credentials for profile [$PROFILE]..."
aws configure set aws_access_key_id "$NEW_ACCESS_KEY_ID" --profile "$PROFILE"
aws configure set aws_secret_access_key "$NEW_SECRET_ACCESS_KEY" --profile "$PROFILE"
echo "  Updated profile [$PROFILE]."
echo ""

# ─── Step 5: Verify new key with retries ─────────────────────
echo "[5/6] Verifying new key (may take up to 60s for IAM propagation)..."
MAX_ATTEMPTS=6
ATTEMPT=0
VERIFIED=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS..."
  if AWS_PROFILE="$PROFILE" aws sts get-caller-identity --no-cli-pager > /dev/null 2>&1; then
    echo "  SUCCESS: New key verified."
    VERIFIED=1
    break
  fi
  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    echo "  Not ready yet, waiting 10s..."
    sleep 10
  fi
done

if [ $VERIFIED -eq 0 ]; then
  echo ""
  echo "  WARNING: New key did not verify after $((MAX_ATTEMPTS * 10))s."
  echo "  Old key has NOT been deactivated."
  echo ""
  echo "  To rollback, restore from backup:"
  echo "    cp $BACKUP $CREDS_FILE"
  echo ""
  echo "  Or manually delete the new key and restore the old one:"
  echo "    aws iam delete-access-key --user-name $IAM_USER --access-key-id $NEW_ACCESS_KEY_ID"
  echo "    cp $BACKUP $CREDS_FILE"
  exit 1
fi
echo ""

# ─── Step 6: Delete the old key ─────────────────────────────
echo "[6/6] Deleting old access key: $OLD_KEY_ID ..."
AWS_PROFILE="$PROFILE" aws iam delete-access-key \
  --user-name "$IAM_USER" \
  --access-key-id "$OLD_KEY_ID" \
  --no-cli-pager
echo "  Old key $OLD_KEY_ID has been permanently deleted."
echo ""

# ─── Done ─────────────────────────────────────────────────────
echo "=============================================="
echo "KEY ROTATION COMPLETE"
echo "=============================================="
echo ""
echo "  Profile:  $PROFILE"
echo "  New key:  $NEW_ACCESS_KEY_ID"
echo "  Old key:  $OLD_KEY_ID (deleted)"
echo "  Backup:   ${BACKUP:-none}"
echo ""
echo "You may remove the credentials backup when ready:"
echo "  rm ${BACKUP:-<no backup created>}"
echo "=============================================="
