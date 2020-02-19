#!/usr/local/cpanel/3rdparty/bin/perl
package Troglodyne::CGI::PgUpgrade;

# TODO move to lib/ and just symlink it into cgi? lol
use strict;
use warnings;

use Cpanel::Template::Simple ();
 
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
