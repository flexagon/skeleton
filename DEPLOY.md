# Deployment Guide

How to build a Flexagon application into a container image and deploy it to the cloud (Cloud Run, ECS, Kubernetes and the like). Everything here uses the `production` target of the `Dockerfile` that ships with the skeleton.

- [Principle: one container, one site](#principle-one-container-one-site)
- [1. Prerequisites](#1-prerequisites)
- [2. Build the image](#2-build-the-image)
- [3. Try it locally](#3-try-it-locally)
- [4. Push to a registry](#4-push-to-a-registry)
- [5. Deploy](#5-deploy)
- [6. Checklist](#6-checklist)
- [7. Updates and rollback](#7-updates-and-rollback)
- [Environment variables](#environment-variables)
- [Limitations](#limitations)

---

## Principle: one container, one site

A container ignores the Host header and sends every request to a single directory, `FLEXAGON_PUBLIC` (default `public`). Which domain reaches which container is up to the load balancer, ingress or Cloud Run domain mapping.

```
example.com        ─┐                   ┌─ service myapp-web    (FLEXAGON_PUBLIC=public)
                    ├─ load balancer ───┤
admin.example.com  ─┘                   └─ service myapp-admin  (FLEXAGON_PUBLIC=public_admin)
                                             └ same image myapp:1.0.0
```

Build one image and run one service per `public_*` site. Each site then has its own scaling, memory, database account and network exposure, and load on one site never crowds out requests to another.

---

## 1. Prerequisites

The project needs:

| File | Notes |
|---|---|
| `Dockerfile`, `.dockerignore`, `docker/` | Created by `composer create-project flexagon/skeleton` or `flexagon init` |
| `composer.json`, `composer.lock` | **Commit the lock file.** The build installs exactly the versions it lists |
| `public/`, `public_*/` | Site directories, each with its own `__flexagon.php` |

`.dockerignore` keeps the following out of the build, so **they never reach the image**:

| Excluded | Why |
|---|---|
| `.env.php`, `.env` | Secrets are handed in as environment variables at run time |
| `vendor/` | Installed fresh inside the build with `--no-dev` |
| `.git`, `tests/`, `.claude/`, IDE settings | Not needed at run time |

---

## 2. Build the image

```bash
docker build --target production --platform linux/amd64 -t myapp:1.0.0 .
```

- `--target` — chooses which stage of the `Dockerfile` to build up to. The deploy image is the stage of the server you deploy to (`alpha`, `beta`, `production`).

`--target` takes the name of a `Dockerfile` stage. These four are the ones you choose directly.

| `--target` | Purpose | `application/_Config.php` |
|---|---|---|
| `production` | **Deploy image for the production server** | Overwritten by the files in `application/_Config/production/` |
| `beta` | Deploy image for the beta server | Overwritten by the files in `application/_Config/beta/` |
| `alpha` | Deploy image for the alpha server | Overwritten by the files in `application/_Config/alpha/` |
| `dev` | Local development (used by `compose.yaml`) | Not copied. The mounted project's files are used as they are |

- **Stage config** — as when deploying to a server with Ant, the build copies **every file** in `application/_Config/<stage>/` into `application/`. Not just `_Config.php`: any other file you put in that directory (`_Const.php` and so on) overwrites its namesake too. If the stage directory does not exist, the build fails.
- **The three stages share one runtime** — project copied in, dependencies without `require-dev`, `php.ini-production`, runs as `www-data`, `flexagon check` during the build (checking the copied stage config). Only the config files differ.
- Each stage builds its own image, so tell them apart by tag (for example `myapp:1.0.0-beta`). Secrets still come in as environment variables at run time.
- Without `--target`, the last stage, `production`, is built. It is still better to write it out so it is clear what is being built.
- The other stages, `base` (PHP, Apache, extensions), `build` (`composer install --no-dev`), `config-<stage>` (copies the stage config) and `runtime` (production php.ini), are intermediate and not used directly.
- To add a stage, create `application/_Config/<name>/`, then add a `config-<name>` stage and a `<name>` target block to the `Dockerfile`, and a `<name>` target to `build.xml`, like the existing ones.
- The `dev` image has no code in it. Run it with `docker run` and no mount, and it exits at once because the `FLEXAGON_PUBLIC` directory does not exist. For local development use `docker compose up`.

- **PHP extensions** — list **every** extension the image should have in `PHP_EXTENSIONS` at the top of the `Dockerfile`. So that a build or a request does not fail for a missing one, the default carries commonly used extensions; **delete what you do not use** to keep the image small.

  Default PHP extensions in the image: `pdo_mysql`, `pdo_pgsql`, `opcache`, `bcmath`, `exif`, `gd`, `gettext`, `intl`, `zip`

  Add any other extension the application needs to `PHP_EXTENSIONS`.

  Extensions built into the official PHP image (`php:8.3-apache`): `ctype`, `curl`, `date`, `dom`, `fileinfo`, `filter`, `hash`, `iconv`, `json`, `libxml`, `mbstring`, `mysqlnd`, `openssl`, `pcre`, `PDO`, `pdo_sqlite`, `Phar`, `posix`, `random`, `readline`, `session`, `SimpleXML`, `sodium`, `sqlite3`, `tokenizer`, `xml`, `xmlreader`, `xmlwriter`, `zlib`, `opcache`

```dockerfile
# default
ARG PHP_EXTENSIONS="pdo_mysql pdo_pgsql opcache bcmath exif gd gettext intl zip"

# e.g. MySQL only, keeping just what is needed
ARG PHP_EXTENSIONS="pdo_mysql opcache gd zip gettext"
```

- Extension names follow [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer), which also installs the system libraries they need.
- Extensions built into the official PHP image are not listed in `PHP_EXTENSIONS`. Deleting them from the list does not remove them, and listing them changes nothing. `docker run --rm php:8.3-apache php -m` shows them for yourself.
- `dev` and the stage targets share the `base` stage, so both get them.

- `--platform` — on an Apple Silicon Mac the image is arm64 by default. Use `linux/amd64` for amd64 servers, or `linux/arm64` for arm servers such as Graviton.

Match the CPU of **where the image runs**, not the machine that builds it.

| Where it runs | `uname -m` | `--platform` | Notes |
|---|---|---|---|
| Linux server (Intel, AMD) | `x86_64` | `linux/amd64` | Most VPS and on-premises servers |
| Linux server (ARM) | `aarch64` | `linux/arm64` | Ampere, Raspberry Pi (64-bit OS), etc. |
| macOS (Apple Silicon), running locally | `arm64` | `linux/arm64` | The default on this Mac, can be omitted |
| macOS (Intel), running locally | `x86_64` | `linux/amd64` | The default on this Mac, can be omitted |
| Windows (Docker Desktop, x64) | — | `linux/amd64` | Linux containers on WSL 2 |
| Windows (Docker Desktop, ARM) | — | `linux/arm64` | ARM PCs such as Snapdragon |
| AWS EC2 (x86) | `x86_64` | `linux/amd64` | |
| AWS EC2 (Graviton) | `aarch64` | `linux/arm64` | Instances with a `g` in the name, such as `t4g`, `m7g`, `c7g` |
| AWS ECS, Fargate, EKS (x86) | — | `linux/amd64` | |
| AWS ECS, Fargate, EKS (Graviton) | — | `linux/arm64` | On Fargate, also set `runtimePlatform.cpuArchitecture: ARM64` in the task definition |
| Oracle Cloud (Ampere A1) | `aarch64` | `linux/arm64` | |
| Google Cloud Run | — | `linux/amd64` | arm64 images do not run |
| GKE | — | `linux/amd64` / `linux/arm64` | Match the node pool's machine type (Tau T2A and Axion are arm64) |
| Azure Container Apps, App Service | — | `linux/amd64` | |

`uname -m` is what the machine that runs the image reports (— for managed services you cannot check directly). An image built with a `--platform` other than the one in the table fails to start with `exec format error`.

> Images for another architecture do run under emulation (QEMU, Rosetta), but slowly. Building for amd64 on an Apple Silicon Mac also takes several times longer.

If you run on both amd64 and arm64, one tag can hold both architectures. A multi-platform image cannot go straight into the local image list, so push it to a registry with `--push` ([4. Push to a registry](#4-push-to-a-registry)).

```bash
docker buildx build --target production --platform linux/amd64,linux/arm64 \
  -t asia-northeast3-docker.pkg.dev/my-project/apps/myapp:1.0.0 --push .
```

**Running on arm64 machines** — build an image that runs on an arm64 machine, such as a Graviton or Ampere server, a Raspberry Pi (64-bit OS) or an Apple Silicon Mac, for `linux/arm64`.

```bash
docker build --target production --platform linux/arm64 -t myapp:1.0.0-arm64 .
docker image inspect myapp:1.0.0-arm64 --format '{{.Os}}/{{.Architecture}}'   # linux/arm64
```

- Check the architecture of the machine that runs it with `uname -m`: `aarch64` or `arm64` is arm64, `x86_64` is amd64.
- On an Apple Silicon Mac the image is arm64 even without `--platform`, but for a deploy image it is clearer to write it out.
- Building for arm64 on an amd64 machine needs emulation. Docker Desktop has it; on a Linux server, install it once with `docker run --privileged --rm tonistiigi/binfmt --install arm64`.
- The official PHP image and the extensions in `PHP_EXTENSIONS` support arm64 too.

**`exec /usr/local/bin/flexagon-entrypoint: exec format error`** — the image and the machine running it have different architectures. The `/bin/sh` in the image that runs the entrypoint script is built for another CPU, so the container cannot start. This happens, for example, when an image built for amd64 runs on an arm64 server, or when an arm64 image built on an Apple Silicon Mac without `--platform` runs on an amd64 server (Cloud Run and the like). Compare the two with `docker image inspect` and `uname -m` above, and rebuild with the `--platform` of where it runs. If it runs on both, build a multi-platform image.

The build:

1. Copies the project in. The host's `vendor/` is not copied (`.dockerignore`).
2. Runs `composer install --no-dev` and `composer dump-autoload --optimize`, installing fresh from `composer.lock` against this image's PHP and extensions. A path repository inside the project (`"url": "./packages/..."`) is installed here too. Downloads stay in a build cache (not in the image), so a rebuild after a code change does not download them again.
3. Applies `php.ini-production` plus `docker/php-production.ini`:
   - `opcache.validate_timestamps = 0` — the code in the image never changes, so files are never checked again.
   - `opcache.save_comments = 1` — without it, doc block annotations (`@encrypt` and others) are ignored, silently.
   - `opcache.file_cache` off — otherwise the compiled `.env.php` is written to disk.
   - `expose_php = Off`
4. Runs **`flexagon check`**. A layout or configuration problem fails the build. Values that only arrive as environment variables at run time show up as warnings.

   ```
   ok       .env.php  none -- settings come from the environment and _Config.php
   warn     settings  not set: DB_HOST, DB_PASSWORD, ...      ← expected
   0 problem(s), 2 warning(s)
   ```

5. Switches to `www-data`. The code is owned by root, so a request cannot change it.

The `alpha`, `beta` and `production` images have no Xdebug and no composer.

---

## 3. Try it locally

```bash
docker run --rm -p 8080:8080 \
  -e DB_HOST=host.docker.internal -e DB_USER=app -e DB_PASSWORD=... -e DB_NAME=app \
  -e SESSION_ENCRYPTION_STRING=... -e CLASS_PROPERTY_ENCRYPTION_PASSPHRASE=... \
  myapp:1.0.0
# http://localhost:8080

docker run --rm -p 8081:8080 -e FLEXAGON_PUBLIC=public_admin ... myapp:1.0.0
# http://admin.localhost:8081
```

To pass the variables from a file, use one **outside the project**, such as `--env-file ~/secrets/myapp.env`. A `.env` in the project root draws a `flexagon check` warning and is easy to commit by mistake.

Look for these lines in the start-up log:

```
flexagon: serving /app/public on port 8080
flexagon: 9 workers (auto: 512MB - 64MB reserved, 48MB each)
```

If `FLEXAGON_PUBLIC` is wrong (no such directory, no `__flexagon.php`, or a path rather than a name), the container exits without starting Apache.

---

## 4. Push to a registry

```bash
docker tag myapp:1.0.0 asia-northeast3-docker.pkg.dev/my-project/apps/myapp:1.0.0
docker push asia-northeast3-docker.pkg.dev/my-project/apps/myapp:1.0.0
```

ECR, GHCR and Docker Hub work the same way. Tag with a version or commit hash rather than `latest`, so that a rollback knows exactly which image to go back to.

---

## 5. Deploy

### Cloud Run

```bash
gcloud run deploy myapp-web \
  --image asia-northeast3-docker.pkg.dev/my-project/apps/myapp:1.0.0 \
  --memory 512Mi --concurrency 9 \
  --set-env-vars FLEXAGON_PUBLIC=public,DB_HOST=10.0.0.5,DB_USER=app,DB_NAME=app \
  --set-secrets DB_PASSWORD=db-password:latest,SESSION_ENCRYPTION_STRING=session-key:latest,CLASS_PROPERTY_ENCRYPTION_PASSPHRASE=prop-key:latest

gcloud run deploy myapp-admin \
  --image asia-northeast3-docker.pkg.dev/my-project/apps/myapp:1.0.0 \
  --memory 512Mi --concurrency 9 \
  --set-env-vars FLEXAGON_PUBLIC=public_admin,... \
  --set-secrets ... \
  --ingress internal
```

Apache listens on the `PORT` Cloud Run provides. Connect domains per service with domain mapping or an HTTPS load balancer.

### Kubernetes

One Deployment per site:

```yaml
containers:
  - name: web
    image: registry.example.com/myapp:1.0.0
    ports: [{ containerPort: 8080 }]
    env:
      - { name: FLEXAGON_PUBLIC, value: public }
      - { name: DB_HOST, value: mysql.internal }
      - name: DB_PASSWORD
        valueFrom: { secretKeyRef: { name: myapp, key: db-password } }
      - name: SESSION_ENCRYPTION_STRING
        valueFrom: { secretKeyRef: { name: myapp, key: session-key } }
    resources:
      limits: { memory: 512Mi }        # sets the number of processes
    readinessProbe:
      httpGet: { path: /, port: 8080 }
```

Route each host to its Service in the Ingress.

### ECS

One Task Definition and Service per site: container port 8080, `FLEXAGON_PUBLIC` under `environment`, Secrets Manager or Parameter Store values under `secrets`, and a container `memory` limit. Route hosts to each service's target group with ALB host-based rules.

---

## 6. Checklist

| Item | What to do |
|---|---|
| Secrets | Hand in `DB_PASSWORD`, `SESSION_ENCRYPTION_STRING`, `CLASS_PROPERTY_ENCRYPTION_PASSPHRASE` and the rest through your platform's secret store. The keys in `.env.example.php` are the list |
| Session key | Give every instance of a site the **same** `SESSION_ENCRYPTION_STRING`. Sessions are encrypted cookies and need no shared store, but with different keys every switch between instances logs the user out |
| Memory and concurrency | The number of Apache processes follows the memory limit (table below). Requests beyond it wait, so set the platform's per-instance concurrency to match |
| Memory use | Watch the real RSS of the PHP processes in production and set `APACHE_WORKER_MEMORY_MB` to match |
| HTTPS | Terminate TLS at the load balancer. With `X-Forwarded-Proto: https`, the session cookie gets the Secure flag |
| Database TLS | If the managed database requires TLS, give MySQL `pdoOptions: [PDO::MYSQL_ATTR_SSL_CA => ...]`. For PostgreSQL, set `PGSSLMODE=verify-full` and `PGSSLROOTCERT` to verify the certificate too. Put the CA file in the image or mount it (README, "Data Sources") |
| Files | The container's disk is gone on restart. Use object storage for uploads and a managed database; do not use SQLite |
| Network exposure | Keep internal services, such as an admin site, off the public load balancer |
| Read-only file system (optional) | Mount tmpfs at `/var/run/apache2` and `/tmp` |

**Apache processes by memory** — (limit − 64MB) ÷ 48MB, at least 2 and at most 256

| Memory | 512MB | 1GB | 2GB | 4GB |
|---|---|---|---|---|
| Processes | 9 | 20 | 41 | 84 |

---

## 7. Updates and rollback

```bash
docker build --target production --platform linux/amd64 -t .../myapp:1.0.1 .
docker push .../myapp:1.0.1
# deploy 1.0.1 to every site's service
```

All sites share `application/`, so deploy every site's service with the same image tag. To roll back, deploy the previous tag.

In CI, run build → push → deploy in that order. If `flexagon check` fails during the build, the pipeline stops there.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `FLEXAGON_PUBLIC` | `public` | Directory to serve: `public` or `public_<name>` |
| `PORT` | `8080` | Port Apache listens on; the platform's value when it sets one |
| `APACHE_MAX_REQUEST_WORKERS` | `auto` | Number of Apache processes; a number is used as given |
| `APACHE_WORKER_MEMORY_MB` | `48` | Memory per process, for the `auto` calculation |
| `APACHE_RESERVED_MEMORY_MB` | `64` | Memory kept back for the Apache parent and the OS, for the `auto` calculation |
| `APACHE_MAX_CONNECTIONS_PER_CHILD` | `1000` | A process is replaced after this many connections |

Application settings (`DB_*`, session and encryption keys and so on) follow the keys defined in `.env.example.php` and `application/_Config.php`. Environment variables take precedence over `.env.php`.

---

## Limitations

- A path repository (`"type": "path"`) must be **inside the project** (`"url": "./packages/..."`). One outside it (`"../shared/lib"`) is outside the Docker build context and cannot be built; move it into the project or turn it into a Git repository (`"type": "vcs"`).
- A project on `application/_Flexagon.phar` without `composer.json` builds, but `flexagon check` is skipped during the build.
- There is no dedicated health check path. Use `/`, or add a page that does not touch the database.
