# MediaWiki Deployment Pack

This directory contains a production-oriented MediaWiki deployment pack built around:

- MediaWiki on the host
- `nginx` on the host
- `php-fpm` on the host
- `caddy` in Docker as the public reverse proxy
- `mariadb` in Docker with bind-mounted `./` data

Start with [docs/OPERATIONS.md](/Users/assisrmatheus/Developer/wiki/docs/OPERATIONS.md).

If you are a coding agent or need the full architecture and live-environment context first, read [docs/AGENT_CONTEXT.md](/Users/assisrmatheus/Developer/wiki/docs/AGENT_CONTEXT.md) before making changes.

## Why this shape

This keeps the MediaWiki application close to the official install and upgrade path, while still making Docker-managed service data easy to move or back up from one directory tree.

It also keeps host features such as `ffmpeg`, ImageMagick, and extension installs straightforward.

## Directory map

```text
wiki/
  app/          MediaWiki releases, shared uploads, config examples
  infra/        Docker Compose, Caddy, MariaDB config
  ops/          Host config examples, scripts, systemd units
  backups/      Logical and file backups
  docs/         Runbook and operational notes
```
