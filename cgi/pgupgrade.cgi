#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:better_postgres:PostgreSQL Upgrade:troglophant.png
#ACLS:all

package Troglodyne::CGI::PgUpgrade;

use strict;
use warnings;

use Cpanel::Template           ();
use Cpanel::LoadModule::Custom ();
 
run() unless caller();
 
sub run {
    Cpanel::LoadModule::Custom::load_perl_module("Troglodyne::CGI");
    my $args = Troglodyne::CGI::get_args();
    my $tmpl = 'pgupgrade';
    if( $args->{'version'} ) {
        $tmpl = 'pginstall';
    }

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
