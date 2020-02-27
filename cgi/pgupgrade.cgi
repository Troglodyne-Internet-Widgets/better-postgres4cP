#!/usr/local/cpanel/3rdparty/bin/perl
package Troglodyne::CGI::PgUpgrade;

use strict;
use warnings;

use Cpanel::LoadModule::Custom ();

run() unless caller();

sub run {
    Cpanel::LoadModule::Custom::load_perl_module("Troglodyne::CGI");

    print "Content-type: text/html\r\n\r\n";
    Troglodyne::CGI::render_cached_or_process_template(
        'whostmgr',
        {
            'troglodyne_do_static_render' => 1,
            'template_file'               => "troglodyne/pgupgrade.tmpl",
            'print'                       => 1,
        },
    );

    exit;
}

1;
