---
name: rotate-aws-keys
description: >
  Generates a bash script to rotate AWS IAM access keys for a given user. Use this skill whenever the user mentions
  rotating AWS keys, refreshing AWS credentials, replacing access keys, or asks about AWS key rotation best practices.
  Also trigger when the user says things like "my AWS keys are old", "time to rotate credentials", "new access key",
  or "update my AWS secrets". This skill reads ~/.aws/credentials to identify the current key and produces a safe,
  reviewable rotation script — it never executes AWS commands directly.
---

# AWS Access Key Rotation

This skill generates a self-contained bash script that safely rotates AWS IAM access keys. The script is designed to be reviewed by the user before execution — Claude should never run the rotation commands directly.

## Why this approach

AWS key rotation is a sensitive operation: if done wrong, you can lock yourself out. Generating a script (rather than executing live) lets the user review every step, run it on the machine that actually has the credentials, and abort if anything looks off. The script includes rollback instructions in case the new key fails verification.

## What the script does

1. Reads the current access key ID from `~/.aws/credentials` for the specified profile
2. Verifies the current credentials work (`sts get-caller-identity`)
3. Creates a new access key via `iam create-access-key`
4. Updates `~/.aws/credentials` in-place with the new key
5. Waits for IAM propagation (with retries), then verifies the new key works (`sts get-caller-identity`)
6. Permanently deletes the old key via `iam delete-access-key`

## How to use this skill

When the user asks to rotate their AWS keys:

1. Ask which **IAM username** to rotate keys for (no default — required)
2. Ask which **AWS profile** to use (default: `default`)
3. Read the bundled script template at `scripts/rotate-aws-keys.sh` (relative to this skill's directory)
4. Customize the `IAM_USER` and `PROFILE` defaults in the script based on the user's answers
5. Save the customized script to the user's working directory
6. Tell the user to review it and run it from their terminal:
   ```
   bash rotate-aws-keys.sh
   ```
   or with a specific profile:
   ```
   bash rotate-aws-keys.sh dev
   ```

## Important notes

- **Never run the rotation script yourself.** The credentials file lives on the user's local machine, not in Claude's sandbox. Always hand the script to the user.
- **One key at a time.** AWS allows a maximum of two access keys per IAM user. The script creates a new one before deactivating the old one, so it will fail if the user already has two active keys.
- If the user has multiple profiles that share the same IAM user but different key pairs, mention that they'll need to update each profile separately (or consolidate to a single key).
- The script uses `aws configure set` to update credentials in-place, which preserves other profiles in the file.
