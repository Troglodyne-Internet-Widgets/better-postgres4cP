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

    # XXX Validation plz

    # Load route code
    my $namespace = "Troglodyne::API::$args->{'module'}";
    my ( $loaded, $err, $coderef );
    {
        local $@;
        $loaded = eval {
            Cpanel::LoadModule::Custom::load_perl_module($namespace);
        };
        $err = $@;
        $coderef = $namespace->can($args->{'function'});
    }

    # Get back the datastruct from the called module.
    # Yeah, yeah, I know. String eval. XXX
    my $ret = {
        'metadata' => {
            'input_args' => $args,
        },
    };
    if( $loaded && $coderef ) {
        my $data = $coderef->();
        $ret->{'data'} = $data;
        $ret->{'result'} = 1;
    } elsif( !$coderef ) {
        $ret->{'error'} = "No such function '$args->{'function'}' in $namespace";
        $ret->{'result'} = 0;
    } else {
        $ret->{'error'} = $err;
        $ret->{'result'} = 0;
    }

    # Emit the JSON
    print "Content-type: application/json\r\n\r\n";
    print JSON::XS::encode_json($ret);
    exit;
}

1;
