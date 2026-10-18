<?php
/*
 * Copy to .env.php and fill in. .env.php holds this machine's secrets: it is
 * ignored by git and must stay out of public/.
 *
 * A variable set in the server's environment (PHP-FPM env[], Docker, a PaaS)
 * wins over the same key here, so production can leave this file out.
 *
 * Values keep their PHP type: 3306 is an int, false is a bool.
 */
return [
    'DB_HOST'     => 'localhost',
    'DB_PORT'     => 3306,
    'DB_USER'     => '',
    'DB_PASSWORD' => '',
    'DB_NAME'     => '',

    // At least 10 characters each. Generate with: php -r "echo bin2hex(random_bytes(32));"
    'SESSION_ENCRYPTION_STRING'            => '',
    'CLASS_PROPERTY_ENCRYPTION_PASSPHRASE' => '',
];
