# Flexagon

[![PHP](https://img.shields.io/badge/php-%3E%3D8.3-777bb4.svg)](https://www.php.net/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](#license)

Flexagon is a **lightweight, high-performance PHP web framework**.

It embraces PHP's inherent simplicity over complex abstractions, keeping conventions to a minimum so you can build applications quickly.

-   **Simple, flexible routing** --- The file structure maps directly to the URL structure, keeping routing intuitive and straightforward.
-   **Independent request execution** --- Each request leaves no unnecessary state behind, keeping behavior stable and predictable.
-   **Simple, idiomatic PHP development** --- Build with PHP in its natural form, without introducing a separate template language.

## Why Flexagon?

**If you know PHP, you can get started right away.**  
Pages are `.php` files, views are written directly in PHP and HTML, and you can use the SQL you already know. There is no routing syntax, service container, or query DSL to learn before you start building.

**Zero runtime dependencies.**  
Flexagon runs with PHP 8.3 and the `pdo`, `openssl`, and `json` extensions. There is no need to install dozens of third-party packages just to use the framework.

**Small and fast.**  
In the same environment, framework bootstrap takes **1.09 ms, 2 MB of memory, and 15 loaded files**. The framework itself remains compact at 39 PHP files and 7,148 lines of code.

|                    |         Flexagon 3.5.0 | Laravel 13.26.1 |
| ------------------ | ---------------------: | --------------: |
| Runtime dependencies      |                **0** |     77 packages |
| Installed size          | **532KB** (PHAR 237KB) |            42MB |
| Bootstrap time          |             **1.09ms** |         12.85ms |
| Bootstrap memory        |                **2MB** |            20MB |
| Files loaded at bootstrap  |               **15** |           336 |

**Simple deployment.**  
The entire framework can be deployed as a single 237 KB PHAR file. The target server does not need Composer or a separate cache-warming step.

## Design Principles

### URLs map directly to file paths

A request to `/user/profile` maps directly to `public/user/profile.php`.

There is no routing table to maintain. Create a file and it gets a URL; move the file and the URL moves with it. The URL itself makes it easy to see which file will be executed.

### The database is the source of truth for the schema

On the first query, a DAO runs `DESCRIBE` to read column, primary-key, and `auto_increment` metadata, then reuses it for the rest of the request.

A schema already defined in the database does not need to be duplicated in PHP. When the schema changes, there is no separate mapping definition to keep in sync.

### Global configuration stays explicit

Configuration is collected in the static `_Global` class.

There is no DI container or service locator between you and the configuration, so it is easy to see where settings live and which values are in use. Type `_Global::` in your IDE to discover the available settings through autocompletion.

### Minimal overhead per request

Framework bootstrap consists of defining constants, registering the autoloader, and loading configuration files.

Flexagon does not eagerly create unnecessary objects or services, and `DataSourceManager` reuses database connections within each request.

---

## Requirements

| Item | Version / Notes |
|---|---|
| PHP | 8.3 or later |
| Extensions | `pdo_mysql` (or `pdo_pgsql`, `pdo_sqlite`, `pdo_sqlsrv`/`pdo_dblib`), `openssl`, `json` |
| Web server | Apache (`mod_rewrite`) or nginx |
| Database | MySQL / MariaDB, PostgreSQL, SQLite, MS SQL Server |

---

## Installation

Flexagon is distributed as two Composer packages.

| Package | Purpose |
|---|---|
| [`flexagon/framework`](https://packagist.org/packages/flexagon/framework) | Framework core (library) |
| [`flexagon/skeleton`](https://packagist.org/packages/flexagon/skeleton) | Application skeleton (project template) |

### New Project

```bash
composer create-project flexagon/skeleton myapp
cd myapp
```

```
myapp/
├── application/          # Domain code
├── public/               # ← document root
├── script/               # CLI jobs
├── flexagon.php
├── composer.json
└── vendor/
    └── flexagon/framework/   # Framework core
```

You can update the framework independently.

```bash
composer update flexagon/framework
```

### Add to an Existing Project

```bash
composer require flexagon/framework
composer exec flexagon init      # or php vendor/bin/flexagon init
```

`init` creates the 31 files that make up the project structure, including `public/`, `application/`, `script/`, and `flexagon.php`. **Existing files are left untouched**, so you can also use it after an upgrade to add only newly introduced structure files. Use `--force` to overwrite existing files.

```
create   flexagon.php
create   application/_Global.php
...
keep     public/index.php        ← keep existing file
```

> Installing only `flexagon/framework` gives you immediate access to utility classes such as `StringUtil`, `ValidUtil`, and `CryptoUtil`, as well as `BaseModel`. However, **the DAO layer requires the application to define `_Global`.** Without it, `BaseGlobal` defaults are used, so no fatal error occurs, but the empty data-source configuration prevents database connections. For real applications, start with the skeleton package.

`flexagon.php` checks two layouts in order, so the entry-point code remains the same regardless of how the framework is installed.

| Order | Path | Scenario |
|---|---|---|
| 1 | `vendor/flexagon/framework/Bootstrap.php` | Composer installation |
| 2 | `application/_Flexagon.phar` (file) | Packaged as a single PHAR |

If neither is found, it stops with a `RuntimeException` that tells you to run `composer install` or build the PHAR with `ant build`. `vendor/autoload.php` is loaded before the framework so that Composer `files` entries are registered first.

`Bootstrap.php` finds the nearest parent directory containing `application/_Global.php` and uses it as `PROJECT_ROOT`. Application path resolution therefore works the same whether the framework lives under `vendor/` or inside a PHAR.

### Autoloading

Application classes are mapped to `application/` through PSR-4 in `composer.json`.

```
ExampleUser\UserDAO  →  application/ExampleUser/UserDAO.php
```

To add a namespace, simply create a directory with the same name. There is no need to modify `composer.json`.

The framework automatically loads the `_Flexagon\` namespace, global helpers (`_echo`, `_t`, `___`), and `TemplateLoader`. No additional configuration is required.

### Docker

The included `Dockerfile` and `compose.yaml` run **one site per container**. A container sends every request, whatever its host name, to the `FLEXAGON_PUBLIC` directory (default `public`). Which domain reaches which container is up to the load balancer, ingress or Cloud Run domain mapping.

| Target | Purpose | Contents |
|---|---|---|
| `dev` | Local development (`compose.yaml`) | Project mounted at `/app`, `php.ini-development`, composer, Xdebug (installed, not loaded) |
| `alpha`, `beta`, `production` | Deploy image per stage | Project copied in and `application/` overwritten by the files in `application/_Config/<stage>/`, `composer install --no-dev`, `php.ini-production`, opcache timestamp checks off, runs as `www-data`, `flexagon check` during the build |

A PHP 8.3 + Apache image; the container listens on `PORT` (default 8080). The extensions to install are set in `PHP_EXTENSIONS` at the top of the `Dockerfile`: delete the ones you do not use and add the ones that are missing (see [DEPLOY.md](DEPLOY.md)).

Default PHP extensions in the image: `pdo_mysql`, `pdo_pgsql`, `opcache`, `bcmath`, `exif`, `gd`, `gettext`, `intl`, `zip`

**Development**

```bash
docker compose up -d                       # web (:8080)
docker compose exec web composer install   # when vendor/ is missing
docker compose --profile xdebug up -d      # + web-xdebug with Xdebug on (:8081)
```

The MySQL 8.4 and PostgreSQL 17 containers are included as comments, so by default they do not start and the application connects as `.env.php` says. To use one, uncomment the parts of `compose.yaml` marked `MySQL` or `PostgreSQL` (`DB_*` / `PGSQL_DB_*` under `environment`, `depends_on`, the service, and `volumes`).

Once uncommented, the `DB_*` and `PGSQL_DB_*` values take precedence over `.env.php`, so the application in the container reaches these database containers whatever `.env.php` says. Every port listens on 127.0.0.1 only and can be changed with `FLEXAGON_HTTP_PORT`, `FLEXAGON_XDEBUG_PORT`, `FLEXAGON_MYSQL_PORT` and `FLEXAGON_PGSQL_PORT`.

**More than one site** — a `public_*` directory next to `public/` is another site. It shares `application/` and needs its own `__flexagon.php`, `.htaccess`, `_entry.php`, `_prepare.php` and `_router.php` (copy them from `public/`). Run one container per site with, for example, `FLEXAGON_PUBLIC: public_admin` (see the `admin` example in `compose.yaml`). Locally the sites differ by port, but cookies do not, so open each under its own host name as well: `http://admin.localhost:8082`.

**Deployment** — step-by-step instructions are in [DEPLOY.md](DEPLOY.md).

```bash
docker build --target production -t myapp .
docker run -p 8080:8080 -e DB_HOST=... -e DB_PASSWORD=... myapp                 # public/
docker run -p 8080:8080 -e FLEXAGON_PUBLIC=public_admin -e DB_HOST=... myapp    # public_admin/
```

- Hand secrets in as environment variables through your platform's secret store. `.dockerignore` keeps `.env.php` and `.env` out of the build, so they never reach an image.
- Build one image and run it as one service per site, changing only `FLEXAGON_PUBLIC`. Each site can then have its own database account, scaling and network exposure (an admin site on the internal network only, say).
- Sessions are encrypted cookies, so more instances need no shared store. Give every instance the same `SESSION_ENCRYPTION_STRING`.
- A container's file system is gone on restart. Do not use SQLite or local uploads in production; use a managed database and object storage.
- With a read-only root file system, mount tmpfs at `/var/run/apache2` and `/tmp`.
- The number of Apache processes (`MaxRequestWorkers`) is set at start-up from the container's memory limit: (limit − 64MB) ÷ 48MB, at least 2 and at most 256 (512MB → 9, 1GB → 20, 2GB → 41). Raise `APACHE_WORKER_MEMORY_MB` if your requests use more memory, or set `APACHE_MAX_REQUEST_WORKERS` to choose the number yourself. Requests beyond it wait rather than fail. On platforms that set a per-instance concurrency, such as Cloud Run, match it to the process count. A process is replaced after 1000 connections (`APACHE_MAX_CONNECTIONS_PER_CHILD`).

### Database Configuration

Edit `application/_Config.php`.

```php
<?php
use _Flexagon\Libs\Env;
use _Flexagon\Models\DataSourceModel;

_Global::$DATA_SOURCES['default'] = new DataSourceModel(
    Env::get('DB_HOST', 'localhost'),
    Env::int('DB_PORT', 3306),
    Env::get('DB_USER'),
    Env::required('DB_PASSWORD'),
    Env::get('DB_NAME')
);
```

The values come from `.env.php` or the environment; see the next section.

### Secrets (`.env.php`)

Keep passwords and keys out of `application/`. Copy `.env.example.php` to `.env.php` in the project root and fill it in; `_Config.php` reads the values with `Env`.

```php
<?php
// .env.php — ignored by git, never under public/
return [
    'DB_USER'     => 'app',
    'DB_PASSWORD' => 's3cr3t',
    'DB_NAME'     => 'service',
    'SESSION_ENCRYPTION_STRING' => '...',
];
```

| Method | Returns |
|---|---|
| `Env::get($key, $default = null)` | The value, or `$default` |
| `Env::required($key)` | The value; throws when it is missing or empty |
| `Env::int($key, $default)` / `Env::bool($key, $default)` | Typed value; throws when it does not parse |
| `Env::has($key)` | Whether the key is set |

A value is looked up in **the process environment first, then `.env.php`, then the default**. In production you can set the same keys through PHP-FPM `env[...]`, Docker or your platform, and leave `.env.php` out. The file is plain PHP, so opcache keeps it compiled and values keep their types. It is read the first time `Env` is used, so an application that does not use it pays nothing. Define `ENV_FILE` before boot, or call `Env::load($path)`, to read another file.

Nothing is written to `putenv()` or `$_ENV`, error messages name the key but never the value, and `var_dump()` of a `DataSourceModel` shows the password as `***`.

`flexagon check` fails when `.env.php` is under `public/` or tracked by git, and warns about keys from `.env.example.php` that are not set, a password written directly into `_Config.php`, a leftover `.env` (Flexagon does not read it), and `opcache.file_cache` (which writes the compiled secrets to disk).

#### Keeping AI coding agents out

With the secrets in `.env.php`, the files under `application/` are safe for an agent to read. Block the one file in the agent itself. For Claude Code the skeleton ships `.claude/settings.json` (and `flexagon init` creates it when missing):

```json
{
  "permissions": {
    "deny": ["Read(./.env.php)", "Read(./**/.env.php)"]
  },
  "sandbox": {
    "filesystem": { "denyRead": ["./.env.php"] }
  }
}
```

`permissions.deny` stops the Read tool; `sandbox.filesystem.denyRead` also stops shell commands such as `cat .env.php`. Use both. Other agents have their own ignore settings. An agent that can run code can still print a value at runtime (`php -r 'echo Env::get(...)'`), so give it a development `.env.php` with development credentials, not production ones.

### Your First Page

```php
<?php
// public/hello.php
_Global::$SITE_TITLE = 'Hello';

TemplateLoader::show('head');
echo '<h1>Hello, Flexagon</h1>';
TemplateLoader::show('tail');
```

Open `http://127.0.0.1:9001/hello` to render the page.

### Environment Check

Verify that the project layout and runtime configuration are consistent.

```bash
php script/flexagon.php check     # works with any installation type
php vendor/bin/flexagon check     # also available with Composer installations
```

```
ok       php 8.3.33
ok       opcache.save_comments
ok       project layout
ok       bootstrap
warn     data sources  default still contains template placeholders
ok       display_errors  off
```

**It catches configuration mistakes that might otherwise fail silently.** If `opcache.save_comments` is disabled, `@encrypt` and `@db_auto_timestamp` are ignored without an error. If `_Config.php` is placed under `public/`, database credentials may be exposed over the web. The command exits with status 1 when it finds a problem, making it suitable for deployment pipelines.

See [Framework CLI](#framework-cli) for the complete list of checks.

---

## Directory Structure

```
myapp/
├── application/                 # Domain code
│   ├── _Global.php              #   Application globals (extends BaseGlobal)
│   ├── _Const.php               #   Application constants
│   ├── _Config.php              #   Base configuration, including data sources
│   ├── _Config/                 #   Stage-specific configuration (alpha · beta · production)
│   └── <Namespace>/             #   Models and DAOs
├── public/                      # ← document root
│   ├── .htaccess
│   ├── __flexagon.php           #   Front controller for all requests
│   ├── _entry.php               #   Request-start hook
│   ├── _prepare.php             #   Post-session hook
│   ├── _router.php              #   Dispatch point
│   ├── _Template/               #   Shared templates (head · tail · error404)
│   └── **/*.php                 #   Pages mapped 1:1 to URLs
├── script/                      # CLI jobs
├── composer.json
├── flexagon.php                 # Bootstrap loader
└── vendor/
    └── flexagon/framework/      # Framework core
```

**Under `application/`, namespaces map directly to directory paths.** `ExampleUser\UserDAO` → `application/ExampleUser/UserDAO.php`.

The `_Flexagon\` namespace resolves to the framework itself and normally does not need to be defined by the application.

**Expose only `public/` to the web.** `application/_Config.php` contains database credentials; if the document root points to the project root, those files may be served directly.

---

## Request Lifecycle

```
Browser
  │
  ├─ .htaccess          rewrites all .php requests to __flexagon.php
  │
  ├─ __flexagon.php ──► flexagon.php ──► Bootstrap.php
  │                                        │
  │                                        ├─ defines constants (PROJECT_ROOT, PUBLIC_ROOT, _FLEXAGON_ROOT ...)
  │                                        ├─ registers the autoloader
  │                                        ├─ loads _Const.php / _Global.php / _Config.php
  │                                        └─ parses the URL → _Global::$URL_PARAM
  │
  ├─ public/_entry.php      ① request-start hook (site title, shared headers, etc.)
  ├─ [automatic session start] ② when $SESSION_AUTO_START is true
  ├─ public/_prepare.php    ③ post-session hook (authorization checks, etc.)
  └─ public/_router.php     ④ dispatch — default implementation uses TemplateLoader::content()
                                 → executes public/<URL path>.php
```

The three hooks run at distinct stages of the request lifecycle.

| File | Stage | Purpose |
|---|---|---|
| `_entry.php` | **Before** session | Site metadata, response headers, locale |
| `_prepare.php` | **After** session | Authentication/authorization checks, shared data loading |
| `_router.php` | Dispatch | Executes the page. Replace this file when custom routing is needed |

### URL Mapping Rules

| Request URL | Executed file |
|---|---|
| `/` | `public/index.php` |
| `/hello` | `public/hello.php` |
| `/user/profile` | `public/user/profile.php` |
| `/user/` | `public/user/index.php` |
| `/user/profile?id=3` | `public/user/profile.php` |

Request paths are normalized first by `HttpUtil::normalizePath()`. It removes NUL bytes, converts backslashes to `/`, and removes empty segments, `.`, and `..`, preventing traversal to parent directories.

`TemplateLoader` then resolves the final path with `realpath()` and includes it **only after verifying that it remains inside** `public/` (or `_Template/`). Paths outside that boundary are rejected with a 404. This protection is enforced by the framework itself rather than relying solely on web-server path normalization.

The parsed result is stored in `_Global::$URL_PARAM` (`UrlParamsModel`).

```php
_Global::$URL_PARAM->filePath;       // 'user/profile'
_Global::$URL_PARAM->filePathArray;  // ['user', 'profile']
_Global::$URL_PARAM->filePathEnd;    // 'profile'
_Global::$URL_PARAM->params;         // '?id=3'
```

### Custom Routing

To dispatch requests manually instead of using file mapping, replace `public/_router.php`.

```php
<?php
// public/_router.php
$path = _Global::$URL_PARAM->filePath;

if (str_starts_with($path, 'api/')) {
    header('Content-Type: application/json');
    include_once PUBLIC_ROOT . '/api/_dispatch.php';
} else {
    TemplateLoader::content();
}
```

---

## Configuration

### `_Global`

All global configuration values are static properties of the `_Global` class, which extends `BaseGlobal`.

```php
<?php
// application/_Global.php
use _Flexagon\Base\BaseGlobal;

class _Global extends BaseGlobal {
    // Add application-specific globals here
    public static ?\Session\SessionUserModel $SESSION_USER_MODEL = null;
}
```

Key configuration options:

| Property | Default | Description |
|---|---|---|
| `$SITE_TITLE` | `'Flexagon'` | Site title |
| `$TIMEZONE` | `'Asia/Seoul'` | Passed to `date_default_timezone_set()` |
| `$DATA_SOURCES` | `[]` | Data-source map (see below) |
| `$DATA_SOURCE_ID` | `'default'` | Default data-source ID |
| `$USE_COMPOSER` | `true` | `vendor/autoload.php` auto-load |
| `$USE_OUTPUT_BUFFER` | `true` | Wrap the entire request with `ob_start()` |
| `$DB_STATEMENT_CACHE_SIZE` | `64` | Number of prepared statements cached per connection. `0` prepares every time |
| `$DB_CONNECT_FAILURE_FATAL` | `true` | Throw `_Flexagon\DB\ConnectionException` on DB connection failure (from the DAO constructor). If `false`, `connect()` returns `false` |
| `$ENABLE_EXTENSION_PHP` | `false` | If `true`, URLs must explicitly include `.php` |
| `$USE_AUTO_CREATED_AT_TIMESTAMP` | `true` | `@db_auto_timestamp insert` automatic timestamping |
| `$USE_AUTO_UPDATED_AT_TIMESTAMP` | `true` | `@db_auto_timestamp update` automatic timestamping |
| `$RUNNING_MODE` | `FLEXAGON_CONST::RUNNING_MODE_PRODUCTION` | Runtime mode. The framework does not interpret this value; applications may use it for branching |
| `$DEBUG_ON` | `false` | Debug flag for application use |
| `$DEBUG_QUERY_BREAKPOINT` | `false` | after each query `Mysql::debugQueryAfter()` call (for debugger breakpoints) |
| `$SITE_CONFIG['web']['header']` | — | HTTP headers added to every response |
| `$SESSION_AUTO_START` | `false` | Restore session automatically during bootstrap |
| `$SESSION_NAME` | `'session_data'` | Session cookie name |
| `$SESSION_DOMAIN` | `''` | Cookie domain (`.example.com`) |
| `$SESSION_COOKIE_SECURE` | `null` | Cookie Secure flag. `null` enables it automatically for HTTPS requests |
| `$SESSION_COOKIE_HTTPONLY` | `true` | Cookie HttpOnly flag |
| `$SESSION_COOKIE_SAMESITE` | `'Lax'` | `'Lax'` · `'Strict'` · `'None'`. `'None'`automatically enables Secure |
| `$SESSION_MODEL_CLASSES` | `[]` | Classes allowed in session cookies. If empty, only `BaseModel` inheritance is checked |
| `$SESSION_TIMEOUT_SECONDS` | `86400` | Session lifetime (seconds) |
| `$SESSION_REQUIRE_EXPIRY` | `false` | Reject legacy cookies without `exp`. Set to `true` after the migration period |
| `$SESSION_NOT_BEFORE` | `0` | Invalidate all sessions issued before this timestamp (stateless forced logout) |
| `$SESSION_ENCRYPTION_STRING` | `''` | Session encryption key (**10characters or more**) |
| `$CLASS_PROPERTY_ENCRYPTION_PASSPHRASE` | `''` | `@encrypt` property encryption key (**10characters or more**) |

### Data Sources

```php
new DataSourceModel(
    string $host,
    int    $port,
    string $username,
    string $password,
    string $dbName,
    ?string $charset = 'utf8mb4',
    ?bool   $usePrepareStatement = true,
    array   $pdoOptions = []
);
```

You can register multiple data sources.

```php
_Global::$DATA_SOURCES['default']   = new DataSourceModel('db-master', 3306, 'app', '****', 'service');
_Global::$DATA_SOURCES['analytics'] = new DataSourceModel('db-replica', 3306, 'ro',  '****', 'stats');
```

Each data source receives a unique ID based on `sha1(username@host/dbName)`, and `DataSourceManager` reuses connections by that ID. Multiple DAOs pointing to the same database therefore share a single connection within the request.

`pdoOptions` is passed to `new PDO()` as is. It is where values the framework does not set go: TLS, timeouts and the like. The options the driver depends on (error mode, fetch mode, emulated prepares, connection charset) are the driver's and win.

```php
// MySQL that requires TLS (RDS, Azure, PlanetScale and others)
_Global::$DATA_SOURCES['default'] = new DataSourceModel(
    Env::get('DB_HOST'), Env::int('DB_PORT', 3306), Env::get('DB_USER'), Env::get('DB_PASSWORD'), Env::get('DB_NAME'),
    pdoOptions: [PDO::MYSQL_ATTR_SSL_CA => '/etc/ssl/certs/rds-ca.pem'],
);
```

> **Without an SSL option, MySQL connects in plain text even when the server offers TLS,** and a server that requires TLS refuses the connection. With a CA, the certificate and host name are verified.
> **PostgreSQL defaults to `sslmode=prefer`:** TLS when the server offers it, but the certificate is not verified. To verify it, set the environment variables `PGSSLMODE=verify-full` and `PGSSLROOTCERT=/path/ca.pem` (read by libpq).

### Stage-specific Configuration

Place stage-specific configuration in `application/_Config/<stage>/_Config.php` and select it from the CLI with the `runtimeStage` argument.

```bash
php script/batch.php runtimeStage=production
```

The default stage directories are `alpha`, `beta`, and `production`. A Docker image built with the target of the same name (`--target production` and so on) gets that stage directory's files copied into `application/` (see [Docker](#docker)).

---

## Models and DAOs

### Models

Extending `BaseModel` provides array/JSON conversion, encryption/decryption, and automatic timestamps. Declare properties as `private` with getters and setters; mapping is based on **method names**.

```php
<?php
namespace ExampleUser;

use _Flexagon\Base\BaseModel;

class UserModel extends BaseModel {
    private ?int    $id       = null;
    private string  $name;
    private ?string $address  = null;

    public function getId(): ?int          { return $this->id; }
    public function setId(?int $id): void  { $this->id = $id; }

    public function getName(): string             { return $this->name; }
    public function setName(string $name): void   { $this->name = $name; }

    public function getAddress(): ?string             { return $this->address; }
    public function setAddress(?string $a): void      { $this->address = $a; }
}
```

Methods provided by `BaseModel`:

| Method | Description |
|---|---|
| `getArray(bool $containsObject = true, bool $forceAll = false)` | Convert getters to an associative array |
| `setByArray(array $data)` | Populate through setters; both snake_case and camelCase keys are accepted |
| `getJson(int $flags = JSON_UNESCAPED_UNICODE)` | JSON serialization (nested objects are flattened to arrays) |
| `encrypt()` / `decrypt()` | `@encrypt` Encrypt/decrypt annotated properties |
| `getCreatedAt()` / `getUpdatedAt()` | Unix timestamp |
| `getCreatedAtDatetimeString()` | `Y-m-d H:i:s` string |

Because `BaseModel` implements `JsonSerializable`, `json_encode($model)` works directly.

`setByArray()` uses reflection to reconcile common type mismatches. Empty strings become `null` for nullable properties, and scalar values are converted to matching cases for backed-enum properties. This makes it practical to pass form input directly into a model.

### DAOs

Extend `BaseMySqlDAO` and specify `$tableName` to get the core CRUD operations.

The framework wraps `$tableName` in backticks (MySQL) or brackets (SQL Server), so a reserved word such as `'order'` works as is. A name you have already quoted is not wrapped again: `'audit.users'`, `'[audit].[users]'` and `` '`app`.`users`' `` all produce the same statement.

```php
<?php
namespace ExampleUser;

use _Flexagon\Base\BaseMySqlDAO;

class UserDAO extends BaseMySqlDAO {
    protected string $tableName = 'users';

    public function insert(UserModel $user): int|false { return $this->_insert($user); }
    public function update(UserModel $user): bool      { return $this->_update($user); }
    public function delete(UserModel $user): bool      { return $this->_delete($user); }

    public function findById(int $id): ?UserModel {
        return $this->_select(['id' => $id], new UserModel());
    }

    /** @return UserModel[] */
    public function findByCity(string $city, int $page = 1, int $perPage = 20): array {
        return $this->_selectList(
            new UserModel(), $page, $perPage,
            '`address` = :CITY', ['CITY' => $city],
            '`created_at` DESC'
        );
    }

    public function countByCity(string $city): int {
        return $this->_selectTotalCount('`address` = :CITY', ['CITY' => $city]);
    }
}
```

The CRUD methods are `protected` by design. Each DAO explicitly chooses which operations to expose, keeping its public interface narrow and aligned with the domain.

| Method | Description |
|---|---|
| `_insert($modelOrArray)` | INSERT. Returns the auto-increment value (`false` on failure) |
| `_update($modelOrArray)` | UPDATE by primary key |
| `_updateByQuery($modelOrArray, $whereSql, $params)` | UPDATE with a custom condition |
| `_select($modelOrArray, ?object $vo)` | Fetch one row; returns an object when `$vo` is provided, otherwise an array |
| `_selectByQuery($whereSql, $params, ?object $vo)` | Fetch one row with a custom condition |
| `_selectList(?object $vo, $page, $perPage, $whereSql, $params, $orderSql)` | Fetch a paginated list |
| `_selectTotalCount($whereSql, $params)` | Count matching rows |
| `_delete($modelOrArray)` | DELETE by primary key |
| `_deleteByQuery($whereSql, $params)` | DELETE with a custom condition |
| `_insertAll($modelList, $chunkSize = 500)` | Bulk INSERT using one statement per chunk; returns the number of inserted rows |
| `_truncate()` | TRUNCATE |

For PostgreSQL extend `BasePgSqlDAO`, for SQLite `BaseSqliteDAO`, and for SQL Server `BaseMsSqlDAO`; all provide **the same method surface**. Every DAO implementation extends `BaseSqlDAO`, where CRUD operations, schema caching, and transaction handling are shared. Subclasses contain only dialect-specific behavior: identifier quoting (`` `name` `` / `"name"` / `[name]`), schema inspection (`DESCRIBE` / `information_schema` / `PRAGMA table_info`), and pagination (`LIMIT` / `LIMIT·OFFSET` / `OFFSET·FETCH`).

> **PostgreSQL:** a double-quoted identifier is case-sensitive, and the framework quotes `$tableName`. Write it as the table is stored, normally lower case (`'users'`, not `'Users'`). A bare name resolves through `search_path`; use `'audit.users'` for another schema.

> **SQLite:** the data source is a file, created with `DataSourceModel::file()`.
>
> ```php
> _Global::$DATA_SOURCES['default'] = DataSourceModel::file(PROJECT_ROOT . '/var/app.sqlite');
> ```
>
> The directory must exist; a wrong path fails to connect instead of creating an empty database. `INTEGER PRIMARY KEY` is the auto-increment column, `_truncate()` runs `DELETE`, and foreign keys are enforced. SQLite locks the whole file for writes, so for a site with concurrent writers turn on WAL once (`PRAGMA journal_mode = WAL`).

When you need direct SQL, use `$this->db` (a `Mysql` instance).

```php
public function findTopSpenders(int $limit): array {
    $this->db->executeQuery(
        'SELECT u.* FROM users u JOIN orders o ON o.user_id = u.id
         GROUP BY u.id ORDER BY SUM(o.amount) DESC LIMIT :LIMIT',
        ['LIMIT' => $limit]
    );
    return $this->db->getAllResultAsObject(new UserModel());
}
```

### Column ↔ Property Mapping

Database `snake_case` columns are mapped automatically to PHP `camelCase` properties.

| DB column | Getter / Setter | Property |
|---|---|---|
| `id` | `getId()` / `setId()` | `$id` |
| `user_name` | `getUserName()` / `setUserName()` | `$userName` |
| `created_at` | `getCreatedAt()` / `setCreatedAt()` | `$createdAt` |

### Parameter Binding

Queries use PDO prepared statements with named placeholders. Framework-generated queries use the **uppercase column name** as the placeholder (`user_name` → `:USER_NAME`).

If the same placeholder appears multiple times in a query, `SqlUtil::expandQueryParams()` automatically expands it into distinct parameters, avoiding PDO's duplicate-binding limitation.

```php
$this->_selectList(new UserModel(), 1, 20,
    '`name` LIKE :KEYWORD OR `address` LIKE :KEYWORD',   // may appear more than once
    ['KEYWORD' => "%{$keyword}%"]
);
```

### Debugging

```php
echo $userDAO->debugQuery();   // actual SQL with parameters substituted
echo $userDAO->getError();     // last error message
$userDAO->debugDumpParams();   // PDOStatement::debugDumpParams()
```

When `_Global::$DEBUG_QUERY_BREAKPOINT` is enabled, `Mysql::debugQueryAfter()` is called after every query. The method is intentionally empty, making it a convenient IDE breakpoint for inspecting executed queries.

---

## Annotations

Flexagon reads PHPDoc tags at runtime to modify behavior (`PhpDocUtil`).

The canonical notation is **snake_case**.

```php
/** @encrypt */
/** @db_auto_timestamp insert|update */
/** @exclude_from_get_array */
```

**Tag names are case-insensitive and separator-insensitive.** The following forms are equivalent.

```php
@db_auto_timestamp    @DbAutoTimestamp    @DB_AUTO_TIMESTAMP    @dbautotimestamp
```

Tag **values** are case-insensitive, but separators remain significant (`insert` = `INSERT`, while `my_value` ≠ `myvalue`).

Both single-line docblocks (`/** @db_auto_timestamp insert */`) and multiline docblocks are supported.

### `@db_auto_timestamp`

Automatically fills Unix timestamps on INSERT and UPDATE. This is already applied to `createdAt` and `updatedAt` in `BaseModel`.

```php
/**
 * @var int|null
 * @db_auto_timestamp insert
 */
protected ?int $createdAt = null;

/**
 * @var int|null
 * @db_auto_timestamp insert|update
 */
protected ?int $updatedAt = null;
```

### `@encrypt`

Automatically encrypts and decrypts properties with AES-256-CBC. Values are encrypted before being stored in the database and decrypted when query results are mapped back to objects.

Ciphertext uses the format `base64(version || IV || HMAC-SHA256 || ciphertext)`. The IV is a synthetic IV derived from the plaintext with a keyed HMAC, so identical plaintext always produces identical ciphertext and an encrypted column can be matched with `WHERE col = :COL` (in exchange, rows with equal values are recognisable as equal in the database). Before decryption, the HMAC is verified with `hash_equals()` to reject tampered data. Encryption and authentication keys are derived separately from the passphrase using `hash_hkdf()`.

```php
/**
 * @var string
 * @encrypt
 */
private string $residentNumber = '';
```

`_Global::$CLASS_PROPERTY_ENCRYPTION_PASSPHRASE` must be at least **10 characters** long or an exception is thrown. Make sure the database column is large enough to hold the ciphertext.

### `@exclude_from_get_array`

Excludes a getter from `getArray()` / `getJson()` output. Use it for values such as password hashes that should not be serialized.

```php
/**
 * @exclude_from_get_array
 */
public function getPasswordHash(): string { return $this->passwordHash; }
```

Calling `getArray(forceAll: true)` ignores exclusions and returns all values. DAOs use this mode internally when writing to the database.

---

See **[ANNOTATIONS.md](ANNOTATIONS.md)** for the complete list, constraints, and instructions for defining custom annotations.

---

## Transactions and Multiple Data Sources

### Single DAO

```php
$userDAO->startTransaction();
try {
    $userDAO->insert($user);
    $userDAO->commit();
} catch (Throwable $e) {
    $userDAO->rollback();
    throw $e;
}
```

### Transactions Across Multiple DAOs

Start a global transaction with `DataSourceManager`, and every data source used afterward automatically participates in the transaction.

```php
use _Flexagon\Libs\DataSourceManager;

DataSourceManager::startTransaction();
try {
    $userDAO->insert($user);
    $orderDAO->insert($order);
    $pointDAO->update($point);
    DataSourceManager::commit();
} catch (Throwable $e) {
    DataSourceManager::rollback();
    throw $e;
}
```

Commits and rollbacks are performed in the **reverse order** in which connections were registered.

### Assigning a Data Source to a DAO

Override the `DATA_SOURCE_ID` constant.

```php
class StatsDAO extends BaseMySqlDAO {
    const DATA_SOURCE_ID = 'analytics';   // _Global::$DATA_SOURCES['analytics']
    protected string $tableName = 'daily_stats';
}
```

### Connection Failures

When a data source cannot be reached, the DAO constructor throws `_Flexagon\DB\ConnectionException` (with the default `_Global::$DB_CONNECT_FAILURE_FATAL = true`). Left uncaught, the request ends with a 500, or exit code 255 on the command line. Catch it to choose the response yourself.

```php
// public/_entry.php
set_exception_handler(function (Throwable $e) {
    if ( $e instanceof \_Flexagon\DB\ConnectionException ) {
        http_response_code(503);
        TemplateLoader::show('maintenance');
        return;
    }
    throw $e;
});
```

The message names only the data source (`$e->getDataSourceId()`, the key in `_Global::$DATA_SOURCES`). The driver message, which includes host and account, goes to the error log; the original `PDOException` is available from `getPrevious()`. Keep `display_errors` off in production: an uncaught exception printed on screen includes the previous exception too.

Set `$DB_CONNECT_FAILURE_FATAL = false` to have `connect()` return `false` instead of throwing.

---

## Sessions

Flexagon sessions serialize model objects into **encrypted cookies** rather than server-side files. Because there is no shared session store, horizontally scaling across multiple web servers requires no additional session-storage configuration.

### Configuration

```php
// application/_Config.php
_Global::$SESSION_AUTO_START      = true;
_Global::$SESSION_ENCRYPTION_STRING = Env::required('SESSION_ENCRYPTION_STRING');   // from .env.php
_Global::$SESSION_DOMAIN          = '.example.com';
_Global::$SESSION_TIMEOUT_SECONDS = 86400;

// Cookie security attributes — the defaults are already secure and usually do not need to be changed.
_Global::$SESSION_COOKIE_SECURE   = null;    // null = automatically enabled for HTTPS requests
_Global::$SESSION_COOKIE_HTTPONLY = true;    // prevent JavaScript from accessing the session cookie
_Global::$SESSION_COOKIE_SAMESITE = 'Lax';
```

Session cookies carry authentication state, so `HttpOnly` and `SameSite=Lax` are enabled by default, and `Secure` is added automatically for HTTPS requests. HTTPS detection checks `$_SERVER['HTTPS']`, port 443, and then `X-Forwarded-Proto`.

### Session Model and DAO

```php
<?php
namespace Session;

use _Flexagon\Base\BaseModel;

class SessionUserModel extends BaseModel {
    private string  $role     = 'USER';
    private ?string $username = '';
    private ?string $email    = '';
    // 게터 / 세터 ...
}
```

```php
<?php
namespace Session;

use _Flexagon\Base\BaseSessionDAO;

class SessionDAO extends BaseSessionDAO {}
```

### Usage

```php
// 로그인
$sessionUser = new SessionUserModel();
$sessionUser->setUsername($user->getUsername());
$sessionUser->setRole('ADMIN');

$sessionDAO = new SessionDAO();
$sessionDAO->makeSession($sessionUser);

// 로그아웃
$sessionDAO->cleanSession();
```

When `$SESSION_AUTO_START` is enabled, the session is restored during bootstrap and exposed in two locations.

```php
_Global::$SESSION_MODEL;        // always available here
_Global::$SESSION_USER_MODEL;   // class-name-based global (see below)
```

The second form is derived by converting the model class name to UPPER_SNAKE_CASE (`SessionUserModel` → `SESSION_USER_MODEL`). To access it with a type hint, declare the corresponding static property in `_Global` **in advance**.

```php
class _Global extends BaseGlobal {
    public static ?\Session\SessionUserModel $SESSION_USER_MODEL = null;
}
```

A common pattern is to perform authorization checks in `_prepare.php`.

```php
<?php
// public/_prepare.php
if (str_starts_with(_Global::$URL_PARAM->filePath, 'admin/')) {
    if (_Global::$SESSION_USER_MODEL?->getRole() !== 'ADMIN') {
        \_Flexagon\Libs\HtmlUtil::redirectPage('/login');
    }
}
```

> **Note:** A session-model property marked with `@encrypt` is encrypted twice inside the cookie. Because the entire session cookie is already encrypted with `$SESSION_ENCRYPTION_STRING`, the additional annotation is usually unnecessary.

---

## Security

The line between what the framework protects against and what the application is responsible for is clearly drawn. If you find a security vulnerability, do not open a public issue; report it to **young@phpk.org** (with `[SECURITY]` in the subject).

### What the Framework Provides

| Item | Description |
|---|---|
| SQL injection | All DAO queries use PDO prepared statements |
| Path traversal | Router include paths cannot escape `public/` |
| Session integrity | AES-256-CBC + HMAC-SHA256, expiration verified **server-side** |
| Session cookies | `HttpOnly`·`SameSite` enabled by default; `Secure` automatic |
| Column encryption | `@encrypt` — synthetic IV (exact-match searchable), HMAC verification, HKDF key derivation |
| Forced logout | `$SESSION_NOT_BEFORE`invalidates all sessions (stateless) |

### Application Responsibilities

**These features are intentionally not provided by the framework.** Do not assume Flexagon handles them automatically.

```php
// CSRF — no token mechanism is provided. Validate state-changing requests yourself.
// Output escaping — templates do not provide automatic escaping.
echo htmlspecialchars($user->getName(), ENT_QUOTES, 'UTF-8');

// Mass assignment — passing $_POST directly may overwrite fields such as id and role.
$user->setByArray(array_intersect_key($_POST, array_flip(['name', 'email'])));

// Serialization — getArray()/getJson() include all getters by default.
/** @exclude_from_get_array */
public function getPasswordHash(): string { ... }
```

The application is also responsible for validating redirect targets, preventing SSRF, sanitizing HTML, and setting appropriate security headers.

> The `HtmlUtil::stripSpecificTag()` family is regex-based and **is not an XSS filter**. These methods are convenience helpers for cleaning up tags only.

---

## Templates and Assets

### TemplateLoader

```php
TemplateLoader::show('head', ['title' => 'Product List']);   // public/_Template/head.php
TemplateLoader::content();                                   // execute the page mapped to the URL
TemplateLoader::entryDir('_layout');                         // _layout.php in the current URL directory
TemplateLoader::entryRoot('_footer');                        // public/_footer.php
```

The supplied array is passed through `extract()` and exposed as local variables inside the template.

```php
<!-- public/_Template/head.php -->
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="utf-8">
    <title><?= htmlspecialchars($title ?? _Global::$SITE_TITLE) ?></title>
    <?php \_Flexagon\Libs\AssetLoader::printPreloads('    ') ?>
    <?php \_Flexagon\Libs\AssetLoader::printStyles('    ') ?>
</head>
<body>
```

### AssetLoader

Collect CSS and JavaScript assets and render them together at the desired location. A version query string can be added for cache invalidation.

```php
use _Flexagon\Libs\AssetLoader;

AssetLoader::setVersion('3.4.13');          // append ?_=3.4.13 to all asset URLs
AssetLoader::setAssetRootPath('/assets/');

AssetLoader::setCss('main.css');                        // /assets/css/main.css (includes preload)
AssetLoader::setJs('app.js', isModule: true);           // /assets/js/app.js
AssetLoader::setJs('https://cdn.example.com/lib.js');   // external URLs remain unchanged

echo AssetLoader::getImageHtml('logo.png', 120, 40, 'Logo');
echo AssetLoader::getAssetUrl('fonts/pretendard.woff2');
```

- Relative paths are prefixed with `assetRootPath + dirPath`; URLs beginning with `http://`, `https://`, or `//` are left unchanged.
- Preload hints are rendered separately with `printPreloads()`. Place them in `<head>` while leaving script tags at the `printScripts()` location (typically just before `</body>`) so scripts can be fetched while the document body is being parsed.
- Preload hints are not added to absolute URLs because a mismatched `crossorigin` setting may cause the browser to download the resource twice.
- Each `print*()` method renders one asset type, and the template controls placement: `printPreloads()` and `printStyles()` belong in `<head>`, while `printScripts()` typically goes just before `</body>`.
- Use `unsetJs('analytics.js')` to remove a previously registered script.

---

## Utility Libraries

All utilities use static methods and have no external dependencies. Their namespace is `_Flexagon\Libs`.

| Class | Key Features |
|---|---|
| `StringUtil` | case conversion, UTF-8 cleanup, hex encoding, random string generation |
| `ArrayUtil` | camelCase key conversion, array diff, nested-array key lookup |
| `ValidUtil` | email, integer, float, alphanumeric, and ID validation |
| `CryptoUtil` | AES-256-CBC encryption/decryption (deterministic `encryptString()` for columns; random-IV `encrypt()` for strings / arrays) |
| `FileUtil` | directory traversal, recursive creation, extension detection |
| `HttpUtil` | URL parsing, query-string parsing, request-path resolution |
| `NetUtil` | GET/POST HTTP client, JSON response parsing, file uploads |
| `HtmlUtil` | redirects, HTML tag/attribute removal, image URL extraction |
| `TimeDateUtil` | timestamp conversion, timezone offsets, relative time formatting |
| `SqlUtil` | parameter normalization/expansion, SQL escaping, SELECT → COUNT conversion |
| `ClassUtil` | class name, path, property, and caller inspection |
| `PhpDocUtil` | PHPDoc tag parsing (basis of annotation support) |
| `AssetLoader` | CSS/JS management |
| `TemplateLoader` | template loading |
| `DataSourceManager` | connection reuse and global transactions |
| `Env` | settings and secrets from the environment and `.env.php` |

### Global Helper Functions

The three functions defined by `Libs/_Util.php` are available globally without a namespace.

```php
_echo('Hello, {name}', ['name' => $user->getName()]);   // substitute and output
$msg = _t('{count} results found', ['count' => 42]);    // substitute and return
```

`___()` is an alias of `_t()`. Placeholders are substituted in a single pass, so a value that itself contains `{name}` is not substituted again.

### Translation (I18n)

The helpers translate a message through the translator registered with `_Flexagon\I18n\Translator` before substituting placeholders. **If no translator is registered, the original message is used as is.**

A translator implements a single method.

```php
namespace _Flexagon\I18n;

interface TranslatorInterface
{
    public function translate(string $message): string;
}
```

Register it once, early in the request (`public/_entry.php` or `application/_Config.php`).

```php
// public/_entry.php
use _Flexagon\I18n\Translator;

setlocale(LC_MESSAGES, 'ko_KR.UTF-8');
bindtextdomain('messages', LOCALE_ROOT);
textdomain('messages');

Translator::setTranslator(new \I18n\GettextTranslator());
```

The skeleton ships three example adapters in `application/I18n/`.

| Class | Translates with | Requires |
|---|---|---|
| `GettextTranslator` | `gettext()` | `ext-gettext` |
| `MoTranslator` | `__()` | A library that defines `__()` (e.g. a `.mo` reader) |
| `SymfonyTranslator` | `trans()` | `symfony/translation` |

```php
Translator::setTranslator(new \I18n\SymfonyTranslator($symfonyTranslator));
```

`LOCALE_ROOT` defaults to `PROJECT_ROOT . '/locale'`. To change it, `define()` it before the framework boots.

Keep these points in mind:

- **Output is not escaped.** `_echo()` prints the translated, substituted string as is. Escape user-supplied values with `htmlspecialchars()` before passing them in, and treat translation catalogs as trusted HTML sources.
- **The translator is static, per process.** That fits the PHP-FPM model, where every request starts clean. In long-running workers (Swoole, RoadRunner, FrankenPHP worker mode), re-register the translator for every request. `setlocale()` is process-wide and not safe across threads.
- **The adapter determines the cost.** The framework adds about 0.3 µs per call. gettext caches `.mo` files per process (restart PHP-FPM after updating them); some `.mo` libraries parse the file on every request; Symfony Translation reloads catalogs on each request unless `cache_dir` is set.

### Enum Helpers

Add the `EnumSupporter` trait to a backed enum to enable convenience methods.

```php
use _Flexagon\Supporters\EnumSupporter;

enum UserRole: string {
    use EnumSupporter;

    case ADMIN = 'ADMIN';
    case USER  = 'USER';
}

UserRole::keys();            // ['ADMIN', 'USER']
UserRole::values();          // ['ADMIN', 'USER']
UserRole::toArray();         // ['ADMIN' => 'ADMIN', 'USER' => 'USER']
UserRole::toCommaString();   // 'ADMIN,USER'
```

When generating DDL for an ENUM column, use `toQuotedCommaString()`. It quotes each value and escapes embedded quotes by doubling them.

```php
UserRole::toQuotedCommaString();      // "'ADMIN','USER'"
UserRole::toQuotedCommaString('"');   // '"ADMIN","USER"'

// Safe even when values contain quotes or commas
// case A = "it's";  case B = 'a,b';
//   toCommaString()        → it's,a,b          (breaks DDL)
//   toQuotedCommaString()  → 'it''s','a,b'
```

For pure enums without backing values, `keys()` and `toCommaString()` return case names, while `values()` and `toArray()` return `null` values.

Enum-typed properties are also handled automatically by DAO mapping. Scalar database values are converted to matching enum cases when models are hydrated, and `->value` is bound when values are stored.

---

## CLI Scripts

Place batch jobs in the `script/` directory.

```php
<?php
// script/cleanup.php
require_once '__flexagon.php';

$deleted = (new \ExampleUser\UserDAO())->deleteExpired();
echo "Deleted: {$deleted} rows\n";
```

```bash
php script/cleanup.php runtimeStage=production days=30
```

Arguments in `key=value` form are parsed into both `$_PARAMS` and `$_REQUEST`. `runtimeStage` is reserved and selects the configuration directory to load.

When running from the CLI, `FLEXAGON_ENV::$_RUNTIME_ENV` is set to `RUNTIME_ENV_SCRIPT`, bypassing the web request pipeline entirely, including sessions, routing, and output buffering.

### Framework CLI

The framework itself provides two commands.

```bash
php script/flexagon.php init [--path=DIR] [--force]
php script/flexagon.php check [--path=DIR]
```

| Invocation | Supported installation types |
|---|---|
| `php script/flexagon.php` | All (Composer · PHAR · source) |
| `php vendor/bin/flexagon` | Composer installation |

> A PHAR cannot be passed to the PHP CLI as a `phar://...` script path, so `script/flexagon.php` acts as the entry point. The PHAR does not contain templates for `init`, so only `check` is available in that installation mode.

#### `init`

Creates the 31 files that make up the project structure. If you started with `composer create-project flexagon/skeleton`, these files already exist. This command is primarily useful when **adding `flexagon/framework` to an existing project with `composer require`**.

**Existing files are left untouched.** You can also run the command after an upgrade to add only newly introduced structure files.

```
create   script/flexagon.php
keep     public/index.php
1 created, 22 kept, 0 failed
```

Use `--force` if you need to overwrite existing files. Be careful: modified files will be replaced with the template versions.

#### `check`

Checks that the project layout and runtime configuration are consistent and returns **exit code 1 when a problem is found**, making it suitable for deployment pipelines.

| Item | Check | Result |
|---|---|---|
| `php` | 8.3 or later | Error |
| `ext-json` · `ext-openssl` · `ext-pdo` | Loaded | Error |
| `opcache.save_comments` | Enabled | Error |
| `project layout` | `flexagon.php` · `application/_Global.php` · `public/__flexagon.php` · `public/_router.php` | Error |
| `config placement` | `_Config.php` and `application/` are not exposed under `public/` or any `public_*` | Error |
| `bootstrap` | Framework boots successfully | Error |
| `session key` | `$SESSION_ENCRYPTION_STRING` length when `$SESSION_AUTO_START` is enabled | Error |
| `data sources` | Configured; no template placeholders remain | Warning |
| `display_errors` | Enabled in production mode | Warning |
| `secrets placement` | `.env.php` / `.env` under `public/` or any `public_*` | Error |
| `.env.php` | Returns an array; not tracked by git | Error |
| `settings` | Keys in `.env.example.php` that are not set | Warning |
| `secrets in config` | A data source password written into `_Config.php` | Warning |
| `.env` | Present but not read by Flexagon | Warning |
| `opcache.file_cache` | On while `.env.php` exists (compiled secrets on disk) | Warning |

The following checks are especially important because these issues can otherwise **fail silently**.

- If `opcache.save_comments` is disabled, `@encrypt`, `@db_auto_timestamp`, and `@exclude_from_get_array` are all ignored. A column that should be encrypted may be stored in plaintext without any exception.
- If `_Config.php` is placed under `public/`, database credentials may be served directly if PHP handling is unavailable or misconfigured.
- If a data source still contains the default `username` / `dbname` placeholders, the connection simply fails.

```
$ php script/flexagon.php check

  ok       php 8.3.33
  ok       ext-json
  ok       opcache.save_comments
  ok       project layout
  ok       bootstrap
  warn     data sources  default still contains template placeholders
  ok       session  auto start off
  ok       display_errors  off

  0 problem(s), 1 warning(s)
```

## License

[MIT License](LICENSE)

Copyright (c) 2010-2026 Younghwan Yong