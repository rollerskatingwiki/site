# Rollerskating Wiki: Agent Context

Last updated: 2026-03-21

This document is for LLM coding agents and operators. It explains the current architecture, the intended deployment model, the known drift between the deployment pack and the live server, and the operational rules that should be preserved.

Read this before editing config, changing ports, adding extensions, or touching backups.

## Purpose

This repository is a deployment pack and operator knowledge base for a public MediaWiki instance at:

- `https://rollerskating.wiki`

The wiki is intended to be:

- public
- community-driven
- production-oriented
- stable and maintainable
- source-oriented and archival

The stack was intentionally designed to keep the MediaWiki application itself off Docker while still allowing Docker-managed infrastructure around it.

## High-Level Architecture

The intended architecture is:

- MediaWiki application on the host
- host `nginx`
- host `php-fpm`
- Docker `caddy` as the public reverse proxy
- Docker `mariadb`
- Cloudflare in front of Caddy

However, the live environment has drifted from the initial examples in this repo.

## What Is Canonical vs What Is Example

There are two layers of truth:

1. The **deployment pack** under this repo
2. The **actual live server state**, which may differ

Important: several example files in this repo still reflect the original baseline values and may not exactly match the live server anymore.

Before making changes, agents should inspect the live server values and not blindly trust the examples.

## Known Live-Server Drift

These values are known from the live setup conversation and should be treated as higher priority than older examples if they conflict.

### Domain

Live domain:

- `rollerskating.wiki`

Not the old placeholders:

- `wiki.example.com`

### PHP Version

Do not hardcode the PHP version in docs, scripts, or generated config.

Agents should derive the installed PHP major.minor version from the machine:

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
echo "${PHP_VERSION}"
```

Use that value for:

- `/etc/php/${PHP_VERSION}/...`
- `php${PHP_VERSION}-fpm`
- PHP-FPM pool paths

Earlier setup examples in this repo used `8.3`, and the live setup discussion later used `8.4`. Treat both as historical, not canonical.

### MediaWiki Upstream Port

The original example files used:

- `8081`

The live setup moved to:

- `7734`

This matters for:

- nginx listen directives
- Caddy upstream target
- testing commands

### MariaDB Host Port

The original example files used:

- `127.0.0.1:3307`

The live setup used:

- `127.0.0.1:4938`

This matters for:

- installer commands
- `db.php`
- backup and restore assumptions

### Caddy / Edge Stack Location

The repo contains an example Docker Compose file under:

- `infra/docker-compose.yml`

But the live server appears to use an existing broader Docker stack under:

- `~/dev/docker`

That live stack includes at least:

- `caddy`
- `dns` (`ddclient`)

Agents must not assume the repo-local Compose file is the live source of truth for Caddy or ddclient.

## Current Deployment Model

### Wiki Filesystem Layout

The intended live root is:

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

The deployment pack in this repo mirrors that structure for reproducibility.

### Release Management

MediaWiki is release-directory based:

- core is unpacked into `app/releases/mediawiki-x.y.z/`
- `app/current` is a symlink to the active release
- uploads live in `app/shared/images`
- `LocalSettings.php` lives outside the release tree and is symlinked into the release

This must be preserved. Do not convert the app into an in-place mutable tree.

### Web Request Flow

Public traffic path:

```text
Cloudflare -> Caddy (Docker) -> host nginx -> host php-fpm -> MediaWiki
```

### Important Upstream Rule

If Caddy runs in Docker and proxies to the host, the host nginx listener cannot remain bound to `127.0.0.1` only.

This caused a real failure during setup:

- host curl to `127.0.0.1:7734` worked
- Caddy container could not reach `host.docker.internal:7734`

So for container-to-host proxying, nginx must listen on:

- `0.0.0.0:<port>` temporarily
- or preferably the Docker bridge IP on the host

Do not reintroduce `127.0.0.1`-only binding if Caddy must reach the origin from a container.

## nginx

### Role

Host nginx serves MediaWiki and forwards PHP requests to the dedicated PHP-FPM pool.

### Important Live Characteristics

- `server_name` should be `rollerskating.wiki` and optionally `www.rollerskating.wiki`
- the wiki origin currently uses a host-side port such as `7734`
- upload size limits are enforced in nginx using `client_max_body_size`
- `/mw-config/` is denied
- `/images/` must not allow PHP execution
- `X-Content-Type-Options: nosniff` should be present

### Short URL Pattern

The chosen short URL shape is:

- `/wiki/Page_Title`

This is implemented with:

- `$wgArticlePath = '/wiki/$1';`
- `$wgUsePathInfo = true;`
- nginx rewrite for `/wiki/`

This setup is adapted from the MediaWiki nginx short URL guidance, but the app itself is still served from the vhost root, not from `/w`.

## PHP-FPM

### Role

Host PHP-FPM runs MediaWiki under a dedicated pool.

### Current Direction

Use the currently installed PHP major.minor version on the machine rather than a hardcoded value.

For the PHP-FPM service name:

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
echo "php${PHP_VERSION}-fpm"
```

For the dedicated socket path, this deployment pack now prefers a version-agnostic custom socket:

- `/run/php/php-fpm-wiki.sock`

### Upload Settings

Upload limits belong in PHP-FPM config, not Apache and not `LocalSettings.php`.

Typical override file:

- `/etc/php/<current-version>/fpm/conf.d/90-mediawiki-uploads.ini`

OPcache settings also belong in PHP-FPM config.

### open_basedir

The PHP-FPM pool config includes `open_basedir`. If upload behavior changes, ensure the upload temp dir and MediaWiki paths are still permitted.

## Caddy

### Role

Caddy is the public reverse proxy and TLS terminator, running in Docker.

### Current Live Pattern

The user already has an existing Docker/Caddy setup for other applications such as Jellyfin, requests, torrents, etc.

Observed characteristics:

- Docker Compose under `~/dev/docker`
- container name `caddy`
- `extra_hosts` includes `host.docker.internal:host-gateway`
- Caddy publishes `80/443`

### Cloudflare Tokens

The wiki uses a separate Cloudflare token from the main account/token used by other domains.

Expected env vars:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_API_TOKEN_WIKI`

Important operational rule:

- if a token env var is referenced in the Caddyfile, it must also be explicitly passed into the Docker container via Compose
- if Caddy logs show `API token '' appears invalid`, that means the env var expanded to an empty string inside the container

### Per-Site DNS Challenge

Do not use one global Cloudflare DNS credential if different domains belong to different Cloudflare accounts.

Preferred pattern:

```caddy
rollerskating.wiki {
  reverse_proxy host.docker.internal:7734
  tls {
    dns cloudflare {env.CLOUDFLARE_API_TOKEN_WIKI}
  }
}
```

### Logging

Be aware that the user’s Caddy file log path and Docker volume path may not match perfectly in the live stack. When diagnosing, prefer:

```bash
docker logs caddy
```

over assuming file logs are persisted exactly where intended.

## ddclient

### Role

The live Docker stack also includes `ddclient` under the container name:

- `dns`

It updates Cloudflare DNS records.

### Multi-Account Pattern

The configuration can contain multiple Cloudflare blocks for different zones and different tokens. That is supported, but separate containers/configs would be cleaner if strict separation is desired.

Known live zones discussed:

- `assisr.com`
- `rollerskating.wiki`

### Important Note

If the server has a stable dedicated public IP, ddclient may not be necessary for the wiki zone at all. Do not assume DDNS is required unless the IP actually changes.

## MariaDB

### Role

MariaDB runs in Docker and stores the MediaWiki database.

### Choice

MariaDB was chosen over MySQL because:

- MediaWiki recommends `MariaDB / MySQL`
- Wikimedia uses MariaDB
- it is the safer default for MediaWiki operations

### Important Install Caveat

The initial installer flow hit a real issue when `--dbserver` included `host:port` and the installer also tried to grant DB privileges using `--installdbuser` and `--installdbpass`.

Observed failure mode:

- installer tried to grant to `'mediawiki'@'127.0.0.1:4938'`
- MariaDB rejected that because host entries are not `host:port`

Operational rule:

- on non-default host ports, prefer pre-creating the DB and DB user manually
- then run the MediaWiki installer without `--installdbuser` and `--installdbpass`

This is important context for future rebuilds or automation work.

## MediaWiki Application

### Current Version

The installation was based on:

- MediaWiki `1.43.6`

### Site Identity

Known site name chosen during setup:

- `Rollerskate Wiki`

Known initial admin account discovered from the DB:

- `Assisr`

Do not assume the admin username matches shell usernames or prior guesses like `assisr.skates`.

### LocalSettings.php

Canonical live config path:

- `/home/wiki/dev/wiki/app/config/LocalSettings.php`

Symlink expected at:

- `/home/wiki/dev/wiki/app/current/LocalSettings.php`

### Current Settings Direction

The following choices were made during setup:

- uploads enabled
- short URLs via `/wiki/$1`
- caching baseline is OPcache + APCu
- public-read model
- uploads restricted to trusted users, not anonymous users

### File Upload Policy

Uploads are enabled, but the intended safe baseline is:

- only selected file extensions, initially images and PDF
- upload directory writable by the web stack
- no PHP execution allowed in uploads
- `nosniff` response header enabled

### Upload Permissions

The intended `LocalSettings.php` policy is:

- public can read
- public cannot upload
- new users cannot upload immediately
- `autoconfirmed` can upload

### Permissions Model

This area caused real problems during setup.

Key points:

- app code should be owned by `wiki`
- upload directory should be writable by `www-data`
- `LocalSettings.php` and secrets files must be readable by the web stack
- parent directories under `/home/wiki/...` must be traversable by nginx/PHP
- **both files and their parent directories** must be group-accessible by `www-data`

### Config File Permissions

`LocalSettings.php` is committed to version control (it contains no secrets). It must still be readable by PHP-FPM.

Required state:

- `/home/wiki/dev/wiki/app/config/LocalSettings.php` — `wiki:www-data`, mode `640`
- `/home/wiki/dev/wiki/app/config/` directory — `wiki:www-data` (or at least group-traversable by `www-data`)

### Secrets File Permissions

Secrets live in `app/config/secrets/` and are gitignored. The directory and every file PHP-FPM needs to read must be group-owned by `www-data`.

Required state:

- `/home/wiki/dev/wiki/app/config/secrets/` directory — `wiki:www-data` (group must have traverse permission)
- `/home/wiki/dev/wiki/app/config/secrets/SecretsSettings.php` — `wiki:www-data`, mode `640`
- `/home/wiki/dev/wiki/app/config/secrets/db.php` — `wiki:www-data`, mode `640`

Important known failure:

- PHP-FPM returned `Failed to open stream: Permission denied` for `SecretsSettings.php`
- the file itself had correct ownership (`wiki:www-data`, `640`)
- the cause was the **parent directory** `secrets/` being owned by `wiki:wiki` — `www-data` could not traverse into it

Practical rules:

- if a file is `640 wiki:www-data`, its parent directory must also be group-accessible by `www-data`
- one workable model is `wiki:www-data` on both the directory and files
- always check directory ownership, not just file ownership

Agents must be very careful not to tighten permissions so far that the app becomes unreadable.

### The `wiki` User Is Restricted

The `wiki` user does not have `sudo` access. This has direct operational consequences:

- agents running as `wiki` **cannot** restart services (`nginx`, `php-fpm`, etc.)
- agents running as `wiki` **cannot** change file ownership (`chown`)
- agents running as `wiki` **cannot** edit system config under `/etc/`

When an agent edits a file that was previously owned by `wiki:www-data`, the resulting file will be owned by `wiki:wiki` because the agent cannot preserve or restore the `www-data` group. This **will break the live site** for any file that PHP-FPM needs to read (e.g. `LocalSettings.php`, `db.php`).

After any edit to config files, agents **must** tell the operator to run:

```bash
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/LocalSettings.php
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/secrets/
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/secrets/SecretsSettings.php
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config/secrets/db.php
```

Similarly, after config changes that affect loaded extensions or PHP, agents must tell the operator to restart PHP-FPM:

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
sudo systemctl restart "php${PHP_VERSION}-fpm"
```

Do not silently assume these steps will happen. Always surface them explicitly.

## Caching

Chosen baseline:

- OPcache
- APCu
- Cloudflare for TLS, shielding, static assets
- no Redis
- no Memcached

This is a deliberate simplicity choice for a single-host public wiki.

Do not casually add Redis or Memcached unless there is an operational need.

## Security Posture

The intended security posture is:

- only Caddy is public
- no public DB port
- no public host nginx admin/origin port unless necessary for container reachability
- `/mw-config/` blocked and ideally removed after install
- no PHP execution under `/images`
- strict Cloudflare mode
- separate Cloudflare token for the wiki
- minimal exposed admin surfaces

### Community-Wiki Risks

Because this is a public community wiki, agents should assume:

- anti-abuse and moderation matter
- uploads are a risk surface
- source quality matters
- extension count should stay low

## Extensions

### Current State

Treat extension state as unknown until confirmed via:

- `Special:Version`
- live `LocalSettings.php`
- release `extensions/` directory

Do not assume all discussed extensions are already installed.

### Planned / Recommended Extensions

These were discussed as useful candidates:

- `Cargo`
- `Page Forms`
- `TimedMediaHandler`
- `Approved Revs`
- `Maps`
- `Translate`

But they should be installed deliberately, one at a time, with `update` and verification after each.

### Rule For Production

Do not bulk-install all planned extensions on a live public wiki in one pass.

Install sequence should be phased and verified.

## Skins / UI Strategy

The current strategic recommendation is:

- stay on the default Vector family initially
- customize with CSS, templates, logo, main page, infoboxes, and navigation
- avoid a custom third-party skin early

For game-style wiki density, Vector or Vector legacy is the preferred direction, not a skin swap.

## Backups

Backups are critical and already have scripted support in this repo.

### Backup Types

The intended backup set includes:

- logical DB dumps
- file archive for config, images, infra, ops
- XML export
- deployment inventory
- live host config archive
- migration bundle

### Important Scripts

Core scripts:

- `ops/bin/backup-db.sh`
- `ops/bin/backup-files.sh`
- `ops/bin/backup-xml.sh`
- `ops/bin/export-inventory.sh`
- `ops/bin/verify-backups.sh`
- `ops/bin/create-migration-bundle.sh`
- `ops/bin/pre-migration-check.sh`
- `ops/bin/restore-db.sh`
- `ops/bin/restore-host-config.sh`
- `ops/bin/post-restore-check.sh`

### Recovery Principle

The recovery set is not just “copy the wiki folder”.

It must include:

- SQL dump
- `LocalSettings.php`
- DB secrets
- uploads
- infra config
- ops scripts
- extension inventory
- host config

## Maintenance

### Routine Expectations

Agents should assume the operator wants:

- stable LTS MediaWiki branch
- release-directory upgrades
- Cloudflare in front
- low extension count
- conservative caching
- off-host backups

### Upgrade Pattern

Upgrades should follow this sequence:

1. back up first
2. unpack new MediaWiki release into a new release dir
3. re-link `LocalSettings.php` and `images`
4. reinstall/update non-bundled extensions for the new release
5. run `maintenance/run.php update`
6. test before switching `current`

### Migration / Rebuild Pattern

The repo already contains a dedicated migration runbook:

- `docs/Migrating.md`

Use it before wiping or rebuilding the server.

## Agent Rules

If you are an LLM coding agent working on this setup:

- inspect the live server before trusting example files
- do not assume the repo examples match the live PHP version or ports
- do not bind the nginx origin to `127.0.0.1` if Caddy in Docker must reach it
- do not tighten `LocalSettings.php` permissions until you confirm nginx/PHP-FPM can still read it
- do not expose DB/admin services publicly
- do not add many extensions at once
- do not change short URL layout casually
- do not move the app into a mutable single release tree
- do not assume Caddy and ddclient live under this repo; the live edge stack may be elsewhere
- the `wiki` user has no `sudo` — after editing config files, tell the operator to fix ownership and restart services

## Recommended First Checks For Future Agents

Before changing anything, run or inspect:

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

Also confirm:

- actual Caddy Compose path
- actual ddclient config path
- actual DB host port
- actual nginx listen port
- actual `LocalSettings.php` contents

## Related Documents

- [README.md](/Users/assisrmatheus/Developer/wiki/README.md)
- [OPERATIONS.md](/Users/assisrmatheus/Developer/wiki/docs/OPERATIONS.md)
- [Migrating.md](/Users/assisrmatheus/Developer/wiki/docs/Migrating.md)
