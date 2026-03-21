# Migrating MediaWiki To A Fresh Server

Last reviewed: 2026-03-16

This document is for the specific case where you are about to format or reset the server and need to preserve the entire wiki safely.

It is intentionally conservative. The goal is not just to make backups, but to verify that the backups are complete, readable, and sufficient to restore the wiki without data loss.

Primary references:

- <https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki>
- <https://www.mediawiki.org/wiki/Manual:Upgrading>
- <https://www.mediawiki.org/wiki/Manual:Installing_MediaWiki>
- <https://www.mediawiki.org/wiki/Manual:Security>

Related local files:

- [docs/OPERATIONS.md](/Users/assisrmatheus/Developer/wiki/docs/OPERATIONS.md)
- [ops/bin/backup-db.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/backup-db.sh)
- [ops/bin/backup-files.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/backup-files.sh)
- [ops/bin/backup-xml.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/backup-xml.sh)
- [ops/bin/export-inventory.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/export-inventory.sh)
- [ops/bin/backup-live-host-config.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/backup-live-host-config.sh)
- [ops/bin/verify-backups.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/verify-backups.sh)
- [ops/bin/create-migration-bundle.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/create-migration-bundle.sh)
- [ops/bin/pre-migration-check.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/pre-migration-check.sh)
- [ops/bin/restore-db.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/restore-db.sh)
- [ops/bin/restore-host-config.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/restore-host-config.sh)
- [ops/bin/post-restore-check.sh](/Users/assisrmatheus/Developer/wiki/ops/bin/post-restore-check.sh)

## What Must Survive

For this deployment, treat these as the required recovery set:

- database logical dump
- `app/config/`
- `app/shared/images/`
- `infra/`
- `ops/`
- current MediaWiki release version information
- installed extension list and their branches

Do not rely only on raw Docker volume data or only on copying the application folder. The official MediaWiki backup guidance is clear that the critical data is the database and the filesystem together.

## Migration Strategy

Use this order:

1. Freeze writes.
2. Create fresh backups.
3. Verify those backups locally.
4. Copy them off the server.
5. Export a machine-readable inventory of the running deployment.
6. Only then format or rebuild the server.
7. Reinstall the base OS and packages.
8. Restore the deployment tree.
9. Restore the database.
10. Validate the site before putting it back in service.

## Part 1: Before Formatting The Server

### Fast path

If the server is already configured and you want the streamlined path, use:

```bash
sudo /home/wiki/dev/wiki/ops/bin/pre-migration-check.sh
```

That will:

- stop the job timer
- create DB, file, and XML backups
- export the deployment inventory
- archive the live host config from `/etc`
- verify the backup artifacts
- create one migration bundle tarball

You should still read the rest of this document once before relying on it.

### 1. Confirm the current state

Record the current versions before touching anything:

```bash
uname -a
docker --version
docker compose version
php -v
nginx -v
```

Record the active MediaWiki release:

```bash
readlink -f /home/wiki/dev/wiki/app/current
```

Record running containers:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

### 2. Put the wiki into maintenance mode

Before backup, stop edits and content changes. The cleanest way is to set the wiki read-only in `LocalSettings.php` temporarily.

Add a temporary line like this to the active `LocalSettings.php`:

```php
$wgReadOnly = 'Server maintenance in progress';
```

Then reload PHP-FPM if needed:

```bash
sudo systemctl reload php8.3-fpm
```

If you do not want to edit the file manually, at minimum stop user traffic at the reverse proxy while the final backup is taken.

### 3. Stop non-essential write activity

Disable the job timer before the final backup:

```bash
sudo systemctl stop wiki-jobs.timer
sudo systemctl stop wiki-jobs.service || true
```

If you run any other scripts that write into the wiki or database, stop them too.

### 4. Take fresh backups

Run all three backup types:

```bash
sudo /home/wiki/dev/wiki/ops/bin/backup-db.sh
sudo /home/wiki/dev/wiki/ops/bin/backup-files.sh
sudo /home/wiki/dev/wiki/ops/bin/backup-xml.sh
```

This gives you:

- SQL dump for the canonical restore path
- filesystem archive for config, images, infra, and ops
- XML content export as an extra fallback

### 5. Verify that the backups are readable

Do not skip this step.

Automated:

```bash
sudo /home/wiki/dev/wiki/ops/bin/verify-backups.sh
```

Check the newest DB dump:

```bash
ls -lh /home/wiki/dev/wiki/backups/db
gzip -t "$(ls -t /home/wiki/dev/wiki/backups/db/*.sql.gz | head -n 1)"
zcat "$(ls -t /home/wiki/dev/wiki/backups/db/*.sql.gz | head -n 1)" | head -n 20
```

Check the newest file archive:

```bash
ls -lh /home/wiki/dev/wiki/backups/files
tar -tzf "$(ls -t /home/wiki/dev/wiki/backups/files/*.tar.gz | head -n 1)" | head -n 50
```

Check the newest XML export:

```bash
ls -lh /home/wiki/dev/wiki/backups/xml
head -n 20 "$(ls -t /home/wiki/dev/wiki/backups/xml/*.xml | head -n 1)"
```

### 6. Create a deployment inventory

Create a record of exactly what is deployed right now. Save this as plain text alongside the backups.

Automated:

```bash
sudo /home/wiki/dev/wiki/ops/bin/export-inventory.sh
```

```bash
mkdir -p /home/wiki/dev/wiki/backups/inventory
{
  echo "DATE=$(date --iso-8601=seconds)"
  echo "CURRENT_RELEASE=$(readlink -f /home/wiki/dev/wiki/app/current)"
  echo "PHP_VERSION=$(php -r 'echo PHP_VERSION;')"
  echo "DOCKER_VERSION=$(docker --version)"
  echo "COMPOSE_VERSION=$(docker compose version)"
  echo
  echo "[docker ps]"
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
  echo
  echo "[nginx version]"
  nginx -v 2>&1
  echo
  echo "[php modules]"
  php -m | sort
} > /home/wiki/dev/wiki/backups/inventory/system.txt
```

Capture extension and skin directories from the current release:

```bash
find /home/wiki/dev/wiki/app/current/extensions -maxdepth 1 -mindepth 1 -type d | sort > /home/wiki/dev/wiki/backups/inventory/extensions.txt
find /home/wiki/dev/wiki/app/current/skins -maxdepth 1 -mindepth 1 -type d | sort > /home/wiki/dev/wiki/backups/inventory/skins.txt
```

If any extensions are Git clones, capture their branch and revision:

```bash
while read -r dir; do
  if [ -d "$dir/.git" ]; then
    {
      echo "[$dir]"
      git -C "$dir" branch --show-current || true
      git -C "$dir" rev-parse HEAD || true
    } >> /home/wiki/dev/wiki/backups/inventory/extensions-git.txt
  fi
done < /home/wiki/dev/wiki/backups/inventory/extensions.txt
```

### 7. Save host configuration that lives outside `/home/wiki/dev/wiki`

Your deployment pack stores examples in the tree, but the live server also has real config in `/etc`.

Back up the live copies too:

Automated:

```bash
sudo /home/wiki/dev/wiki/ops/bin/backup-live-host-config.sh
```

```bash
sudo tar -czf /home/wiki/dev/wiki/backups/files/live-host-config-$(date +%F-%H%M%S).tar.gz \
  /etc/nginx/sites-available/wiki.conf \
  /etc/nginx/sites-enabled/wiki.conf \
  /etc/php/8.3/fpm/pool.d/wiki.conf \
  /etc/php/8.3/fpm/conf.d/10-opcache.ini \
  /etc/systemd/system/wiki-jobs.service \
  /etc/systemd/system/wiki-jobs.timer \
  /etc/systemd/system/wiki-backup-db.service \
  /etc/systemd/system/wiki-backup-db.timer \
  /etc/systemd/system/wiki-backup-files.service \
  /etc/systemd/system/wiki-backup-files.timer
```

If your PHP version differs, adjust the `/etc/php/8.3/` path accordingly.

### 8. Copy the recovery set off the server

Before formatting the machine, copy the full backup set to another device or another machine.

Minimum set to copy:

- `/home/wiki/dev/wiki/backups/`
- `/home/wiki/dev/wiki/infra/.env`
- `/home/wiki/dev/wiki/app/config/LocalSettings.php`
- `/home/wiki/dev/wiki/app/config/secrets/db.php`
- `/home/wiki/dev/wiki/README.md`
- `/home/wiki/dev/wiki/docs/`
- `/home/wiki/dev/wiki/ops/`

Best practice:

- keep one local copy on an external SSD
- keep one second copy elsewhere
- verify file sizes after transfer

To make the handoff simpler, create one migration bundle too:

```bash
sudo /home/wiki/dev/wiki/ops/bin/create-migration-bundle.sh
```

That bundle is not a substitute for your copied `backups/` directory. It is an extra convenience archive.

### 9. Optional cold backup of MariaDB data directory

This is optional and should not replace the SQL dump.

If you want a raw copy of `infra/mariadb/data`:

1. Stop the MariaDB container cleanly.
2. Archive the data directory.
3. Start the container again only if the server remains in service.

Example:

```bash
cd /home/wiki/dev/wiki/infra
docker compose stop mariadb
tar -czf /home/wiki/dev/wiki/backups/files/mariadb-datadir-$(date +%F-%H%M%S).tar.gz /home/wiki/dev/wiki/infra/mariadb/data
docker compose start mariadb
```

This is useful as an extra forensic copy, not as the primary restore path.

### 10. Final pre-format checklist

Do not reset the server until all of these are true:

- the wiki is in maintenance mode
- the latest SQL dump exists and passes `gzip -t`
- the latest file archive opens with `tar -tzf`
- the XML export exists
- the backup set has been copied off the server
- the copied backup set has been spot-checked
- the deployment inventory files exist

## Part 2: Rebuilding And Restoring On The Fresh Server

### 1. Reinstall the base OS and packages

On the new server:

- install Ubuntu
- install Docker and Docker Compose
- install host packages required by the wiki runtime

Use the package list from [docs/OPERATIONS.md](/Users/assisrmatheus/Developer/wiki/docs/OPERATIONS.md).

### 2. Restore the deployment tree

Restore the full deployment pack to:

```text
/home/wiki/dev/wiki
```

After restoring, verify the tree contains at least:

- `app/`
- `infra/`
- `ops/`
- `backups/`
- `docs/`

Restore ownership:

```bash
sudo adduser --disabled-password --gecos "" wiki
sudo chown -R wiki:wiki /home/wiki/dev/wiki
```

### 3. Restore live host configuration

Restore the nginx, PHP-FPM, and systemd files from the backup archive or from the examples in the deployment pack.

Automated:

```bash
sudo /home/wiki/dev/wiki/ops/bin/restore-host-config.sh
```

At minimum:

```bash
sudo cp /home/wiki/dev/wiki/ops/nginx/wiki.conf.example /etc/nginx/sites-available/wiki.conf
sudo ln -s /etc/nginx/sites-available/wiki.conf /etc/nginx/sites-enabled/wiki.conf
sudo cp /home/wiki/dev/wiki/ops/php-fpm/wiki.conf.example /etc/php/8.3/fpm/pool.d/wiki.conf
sudo cp /home/wiki/dev/wiki/ops/php-fpm/10-opcache.ini.example /etc/php/8.3/fpm/conf.d/10-opcache.ini
```

Then install systemd units:

```bash
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-jobs.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-jobs.timer /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-db.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-db.timer /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-files.service /etc/systemd/system/
sudo cp /home/wiki/dev/wiki/ops/systemd/wiki-backup-files.timer /etc/systemd/system/
sudo systemctl daemon-reload
```

### 4. Restore Docker service configuration and secrets

Restore:

- `infra/docker-compose.yml`
- `infra/.env`
- `infra/caddy/Caddyfile`
- `infra/mariadb/conf.d/50-mediawiki.cnf`

Then start the containers:

```bash
cd /home/wiki/dev/wiki/infra
docker compose up -d
```

Confirm MariaDB is healthy before proceeding:

```bash
docker ps
docker logs wiki-mariadb --tail 50
```

### 5. Restore MediaWiki core release and shared files

Restore or redeploy the release directory matching the version recorded in the inventory.

If you already restored the full `app/` tree from backup, verify:

```bash
readlink -f /home/wiki/dev/wiki/app/current
ls -la /home/wiki/dev/wiki/app/config
ls -la /home/wiki/dev/wiki/app/shared/images
```

If the release directories were not preserved, redeploy the exact version with:

```bash
sudo -u wiki /home/wiki/dev/wiki/ops/bin/deploy-core.sh 1.43.6
```

Then restore:

- `app/config/LocalSettings.php`
- `app/config/secrets/db.php`
- `app/shared/images/`

### 6. Restore the database from the SQL dump

Identify the newest SQL backup:

```bash
ls -t /home/wiki/dev/wiki/backups/db/*.sql.gz | head -n 1
```

Restore it:

Automated:

```bash
sudo /home/wiki/dev/wiki/ops/bin/restore-db.sh
```

Or specify a file:

```bash
sudo /home/wiki/dev/wiki/ops/bin/restore-db.sh /home/wiki/dev/wiki/backups/db/mediawiki-YYYY-MM-DD-HHMMSS.sql.gz
```

```bash
zcat /home/wiki/dev/wiki/backups/db/mediawiki-YYYY-MM-DD-HHMMSS.sql.gz | \
docker exec -i -e MYSQL_PWD="$(grep '^MARIADB_PASSWORD=' /home/wiki/dev/wiki/infra/.env | cut -d= -f2-)" wiki-mariadb \
  mariadb -umediawiki mediawiki
```

If the database and user do not exist yet, create them first using the root password from `infra/.env`.

### 7. Restore permissions and symlinks

After the files are back in place:

```bash
sudo chown -R wiki:wiki /home/wiki/dev/wiki/app
sudo chown -R www-data:www-data /home/wiki/dev/wiki/app/shared/images
sudo chmod 640 /home/wiki/dev/wiki/app/config/LocalSettings.php
sudo chmod 640 /home/wiki/dev/wiki/app/config/secrets/db.php
```

Verify these symlinks:

```bash
ls -la /home/wiki/dev/wiki/app/current
```

You should see:

- `LocalSettings.php` pointing to `app/config/LocalSettings.php`
- `images` pointing to `app/shared/images`

### 8. Restore extensions and skins

If extensions and skins were restored with the full release tree, verify them against the inventory files.

If they were not restored, reinstall them from the recorded branch and revision information, then run:

```bash
sudo -u wiki php /home/wiki/dev/wiki/app/current/maintenance/run.php update
```

### 9. Start services and validate locally

Bring the host services up:

```bash
sudo nginx -t
sudo systemctl restart php8.3-fpm
sudo systemctl reload nginx
```

Then test from the server:

```bash
curl -I http://127.0.0.1:8081/
curl -I https://wiki.example.com/
```

Check:

- front page loads
- images render
- login works
- a sample article opens
- the edit form opens for an admin
- uploads are present

Automated smoke check:

```bash
sudo /home/wiki/dev/wiki/ops/bin/post-restore-check.sh wiki.example.com
```

### 10. Re-enable background jobs and normal access

Once the site is confirmed healthy:

```bash
sudo systemctl enable --now wiki-jobs.timer
sudo systemctl enable --now wiki-backup-db.timer wiki-backup-files.timer
```

Remove maintenance mode from `LocalSettings.php`:

```php
// remove:
$wgReadOnly = 'Server maintenance in progress';
```

Reload PHP-FPM:

```bash
sudo systemctl reload php8.3-fpm
```

## Post-Restore Validation Checklist

Do not consider the migration finished until all of these are true:

- `docker ps` shows `wiki-caddy` and `wiki-mariadb` healthy
- nginx is serving on `127.0.0.1:8081`
- the domain works through Cloudflare
- the correct MediaWiki version is active
- uploads are present
- articles and revisions are present
- login works
- jobs timer is active
- backup timers are active
- a fresh new backup completes on the rebuilt server

## Practical Recommendation

Before you wipe the old machine, do one dry run mentally against the recovery set:

- If the original disk disappeared right now, do I have the SQL dump?
- Do I have `LocalSettings.php` and DB credentials?
- Do I have `images/`?
- Do I have the exact release version and extension list?
- Do I have the reverse proxy and host config?

If any answer is no, do not format the server yet.
