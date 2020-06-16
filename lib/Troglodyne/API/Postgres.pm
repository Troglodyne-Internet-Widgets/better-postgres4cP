package Troglodyne::API::Postgres;

use strict;
use warnings;

use Cpanel::LoadModule::Custom;

our $dir = '/var/cpanel/logs/troglodyne/pgupgrade';

sub get_postgresql_versions {
    Cpanel::LoadModule::Custom::load_perl_module('Troglodyne::CpPostgreSQL');
    require Cpanel::PostgresUtils;
    my @ver_arr = ( Cpanel::PostgresUtils::get_version() );
    my $running = eval { readlink("$dir/INSTALL_IN_PROGRESS"); } || 0;
    return {
        'installed_version'         => { 'major' => $ver_arr[0], 'minor' => $ver_arr[1] },
        'minimum_supported_version' => $Troglodyne::CpPostgreSQL::MINIMUM_SUPPORTED_VERSION,
        'available_versions'        => \%Troglodyne::CpPostgreSQL::SUPPORTED_VERSIONS_MAP,
        'eol_versions'              => \%Troglodyne::CpPostgreSQL::CP_UNSUPPORTED_VERSIONS_MAP,
        'install_currently_running' => $running,
    };
}

sub enable_community_repositories {
    Cpanel::LoadModule::Custom::load_perl_module('Troglodyne::CpPostgreSQL');
    require Cpanel::Sys::OS;
    my $centos_ver = substr( Cpanel::Sys::OS::getreleaseversion(), 0, 1 );
    my $repo_rpm_url = $Troglodyne::CpPostgreSQL::REPO_RPM_URLS{$centos_ver};
   
    # TODO Use Cpanel::SafeRun::Object to run the install? 
    require Capture::Tiny;
    my @cmd = qw{/bin/rpm -q pgdg-redhat-repo};
    my ( $stdout, $stderr, $ret ) = Capture::Tiny::capture( sub {
        system(@cmd);
    });
    my $installed = !$ret;
    if( !$installed ) {
        @cmd = ( qw{/bin/rpm -i}, $repo_rpm_url );
        ( $stdout, $stderr, $ret ) = Capture::Tiny::capture( sub {
            system(@cmd);
        } );
    }
    return {
        'last_yum_command'  => join( " ", @cmd ),
        'already_installed' => $installed,
        'stdout'            => $stdout,
        'stderr'            => $stderr,
        'exit_code'         => $ret,
    };
}

sub start_postgres_install {
    my ( $args_hr ) = @_;
    my $version = $args_hr->{'version'};
    require Cpanel::Mkdir;
    Cpanel::Mkdir::ensure_directory_existence_and_mode( $dir, 0711 );

    require Cpanel::FileUtils::Touch;
    my $time = time;
    my $lgg = "$dir/pgupgrade-to-$version-at-$time.log";
    Cpanel::FileUtils::Touch::touch_if_not_exists($lgg);
    
    require Cpanel::Autodie;
    Cpanel::Autodie::unlink_if_exists("$dir/last");
    require Cpanel::Chdir;
    {
        my $chdir = Cpanel::Chdir->new($dir);
        symlink( "pgupgrade-to-$version-at-$time.log", "last" );
    }

    # OK. We are logging, now return the log loc after kicking it off.
    # Yeah, yeah, I'm forking twice. who cares
    require Cpanel::Daemonizer::Tiny;
    my $install = sub {
        my ( $ver2install, $log ) = @_;

        my $no_period_version = $ver2install =~ s/\.//r;
        my @RPMS = (
            "postgresql$no_period_version",
        );
        # TODO: Use Cpanel::Yum::Install based module, let all that stuff handle this "for you".
        open( my $lh, ">", $lgg ) or do {
            eval { symlink( "255", "$dir/INSTALL_EXIT_CODE" ); };
            unlink("$dir/INSTALL_IN_PROGRESS");
            return;
        };
        require Cpanel::SafeRun::Object;
        my $run_result = Cpanel::SafeRun::Object->new(
            'program' => 'yum',
            'args'    => [ qw{install -y}, @RPMS ],
            'stdout'  => $lh,
            'stderr'  => $lh,
        );
        unlink("$dir/INSTALL_IN_PROGRESS");
        return;
    };
    my $pid = Cpanel::Daemonizer::Tiny::run_as_daemon( $install, $version, $lgg );
    symlink( $pid, "$dir/INSTALL_IN_PROGRESS" );
    return {
        'log' => $lgg,
        'pid' => $pid,
    };
}

# Elegance??? Websocket??? Nah. EZ mode actibated
sub get_latest_upgradelog_messages {
    my ( $args_hr ) = @_;
    my $child_exit;
    my $in_progress = -f "$dir/INSTALL_IN_PROGRESS";
    if(!$in_progress) {
        $child_exit = readlink("$dir/INSTALL_EXIT_CODE");
    }

    # XXX validate log arg? Don't want arbitrary file reads?
    # read from it using seek and tell to control
    open( my $rh, "<", $args_hr->{'log'} );
    seek( $rh, $args_hr->{'start'}, 0 ) if $args_hr->{'start'};
    my $content = '';
    while( my $line = <$rh> ) {
        $content .= $line;
    }
    my $line_no = tell($rh);
    close($rh);

    return {
        'in_progress' => $in_progress,
        'child_exit'  => $child_exit,
        'next_line'   => $line_no,
        'new_content' => $content,
    }
}

1;
