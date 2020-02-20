#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:better_postgres:PostgreSQL Upgrade:troglophant.png
#ACLS:all

package Troglodyne::CGI::PgUpgrade;

use strict;
use warnings;

use Cpanel::Template ();
 
run() unless caller();
 
sub run {
    print "Content-type: text/html\r\n\r\n";
    Cpanel::Template::process_template(
        'whostmgr',
        {
            'template_file' => 'troglodyne/pgupgrade.tmpl',
            'print'         => 1,
        }
    );
    exit;
}

1;
