#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env file."
  echo "Create it with: cp .env.example .env"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [[ -z "${AWS_REGION:-}" ]]; then
  echo "Missing AWS_REGION in .env"
  exit 1
fi

if [[ -z "${AWS_SECURITY_GROUP_ID:-}" ]]; then
  echo "Missing AWS_SECURITY_GROUP_ID in .env"
  exit 1
fi

CURRENT_IP="$(curl -4 -s https://checkip.amazonaws.com | tr -d '\n')"
CIDR="${CURRENT_IP}/32"

echo "Current public IP: ${CURRENT_IP}"
echo "Adding SSH access for: ${CIDR}"
echo "Security Group: ${AWS_SECURITY_GROUP_ID}"
echo "Region: ${AWS_REGION}"

set +e
OUTPUT="$(
  aws ec2 authorize-security-group-ingress \
    --region "${AWS_REGION}" \
    --group-id "${AWS_SECURITY_GROUP_ID}" \
    --protocol tcp \
    --port 22 \
    --cidr "${CIDR}" 2>&1
)"
STATUS=$?
set -e

if [[ "$STATUS" -eq 0 ]]; then
  echo "SSH access added."
  exit 0
fi

if echo "$OUTPUT" | grep -q "InvalidPermission.Duplicate"; then
  echo "SSH access already exists for ${CIDR}."
  exit 0
fi

echo "$OUTPUT"
exit "$STATUS"
