#!/usr/local/cpanel/3rdparty/bin/perl

use strict;
use warnings;

use Cwd ();
use Git ();
use File::Basename ();

use Cpanel::Mkdir ();

my $repo_dir = Cwd::abs_path(File::Basename::dirname(__FILE__) . "/../");
Cpanel::Mkdir::ensure_directory_existence_and_mode("/var/cpanel/apps", 0755);
my %install_to = qw{lib /var/cpanel/perl templates/config /var/cpanel/templates/troglodyne templates/ui /usr/local/cpanel/whostmgr/docroot/templates/troglodyne cgi /usr/local/cpanel/whostmgr/docroot/cgi/troglodyne img /usr/local/cpanel/whostmgr/docroot/addon_plugins};
foreach my $dir ( keys(%install_to) ) {
    Cpanel::Mkdir::ensure_directory_existence_and_mode( $install_to{$dir}, 0755 );
    my @cmd = ( qw{rsync -r}, "$repo_dir/$dir/", $install_to{$dir} );
    print join( " ", @cmd ) . "\n";
    my $ret = system( @cmd );
    die if $ret != 0;
}

0;
