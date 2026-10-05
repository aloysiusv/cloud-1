# Cloud-1 AWS starter

Ansible deploys a Docker Compose WordPress stack on an Ubuntu/Debian-like host.

The role supports the subject's Ubuntu 20.04 assumption through Ubuntu's `docker.io` package plus a pinned Compose v2 plugin. On Ubuntu 22.04+ it uses Docker's current official APT repository.

## Containers

- `nginx`: only public entry point, routes WordPress and `/phpmyadmin/`, terminates TLS.
- `wordpress`: WordPress with PHP-FPM, reachable only through Nginx.
- `mysql`: private database, attached only to the internal backend network.
- `phpmyadmin`: database UI, proxied by Nginx and restricted by source CIDR.
- `certbot`: one-shot tooling profile for Let's Encrypt issuance and renewal.

## 1. Prepare locally

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip ansible
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.ini.example inventory/hosts.ini
cp host_vars/wp1.yml.example host_vars/wp1.yml
ansible-vault create group_vars/vault.yml
```

Put these variables in `group_vars/vault.yml`:

```yaml
vault_db_password: a-long-random-password
vault_db_root_password: another-long-random-password
vault_duckdns_token: your-duckdns-token
```

Edit:

- `inventory/hosts.ini`: EC2 public/Elastic IP and private key path.
- `host_vars/wp1.yml`: Elastic IP, DuckDNS subdomain and your own public IP `/32`.
- `group_vars/all.yml`: Let's Encrypt email and image choices if needed.

## 2. Test SSH and deploy

```bash
ansible wordpress_servers -m ansible.builtin.ping --ask-vault-pass
ansible-playbook site.yml --ask-vault-pass
```

## 3. Verify

```bash
ssh -i ~/.ssh/cloud1-aws.pem ubuntu@YOUR_ELASTIC_IP
cd /opt/cloud1
sudo docker compose ps
sudo docker compose logs --tail=100
curl -I https://YOUR_DOMAIN/
curl -I https://YOUR_DOMAIN/healthz
```

Open:

- `https://YOUR_DOMAIN/` for WordPress.
- `https://YOUR_DOMAIN/phpmyadmin/` from the IP allowed in `phpmyadmin_allowed_cidr`.

Log in to phpMyAdmin with the `wordpress` user and `vault_db_password`.

## 4. Persistence and reboot test

Create a post and upload an image, then:

```bash
sudo reboot
```

Reconnect and verify the post/image still exist. Docker is enabled at boot and every
long-running service uses `restart: unless-stopped`. MySQL and WordPress use named
Docker volumes.

## 5. Multiple servers

Add hosts to `inventory/hosts.ini`, then create one file per host:

```text
host_vars/wp1.yml
host_vars/wp2.yml
```

Each host needs its own `public_ip` and normally its own `domain_name`. Ansible works
on the group in parallel (up to the configured `forks`). This proves reproducible
parallel deployment; it is not a shared-database horizontal WordPress cluster.

## Important warnings

- Never run `docker compose down -v` unless you intentionally want to delete the
  WordPress and MySQL volumes.
- MySQL initialization variables apply only when `mysql_data` is empty. Changing an
  Ansible password later does not automatically change the existing MySQL account.
- Keep TCP/3306, TCP/9000 and phpMyAdmin's container port closed in the EC2 Security
  Group. Only Nginx publishes host ports.
- Do not commit `group_vars/vault.yml`, inventory addresses or private keys.
