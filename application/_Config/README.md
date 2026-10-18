# application/_Config

Settings per stage. Each directory holds the files that differ on that stage's servers:

```
application/
├── _Config.php              local development and the Docker dev target
└── _Config/
    ├── alpha/_Config.php
    ├── beta/_Config.php
    └── production/_Config.php
```

## How a stage is applied

- **Deploy (Docker, Ant)** — `docker build --target <stage>` and the Ant build copy **every file** in `_Config/<stage>/` over `application/`, so `_Config/production/_Config.php` becomes `application/_Config.php`. Any other file you put there (`_Const.php` and so on) replaces its namesake too. Keep only files meant for `application/` in a stage directory; this README sits outside them for that reason.
- **CLI** — `php script/sample.php runtimeStage=production` reads `_Config/production/_Config.php` instead of `application/_Config.php`.

To add a stage, create `_Config/<name>/_Config.php`, then add a `config-<name>` stage and a `<name>` target block to the `Dockerfile`, like the existing ones.

## Secrets: read them with Env

A stage's `_Config.php` is committed, so it holds no passwords or keys. Read them with `Env`:

```php
use _Flexagon\Libs\Env;
use _Flexagon\Models\DataSourceModel;

_Global::$DATA_SOURCES['default'] = new DataSourceModel(
    Env::get('DB_HOST', 'localhost'),
    Env::int('DB_PORT', 3306),
    Env::get('DB_USER'),
    Env::required('DB_PASSWORD'),     // stops the request when it is missing
    Env::get('DB_NAME')
);

_Global::$SESSION_ENCRYPTION_STRING = Env::required('SESSION_ENCRYPTION_STRING');
```

`Env` looks a key up in this order:

1. the server's environment (PHP-FPM `env[]`, Apache `SetEnv`, Docker, a PaaS)
2. `.env.php` in the project root (copy `.env.example.php`)
3. the default given at the call

`Env` has no notion of stages. What differs per stage is which `_Config.php` runs; the secrets it reads come from the environment or `.env.php` of the server it runs on. So put settings that differ per stage in `_Config/<stage>/_Config.php`, and secrets in each server's environment or `.env.php`.

## Keeping .env.php outside the project

`.env.php` sits in the project root by default, outside `public/`. To keep it somewhere else on each server, such as `/etc/flexagon/`, use one of these.

### 1. ENV_FILE

`Env` reads the file named by the `ENV_FILE` constant when it is defined before the framework boots. `flexagon.php` is committed, so take the path from the server's environment rather than writing it in. Add this at the top of `flexagon.php`:

```php
if ( !defined('ENV_FILE') && getenv('FLEXAGON_ENV_FILE') ) {
    define('ENV_FILE', getenv('FLEXAGON_ENV_FILE'));
}
```

Then set `FLEXAGON_ENV_FILE` on each server:

```
# Apache
SetEnv FLEXAGON_ENV_FILE /etc/flexagon/myapp.env.php

# PHP-FPM pool
env[FLEXAGON_ENV_FILE] = /etc/flexagon/myapp.env.php

# CLI and cron
export FLEXAGON_ENV_FILE=/etc/flexagon/myapp.env.php
```

`flexagon check` still looks for `.env.php` in the project root and reports `none` when it is elsewhere; its check for unset keys runs after boot and does use `ENV_FILE`.

### 2. A symbolic link

No code change: link the project's `.env.php` to the real file.

```bash
ln -s /etc/flexagon/myapp.env.php /var/www/myapp/.env.php
```

`.gitignore` already leaves `/.env.php` out, and `flexagon check` follows the link. A deploy that recreates the project directory has to create the link again.

### Where to put the file

- Use an absolute path. PHP does not expand `~`.
- Web requests run as the web server's user (`www-data` and the like), not as your login user, so a file under another user's home (`/home/deploy/.flexagon`) is usually unreadable to it. Opening up a home directory to fix that is worse than the problem.
- `/etc/flexagon/` owned by root and readable by the web server's group is a good default:

  ```bash
  sudo mkdir -p /etc/flexagon
  sudo install -o root -g www-data -m 0640 myapp.env.php /etc/flexagon/myapp.env.php
  ```

- With `open_basedir` set, add the directory to it.
