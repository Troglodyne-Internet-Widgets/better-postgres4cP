package Troglodyne::API::Postgres;

use strict;
use warnings;

use Cpanel::LoadModule::Custom;

sub get_postgresql_versions {
    Cpanel::LoadModule::Custom::load_perl_module('Troglodyne::CpPostgreSQL');
    require Cpanel::PostgresUtils;
    my @ver_arr = ( Cpanel::PostgresUtils::get_version() );
    return {
        'installed_version'         => { 'major' => $ver_arr[0], 'minor' => $ver_arr[1] },
        'minimum_supported_version' => $Troglodyne::CpPostgreSQL::MINIMUM_SUPPORTED_VERSION,
        'available_versions'        => \%Troglodyne::CpPostgreSQL::SUPPORTED_VERSIONS_MAP,
        'eol_versions'              => \%Troglodyne::CpPostgreSQL::CP_UNSUPPORTED_VERSIONS_MAP,
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
        @cmd = qw{/bin/rpm -i}, $repo_rpm_url;
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
    my $dir = '/var/cpanel/logs/troglodyne/pgupgrade'
    require Cpanel::Mkdir;
    Cpanel::Mkdir::ensure_directory_existence_and_mode( $dir, 0711 );

    require Cpanel::FileUtils::Touch;
    my $time = time;
    Cpanel::FileUtils::Touch::touch_if_not_exists("$dir/pgupgrade-to-$version-at-$time.log");
    
    require Cpanel::Autodie;
    Cpanel::Autodie::unlink_if_exists("$dir/last");
    require Cpanel::Chdir;
    {
        my $chdir = Cpanel::Chdir->new($dir);
        symlink( "pgupgrade-to-$version-at-$time.log", "last" );
    }
}

1;
