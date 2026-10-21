# MediaWiki Operations

Last reviewed: 2026-10-21

This runbook is intentionally anchored to official MediaWiki documentation and then narrowed to one deployment shape:

- host MediaWiki
- host `nginx`
- host `php-fpm`
- Docker `caddy`
- Docker `mariadb`

Primary references:

- <https://www.mediawiki.org/wiki/Manual:Installing_MediaWiki>
- <https://www.mediawiki.org/wiki/Manual:Installation_requirements>
- <https://www.mediawiki.org/wiki/Manual:Install.php>
- <https://www.mediawiki.org/wiki/Manual:Upgrading>
- <https://www.mediawiki.org/wiki/Manual:Extensions/Installation_and_upgrade>
- <https://www.mediawiki.org/wiki/Manual:Security>
- <https://www.mediawiki.org/wiki/Manual:LocalSettings.php>
- <https://www.mediawiki.org/wiki/Manual:Securing_database_passwords>
- <https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki>
- <https://www.mediawiki.org/wiki/Manual:RunJobs.php>
- <https://www.mediawiki.org/wiki/Extension:TimedMediaHandler>
- <https://www.mediawiki.org/wiki/Version_lifecycle>

## Database choice

Use `MariaDB` unless you have a strong reason to standardize on MySQL instead.

Reason:

- MediaWiki officially recommends `MariaDB / MySQL`.
- Wikimedia uses MariaDB.
- For MediaWiki specifically, MariaDB is the safer default choice.

This is not a blanket claim that MariaDB is always faster than MySQL in every workload. It is the lower-risk default for this stack.

## Caching

The chosen baseline for this deployment is:

- PHP `OPcache` on the host
- `APCu` on the host for MediaWiki's local object cache
- Cloudflare for TLS, shielding, and static asset caching
- no `Memcached` for now
- no `Redis` for now

The official MediaWiki docs split caching into separate layers. Do not treat Cloudflare, APCu, Memcached, and Redis as if they solve the same problem.

Officially documented options relevant to your setup:

- PHP opcode cache: OPcache. This is the recommended PHP bytecode cache.
- Local server object cache: APCu is the normal local cache on a single host.
- Main object cache: Memcached is the canonical recommendation in the performance docs.
- Custom object cache backend: Redis is officially documented and supported via `$wgObjectCaches`.
- Fallback object cache: the database via `CACHE_DB`, which is slower.
- Anonymous page-view caching proxy: Varnish or nginx FastCGI cache.
- CDN/proxy layer: MediaWiki supports CDN-style page caching via `$wgUseCdn` and related settings.

Recommended order for this deployment:

1. Always enable OPcache and install APCu on the host.
2. Start without Cloudflare page caching.
3. If the wiki is small or moderate, APCu alone is often enough to start.
4. Add Redis or Memcached only if real usage shows the need for a shared cache layer.
5. Only enable proxy/page caching for anonymous traffic when you are ready to manage purge behavior correctly.

### Cloudflare

Cloudflare is useful here for:

- TLS termination in front of your origin
- DDoS and bot mitigation
- caching of static assets

Be conservative with whole-page caching:

- Do not blindly enable `Cache Everything` for a wiki with logged-in users.
- Logged-in and personalized responses should not be edge-cached as generic public pages.
- If you want anonymous page caching, use MediaWiki's CDN-aware settings deliberately and test purge behavior.

### OPcache and APCu

Install on the host:

```bash
sudo apt install -y php-apcu
```

`OPcache` should be enabled in your PHP-FPM configuration. `APCu` is the first MediaWiki cache layer to enable on a single host. MediaWiki auto-detects the local-server cache backend.

See also:

- <https://www.mediawiki.org/wiki/Manual:Performance_tuning>

### Memcached

This is the canonical shared object-cache option in the official performance docs. It is a good choice if you want a central cache for one or more app servers.

Security warning from the official docs:

- Memcached has no authentication.
- It must never be publicly exposed.

Examples included in this deployment pack:

- [infra/docker-compose.memcached.override.yml.example](/Users/assisrmatheus/Developer/wiki/infra/docker-compose.memcached.override.yml.example)
- [app/config/cache.memcached.php.example](/Users/assisrmatheus/Developer/wiki/app/config/cache.memcached.php.example)

See also:

- <https://www.mediawiki.org/wiki/Manual:Memcached>
- <https://www.mediawiki.org/wiki/Manual:$wgMainCacheType>

### Redis

Redis is also officially documented as an object cache backend. In practice it is often attractive for self-hosters because it can be authenticated and reused for sessions, stash, and optionally the job queue.

Examples included in this deployment pack:

- [infra/docker-compose.redis.override.yml.example](/Users/assisrmatheus/Developer/wiki/infra/docker-compose.redis.override.yml.example)
- [app/config/cache.redis.php.example](/Users/assisrmatheus/Developer/wiki/app/config/cache.redis.php.example)

See also:

- <https://www.mediawiki.org/wiki/Redis>
- <https://www.mediawiki.org/wiki/Manual:$wgObjectCaches>

### Recommendation for your setup

For your deployment, the chosen setup is:

1. `OPcache + APCu` on day one.
2. Cloudflare for TLS, protection, and static assets.
3. No Memcached or Redis unless later metrics or observed load justify them.

That is the lowest-complexity production baseline for a single-host deployment.

## Version policy

For production, prefer the current LTS branch from the version lifecycle page unless you need a newer feature. Keep extensions on the matching branch, such as `REL1_43`.

## Install

### 1. Create a service account

Use a dedicated `wiki` user on the server:

```bash
sudo adduser --disabled-password --gecos "" wiki
sudo chown -R wiki:wiki /home/wiki/dev/wiki
```

If you are keeping this deployment pack under `/Users/assisrmatheus/Developer/wiki` locally, copy it to `/home/wiki/dev/wiki` on the production server before running the scripts.

### 2. Install host packages

Follow the installation requirements page and keep the host runtime simple:

```bash
sudo apt update
sudo apt install -y nginx php-fpm php-cli php-mysql php-intl php-mbstring php-xml php-curl php-apcu php-gd imagemagick ffmpeg unzip curl git
```

### 3. Configure Docker services

Review and copy:

- [infra/docker-compose.yml](/Users/assisrmatheus/Developer/wiki/infra/docker-compose.yml)
- [infra/.env.example](/Users/assisrmatheus/Developer/wiki/infra/.env.example)
- [infra/caddy/Caddyfile](/Users/assisrmatheus/Developer/wiki/infra/caddy/Caddyfile)
- [infra/mariadb/conf.d/50-mediawiki.cnf](/Users/assisrmatheus/Developer/wiki/infra/mariadb/conf.d/50-mediawiki.cnf)

Then:

```bash
cd /home/wiki/dev/wiki/infra
cp .env.example .env
docker compose up -d
```

### 4. Configure host nginx and php-fpm

Copy the example files and adjust them for your domain and PHP version:

- [ops/nginx/wiki.conf.example](/Users/assisrmatheus/Developer/wiki/ops/nginx/wiki.conf.example)
- [ops/php-fpm/wiki.conf.example](/Users/assisrmatheus/Developer/wiki/ops/php-fpm/wiki.conf.example)
- [ops/php-fpm/10-opcache.ini.example](/Users/assisrmatheus/Developer/wiki/ops/php-fpm/10-opcache.ini.example)

Suggested install:

```bash
sudo cp /home/wiki/dev/wiki/ops/nginx/wiki.conf.example /etc/nginx/sites-available/wiki.conf
sudo ln -s /etc/nginx/sites-available/wiki.conf /etc/nginx/sites-enabled/wiki.conf
sudo cp /home/wiki/dev/wiki/ops/php-fpm/wiki.conf.example /etc/php/8.3/fpm/pool.d/wiki.conf
sudo cp /home/wiki/dev/wiki/ops/php-fpm/10-opcache.ini.example /etc/php/8.3/fpm/conf.d/10-opcache.ini
sudo nginx -t
sudo systemctl restart php8.3-fpm
sudo systemctl reload nginx
```

### 5. Deploy a MediaWiki release

Use the deploy script rather than unpacking into a mutable live tree:

```bash
sudo -u wiki /home/wiki/dev/wiki/ops/bin/deploy-core.sh 1.43.6
```

That creates `app/releases/mediawiki-1.43.6/`, wires shared directories and config symlinks, and sets `app/current` if it does not exist yet.

### 6. Install MediaWiki using the CLI installer

Use the official CLI installer rather than the web installer:

```bash
sudo -u wiki php /home/wiki/dev/wiki/app/current/maintenance/run.php install \
  --dbname mediawiki \
  --dbserver 127.0.0.1:3307 \
  --dbuser mediawiki \
  --dbpass 'replace_me' \
  --installdbuser root \
  --installdbpass 'replace_me' \
  --server https://wiki.example.com \
  --scriptpath "" \
  --lang en \
  "Wiki Name" "WikiAdmin"
```

After that:

```bash
sudo -u wiki mv /home/wiki/dev/wiki/app/current/LocalSettings.php /home/wiki/dev/wiki/app/config/LocalSettings.php
sudo -u wiki ln -s /home/wiki/dev/wiki/app/config/LocalSettings.php /home/wiki/dev/wiki/app/current/LocalSettings.php
cp /home/wiki/dev/wiki/app/config/secrets/db.php.example /home/wiki/dev/wiki/app/config/secrets/db.php
chmod 640 /home/wiki/dev/wiki/app/config/LocalSettings.php /home/wiki/dev/wiki/app/config/secrets/db.php
```

Then edit:

- [app/config/LocalSettings.php.example](/Users/assisrmatheus/Developer/wiki/app/config/LocalSettings.php.example)
- [app/config/secrets/db.php.example](/Users/assisrmatheus/Developer/wiki/app/config/secrets/db.php.example)

### 7. Enable jobs

Install the systemd job runner:

```bash
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-jobs.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-jobs.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wiki-jobs.timer
```

### 8. Install extensions

For non-bundled extensions, use matching branches and run the updater after changes:

```bash
sudo -u wiki /home/wiki/dev/wiki/ops/bin/install-extension.sh TimedMediaHandler REL1_43
sudo -u wiki php /home/wiki/dev/wiki/app/current/maintenance/run.php update
```

For FFmpeg-backed media support, keep `ffmpeg` installed on the host and follow the TimedMediaHandler docs.

## Upgrades

Follow `Manual:Upgrading` as the source of truth.

Standard workflow:

1. Take fresh DB and file backups.
2. Deploy a new release directory.
3. Update non-bundled extensions to the matching branch.
4. Run `maintenance/run.php update`.
5. Test through the local origin.
6. Switch `app/current`.
7. Keep the previous release until the new one is confirmed healthy.

Scripted example:

```bash
sudo -u wiki /home/wiki/dev/wiki/ops/bin/upgrade-core.sh 1.43.12
# test the new release, then:
sudo -u wiki /home/wiki/dev/wiki/ops/bin/upgrade-core.sh 1.43.12 --switch
```

The first run backs up the DB and files, deploys the release, carries over only non-bundled extensions/skins (bundled ones come from the new tarball), copies custom `resources/assets/` files, and runs `update`. It does not switch `app/current`; `--switch` does that atomically.

Carried-over extensions keep their old code: update each one to the matching `REL1_xx` branch or release tag. `TimedMediaHandler` and `Translate` load their own `vendor/`, so run `composer install --no-dev` in those directories after updating them.

MediaWiki's `updatelog` keys include the absolute patch path, so a few extension schema patches (Translate, TimedMediaHandler) re-apply once per new release directory. They are idempotent.

## Maintenance

Monthly checks:

- apply Ubuntu security updates
- review MediaWiki LTS point releases
- review extension branch compatibility
- verify systemd job timer success
- verify DB and file backups can be read
- test a restore outside production

## Backups

The official backup docs are clear that the important data is the database and the filesystem.

Back up:

- database dumps
- `app/config/`
- `app/shared/images/`
- `infra/`
- custom extensions and skins if present
- optional XML exports

Scripts:

- [ops/bin/backup-db.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/backup-db.sh)
- [ops/bin/backup-files.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/backup-files.sh)
- [ops/bin/backup-xml.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/backup-xml.sh)

Systemd automation:

- [ops/systemd/wiki-backup-db.service](/Users/assisrmatheus/Developer/wiki/ops/systemd/wiki-backup-db.service)
- [ops/systemd/wiki-backup-db.timer](/Users/assisrmatheus/Developer/wiki/ops/systemd/wiki-backup-db.timer)
- [ops/systemd/wiki-backup-files.service](/Users/assisrmatheus/Developer/wiki/ops/systemd/wiki-backup-files.service)
- [ops/systemd/wiki-backup-files.timer](/Users/assisrmatheus/Developer/wiki/ops/systemd/wiki-backup-files.timer)

Install:

```bash
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-db.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-db.timer /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-files.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-files.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wiki-backup-db.timer wiki-backup-files.timer
```

`backup-db.sh` and `restore-db.sh` read `MARIADB_PASSWORD` from `infra/.env` if it exists, otherwise from `app/config/secrets/db.php`.

Sitemap (daily, as `wiki`):

```bash
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-sitemap.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-sitemap.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wiki-sitemap.timer
```

Useful extra backups:

- encrypted off-host copies of `backups/`
- periodic cold copy of `infra/mariadb/data/` after a clean shutdown
- snapshot backups at the host or provider layer

## Security

Keep these constraints in place:

- Only Caddy is publicly reachable.
- Keep host nginx bound to the Docker bridge IP (`172.17.0.1:7734`), not `0.0.0.0`; Caddy reaches it as `host.docker.internal:7734`.
- Keep MariaDB bound to `127.0.0.1:4938` only.
- Only MediaWiki's entry points (`index`, `load`, `api`, `rest`, `thumb`, `opensearch_desc`, `img_auth`) run PHP; see `ops/nginx/wiki.conf.example`.
- Keep Cloudflare on `Full (strict)`.
- Deny PHP execution from uploads.
- Block `/mw-config/` after installation.
- Minimize extensions.
- Disable anonymous editing and self-service registration unless needed.

When this file conflicts with official MediaWiki docs, prefer the official docs.
