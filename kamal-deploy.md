# Kamal Deployment

> Deploying Rails apps with Kamal on Hetzner Cloud servers with PostgreSQL.

---

## Prerequisites

### Local Machine

- Docker Desktop running
- Kamal installed: `gem install kamal`
- SSH key added to Hetzner Cloud console

### Hetzner Cloud

1. Create a Hetzner Cloud account at [console.hetzner.cloud](https://console.hetzner.cloud)
2. Create a new project
3. Add your SSH public key under **Security → SSH Keys**
4. Create an API token under **Security → API Tokens** (read/write)

### Container Registry

Use Docker Hub or GitHub Container Registry (GHCR). Example uses Docker Hub:

1. Create a Docker Hub account
2. Create an access token at [hub.docker.com/settings/security](https://hub.docker.com/settings/security)

---

## Server Setup

### Provision Hetzner Servers

Create servers via the Hetzner Cloud console or CLI:

| Server | Type | Purpose |
|--------|------|---------|
| **web-1** | CX22 (2 vCPU, 4 GB) | Web + worker |
| **db-1** | CX22 (2 vCPU, 4 GB) | PostgreSQL |

> Start with CX22 for both. Scale up the web server type or add more web servers as traffic grows. For the DB server, upgrade to CX32 or dedicated vCPU when you need more headroom.

**Recommended OS:** Ubuntu (latest LTS)

#### Hetzner Firewall Rules

Create a firewall in Hetzner Cloud console and attach to both servers:

| Direction | Protocol | Port | Source |
|-----------|----------|------|--------|
| Inbound | TCP | 22 | Any (SSH) |
| Inbound | TCP | 80 | Any (HTTP) |
| Inbound | TCP | 443 | Any (HTTPS) |
| Inbound | TCP | 5432 | 10.0.0.0/8 (Private network only) |
| Outbound | All | All | Any |

> Set up a **Private Network** in Hetzner and attach both servers. PostgreSQL should only be accessible over the private network, never the public internet.

### PostgreSQL on db-1

SSH into the database server and install PostgreSQL:

```bash
ssh root@<db-1-public-ip>

# Install PostgreSQL (latest stable)
apt update && apt install -y postgresql postgresql-client

# Switch to postgres user
sudo -u postgres psql
```

```sql
-- Create the app database and user
CREATE USER myapp WITH PASSWORD 'STRONG_PASSWORD_HERE' CREATEDB;
CREATE DATABASE myapp_production OWNER myapp;
CREATE DATABASE myapp_queue_production OWNER myapp;
CREATE DATABASE myapp_cache_production OWNER myapp;
CREATE DATABASE myapp_cable_production OWNER myapp;

\q
```

Configure PostgreSQL to listen on the private network:

```bash
# /etc/postgresql/16/main/postgresql.conf
listen_addresses = 'localhost,<db-1-private-ip>'

# /etc/postgresql/16/main/pg_hba.conf (add this line)
host    myapp_production    myapp    10.0.0.0/8    scram-sha-256
host    myapp_queue_production    myapp    10.0.0.0/8    scram-sha-256
host    myapp_cache_production    myapp    10.0.0.0/8    scram-sha-256
host    myapp_cable_production    myapp    10.0.0.0/8    scram-sha-256
```

```bash
systemctl restart postgresql
```

### Database Backups

Set up automated daily backups on the db server:

```bash
# /opt/scripts/pg_backup.sh
#!/bin/bash
BACKUP_DIR="/opt/backups/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=14

mkdir -p "$BACKUP_DIR"
pg_dump -U myapp -Fc myapp_production > "$BACKUP_DIR/myapp_$TIMESTAMP.dump"

# Remove backups older than $KEEP_DAYS days
find "$BACKUP_DIR" -name "*.dump" -mtime +$KEEP_DAYS -delete
```

```bash
chmod +x /opt/scripts/pg_backup.sh

# Add to crontab — daily at 3 AM
crontab -e
# 0 3 * * * /opt/scripts/pg_backup.sh
```

> For production-critical apps, also enable Hetzner Cloud **Snapshots** on the DB server (weekly) and consider streaming replication to a standby.

---

## Kamal Configuration

### config/deploy.yml

```yaml
service: myapp

image: your-dockerhub-username/myapp

servers:
  web:
    hosts:
      - <web-1-public-ip>
    labels:
      traefik.http.routers.myapp.rule: Host(`myapp.com`) || Host(`www.myapp.com`)
      traefik.http.routers.myapp.tls: true
      traefik.http.routers.myapp.tls.certresolver: letsencrypt
      traefik.http.routers.myapp_www.rule: Host(`www.myapp.com`)
      traefik.http.routers.myapp_www.middlewares: myapp-www-redirect
      traefik.http.middlewares.myapp-www-redirect.redirectregex.regex: ^https://www\.(.*)
      traefik.http.middlewares.myapp-www-redirect.redirectregex.replacement: https://$${1}
      traefik.http.middlewares.myapp-www-redirect.redirectregex.permanent: true

proxy:
  ssl: true
  host: myapp.com
  app_port: 3000

registry:
  username: your-dockerhub-username
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  arch: amd64

env:
  clear:
    RAILS_ENV: production
    RAILS_SERVE_STATIC_FILES: true
    RAILS_LOG_TO_STDOUT: true
    APP_NAME: "My App"
    APP_HOST: myapp.com
    APP_URL: https://myapp.com
    WEB_CONCURRENCY: 2
    RAILS_MAX_THREADS: 5
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - QUEUE_DATABASE_URL
    - CACHE_DATABASE_URL
    - CABLE_DATABASE_URL
    - BREVO_SMTP_USERNAME
    - BREVO_SMTP_PASSWORD
    - BREVO_API_KEY
    - BREVO_SMS_SENDER
    - BREVO_FROM_ADDRESS
    - STRIPE_PUBLIC_KEY
    - STRIPE_SECRET_KEY
    - STRIPE_WEBHOOK_SECRET
    - GOOGLE_CLIENT_ID
    - GOOGLE_CLIENT_SECRET
    - SENTRY_DSN
    - TELEGRAM_API_KEY

accessories:
  # No db accessory — PostgreSQL is installed directly on db-1,
  # not managed by Kamal. Connect via DATABASE_URL.

volumes:
  - "myapp_storage:/rails/storage"

asset_path: /rails/public/assets

# Healthcheck
healthcheck:
  path: /up
  port: 3000
  interval: 10
  max_attempts: 30
```

### .kamal/secrets

Store secrets locally (never committed). Kamal reads these automatically:

```bash
# .kamal/secrets
KAMAL_REGISTRY_PASSWORD=dckr_pat_XXX
RAILS_MASTER_KEY=<paste from config/master.key>
DATABASE_URL=postgres://myapp:STRONG_PASSWORD_HERE@<db-1-private-ip>:5432/myapp_production
QUEUE_DATABASE_URL=postgres://myapp:STRONG_PASSWORD_HERE@<db-1-private-ip>:5432/myapp_queue_production
CACHE_DATABASE_URL=postgres://myapp:STRONG_PASSWORD_HERE@<db-1-private-ip>:5432/myapp_cache_production
CABLE_DATABASE_URL=postgres://myapp:STRONG_PASSWORD_HERE@<db-1-private-ip>:5432/myapp_cable_production
BREVO_SMTP_USERNAME=your-smtp-login@smtp-brevo.com
BREVO_SMTP_PASSWORD=xsmtpsib-XXXXXXXX
BREVO_API_KEY=xkeysib-XXXXXXXX
BREVO_SMS_SENDER=MyApp
BREVO_FROM_ADDRESS=noreply@yourdomain.com
STRIPE_PUBLIC_KEY=pk_live_XXX
STRIPE_SECRET_KEY=sk_live_XXX
STRIPE_WEBHOOK_SECRET=whsec_XXX
GOOGLE_OAUTH_CLIENT_ID=XXX.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-XXX
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
TELEGRAM_API_KEY=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
```

> Add `.kamal/secrets` to `.gitignore`. Commit `.kamal/secrets.example` with placeholder values.

---

## Required Files

### Dockerfile

Kamal deploys Docker images. Rails generates a production-ready Dockerfile. Verify these patterns are present:

```dockerfile
# Dockerfile (Rails default with optimizations)
FROM docker.io/library/ruby:<latest-stable>-slim AS base

# Install jemalloc for memory optimization
RUN apt-get update && apt-get install -y libjemalloc2 && rm -rf /var/lib/apt/lists/*
ENV LD_PRELOAD=libjemalloc.so.2

# ... (rest of base stage)

# Build stage
FROM base AS build

# Install bun for JS deps
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# Install JS dependencies
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile

# Precompile assets (no master key needed at build)
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage
FROM base

# Create non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd --system --uid 1000 --gid rails --create-home rails

USER rails:rails

# Copy built artifacts...
```

**Key optimizations:**
- **jemalloc** — Reduces memory fragmentation, especially important for long-running Rails processes
- **Non-root user** — Security best practice; the app runs as `rails:rails` (UID 1000)
- **SECRET_KEY_BASE_DUMMY** — Allows asset precompilation without the real master key

### Procfile.dev

```procfile
web: bin/rails server -p 3000
js: bun run build --watch
css: bun run build:css --watch
```

### bin/docker-entrypoint

```bash
#!/bin/bash
set -e

# Run migrations on deploy (use db:prepare for schema + migrations)
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails db:prepare
fi

exec "${@}"
```

> Use `db:prepare` instead of `db:migrate` — it runs migrations on existing databases and creates + loads schema on empty ones. This handles initial deploys and subsequent deploys with a single command.

### config/puma.rb

```ruby
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT") { 3000 }

environment ENV.fetch("RAILS_ENV") { "development" }

pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

workers ENV.fetch("WEB_CONCURRENCY") { 2 }

preload_app!

plugin :solid_queue if ENV.fetch("RAILS_ENV", "development") == "production"
plugin :solid_cable if ENV.fetch("RAILS_ENV", "development") == "production"
```

### Healthcheck Endpoint

Rails includes `/up` by default. Verify it exists:

```ruby
# config/routes.rb
get "up" => "rails/health#show", as: :rails_health_check
```

---

## Deploy

### First Deploy

```bash
# 1. Bootstrap Kamal on servers (installs Docker, sets up Traefik)
kamal setup

# 2. Verify it worked
kamal app details
kamal traefik details
```

### Subsequent Deploys

```bash
# Deploy latest code
kamal deploy

# Deploy with a specific git ref
kamal deploy --version=$(git rev-parse --short HEAD)
```

### Useful Commands

```bash
# View app logs
kamal app logs -f

# Run Rails console
kamal app exec -i "bin/rails console"

# Run one-off command
kamal app exec "bin/rails runner 'puts User.count'"

# Run migrations manually
kamal app exec "bin/rails db:migrate"

# Rollback to previous version
kamal rollback

# Check running containers
kamal app details

# Restart app
kamal app boot

# View Traefik logs
kamal traefik logs -f

# Push env changes without redeploying
kamal env push
```

---

## Git & GitHub

### Repository Setup

```bash
# Initialize repo (if not already)
git init
git add .
git commit -m "chore: initial commit"

# Create GitHub repo and push
gh repo create myapp --private --source=. --push
```

> Single-branch workflow: push to `main` → tests run → auto-deploy. No feature branches required.

### .gitignore Essentials

Verify these are in `.gitignore`:

```gitignore
.env
.env.local
.kamal/secrets
tmp/latest.dump
```

> Always commit `.env.example` and `.kamal/secrets.example` with placeholder values.

---

## Automated Deployment (GitHub Actions)

Deploy automatically on every push to `main`. The workflow runs tests, then deploys via Kamal.

### GitHub Secrets

Add all secrets from `.kamal/secrets` plus deployment keys to GitHub:

```bash
# Install GitHub CLI if needed
brew install gh
gh auth login

# Add secrets (one by one)
gh secret set KAMAL_REGISTRY_PASSWORD
gh secret set RAILS_MASTER_KEY
gh secret set DATABASE_URL
gh secret set QUEUE_DATABASE_URL
gh secret set CACHE_DATABASE_URL
gh secret set CABLE_DATABASE_URL
gh secret set BREVO_SMTP_USERNAME
gh secret set BREVO_SMTP_PASSWORD
gh secret set BREVO_API_KEY
gh secret set BREVO_SMS_SENDER
gh secret set BREVO_FROM_ADDRESS
gh secret set STRIPE_PUBLIC_KEY
gh secret set STRIPE_SECRET_KEY
gh secret set STRIPE_WEBHOOK_SECRET
gh secret set GOOGLE_CLIENT_ID
gh secret set GOOGLE_CLIENT_SECRET
gh secret set SENTRY_DSN
gh secret set TELEGRAM_API_KEY

# Add SSH private key for Kamal to access servers
gh secret set SSH_PRIVATE_KEY < ~/.ssh/id_ed25519
```

> When prompted, paste the value interactively. Or pipe it: `echo "value" | gh secret set KEY`

### Managing GitHub Secrets

```bash
# List all secrets
gh secret list

# Update a secret (same command as add — overwrites)
gh secret set STRIPE_SECRET_KEY

# Delete a secret
gh secret delete OLD_SECRET_NAME

# Set secret from a file
gh secret set SSH_PRIVATE_KEY < ~/.ssh/id_ed25519

# Set secret from environment variable
printenv RAILS_MASTER_KEY | gh secret set RAILS_MASTER_KEY
```

### Workflow File

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

concurrency:
  group: deploy
  cancel-in-progress: false

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres
        env:
          POSTGRES_USER: myapp
          POSTGRES_PASSWORD: password
          POSTGRES_DB: myapp_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd="pg_isready"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5

    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://myapp:password@localhost:5432/myapp_test

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - uses: oven-sh/setup-bun@v2

      - run: bun install --frozen-lockfile

      - run: bin/rails db:prepare

      - run: bundle exec rspec

      - run: bun test

  deploy:
    runs-on: ubuntu-latest
    needs: test

    env:
      DOCKER_BUILDKIT: 1
      KAMAL_REGISTRY_PASSWORD: ${{ secrets.KAMAL_REGISTRY_PASSWORD }}
      RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
      DATABASE_URL: ${{ secrets.DATABASE_URL }}
      QUEUE_DATABASE_URL: ${{ secrets.QUEUE_DATABASE_URL }}
      CACHE_DATABASE_URL: ${{ secrets.CACHE_DATABASE_URL }}
      CABLE_DATABASE_URL: ${{ secrets.CABLE_DATABASE_URL }}
      BREVO_SMTP_USERNAME: ${{ secrets.BREVO_SMTP_USERNAME }}
      BREVO_SMTP_PASSWORD: ${{ secrets.BREVO_SMTP_PASSWORD }}
      BREVO_API_KEY: ${{ secrets.BREVO_API_KEY }}
      BREVO_SMS_SENDER: ${{ secrets.BREVO_SMS_SENDER }}
      BREVO_FROM_ADDRESS: ${{ secrets.BREVO_FROM_ADDRESS }}
      STRIPE_PUBLIC_KEY: ${{ secrets.STRIPE_PUBLIC_KEY }}
      STRIPE_SECRET_KEY: ${{ secrets.STRIPE_SECRET_KEY }}
      STRIPE_WEBHOOK_SECRET: ${{ secrets.STRIPE_WEBHOOK_SECRET }}
      GOOGLE_OAUTH_CLIENT_ID: ${{ secrets.GOOGLE_OAUTH_CLIENT_ID }}
      GOOGLE_OAUTH_CLIENT_SECRET: ${{ secrets.GOOGLE_OAUTH_CLIENT_SECRET }}
      SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
      TELEGRAM_API_KEY: ${{ secrets.TELEGRAM_API_KEY }}

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - run: kamal deploy

---

## Custom Domain & SSL

### DNS Setup

Point your domain to the web server's public IP:

| Type | Name | Value |
|------|------|-------|
| A | @ | `<web-1-public-ip>` |
| A | www | `<web-1-public-ip>` |

### SSL

Kamal's built-in Traefik proxy handles Let's Encrypt certificates automatically. SSL is configured in `config/deploy.yml` via `proxy.ssl: true`. No additional setup needed — certificates are provisioned on first request.

### Force SSL in Rails

```ruby
# config/environments/production.rb
config.force_ssl = true
config.assume_ssl = true  # Trust Traefik's X-Forwarded-Proto
```

---

## Scaling

### Horizontal (more web servers)

Add more Hetzner servers and list them in `config/deploy.yml`:

```yaml
servers:
  web:
    hosts:
      - <web-1-public-ip>
      - <web-2-public-ip>
      - <web-3-public-ip>
```

Kamal + Traefik automatically load-balance across all hosts.

### Vertical (bigger servers)

Resize the server in Hetzner Cloud console:

| Stage | Web Server | DB Server |
|-------|-----------|-----------|
| Launch | CX22 (2 vCPU, 4 GB) | CX22 (2 vCPU, 4 GB) |
| Growing | CX32 (4 vCPU, 8 GB) | CX32 (4 vCPU, 8 GB) |
| Scale | CX42 (8 vCPU, 16 GB) | CCX33 (8 ded. vCPU, 32 GB) |

### Worker Scaling

For heavy background job loads, run Solid Queue workers on a separate server:

```yaml
servers:
  web:
    hosts:
      - <web-1-public-ip>
  worker:
    hosts:
      - <worker-1-public-ip>
    cmd: bundle exec rake solid_queue:start
```

---

## Monitoring

### Application Logs

```bash
# Stream logs
kamal app logs -f

# Last 100 lines
kamal app logs -n 100

# Search logs
kamal app logs | grep ERROR
```

### Server Monitoring

Install basic monitoring on each Hetzner server:

```bash
# htop for resource usage
apt install -y htop

# Check disk space
df -h

# Check memory
free -m

# Check running containers
docker ps
```

### Database Monitoring

```bash
# Connect to production DB
ssh root@<db-1-public-ip>
sudo -u postgres psql myapp_production

# Check active connections
SELECT count(*) FROM pg_stat_activity WHERE datname = 'myapp_production';

# Check database size
SELECT pg_size_pretty(pg_database_size('myapp_production'));

# Slow queries (if pg_stat_statements enabled)
SELECT query, mean_exec_time, calls FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;
```

### Sentry

Error tracking is handled by Sentry (see [sentry.md](sentry.md)). Verify `SENTRY_DSN` is set in `.kamal/secrets`.

---

## Stripe Webhook Setup

1. Go to Stripe Dashboard → Developers → Webhooks
2. Add endpoint: `https://myapp.com/webhooks/stripe`
3. Select events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
4. Copy signing secret to `STRIPE_WEBHOOK_SECRET` in `.kamal/secrets`
5. Push env: `kamal env push`

---

## Maintenance

### Download & Load Production DB Locally

Add a rake task to pull the latest production dump and load it into the local dev database.

```ruby
# lib/tasks/db_pull.rake
namespace :db do
  desc "Download latest production DB dump and load locally. Usage: rake db:pull"
  task pull: :environment do
    db_config = ActiveRecord::Base.connection_db_config
    local_db  = db_config.database
    dump_file = Rails.root.join("tmp", "latest.dump")

    db_host = ENV.fetch("PRODUCTION_DB_HOST") { abort "Set PRODUCTION_DB_HOST (public IP of db server)" }
    db_name = ENV.fetch("PRODUCTION_DB_NAME", "#{Rails.application.class.module_parent_name.underscore}_production")
    db_user = ENV.fetch("PRODUCTION_DB_USER", Rails.application.class.module_parent_name.underscore)

    puts "==> Dumping #{db_name} from #{db_host}..."
    system("ssh root@#{db_host} 'sudo -u postgres pg_dump -Fc #{db_name}' > #{dump_file}") || abort("Dump failed")

    size_mb = (File.size(dump_file) / 1_048_576.0).round(1)
    puts "==> Downloaded #{dump_file} (#{size_mb} MB)"

    puts "==> Dropping & recreating #{local_db}..."
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke

    puts "==> Restoring dump into #{local_db}..."
    system("pg_restore --no-owner --no-privileges -d #{local_db} #{dump_file}") || abort("Restore failed")

    puts "==> Done. Local #{local_db} is now a copy of production."
  end
end
```

#### Environment setup

Add to `.env` (or export before running):

```bash
PRODUCTION_DB_HOST=<db-1-public-ip>
# Optional overrides (defaults are convention-based):
# PRODUCTION_DB_NAME=myapp_production
# PRODUCTION_DB_USER=myapp
```

#### Usage

```bash
rake db:pull                          # Download + load
PRODUCTION_DB_HOST=1.2.3.4 rake db:pull  # One-off with explicit host
```

#### Notes

- Requires SSH access to the db server (`ssh root@<db-1-public-ip>`)
- Dump is streamed via SSH — no file left on the remote server
- Drops and recreates the local dev database — never run in production
- The dump file is saved to `tmp/latest.dump` (gitignored)
- For large databases, add `--jobs=4` to `pg_restore` for parallel restore

### Database Maintenance

```bash
# Backup before any maintenance
ssh root@<db-1-public-ip>
sudo -u postgres pg_dump -Fc myapp_production > /tmp/myapp_backup.dump

# Restore from backup
sudo -u postgres pg_restore -d myapp_production /tmp/myapp_backup.dump

# Vacuum and analyze
sudo -u postgres vacuumdb --analyze myapp_production
```

### Server Updates

```bash
# Update packages on each server
ssh root@<server-ip>
apt update && apt upgrade -y

# Reboot if kernel was updated
reboot
```

### Rails Credentials

```bash
# Edit credentials locally
EDITOR=vim bin/rails credentials:edit

# After editing, update RAILS_MASTER_KEY in .kamal/secrets if changed
# Then redeploy
kamal deploy
```

---

## Common Issues

### Container won't start

```bash
# Check logs for errors
kamal app logs -n 200

# Common causes:
# - Missing ENV vars (check .kamal/secrets)
# - Database connection refused (check private network + pg_hba.conf)
# - Migrations failed (run manually: kamal app exec "bin/rails db:migrate")
```

### Database connection refused

```bash
# Verify PostgreSQL is listening on the private interface
ssh root@<db-1-public-ip>
ss -tlnp | grep 5432

# Verify pg_hba.conf allows the private network
cat /etc/postgresql/16/main/pg_hba.conf | grep myapp

# Test connection from web server
ssh root@<web-1-public-ip>
apt install -y postgresql-client
psql postgres://myapp:PASSWORD@<db-1-private-ip>:5432/myapp_production
```

### Asset compilation fails

```bash
# Verify Bun is installed in Docker image
kamal app exec "bun --version"

# Verify assets are precompiled
kamal app exec "ls /rails/public/assets"
```

### Traefik not routing

```bash
# Check Traefik is running
kamal traefik details

# Restart Traefik
kamal traefik reboot

# Check certificate status
kamal traefik logs | grep -i "certif"
```

---

## Pre-Deploy Checklist

- [ ] Hetzner servers provisioned (web + db)
- [ ] Private network created and both servers attached
- [ ] Firewall rules applied (SSH, HTTP, HTTPS, PG on private only)
- [ ] PostgreSQL installed and configured on db-1
- [ ] Database user and database created
- [ ] `config/deploy.yml` configured with server IPs
- [ ] `.kamal/secrets` populated with all secrets
- [ ] `.kamal/secrets` added to `.gitignore`
- [ ] `RAILS_MASTER_KEY` matches `config/master.key`
- [ ] `DATABASE_URL` uses the private IP
- [ ] Docker Hub account + access token ready
- [ ] Domain DNS pointing to web server IP
- [ ] Healthcheck endpoint (`/up`) exists
- [ ] `config/environments/production.rb` has `force_ssl` + `assume_ssl`
- [ ] Tested `docker build .` locally
- [ ] GitHub repo created (`gh repo create`)
- [ ] All `.kamal/secrets` values added as GitHub secrets (`gh secret list`)
- [ ] `SSH_PRIVATE_KEY` added as GitHub secret
- [ ] `.github/workflows/deploy.yml` committed

---

## Post-Deploy Checklist

- [ ] App loads at `https://myapp.com`
- [ ] SSL certificate provisioned (green padlock)
- [ ] www redirects to non-www (or vice versa)
- [ ] User can sign up / log in
- [ ] Email verification / password reset works
- [ ] Stripe checkout works
- [ ] Stripe webhook events received
- [ ] Solid Queue processing background jobs
- [ ] Sentry receiving errors
- [ ] Database backups cron running
- [ ] Logs show no errors (`kamal app logs -f`)
