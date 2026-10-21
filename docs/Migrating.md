# Migrating the Wiki to a Fresh Server

Last reviewed: 2026-10-21

Use this runbook before you format the server that hosts rollerskating.wiki. You freeze writes, back up, verify the backups, copy them off the machine and record an inventory. You format after all of that, then rebuild the wiki from the off-server copy.

References:

- <https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki>
- <https://www.mediawiki.org/wiki/Manual:Upgrading>
- <https://www.mediawiki.org/wiki/Manual:$wgReadOnly>
- [OPERATIONS.md](OPERATIONS.md) for day-to-day commands

Scripts in this repo:

- Backups: [backup-db.sh](../ops/bin/backup-db.sh), [backup-files.sh](../ops/bin/backup-files.sh), [backup-xml.sh](../ops/bin/backup-xml.sh), [backup-live-host-config.sh](../ops/bin/backup-live-host-config.sh)
- Checks and records: [verify-backups.sh](../ops/bin/verify-backups.sh), [export-inventory.sh](../ops/bin/export-inventory.sh), [create-migration-bundle.sh](../ops/bin/create-migration-bundle.sh)
- Wrappers: [pre-migration-check.sh](../ops/bin/pre-migration-check.sh), [post-restore-check.sh](../ops/bin/post-restore-check.sh)
- Restore: [restore-db.sh](../ops/bin/restore-db.sh), [restore-host-config.sh](../ops/bin/restore-host-config.sh)

The build and update files live outside the repo, in `/home/assisr/dev/docker/wiki`.

## The deployment

The wiki runs in Docker as part of the shared stack in `/home/assisr/dev/docker`. The stack's `.env` sets `COMPOSE_FILE` to ten compose files, `docker-compose-wiki.yml` among them, so run each `docker compose` command from `/home/assisr/dev/docker`.

| Container | Compose service | Role |
|---|---|---|
| `wiki` | `wiki` | PHP-FPM, built `FROM mediawiki:1.43-fpm`. Mounts `app/config` read-only at `/config` and `app/shared/images` read-write. |
| `wiki-web` | `wiki-web` | nginx. Publishes `172.17.0.1:7734`. |
| `wiki-jobrunner` | `wiki-jobrunner` | Runs `runJobs --wait` in a loop as `www-data`. |
| `wiki-sitemap` | `wiki-sitemap` | Runs `generateSitemap` once a day as `1001:33` into `app/shared/sitemap`. |
| `wiki-mariadb` | `mariadb` | MariaDB 11. Data in `/home/assisr/dev/docker/wiki-mariadb/data`, config in `wiki-mariadb/conf.d`, port `127.0.0.1:4938`. |
| `caddy` | `caddy` | TLS for rollerskating.wiki, proxying to `host.docker.internal:7734`. Defined in `docker-compose-network.yml`, configured in `caddy/Caddyfile`, and needs `CLOUDFLARE_API_TOKEN_WIKI` from the stack `.env`. |

Three systemd timers run on the host: `wiki-backup-db`, `wiki-backup-files` and `wiki-update`. The last one runs `/home/assisr/dev/docker/wiki/update.sh` as `assisr` at 04:30.

## Recovery set

You need each of these to rebuild the wiki.

| Item | Path | Archived by |
|---|---|---|
| Database dump | `backups/db/mediawiki-*.sql.gz` | `backup-db.sh` |
| Settings and secrets | `app/config`: `LocalSettings.php`, plus `secrets/SecretsSettings.php` (DB creds, Turnstile keys, `$wgSecretKey`) and `secrets/db.php` (a second copy of the DB creds) | `backup-files.sh` |
| Uploads | `app/shared/images` | `backup-files.sh` |
| Sitemap | `app/shared/sitemap` | nothing; `wiki-sitemap` rebuilds it on start |
| Wiki repo | `/home/wiki/dev/wiki` (docs, ops, infra) | GitHub, plus `backup-files.sh` for `ops` and `infra` and the migration bundle for `docs` |
| Wiki compose and build files | `/home/assisr/dev/docker/docker-compose-wiki.yml`, `/home/assisr/dev/docker/wiki` | `backup-files.sh`, `backup-live-host-config.sh` |
| Caddyfile | `/home/assisr/dev/docker/caddy/Caddyfile` | `backup-live-host-config.sh` |
| Stack `.env` | `/home/assisr/dev/docker/.env` (`MARIADB_PASSWORD`, `MARIADB_ROOT_PASSWORD`, Cloudflare tokens) | nothing; Part 1 step 4 archives it |
| MariaDB config | `/home/assisr/dev/docker/wiki-mariadb/conf.d` | nothing; Part 1 step 4 archives it |
| Host timer units | `/etc/systemd/system/wiki-{backup-db,backup-files,update}.{service,timer}` | `backup-live-host-config.sh` |

You don't need to save the MediaWiki code or the extensions. `update.sh` rebuilds both images from the Dockerfile, and its `ADD` lines pin each extension to a branch or tag. `export-inventory.sh` copies those lines into `backups/inventory/extensions-git.txt`.

The repo's `.gitignore` excludes `app/config/secrets/`, so a clone of `git@github.com:rollerskatingwiki/site.git` comes without secrets. Commit or archive local changes before you format; `git -C /home/wiki/dev/wiki status --short` lists them.

## Part 1: Before you format

### Fast path

```bash
sudo /home/wiki/dev/wiki/ops/bin/pre-migration-check.sh
```

The script stops `wiki-jobrunner` and `wiki-sitemap`, then runs the DB, files and XML backups. It exports the inventory, archives the stack files, Caddyfile and timer units, verifies the backups and writes a migration bundle. It also stops `wiki-update.timer`. You still do three steps by hand: the read-only freeze (step 2), the stack `.env` archive (step 4) and the off-server copy (step 7).

The bundle step prints `warning: missing /home/wiki/dev/wiki/infra/.env`. The live server has no such file, so ignore the warning.

### 1. Record the current state

```bash
uname -a
docker --version
docker compose version
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
docker exec wiki php -r 'echo PHP_VERSION, PHP_EOL;'
echo 'echo MW_VERSION, PHP_EOL;' | docker exec -i wiki php maintenance/run.php eval
docker exec wiki php maintenance/run.php showSiteStats
find /home/wiki/dev/wiki/app/shared/images -type f | wc -l
```

Save the `showSiteStats` output and the image count. You compare both against the rebuilt server.

### 2. Freeze writes

Append the read-only line to the real settings file:

```bash
echo "\$wgReadOnly = 'Server migration in progress';" | sudo -u wiki tee -a /home/wiki/dev/wiki/app/config/LocalSettings.php
tail -n 2 /home/wiki/dev/wiki/app/config/LocalSettings.php
```

PHP picks up the change within 60 seconds (`opcache.revalidate_freq=60` in the image). You don't reload or restart anything. Confirm it after a minute:

```bash
curl -s -H 'Host: rollerskating.wiki' 'http://172.17.0.1:7734/api.php?action=query&meta=siteinfo&format=json' | grep -o '"readonlyreason":"[^"]*"'
```

An empty result means PHP still serves the old settings.

### 3. Stop background writers

```bash
docker stop wiki-jobrunner wiki-sitemap
sudo systemctl stop wiki-update.timer
```

`update.sh` runs `docker compose up -d` on all four wiki services, so the 04:30 timer would restart the job runner in the middle of your migration.

### 4. Back up

```bash
sudo /home/wiki/dev/wiki/ops/bin/backup-db.sh
sudo /home/wiki/dev/wiki/ops/bin/backup-files.sh
sudo /home/wiki/dev/wiki/ops/bin/backup-xml.sh
sudo /home/wiki/dev/wiki/ops/bin/backup-live-host-config.sh
```

These write:

- `backups/db/mediawiki-<timestamp>.sql.gz`, the restore source
- `backups/files/mediawiki-files-<timestamp>.tar.gz` with `app/config`, `app/shared/images`, `infra`, `ops`, `docker-compose-wiki.yml` and the `wiki/` build dir
- `backups/xml/wiki-full-<timestamp>.xml` with each page and revision, your fallback if the SQL dump won't load
- `backups/files/live-host-config-<timestamp>.tar.gz` with the wiki stack files, the Caddyfile and the six timer units

No script archives the stack `.env`, the MariaDB config or Caddy's Dockerfile. Archive them with the compose files (`COMPOSE_FILE` names all ten, and `docker compose` reads each one):

```bash
sudo tar -czf /home/wiki/dev/wiki/backups/files/docker-stack-$(date +%F-%H%M%S).tar.gz \
  /home/assisr/dev/docker/.env \
  /home/assisr/dev/docker/docker-compose*.yml \
  /home/assisr/dev/docker/caddy/Caddyfile \
  /home/assisr/dev/docker/caddy/Dockerfile \
  /home/assisr/dev/docker/wiki \
  /home/assisr/dev/docker/wiki-mariadb/conf.d
```

This archive holds the Cloudflare tokens and the MariaDB root password. Store it with the same care as `secrets/`. The other services in the stack (Jellyfin, Sonarr, Radarr and the rest) fall outside this runbook; back up their data dirs on your own schedule.

### 5. Verify the backups

```bash
sudo /home/wiki/dev/wiki/ops/bin/verify-backups.sh
```

The script runs `gzip -t` on the newest dump and checks for the `Dump completed` trailer. It lists the newest files archive with `tar -tzf` and checks the XML for its closing `</mediawiki>` tag. It skips the archives you made in step 4, so check those by hand:

```bash
cd /home/wiki/dev/wiki/backups/files
tar -tzf "$(ls -t docker-stack-*.tar.gz | head -n 1)"
tar -tzf "$(ls -t live-host-config-*.tar.gz | head -n 1)"
tar -tzf "$(ls -t mediawiki-files-*.tar.gz | head -n 1)" | grep 'app/shared/images/' | grep -vc '/$'
```

The last count must match the image count from step 1.

### 6. Export the inventory

```bash
sudo /home/wiki/dev/wiki/ops/bin/export-inventory.sh
ls -l /home/wiki/dev/wiki/backups/inventory
```

You get `system.txt` (MediaWiki, PHP and image versions, `docker ps`, PHP modules), `extensions.txt`, `skins.txt` and `extensions-git.txt` (the Dockerfile's `ADD` lines).

### 7. Bundle and copy off the server

```bash
sudo /home/wiki/dev/wiki/ops/bin/create-migration-bundle.sh
```

The bundle in `backups/migration/` packs `backups/`, `docs/`, `ops/`, `README.md`, `LocalSettings.php`, `secrets/db.php` and `secrets/SecretsSettings.php`.

Copy the whole `backups/` tree to two devices that live apart from this server, for example a second machine and an external SSD:

```bash
rsync -a /home/wiki/dev/wiki/backups/ <user>@<backup-host>:wiki-migration/backups/
rsync -a --checksum --dry-run --itemize-changes /home/wiki/dev/wiki/backups/ <user>@<backup-host>:wiki-migration/backups/
```

The second command prints nothing when the copy matches. Repeat both for the second device.

### 8. Optional: cold copy of the MariaDB data dir

The SQL dump stays your restore path. A raw copy of the data dir gives you a second, forensic one, and it restores into the same MariaDB 11 release.

```bash
cd /home/assisr/dev/docker
docker compose stop mariadb
sudo tar -czf /home/wiki/dev/wiki/backups/files/mariadb-datadir-$(date +%F-%H%M%S).tar.gz /home/assisr/dev/docker/wiki-mariadb/data
docker compose start mariadb
```

Copy this archive off the server with the rest.

### 9. Final pre-format checklist

Format the server after you can tick each line:

- [ ] `$wgReadOnly` sits in `app/config/LocalSettings.php`, and the siteinfo call returns `readonlyreason`
- [ ] `wiki-jobrunner`, `wiki-sitemap` and `wiki-update.timer` are stopped
- [ ] you took the dump, files and XML backups after the freeze, and `verify-backups.sh` passed on them
- [ ] the image count in the `mediawiki-files` archive matches the live count
- [ ] the `docker-stack` archive lists `.env`, `caddy/Caddyfile` and `wiki-mariadb/conf.d`
- [ ] `backups/inventory/` holds `system.txt`, `extensions.txt`, `skins.txt` and `extensions-git.txt`
- [ ] you saved the `showSiteStats` output somewhere off the server
- [ ] two off-server copies exist, and `rsync --checksum --dry-run` shows no differences for either
- [ ] you opened one copy from a second machine and listed a tarball in it

## Part 2: Rebuild on the fresh server

### 1. Install the OS and Docker

Install Ubuntu 26.04 LTS. Ubuntu 25.10 has reached end of life. Install Docker Engine and the Compose plugin from Docker's apt repository (<https://docs.docker.com/engine/install/ubuntu/>).

Install `php-cli` on the host as well. `backup-db.sh` and `restore-db.sh` read the DB password from `secrets/db.php` with the host's `php -r`.

```bash
sudo apt update
sudo apt install -y php-cli rsync curl
```

### 2. Create users and groups

The `wiki-sitemap` container runs as `1001:33`, so the `wiki` user needs uid 1001 and `www-data` needs gid 33. Ubuntu ships `www-data` as gid 33; check before you add the user:

```bash
getent group www-data
sudo adduser --uid 1001 --disabled-password --gecos "" wiki
sudo chmod 751 /home/wiki
sudo usermod -aG docker,www-data,wiki assisr
```

`wiki-update.service` runs `update.sh` as `assisr`. That user needs `docker` to build, `www-data` to read `secrets/db.php` and `wiki` to write into `backups/db`. Log out and back in to pick up the groups.

### 3. Restore the files

Clone the repo, pull the backup set back in, then unpack the archives over the tree:

```bash
sudo install -d -o assisr /home/wiki/dev
git clone git@github.com:rollerskatingwiki/site.git /home/wiki/dev/wiki
rsync -a <user>@<backup-host>:wiki-migration/backups/ /home/wiki/dev/wiki/backups/
cd /home/wiki/dev/wiki/backups/files
sudo tar -xzpf "$(ls -t mediawiki-files-*.tar.gz | head -n 1)" -C /
sudo tar -xzpf "$(ls -t docker-stack-*.tar.gz | head -n 1)" -C /
```

The first archive restores `app/config`, `app/shared/images`, `infra`, `ops` and the wiki build files. The second restores the stack `.env`, the compose files, Caddy's Caddyfile and Dockerfile, and the MariaDB config. The `live-host-config` archive duplicates the stack files and adds the `/etc/systemd/system` units, which step 8 reinstalls from the restored dirs.

Restore the other stack services' data into `/home/assisr/dev/docker` from their own backups.

### 4. Set ownership and modes

```bash
sudo chown -R wiki:wiki /home/wiki/dev
sudo chown wiki:www-data /home/wiki/dev/wiki/app/config /home/wiki/dev/wiki/app/config/LocalSettings.php
sudo chown -R wiki:www-data /home/wiki/dev/wiki/app/config/secrets /home/wiki/dev/wiki/app/shared/images
sudo chmod 2770 /home/wiki/dev/wiki/app/config/secrets
sudo chmod 640 /home/wiki/dev/wiki/app/config/LocalSettings.php /home/wiki/dev/wiki/app/config/secrets/SecretsSettings.php /home/wiki/dev/wiki/app/config/secrets/db.php
sudo find /home/wiki/dev/wiki/app/shared/images -type d -exec chmod 2775 {} +
sudo find /home/wiki/dev/wiki/app/shared/images -type f -exec chmod 664 {} +
sudo install -d -o wiki -g wiki -m 775 /home/wiki/dev/wiki/app/shared/sitemap
sudo chmod -R g+w /home/wiki/dev/wiki/backups
```

PHP inside the containers runs as `www-data` (uid 33). It reads `LocalSettings.php` and the secrets through the group and writes uploads through the group bit on `images/`.

### 5. Restore the database

MariaDB starts on an empty `wiki-mariadb/data` and creates the `mediawiki` database and user from `MARIADB_PASSWORD` in the stack `.env`. That value must match `$wgDBpassword` in `secrets/db.php` and `secrets/SecretsSettings.php`.

```bash
cd /home/assisr/dev/docker
docker compose up -d mariadb
until [ "$(docker inspect -f '{{.State.Health.Status}}' wiki-mariadb)" = healthy ]; do sleep 5; done
sudo /home/wiki/dev/wiki/ops/bin/restore-db.sh
```

`restore-db.sh` loads the newest dump by filename through `docker exec -i wiki-mariadb`. Pass a path to load a different one:

```bash
sudo /home/wiki/dev/wiki/ops/bin/restore-db.sh /home/wiki/dev/wiki/backups/db/mediawiki-YYYY-MM-DD-HHMMSS.sql.gz
```

The script reads the password from `infra/.env` if that file exists and falls back to `secrets/db.php`.

If you restore the cold data-dir copy instead, stop `mariadb`, unpack the archive with `sudo tar -xzpf <archive> -C /`, start `mariadb` and skip `restore-db.sh`.

### 6. Build and start the wiki

`update.php` writes to the database (it purges the `objectcache` table at the end), and MediaWiki rejects that write while `$wgReadOnly` is set. The restored `LocalSettings.php` carries the freeze from Part 1, so comment it out for the build. The origin listens on the Docker bridge, and Caddy is still down, so no visitor can edit in this window.

```bash
sudo -u wiki sed -i 's/^\$wgReadOnly = /# &/' /home/wiki/dev/wiki/app/config/LocalSettings.php
/home/assisr/dev/docker/wiki/update.sh
```

Run `update.sh` as `assisr`. It takes a DB backup, builds both images with `--pull`, starts `wiki`, `wiki-web`, `wiki-jobrunner` and `wiki-sitemap`, and runs `update.php --quick`. It ends with a smoke test of four URLs on `172.17.0.1:7734` plus a Scribunto call. The fresh server has no `:previous` images, so a failed smoke test exits without a rollback; read `docker compose logs wiki wiki-web` from `/home/assisr/dev/docker`.

Put the freeze back once `update.sh` prints `wiki updated`:

```bash
sudo -u wiki sed -i 's/^# \(\$wgReadOnly = \)/\1/' /home/wiki/dev/wiki/app/config/LocalSettings.php
```

### 7. Start Caddy

Point the rollerskating.wiki DNS records at the new server in Cloudflare if its IP changed. Wait 60 seconds after the last step so PHP serves the read-only settings, then:

```bash
cd /home/assisr/dev/docker
docker compose up -d caddy
docker logs caddy --tail 50
```

Caddy gets its certificate through the Cloudflare DNS challenge with `CLOUDFLARE_API_TOKEN_WIKI`. A token error in the log means the stack `.env` is missing the variable.

### 8. Install the timers and run the checks

```bash
sudo /home/wiki/dev/wiki/ops/bin/restore-host-config.sh
sudo systemctl enable --now wiki-backup-db.timer wiki-backup-xml.timer wiki-backup-files.timer wiki-update.timer
sudo /home/wiki/dev/wiki/ops/bin/post-restore-check.sh rollerskating.wiki
```

`restore-host-config.sh` installs `wiki-update` from `/home/assisr/dev/docker/wiki/systemd` and the three backup units (DB, XML, files) from `ops/systemd`. Leave `wiki-jobs` and `wiki-sitemap` in `ops/systemd` alone; the containers do that work now.

`post-restore-check.sh` prints the containers, `nginx -t` inside `wiki-web`, the PHP and MediaWiki versions, the origin status and the timer states. It exits non-zero if the origin returns an error such as a 502; on success the origin line prints `200`.

### 9. Lift read-only

```bash
sudo -u wiki sed -i '/^\$wgReadOnly = /d' /home/wiki/dev/wiki/app/config/LocalSettings.php
```

Wait 60 seconds, rerun the siteinfo call from Part 1 step 2 and expect no output. Then log in and save a test edit.

## Post-restore validation checklist

Call the migration done after you can tick each line:

- [ ] `docker ps` shows `wiki`, `wiki-web`, `wiki-jobrunner`, `wiki-sitemap` and `caddy` up, and `wiki-mariadb` healthy
- [ ] `docker exec wiki-web nginx -t` passes
- [ ] the PHP and MediaWiki versions match `backups/inventory/system.txt`
- [ ] `docker exec wiki php maintenance/run.php showSiteStats` matches the numbers you saved in Part 1
- [ ] Special:Version lists the extensions in `backups/inventory/extensions.txt`
- [ ] `curl -sI -H 'Host: rollerskating.wiki' http://172.17.0.1:7734/wiki/Main_Page` returns 200
- [ ] `curl -I https://rollerskating.wiki/` returns 200 with a valid certificate
- [ ] `find /home/wiki/dev/wiki/app/shared/images -type f | wc -l` matches the count from Part 1, and a page with images renders them
- [ ] login and a test edit work
- [ ] `docker exec wiki php maintenance/run.php showJobs` falls toward 0
- [ ] `app/shared/sitemap` holds sitemap files dated today
- [ ] `systemctl list-timers 'wiki-*'` shows three timers
- [ ] `sudo systemctl start wiki-backup-db.service` writes a new dump, and `verify-backups.sh` passes on it

## Disk-loss test

Before you wipe the old disk, assume it failed this minute and you have the off-server copy and nothing else. Check that the copy gives you:

- the SQL dump you took after the freeze
- `LocalSettings.php`, `secrets/SecretsSettings.php` and `secrets/db.php`
- the files under `app/shared/images`, with a count that matches the live server
- the Dockerfile with its `ADD` lines, and the inventory
- the Caddyfile and the stack `.env` with `CLOUDFLARE_API_TOKEN_WIKI` and both MariaDB passwords
- the three timer units

If the copy lacks any of these, keep the server running and fix the copy.
