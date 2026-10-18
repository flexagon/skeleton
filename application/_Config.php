<?php

use _Flexagon\Libs\Env;
use _Flexagon\Models\DataSourceModel;

/*
 * Secrets do not go in this file. Put them in .env.php at the project root
 * (copy .env.example.php) or in the server's environment, and read them here
 * with Env. Env::get() falls back to the second argument when the key is set
 * nowhere; Env::required() stops instead.
 *
 * _Global::$DATA_SOURCES[ID] = new DataSourceModel(host, port, username, password, dbName);
 *
 * A database that requires TLS takes PDO options as they are, for example
 * pdoOptions: [PDO::MYSQL_ATTR_SSL_CA => Env::get('DB_SSL_CA')]
 */
_Global::$DATA_SOURCES['default'] = new DataSourceModel(
    Env::get('DB_HOST', 'localhost'),
    Env::int('DB_PORT', 3306),
    Env::get('DB_USER', 'username'),
    Env::get('DB_PASSWORD', ''),
    Env::get('DB_NAME', 'dbname')
);

/*
 * More data sources work the same way, each with its own keys. compose.yaml
 * sets these for its PostgreSQL container once its PostgreSQL parts are
 * uncommented (DAOs on it extend BasePgSqlDAO):
 *
 * _Global::$DATA_SOURCES['pgsql'] = new DataSourceModel(
 *     Env::get('PGSQL_DB_HOST'), Env::int('PGSQL_DB_PORT', 5432),
 *     Env::get('PGSQL_DB_USER'), Env::get('PGSQL_DB_PASSWORD'), Env::get('PGSQL_DB_NAME')
 * );
 */

_Global::$SESSION_AUTO_START = false;
_Global::$SESSION_ENCRYPTION_STRING = Env::get('SESSION_ENCRYPTION_STRING', '');
_Global::$CLASS_PROPERTY_ENCRYPTION_PASSPHRASE = Env::get('CLASS_PROPERTY_ENCRYPTION_PASSPHRASE', '');
