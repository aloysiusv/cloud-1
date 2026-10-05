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

required_vars=(
  AWS_HOST_ALIAS
  AWS_ELASTIC_IP
  ANSIBLE_USER
  SSH_KEY_PATH
  CLOUD1_PROJECT_DIR
  DUCKDNS_SUBDOMAIN
  ENABLE_DUCKDNS
  ENABLE_TLS
  LETSENCRYPT_EMAIL
  LETSENCRYPT_STAGING
  PHPMYADMIN_ALLOWED_CIDR
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required variable: $var"
    exit 1
  fi
done

mkdir -p "${PROJECT_ROOT}/inventory"
mkdir -p "${PROJECT_ROOT}/host_vars"
mkdir -p "${PROJECT_ROOT}/group_vars"

cat > "${PROJECT_ROOT}/inventory/hosts.ini" <<EOF
[wordpress_servers]
${AWS_HOST_ALIAS} ansible_host=${AWS_ELASTIC_IP}

[wordpress_servers:vars]
ansible_user=${ANSIBLE_USER}
ansible_ssh_private_key_file=${SSH_KEY_PATH}
EOF

cat > "${PROJECT_ROOT}/host_vars/${AWS_HOST_ALIAS}.yml" <<EOF
---
public_ip: ${AWS_ELASTIC_IP}

duckdns_subdomain: ${DUCKDNS_SUBDOMAIN}
domain_name: "{{ duckdns_subdomain }}.duckdns.org"

phpmyadmin_allowed_cidr: ${PHPMYADMIN_ALLOWED_CIDR}
EOF

cat > "${PROJECT_ROOT}/group_vars/generated.yml" <<EOF
---
cloud1_project_dir: ${CLOUD1_PROJECT_DIR}

enable_duckdns: ${ENABLE_DUCKDNS}

enable_tls: ${ENABLE_TLS}
letsencrypt_email: ${LETSENCRYPT_EMAIL}
letsencrypt_staging: ${LETSENCRYPT_STAGING}
EOF

echo "Generated:"
echo "  inventory/hosts.ini"
echo "  host_vars/${AWS_HOST_ALIAS}.yml"
echo "  group_vars/generated.yml"