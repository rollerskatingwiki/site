# MediaWiki Operations

Last reviewed: 2026-10-21

This runbook follows the official MediaWiki documentation and narrows it to one deployment. If this file conflicts with the official docs, trust the docs.

Since 2026-10-21 the wiki runs in Docker. The compose file is `~/dev/docker/docker-compose-wiki.yml`, part of a shared stack that `COMPOSE_FILE` in `~/dev/docker/.env` pulls in. Build files live in `~/dev/docker/wiki/`.

- `wiki`: PHP-FPM, built from Docker Hub `mediawiki:1.43-fpm` (PHP 8.3, MediaWiki 1.43.11)
- `wiki-web`: nginx (`nginx:stable`), published on `172.17.0.1:7734`
- `wiki-jobrunner`: runs the job queue
- `wiki-sitemap`: regenerates the sitemap once a day
- Docker `mariadb` (`wiki-mariadb`): MariaDB 11.8.9 on `127.0.0.1:4938`
- Docker `caddy`, which proxies to `host.docker.internal:7734`. It lives in `~/dev/docker` and uses its own Cloudflare token, `CLOUDFLARE_API_TOKEN_WIKI`.

The compose file and Caddyfile under this repo's `infra/` are outdated examples, and the live stack doesn't use them. AGENTS.md ("Docker Deployment") explains the architecture and the reasoning. The Install and Upgrades sections below describe the pre-Docker host install (host nginx + php-fpm); you'd follow them to roll back to it.

## Docker operations

```bash
cd ~/dev/docker
docker compose ps wiki wiki-web wiki-jobrunner wiki-sitemap
docker compose logs -f wiki wiki-web               # PHP and nginx logs
docker exec wiki php maintenance/run.php showJobs  # read-only maintenance
docker exec -u www-data wiki php maintenance/run.php <script>  # anything that writes files
~/dev/docker/wiki/update.sh                         # rebuild + redeploy (also daily via wiki-update.timer)
```

- Settings: edit `app/config/LocalSettings.php` as before. The containers mount it read-only, and PHP rereads it within 60 s (opcache revalidation), so you don't need a rebuild.
- Container-only overrides (DB host, Lua engine, ffmpeg, job runner): `~/dev/docker/wiki/LocalSettings.php`. This wrapper sets the DB host, LuaSandbox, the ffmpeg path and `$wgJobRunRate = 0`.
- DB credentials: `app/config/secrets/SecretsSettings.php`, with a copy in `app/config/secrets/db.php`.
- PHP limits: the image's php.ini allows 50M uploads and posts, 256M of memory and 120 s of execution. OPcache gets 256M, and the image ships APCu.
- Extensions: add or bump the `ADD` line in `~/dev/docker/wiki/Dockerfile`, load the extension with `wfLoadExtension()` in LocalSettings, and run `update.sh`. If the extension loads its own composer autoloader, add it to the Dockerfile's `composer install` loop.
- Updates: `update.sh` takes a backup, runs `build --pull`, recreates the containers, runs `update.php` and smoke-tests the result. `wiki-update.timer` runs it at 04:30 America/Toronto. Watchtower excludes the wiki containers, so `update.sh` is the one path that updates them.
- Rollback: if the smoke test fails, `update.sh` rolls back to the `:previous` images. To roll back by hand, run `docker tag local/rollerskating-wiki:previous local/rollerskating-wiki:1.43`, repeat it for `-web`, then run `docker compose up -d --force-recreate wiki wiki-web wiki-jobrunner wiki-sitemap`.
- Open issues: email has no SMTP, and MediaWiki sees Caddy's IP as the client IP.

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

Use `MariaDB` unless you have a strong reason to standardize on MySQL. The live stack runs MariaDB 11.8.9.

- MediaWiki's docs recommend `MariaDB / MySQL`.
- Wikimedia runs MariaDB.

For MediaWiki, MariaDB is the lower-risk default. MySQL may win some benchmarks, and that trade is fine for this stack.

## Caching

The baseline for this deployment:

- PHP `OPcache` (256M) in the `wiki` image
- `APCu` in the `wiki` image, as MediaWiki's local object cache
- Cloudflare for TLS, shielding, and static asset caching
- no `Memcached` for now
- no `Redis` for now

MediaWiki's docs split caching into separate layers. Cloudflare, APCu, Memcached and Redis each solve a different problem, so you can't swap one for another.

Options the official docs cover:

- PHP opcode cache: OPcache, the recommended PHP bytecode cache.
- Local server object cache: APCu, the standard local cache on a single host.
- Main object cache: Memcached, the canonical recommendation in the performance docs.
- Custom object cache backend: Redis, documented and supported via `$wgObjectCaches`.
- Fallback object cache: the database via `CACHE_DB`, which is slower.
- Anonymous page-view caching proxy: Varnish or nginx FastCGI cache.
- CDN/proxy layer: MediaWiki supports CDN-style page caching via `$wgUseCdn` and related settings.

Recommended order for this deployment:

1. Enable OPcache and APCu. The `wiki` image ships both.
2. Start without Cloudflare page caching.
3. For a small or moderate wiki, APCu alone covers the start.
4. Add Redis or Memcached once real usage shows you need a shared cache layer.
5. Turn on proxy/page caching for anonymous traffic once you can manage purges.

### Cloudflare

Cloudflare handles these jobs here:

- TLS termination in front of your origin
- DDoS and bot mitigation
- caching of static assets

Be conservative with whole-page caching:

- Don't enable `Cache Everything` for a wiki with logged-in users.
- Keep logged-in and personalized responses out of the edge cache.
- For anonymous page caching, configure MediaWiki's CDN-aware settings with care and test purges before you rely on them.

### OPcache and APCu

The `wiki` image enables OPcache and includes APCu, and MediaWiki auto-detects the local-server cache backend. APCu is the first MediaWiki cache layer to enable on a single host.

On the pre-Docker host install, you installed APCu with this package and enabled OPcache in the PHP-FPM configuration:

```bash
sudo apt install -y php-apcu
```

See also:

- <https://www.mediawiki.org/wiki/Manual:Performance_tuning>

### Memcached

The official performance docs name Memcached as the canonical shared object cache. Pick it if you want a central cache for one or more app servers.

The docs warn that Memcached has no authentication. Keep it off public networks.

Examples in this deployment pack (the compose override targets the outdated `infra/docker-compose.yml`, so port it to `~/dev/docker/docker-compose-wiki.yml` first):

- [infra/docker-compose.memcached.override.yml.example](../infra/docker-compose.memcached.override.yml.example)
- [app/config/cache.memcached.php.example](../app/config/cache.memcached.php.example)

See also:

- <https://www.mediawiki.org/wiki/Manual:Memcached>
- <https://www.mediawiki.org/wiki/Manual:$wgMainCacheType>

### Redis

MediaWiki documents Redis as an object cache backend too. Self-hosters like it because it supports authentication and can hold sessions, stash and the job queue.

Examples in this deployment pack (same caveat about the outdated `infra/` compose):

- [infra/docker-compose.redis.override.yml.example](../infra/docker-compose.redis.override.yml.example)
- [app/config/cache.redis.php.example](../app/config/cache.redis.php.example)

See also:

- <https://www.mediawiki.org/wiki/Redis>
- <https://www.mediawiki.org/wiki/Manual:$wgObjectCaches>

### Recommendation for your setup

1. `OPcache + APCu` from day one.
2. Cloudflare for TLS, protection, and static assets.
3. No Memcached or Redis until metrics or observed load justify them.

For a single host, that is the production baseline with the fewest moving parts.

## Version policy

Run the current LTS branch from the version lifecycle page unless you need a newer feature, and keep extensions on the matching branch, such as `REL1_43`.

The wiki runs MediaWiki 1.43.11 on PHP 8.3. MediaWiki supports 1.43 LTS until December 2027 and plans 1.47 LTS for November 2026. MediaWiki 1.43 supports PHP 8.1 to 8.3.

## Install (pre-Docker host install)

These steps built the original host install with host nginx and php-fpm. The live wiki doesn't use them. Keep them for rollback.

### 1. Create a service account

Create a dedicated `wiki` user on the server:

```bash
sudo adduser --disabled-password --gecos "" wiki
sudo chown -R wiki:wiki /home/wiki/dev/wiki
```

If you keep a local copy of this deployment pack under `/Users/assisrmatheus/Developer/wiki`, copy it to `/home/wiki/dev/wiki` on the production server before you run the scripts.

### 2. Install host packages

Follow the installation requirements page and keep the host runtime lean:

```bash
sudo apt update
sudo apt install -y nginx php-fpm php-cli php-mysql php-intl php-mbstring php-xml php-curl php-apcu php-gd imagemagick ffmpeg unzip curl git
```

### 3. Configure Docker services

This step ran MariaDB and Caddy from the repo's `infra/` compose. The live stack in `~/dev/docker` replaced those files, which survive as outdated examples. Review and copy:

- [infra/docker-compose.yml](../infra/docker-compose.yml)
- [infra/.env.example](../infra/.env.example)
- [infra/caddy/Caddyfile](../infra/caddy/Caddyfile)
- [infra/mariadb/conf.d/50-mediawiki.cnf](../infra/mariadb/conf.d/50-mediawiki.cnf)

Then:

```bash
cd /home/wiki/dev/wiki/infra
cp .env.example .env
docker compose up -d
```

### 4. Configure host nginx and php-fpm

Copy the example files and adjust them for your domain and PHP version:

- [ops/nginx/wiki.conf.example](../ops/nginx/wiki.conf.example)
- [ops/php-fpm/wiki.conf.example](../ops/php-fpm/wiki.conf.example)
- [ops/php-fpm/10-opcache.ini.example](../ops/php-fpm/10-opcache.ini.example)

Install them:

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

Deploy with the script instead of unpacking into a mutable live tree:

```bash
sudo -u wiki /home/wiki/dev/wiki/ops/bin/deploy-core.sh 1.43.6
```

The script creates `app/releases/mediawiki-1.43.6/`, wires shared directories and config symlinks, and sets `app/current` if it doesn't exist yet.

### 6. Install MediaWiki using the CLI installer

Use the official CLI installer instead of the web installer. This command targets `127.0.0.1:3307`; the Docker MariaDB listens on `127.0.0.1:4938`.

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

Move LocalSettings into `app/config/` and create the DB secrets file:

```bash
sudo -u wiki mv /home/wiki/dev/wiki/app/current/LocalSettings.php /home/wiki/dev/wiki/app/config/LocalSettings.php
sudo -u wiki ln -s /home/wiki/dev/wiki/app/config/LocalSettings.php /home/wiki/dev/wiki/app/current/LocalSettings.php
cp /home/wiki/dev/wiki/app/config/secrets/db.php.example /home/wiki/dev/wiki/app/config/secrets/db.php
chmod 640 /home/wiki/dev/wiki/app/config/LocalSettings.php /home/wiki/dev/wiki/app/config/secrets/db.php
```

Then edit both, using these examples as reference:

- [app/config/LocalSettings.php.example](../app/config/LocalSettings.php.example)
- [app/config/secrets/db.php.example](../app/config/secrets/db.php.example)

### 7. Enable jobs

Install the systemd job runner. On Docker, the `wiki-jobrunner` container does this job.

```bash
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-jobs.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-jobs.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wiki-jobs.timer
```

### 8. Install extensions

For non-bundled extensions, use the matching branch and run the updater after each change:

```bash
sudo -u wiki /home/wiki/dev/wiki/ops/bin/install-extension.sh TimedMediaHandler REL1_43
sudo -u wiki php /home/wiki/dev/wiki/app/current/maintenance/run.php update
```

For FFmpeg-backed media, keep `ffmpeg` installed on the host and follow the TimedMediaHandler docs.

## Upgrades (pre-Docker host install)

On Docker, `update.sh` handles upgrades (see Docker operations). This section covers the host install's release-directory workflow. Treat `Manual:Upgrading` as the source of truth.

Standard workflow:

1. Take fresh DB and file backups.
2. Deploy a new release directory.
3. Update non-bundled extensions to the matching branch.
4. Run `maintenance/run.php update`.
5. Test through the local origin.
6. Switch `app/current`.
7. Keep the previous release until you've confirmed the new one works.

Scripted example:

```bash
sudo -u wiki /home/wiki/dev/wiki/ops/bin/upgrade-core.sh 1.43.12
# test the new release, then:
sudo -u wiki /home/wiki/dev/wiki/ops/bin/upgrade-core.sh 1.43.12 --switch
```

The first run backs up the DB and files, deploys the release, carries over the non-bundled extensions and skins (bundled ones come from the new tarball), copies custom `resources/assets/` files, and runs `update`. It leaves `app/current` alone. `--switch` flips it in one atomic step.

Carried-over extensions keep their old code, so update each one to the matching `REL1_xx` branch or release tag. `TimedMediaHandler` and `Translate` load their own `vendor/`; run `composer install --no-dev` in those directories after you update them.

MediaWiki's `updatelog` keys include the absolute patch path, so a few extension schema patches (Translate, TimedMediaHandler) re-apply once per new release directory. They're idempotent.

## Maintenance

`wiki-update.timer` runs `update.sh` each night at 04:30 America/Toronto. Each run pulls the current `mediawiki:1.43-fpm` image, which carries MediaWiki point releases.

The host runs Ubuntu 25.10, which reached end of life on 2026-07-09 and gets no more security updates. Upgrade it to 26.04 LTS; that upgrade is pending.

Monthly checks:

- apply Ubuntu security updates (possible again after the 26.04 upgrade)
- confirm `wiki-update.timer` ran and `update.sh` passed its smoke test
- review MediaWiki LTS point releases and plan the move to 1.47 LTS
- review extension branch compatibility
- confirm the job runner works (`wiki-jobrunner` on Docker, the systemd job timer on the host install)
- confirm you can read the DB and file backups
- test a restore outside production

## Backups

MediaWiki's backup docs name the database and the filesystem as the data you need to keep.

Back up:

- database dumps
- `app/config/`
- `app/shared/images/`
- `infra/`
- custom extensions and skins if present
- optional XML exports

Scripts:

- [ops/bin/backup-db.sh](../ops/bin/backup-db.sh)
- [ops/bin/backup-files.sh](../ops/bin/backup-files.sh)
- [ops/bin/backup-xml.sh](../ops/bin/backup-xml.sh)

`update.sh` takes a backup before it rebuilds the containers.

Systemd automation:

- [ops/systemd/wiki-backup-db.service](../ops/systemd/wiki-backup-db.service)
- [ops/systemd/wiki-backup-db.timer](../ops/systemd/wiki-backup-db.timer)
- [ops/systemd/wiki-backup-files.service](../ops/systemd/wiki-backup-files.service)
- [ops/systemd/wiki-backup-files.timer](../ops/systemd/wiki-backup-files.timer)

`wiki-backup-db.timer` runs at 03:15 UTC, and `wiki-backup-files.timer` runs at 03:45 UTC as root. No timer runs `backup-xml.sh`, so you run it by hand when you want an XML export.

Install:

```bash
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-db.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-db.timer /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-files.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-files.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wiki-backup-db.timer wiki-backup-files.timer
```

`backup-db.sh` and `restore-db.sh` read `MARIADB_PASSWORD` from `infra/.env` if it exists, otherwise from `app/config/secrets/db.php`. The server has no `infra/.env`, so both scripts use `db.php`.

Sitemap on the pre-Docker host install (daily, as `wiki`). The `wiki-sitemap` container replaced this timer.

```bash
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-sitemap.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-sitemap.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wiki-sitemap.timer
```

Extra backups worth keeping:

- encrypted off-host copies of `backups/`
- a periodic cold copy of the MariaDB data directory after a clean shutdown: `~/dev/docker/wiki-mariadb/data/` on Docker, `infra/mariadb/data/` on the host install
- snapshot backups at the host or provider layer

## Security

Keep these constraints in place:

- Caddy is the one service the internet can reach.
- `wiki-web` publishes nginx on the Docker bridge IP (`172.17.0.1:7734`), not `0.0.0.0`, and Caddy reaches it as `host.docker.internal:7734`. The host install bound host nginx to the same address.
- Keep MariaDB bound to `127.0.0.1:4938`.
- Let PHP run for MediaWiki's entry points (`index`, `load`, `api`, `rest`, `thumb`, `opensearch_desc`, `img_auth`) and nothing else. The live config is `~/dev/docker/wiki/nginx.conf`; the host install used `ops/nginx/wiki.conf.example`.
- Keep Cloudflare on `Full (strict)`.
- Deny PHP execution from uploads.
- Block `/mw-config/` after installation.
- Run as few extensions as you can.
- Disable anonymous editing and self-service registration unless you need them.

Two gaps remain open. Email has no SMTP, so the wiki can't send mail. MediaWiki sees Caddy's IP as the client IP, so IP blocks and logs point at Caddy instead of the visitor.
