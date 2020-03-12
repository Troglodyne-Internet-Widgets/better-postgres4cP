package Troglodyne::CGI;

use strict;
use warnings;

# Need to also get POST args, etc.
sub get_args {
    my $args_hr = { map { split( /=/, $_ ) } split( /&/, $ENV{'QUERY_STRING'} ) };
    return $args_hr;
}

our $CP_SECURITY_TOKEN = $ENV{'cp_security_token'} || 'cpsess0000000000';
our $CP_USER = $ENV{'REMOTE_USER'} || 'nobody';

# XXX TODO TODO TODO Need to make API calls return 304 unmodified if the data is
# unchanged! hehehe

# TODO delete cached templates via cron or hook or something, as the cache files
# will otherwise begin to pile up.
# Suggest using Cpanel::Session::is_active_security_token_for_user($user,$token)
# in a loop and trashing inactive templates.

# Yay. I now have ~250ms pageloads instead of 350+ms pageloads.
# XXX Need to check when the chrome updates and pop cache then too?
# Maybe upcp hook instead?
sub render_cached_or_process_template {
    my ( $service, $input_hr ) = @_;
    if( $input_hr->{'troglodyne_do_static_render'} ) {

        # Try to print from cache, as Cpanel::Template is slow AF
        my ( $cached, $cache_dir ) = cached( $service, $input_hr->{'template_file'} );
        return if( $cached && render_from_cache($cache_dir) );

        # OK, so no cache. Let's fix that.
        $input_hr->{'print'} = 0;
        require Cpanel::Template;
        my ( $success, $output_sr ) = Cpanel::Template::process_template( $service, $input_hr );
        if( $success ) {
            return if render_to_cache_and_print( $cache_dir, $output_sr );
        }
    }

    # Crap, everything failed. Just try to print it, sigh
    require Cpanel::Template;
    Cpanel::Template::process_template( $service, $input_hr );
    return;
}

sub render_to_cache_and_print {
    my ( $cache_dir, $content_sr ) = @_;
    local $@;
    require Cpanel::Mkdir;
    Cpanel::Mkdir::ensure_directory_existence_and_mode($cache_dir, 0711);
    my $worked = eval {
        open( my $fh, '>', "$cache_dir/$CP_SECURITY_TOKEN" ) or die "Couldn't open cache file \"$cache_dir/$CP_SECURITY_TOKEN\" for writing: $!";
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
    my ( $cache_dir ) = @_;
    local $@;
    my $worked = eval {
        open( my $fh, '<', "$cache_dir/$CP_SECURITY_TOKEN" ) or die "Couldn't open cache file \"$cache_dir/$CP_SECURITY_TOKEN\" for reading: $!";
        while( <$fh> ) { print $_; }
    };
    if(my $err = $@) {

        # Require bashes $@, so assign first
        require Cpanel::Debug;
        Cpanel::Debug::log_error($err);
    }
    return $worked;
}

# These MUST be indexed by cp_security_token... sadly
our $ULC = '/usr/local/cpanel';
our %TMPL_DIRS_BY_SVC = (
    'whostmgr' => 'whostmgr/docroot/templates',
    'cpanel'   => 'base/frontend/paper_lantern',
    'webmail'  => 'base/webmail/paper_lantern',
);
sub cached {
    my ( $service, $tmpl_file ) = @_;
    my $tmpl_path  = "$ULC/$TMPL_DIRS_BY_SVC{$service}/$tmpl_file";
    my $cache_dir = "${tmpl_path}_caches/$CP_USER";
    my $cache_path = "$cache_dir/$CP_SECURITY_TOKEN";

    # If cache mtime is older than template mtime, we are fine to use the cache.
    my $cached = ( -s $cache_path && ( (stat(_))[9] > (stat($tmpl_path))[9] ) );
    return ( $cached, $cache_dir );
}

1;
