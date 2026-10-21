# MediaWiki Deployment Pack

This repo holds the settings, uploads, sitemap, ops scripts, backups and docs for the wiki. The wiki itself runs in Docker, in five containers:

- `wiki`: PHP-FPM, built `FROM mediawiki:1.43-fpm`
- `wiki-web`: nginx
- `wiki-jobrunner`: the job queue runner
- `wiki-sitemap`: daily sitemap generation
- `wiki-mariadb`: the database

`/home/assisr/dev/docker/docker-compose-wiki.yml` defines these containers, and `/home/assisr/dev/docker/wiki` holds their build files. The `caddy` container in the same stack is the public reverse proxy and sits behind Cloudflare. The containers bind-mount the config, uploads and sitemap from this repo.

Read [AGENTS.md](AGENTS.md) for the architecture and the rules before you change anything. For day-to-day work, use [docs/OPERATIONS.md](docs/OPERATIONS.md) and [docs/Migrating.md](docs/Migrating.md).

## Directory map

```text
wiki/
  app/config/          MediaWiki settings (bind-mounted)
  app/shared/images/   Uploads (bind-mounted)
  app/shared/sitemap/  Sitemap (bind-mounted)
  app/releases/        Pre-Docker host install, kept for rollback
  app/current          Pre-Docker host install, kept for rollback
  ops/bin/             Backup, restore and maintenance scripts
  backups/             Database, file and XML backups
  docs/                Runbooks and notes
  infra/               Outdated example Compose and Caddy files; the live stack doesn't use them
```
