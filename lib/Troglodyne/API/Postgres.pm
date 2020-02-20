package Troglodyne::API::Postgres;

use strict;
use warnings;

sub get_server_version {
    require Cpanel::PostgresUtils;
    my @ver_arr = ( Cpanel::PostgresUtils::get_version() );
    return { 'version' => { 'major' => $ver_arr[0], 'minor' => $ver_arr[1] } };
}

1;
