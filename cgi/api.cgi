#!/usr/local/cpanel/3rdparty/bin/perl
#ACLS:all

package Troglodyne::CGI::API;

use strict;
use warnings;

use Cpanel::LoadModule::Custom ();
use JSON::XS                   ();

run() unless caller();

sub run {
    # Load up CGI processing modules
    Cpanel::LoadModule::Custom::load_perl_module("Troglodyne::CGI");

    # Process the args
    my $args = Troglodyne::CGI::get_args();

    # Get back the datastruct from the called module.
    my $ret = {
        'metadata' => {
            'input_args' => $args,
        },
        'data' => {},
        'result' => 1,
    };

    # Emit the JSON
    print "Content-type: application/json\r\n\r\n";
    print JSON::XS::encode_json($ret);
    exit;
}

1;
