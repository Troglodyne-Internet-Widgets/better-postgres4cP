package Troglodyne::CGI;

use strict;
use warnings;

# Need to also get POST args, etc.
sub get_args {
    my $args_hr = { map { split( /=/, $_ ) } split( /&/, $ENV{'QUERY_STRING'} ) };
    return $args_hr;
}

# Yay. I now have ~250ms pageloads instead of 350+ms pageloads.
sub render_cached_or_process_template {
    my ( $service, $input_hr ) = @_;
    if( $input_hr->{'troglodyne_do_static_render'} ) {

        # Try to print from cache, as Cpanel::Template is slow AF
        my ( $cached, $cache_file ) = cached( $service, $input_hr->{'template_file'} );
        return if( $cached && render_from_cache( $cache_file ) );

        # OK, so no cache. Let's fix that.
        $input_hr->{'print'} = 0;
        require Cpanel::Template;
        my ( $success, $output_sr ) = Cpanel::Template::process_template( $service, $input_hr );
        if( $success ) {
            return if render_to_cache_and_print( $cache_file, $output_sr );
        }
    }

    # Crap, everything failed. Just try to print it, sigh
    require Cpanel::Template;
    Cpanel::Template::process_template( $service, $input_hr );
    return;
}

sub render_to_cache_and_print {
    my ( $cache_file, $content_sr ) = @_;
    local $@;
    my $worked = eval {
        open( my $fh, '>', $cache_file ) or die "Couldn't open cache file \"$cache_file\" for writing: $!";
        print $fh $$content_sr;
        print STDOUT $$content_sr;
    };
    if(my $err = $@) {

        # Require bashes $@, so assign first
        require Cpanel::Debug;
        Cpanel::Debug::log_error($err);
    }
    return $worked;
}

sub render_from_cache {
    my ( $cache_file ) = @_;
    local $@;
    my $worked = eval {
        open( my $fh, '<', $cache_file ) or die "Couldn't open cache file \"$cache_file\" for reading: $!";
        while( <$fh> ) { print $_; }
    };
    if(my $err = $@) {

        # Require bashes $@, so assign first
        require Cpanel::Debug;
        Cpanel::Debug::log_error($err);
    }
    return $worked;
}
our $ULC = '/usr/local/cpanel';
our %TMPL_DIRS_BY_SVC = (
    'whostmgr' => 'whostmgr/docroot/templates',
    'cpanel'   => 'base/frontend/paper_lantern',
    'webmail'  => 'base/webmail/paper_lantern',
);
sub cached {
    my ( $service, $tmpl_file ) = @_;
    my $tmpl_path  = "$ULC/$TMPL_DIRS_BY_SVC{$service}/$tmpl_file";
    my $cache_path = "$tmpl_path.cache";

    # If cache mtime is older than template mtime, we are fine to use the cache.
    my $cached = ( -s $cache_path && ( (stat(_))[9] > (stat($tmpl_path))[9] ) );
    return ( $cached, $cache_path );
}

1;
