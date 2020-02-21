package Troglodyne::CpPostgreSQL;

use strict;
use warnings;

our %REPO_RPM_URLS = (
    '8' => 'https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm',
    '7' => 'https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm',
    '6' => 'https://download.postgresql.org/pub/repos/yum/reporpms/EL-6-x86_64/pgdg-redhat-repo-latest.noarch.rpm',
);

# Repository entries will look like "pgdg$VERSION" -- ex. pgdg95
our $REPO_PREFIX = 'pgdg';
our $PKG_PREFIX = 'postgresql';
our $MINIMUM_SUPPORTED_VERSION = '9.5';

# Times are in seconds since epoch, as that allows easier localization.
our %SUPPORTED_VERSIONS_MAP = (
    '9.5' => { 'release' => 1452146400, 'EOL' => 1613023200 },
    '9.6' => { 'release' => 1475125200, 'EOL' => 1636610400 },
    '10'  => { 'release' => 1507179600, 'EOL' => 1668060000 },
    '11'  => { 'release' => 1539838800, 'EOL' => 1699509600 },
    '12'  => { 'release' => 1570078800, 'EOL' => 1731564000 },
);

# The BS that cPanel will be installing with /scripts/installpostgres
our %CP_UNSUPPORTED_VERSIONS_MAP = (
    '9.2' => { 'release' => 1347253200, 'EOL' => 1510207200 }, # Cent 7
    '8.4' => { 'release' => 1246424400, 'EOL' => 1406178000 }, # Cent 6
);

1;
