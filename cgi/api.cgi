#!/usr/local/cpanel/3rdparty/bin/perl
#ACLS:all

package Troglodyne::CGI::API;

use strict;
use warnings;

use Cpanel::LoadModule::Custom ();
use JSON::XS                   ();

run() unless caller();
 
sub run {
    # Process the args

    # Get back the datastruct from the called module.

    # Emit the JSON
    print "Content-type: application/json\r\n\r\n";
    print JSON::XS::encode_json($ret);
    exit;
}

1;
