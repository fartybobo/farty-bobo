#!/bin/bash
# Removes ~/.aws/credentials.bak.* backup files created by rotate-aws-keys.sh
set -euo pipefail

CREDS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

# Validate the credentials path looks sane before expanding globs from it
if [[ "$CREDS_FILE" != "$HOME/.aws/"* && "$CREDS_FILE" != /home/*/.aws/* ]]; then
  echo "Error: credentials file path looks suspicious: $CREDS_FILE" >&2
  exit 1
fi

# Collect backup files into an array via glob expansion
BACKUPS=( "${CREDS_FILE}".bak.* )

# Check whether the glob matched anything real
if [ ! -e "${BACKUPS[0]}" ]; then
  echo "No backup files found matching ${CREDS_FILE}.bak.*"
  exit 0
fi

echo "Found the following backup files:"
printf '%s\n' "${BACKUPS[@]}"
echo ""
read -r -p "Delete all of the above? [y/N] " CONFIRM
case "$CONFIRM" in
  [yY][eE][sS]|[yY]) ;;
  *) echo "Aborted."; exit 0 ;;
esac

if rm -- "${BACKUPS[@]}"; then
  echo "Done. Backups deleted."
else
  echo "Error: some files could not be deleted." >&2
  exit 1
fi
