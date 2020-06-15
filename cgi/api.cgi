#!/usr/local/cpanel/3rdparty/bin/perl
#ACLS:all

package Troglodyne::CGI::API;

use strict;
use warnings;

use Cpanel::LoadModule::Custom ();
use JSON::XS                   ();

exit run() unless caller();

sub run {
    # Load up CGI processing modules
    Cpanel::LoadModule::Custom::load_perl_module("Troglodyne::CGI");

    my $ret = {
        'metadata' => {
            'input_args' => $args,
        },
    };

    # Process the args
    my $args = {};
    my $err;
    {
        local $@;
        $args = eval { Troglodyne::CGI::get_args() };
        $err = $@;
    }

    if(!scalar(keys(%$args))) {
        $ret->{'result'} = 0;
        $ret->{'error'} = "No args detected! $err";
        return emit($ret);
    }

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
    if( $loaded && $coderef ) {
        local $@;
        my $data = eval { $coderef->($args) };
        my $error = $@;
        if($data) {
            $ret->{'data'} = $data;
            $ret->{'result'} = 1;
        } else {
            $ret->{'result'} = 0;
            $ret->{'error'} = $error;
        }
    } elsif( !$coderef ) {
        $ret->{'error'} = "No such function '$args->{'function'}' in $namespace";
        $ret->{'result'} = 0;
    } else {
        $ret->{'error'} = $err;
        $ret->{'result'} = 0;
    }

    return emit($ret);
}

sub emit {
    print "Content-type: application/json\r\n\r\n";
    print JSON::XS::encode_json($_[0]);
    return 0;
}

1;
