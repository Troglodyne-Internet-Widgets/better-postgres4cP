package Troglodyne::CGI;

use strict;
use warnings;

# Need to also get POST args, etc.
sub get_args {
    my $args_hr = { map { split( /=/, $_ ) } split( /&/, $ENV{'QUERY_STRING'} ) };
    return $args_hr;
}

1;
