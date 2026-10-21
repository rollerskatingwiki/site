# Rollerskating Wiki: Agent Context

Last updated: 2026-10-21

You are reading the context file for agents and operators who work on `https://rollerskating.wiki`. Read it before you edit config, change ports, add extensions or touch backups. If a value here disagrees with the server, trust the server and fix this file.

## Purpose

The repository holds the deployment pack and operator notes for a public MediaWiki instance at:

- `https://rollerskating.wiki`

The owner wants a public, community-driven wiki that stays stable and maintainable in production. Editors build articles from sources, and the wiki doubles as an archive.

## Docker Deployment (current since 2026-10-21)

Treat this section as the source of truth. The host nginx, host php-fpm, `app/releases/` and `app/current` material further down records the old setup for rollback.

### Why the move

- Ubuntu 25.10 on the host reached end of life on 2026-07-09, so host PHP stopped receiving security fixes (e.g. PHP 8.4.27 / 8.3.36, CVE-2026-109618/109619, released 2026-10-21). The upgrade to 26.04 LTS is pending.
- MediaWiki 1.43 supports PHP 8.1–8.3 and the host ran 8.4. The image ships PHP 8.3.
- mediawiki.org warns against MediaWiki-Docker in production. That warning covers the core dev environment (Xdebug, DevelopmentSettings.php, SQLite). For production, mediawiki.org points to the Docker Hub `mediawiki` image, which Wikimedia developers maintain and Docker's official-images pipeline rebuilds on each PHP or MediaWiki release. MediaWiki gives no formal support to any production image, hence the "unofficial, at your own risk" label (https://www.mediawiki.org/wiki/Docker, T318977). Wikimedia serves 100% of its own traffic from containers.

### Where things live

- Compose services: `/home/assisr/dev/docker/docker-compose-wiki.yml`, listed in the shared stack's `COMPOSE_FILE` in `/home/assisr/dev/docker/.env`
- Build files: `/home/assisr/dev/docker/wiki/` (`Dockerfile`, `Dockerfile.web`, `nginx.conf`, `php.ini`, `LocalSettings.php`, `assets/`, `update.sh`, `systemd/`)
- Settings, uploads and sitemap stay in this repo as bind mounts:
  - `app/config/` -> `/config` (read-only). `/home/assisr/dev/docker/wiki/LocalSettings.php` requires `/config/LocalSettings.php` and overrides four container values: `$wgDBserver = 'wiki-mariadb'`, `$wgScribuntoDefaultEngine = 'luasandbox'`, `$wgFFmpegLocation = '/usr/bin/ffmpeg'` and `$wgJobRunRate = 0`.
  - `app/shared/images/` -> `/var/www/html/images`
  - `app/shared/sitemap/` -> `/srv/sitemap`
- DB credentials: `app/config/secrets/SecretsSettings.php`, which `LocalSettings.php` requires. `app/config/secrets/db.php` holds the same values for the backup scripts. The server has no `infra/.env`.

PHP rereads `LocalSettings.php` within 60 s of a change, so you don't restart anything after a settings edit.

### Containers

- `wiki`: `local/rollerskating-wiki:1.43`, built `FROM mediawiki:1.43-fpm` (Debian, PHP 8.3, MediaWiki 1.43.11). The build adds ffmpeg, exif, composer and the non-bundled extensions, and bakes in the logo and favicon files from `assets/`.
- `wiki-web`: `nginx:stable` with the hardened config. The same build copies static files out of the `wiki` image, so code and assets stay in sync. Publishes `172.17.0.1:7734`.
- `wiki-jobrunner`: continuous `runJobs --wait` as `www-data`.
- `wiki-sitemap`: daily `generateSitemap` as uid 1001 (`wiki`).
- `wiki-mariadb`: compose service `mariadb`, image `mariadb:11` (now 11.8.9), bound to `127.0.0.1:4938`.

### Edge: Caddy, Cloudflare and DNS

The `caddy` container in `/home/assisr/dev/docker` terminates TLS. The owner builds the image on this host with the Cloudflare DNS plugin, and its config sits at `/home/assisr/dev/docker/caddy/Caddyfile`. It proxies `rollerskating.wiki` to `host.docker.internal:7734` (= `172.17.0.1`) and sends `Host: host.docker.internal:7734` via `header_up Host {upstream_hostport}`; `wiki-web` treats that host as its default server. The same stack serves Jellyfin, requests and torrents, publishes `80/443`, and maps `host.docker.internal:host-gateway` in `extra_hosts`. You won't find a `wiki-caddy` container. Nothing live uses the repo's `infra/docker-compose.yml` or `infra/caddy`; treat them as outdated examples.

Cloudflare sits in front of Caddy in strict mode. The wiki zone has its own Cloudflare token, separate from the one other domains use:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_API_TOKEN_WIKI`

If the Caddyfile references a token variable, pass that variable into the container in Compose too. A Caddy log line reading `API token '' appears invalid` means the variable expanded to an empty string inside the container.

Use a per-site DNS challenge, since the domains belong to different Cloudflare accounts. The live block adds `encode`, the `header_up` lines and a resolver to this pattern:

```caddy
rollerskating.wiki {
  reverse_proxy host.docker.internal:7734
  tls {
    dns cloudflare {env.CLOUDFLARE_API_TOKEN_WIKI}
  }
}
```

Caddy's file log path and its Docker volume path may not line up. Read the container log first:

```bash
docker logs caddy
```

The container `dns` runs ddclient and updates Cloudflare records for `assisr.com` and `rollerskating.wiki`. One config holds a Cloudflare block per zone, each with its own token; separate containers would give stricter separation. If the server keeps a stable public IP, the wiki zone may not need DDNS at all.

### Updating

- `/home/assisr/dev/docker/wiki/update.sh` backs up the DB, tags the current images `:previous`, runs `docker compose build --pull`, recreates the containers, runs `update.php --quick` and smoke-tests pages, load.php, the API, REST and Lua. On failure it re-tags `:previous` and recreates.
- `wiki-update.timer` runs it once a day at 04:30 America/Toronto, after Watchtower (04:00 America/Toronto) and before the 06:00 reboot.
- Watchtower excludes `wiki`, `wiki-web`, `wiki-jobrunner`, `wiki-sitemap` and `wiki-mariadb`. `update.sh` is their updater.
- To bump Cargo, PageForms or ApprovedRevs, edit the tag in the Dockerfile and run `update.sh`. For a new MediaWiki LTS, change `FROM`, the `REL1_xx` branches and the image tags, then follow Manual:Upgrading.

### Cutover status

The host `wiki-jobs.timer`, `wiki-sitemap.timer`, host nginx and host `php8.4-fpm` get disabled at cutover. Cutover waits for a `mediawiki:1.43-fpm` image with PHP 8.3.36, the release that fixes CVE-2026-109618/109619.

### Known open issues

- Email: `$wgEnableEmail` is on, `$wgPasswordSender` is empty, and the server has no SMTP or sendmail.
- MediaWiki sees Caddy's IP instead of the real client IP.

### Rules

- Check ports, paths and values against the live system (`docker compose config`, `docker inspect`, the Caddyfile) before you trust this document.
- Publish the origin on `172.17.0.1:7734` alone unless you update the Caddyfile in the same change.
- Run maintenance scripts with `docker exec wiki php maintenance/run.php <script>`. Add `-u www-data` for anything that writes files.
- Keep DB and admin services off the public internet.
- Add extensions one at a time.
- Keep the short URL layout (`/wiki/$1`).
- Stay on the MediaWiki LTS branch.
- The `wiki` user has no `sudo`. After you edit config files, tell the operator to fix ownership (see Permissions).

### First checks

```bash
docker ps
docker compose -f /home/assisr/dev/docker/docker-compose-wiki.yml ps
docker logs caddy --tail 100
systemctl list-timers 'wiki-*'
ls -la /home/wiki/dev/wiki/app/config
```

Also confirm the DB host port and the live `LocalSettings.php` contents.

## Site Configuration

These choices carry over from the host setup and still apply in Docker.

### Identity

- Site name: `Rollerskate Wiki`
- Initial admin account (from the DB): `Assisr`

The admin username doesn't match shell usernames or earlier guesses like `assisr.skates`.

### Short URLs

Pages live at `/wiki/Page_Title`, set by:

- `$wgArticlePath = '/wiki/$1';`
- `$wgUsePathInfo = true;`
- nginx rewrite for `/wiki/`

The setup follows MediaWiki's nginx short URL guidance, with the app served from the vhost root instead of `/w`.

### nginx rules

`/home/assisr/dev/docker/wiki/nginx.conf` carries the rules from `ops/nginx/wiki.conf.example`:

- `server_name` `rollerskating.wiki` and `www.rollerskating.wiki`
- `client_max_body_size` caps upload size
- `/mw-config/` denied
- no PHP execution under `/images/`
- `X-Content-Type-Options: nosniff`

`/home/assisr/dev/docker/wiki/php.ini` holds the upload limits and OPcache settings, carried over from the host's `90-mediawiki-uploads.ini` and `10-opcache.ini`.

### Uploads

- Uploads are on, limited to selected extensions (images and PDF at first).
- Anonymous users and new accounts can read but can't upload. `autoconfirmed` users can.
- The web stack can write the upload directory, and nginx blocks PHP there.

Keep `$wgGitInfoCacheDirectory = '';` in `LocalSettings.php` so GitInfo doesn't probe `/gitinfo`.

### Caching

You get OPcache, APCu and Cloudflare (TLS, shielding, static assets). The owner chose to skip Redis and Memcached on this single-host wiki; add them when you can show an operational need.

### Security posture

- Caddy is the public entry point.
- The DB port stays private (`127.0.0.1:4938`).
- Block `/mw-config/` and remove it after install if you can.
- Cloudflare runs in strict mode with a wiki-specific token.
- Keep admin surfaces small.

Anyone can edit, so plan for anti-abuse work and moderation. Treat uploads as attack surface, check sources, and keep the extension count low.

### Extensions

The Dockerfile `ADD` lines bake the non-bundled extensions into the image:

- REL1_43 branches: MobileFrontend, TemplateStyles, TimedMediaHandler, Translate, UniversalLanguageSelector
- release tags: Cargo 3.9.4, PageForms 6.0.11, ApprovedRevs 2.4.2
- GTag from GitHub master

Bundled extensions (VisualEditor, Scribunto, ConfirmEdit and others) come from the image. TimedMediaHandler and Translate get `composer install` in their own directories. Confirm the loaded set with `Special:Version` and the `wfLoadExtension` lines in `LocalSettings.php`. `Maps` came up as a candidate and isn't installed. Install new extensions one at a time and run `update` and a check after each.

### Skin

Stay on the Vector family. Customize with CSS, templates, the logo, the main page, infoboxes and navigation. For game-style wiki density, use Vector or Vector legacy before you consider a third-party skin.

### Permissions

The PHP processes in the `wiki` container run as `www-data` (uid 33, same as the host), so host ownership still decides what PHP can read.

- `wiki` owns the app files.
- `www-data` needs write access to the upload directory.
- `www-data` needs group read on `LocalSettings.php` and the secrets, plus traverse rights on each parent directory under `/home/wiki/...`.

Required state:

- `/home/wiki/dev/wiki/app/config/LocalSettings.php`: `wiki:www-data`, mode `640`. Git tracks it; it holds no secrets.
- `/home/wiki/dev/wiki/app/config/` directory: `wiki:www-data`, or at least group-traversable by `www-data`
- `/home/wiki/dev/wiki/app/config/secrets/` directory: `wiki:www-data` with group traverse. Git ignores its contents.
- `/home/wiki/dev/wiki/app/config/secrets/SecretsSettings.php`: `wiki:www-data`, mode `640`
- `/home/wiki/dev/wiki/app/config/secrets/db.php`: `wiki:www-data`, mode `640`

During setup PHP-FPM returned `Failed to open stream: Permission denied` for `SecretsSettings.php`. The file had `wiki:www-data` and `640`, but the `secrets/` directory belonged to `wiki:wiki`, and `www-data` couldn't enter it. Check directory ownership along with file ownership, and confirm PHP can still read a file before you tighten its mode.

The `wiki` user has no `sudo`, so an agent running as `wiki` can't restart services, run `chown` or edit `/etc/`. A file you edit as `wiki` comes back as `wiki:wiki`, and PHP loses read access to `LocalSettings.php` or `db.php`, which takes the site down. After you edit config files, tell the operator to run:

```bash
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/LocalSettings.php
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/secrets/
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/secrets/SecretsSettings.php
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/secrets/db.php
```

Say so in your reply; the operator won't guess.

## MariaDB

MariaDB runs in Docker and stores the wiki database. The owner picked it over MySQL because MediaWiki recommends `MariaDB / MySQL` and Wikimedia runs MariaDB.

The first install broke when `--dbserver` contained `host:port` and the installer also tried to grant privileges with `--installdbuser` and `--installdbpass`. It issued a grant to `'mediawiki'@'127.0.0.1:4938'`, and MariaDB rejected it because host entries can't carry a port. On a non-default port, create the DB and user by hand, then run the installer without `--installdbuser` and `--installdbpass`. Keep this in mind for rebuilds and automation.

## Backups

Host timers, both running as root:

- `wiki-backup-db`: 03:15 UTC
- `wiki-backup-files`: 03:45 UTC

No timer runs XML backups. Keep a copy of the backups off the host.

The backup set covers:

- logical DB dumps
- a file archive of config, images, infra and ops
- XML export
- deployment inventory
- live host config archive
- migration bundle

Scripts in `ops/bin`:

- `backup-db.sh` and `restore-db.sh` fall back to `secrets/db.php` when `infra/.env` is missing.
- `backup-files.sh` also archives `docker-compose-wiki.yml` and the docker wiki dir.
- `backup-xml.sh` and `export-inventory.sh` use `docker exec wiki`.
- `pre-migration-check.sh` stops `wiki-jobrunner` and `wiki-sitemap`.
- `post-restore-check.sh` checks the containers.
- `verify-backups.sh` checks that the dump ends with "Dump completed" and the XML ends with `</mediawiki>`.
- `create-migration-bundle.sh` and `restore-host-config.sh` cover migration and host config.
- `upgrade-core.sh` and `deploy-core.sh` belong to the old release-dir model (historical).

A full recovery needs more than a copy of the wiki folder:

- SQL dump
- `LocalSettings.php`
- DB secrets
- uploads
- infra config, including `docker-compose-wiki.yml` and `/home/assisr/dev/docker/wiki/`
- ops scripts
- extension inventory
- host config

Read `docs/Migrating.md` before you wipe or rebuild the server.

## Historical: Host Deployment (pre-Docker)

Keep this for rollback. The Docker section above replaces all of it.

The original design kept MediaWiki on the host and put infrastructure in Docker:

```text
Cloudflare -> Caddy (Docker) -> host nginx -> host php-fpm -> MediaWiki
```

Drift between the repo examples and the host setup:

- Domain: `rollerskating.wiki` replaced the placeholder `wiki.example.com`.
- Origin port: `8081` became `7734` (nginx listen, Caddy upstream, test commands).
- MariaDB host port: `127.0.0.1:3307` became `127.0.0.1:4938` (installer commands, `db.php`, backup and restore).
- PHP: early examples used `8.3`, the host ran `8.4`. Derive the version on the machine:

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
echo "${PHP_VERSION}"
```

You plug that value into `/etc/php/${PHP_VERSION}/...`, `php${PHP_VERSION}-fpm` and the PHP-FPM pool paths. The service name:

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
echo "php${PHP_VERSION}-fpm"
```

Filesystem layout:

```text
/home/wiki/dev/wiki/
  app/
    releases/
    current -> release symlink
    shared/images/
    config/
      LocalSettings.php
      secrets/db.php
  infra/
  ops/
  backups/
  docs/
```

Release model: you unpacked core into `app/releases/mediawiki-x.y.z/`, pointed the `app/current` symlink at it, and symlinked `LocalSettings.php` (canonical at `/home/wiki/dev/wiki/app/config/LocalSettings.php`) into `/home/wiki/dev/wiki/app/current/LocalSettings.php`. The host started on MediaWiki `1.43.6` and reached `1.43.11` on 2026-10-21. Logo, favicon and license icon files sat in the release's `resources/assets/`; the copies in `app/shared/assets/` are older and nothing serves them. Upgrades went:

1. back up
2. unpack the new release into a new release dir
3. re-link `LocalSettings.php` and `images`
4. reinstall or update non-bundled extensions
5. run `maintenance/run.php update`
6. test, then switch `current`

Origin binding: host curl to `127.0.0.1:7734` worked, but the Caddy container couldn't reach `host.docker.internal:7734`. A host nginx behind a containerized Caddy has to listen on the Docker bridge IP (or `0.0.0.0:<port>` as a stopgap), and a `127.0.0.1`-only bind breaks the proxy.

PHP-FPM: the repo prefers a version-agnostic socket, `/run/php/php-fpm-wiki.sock`, while the live pool and nginx use `/run/php/php8.4-fpm-wiki.sock` (verified 2026-10-21) and the `ops/` examples match live. Change both together. The pool's `open_basedir` must include `/dev/null`, because Scribunto's LuaStandalone opens it as the Lua binary's stderr, and `{{#invoke:}}` fails without it. Keep the upload temp dir and MediaWiki paths inside `open_basedir` too. Upload limits went in `/etc/php/<current-version>/fpm/conf.d/90-mediawiki-uploads.ini`, alongside the OPcache settings.

After config changes that touched extensions or PHP, the operator restarted PHP-FPM:

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
sudo systemctl restart "php${PHP_VERSION}-fpm"
```

First checks on the host stack:

```bash
php -v
sudo nginx -T
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
sudo systemctl status nginx "php${PHP_VERSION}-fpm"
docker ps
docker logs caddy --tail 100
readlink -f /home/wiki/dev/wiki/app/current
ls -la /home/wiki/dev/wiki/app/config
```

## Related Documents

- [README.md](README.md)
- [OPERATIONS.md](docs/OPERATIONS.md)
- [Migrating.md](docs/Migrating.md)
