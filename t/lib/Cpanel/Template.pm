package Cpanel::Template;
use strict;
use warnings;

use FindBin;

sub process_template {
    my ( $svc, $args_hr ) = @_;
    my $content = "# [$svc] This is a test of Troglodyne::CGI. Please Ignore";
    if($args_hr->{'print'}) {
        print STDOUT $content;
    }
    return ( 1, \$content ); 
};

1;
