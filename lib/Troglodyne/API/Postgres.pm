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
    my $pid = Cpanel::Daemonizer::Tiny::run_as_daemon( \&_real_install, $version, $lgg );
    symlink( $pid, "$dir/INSTALL_IN_PROGRESS" ) if $pid;
    return {
        'log' => $lgg,
        'pid' => $pid,
    };
}

our @ROLLBACKS;
sub _real_install {
    my ( $ver2install, $log ) = @_;

    @ROLLBACKS = ();
    require Cpanel::AccessIds::ReducedPrivileges;
    my $no_period_version = $ver2install =~ s/\.//r;
    my @RPMS = (
        "postgresql$no_period_version",
        "postgresql$no_period_version-server",
    );
    # TODO: Use Cpanel::Yum::Install based module, let all that stuff handle this "for you".
    open( my $lh, ">", $log ) or return _cleanup("255");
    select $lh;
    $| = 1;
    select $lh;
    print $lh "Beginning install...\n";

    require Whostmgr::Services;
    require Cpanel::Services::Enabled;
    if( Cpanel::Services::Enabled::is_enabled('postgres') ) {
        print $lh "Disabling postgresql during the upgrade window since it is currently enabled...\n";
        Whostmgr::Services::disable('postgres');
        my $rb = sub { Whostmgr::Services::enable('postgres'); };
        unlink '/var/lib/pgsql/data/postmaster.pid';
        push @ROLLBACKS, $rb;
    }

    # Check for CCS. Temporarily disable it if so.
    my ( $ccs_installed, $err );
    {
        local $@;
        eval {
            require Cpanel::RPM;
            $ccs_installed = Cpanel::RPM->new()->get_version('cpanel-ccs-calendarserver');
            $ccs_installed = $ccs_installed->{'cpanel-ccs-calendarserver'};
        };
        $err = $@;
    }
    if($err) {
        print $lh "[ERROR] $err\n";
        return _cleanup('255');
    }
    if($ccs_installed) {
        print $lh "\ncpanel-ccs-calendarserver is installed.\nDisabling the service while the upgrade is in process.\n\n";
        Whostmgr::Services::disable('cpanel-ccs');
        unlink '/opt/cpanel-ccs/data/Data/Database/cluster/postmaster.pid';
        my $rb = sub { Whostmgr::Services::enable('cpanel-ccs'); };
        push @ROLLBACKS, $rb;
    }

    require Cpanel::SafeRun::Object;
    my $exit = _saferun( $lh, 'yum', qw{install -y}, @RPMS );
    return _cleanup("$exit") if $exit;
    my $rollbck = sub { _saferun( $lh, 'yum', qw{remove -y}, @RPMS ) };
    push @ROLLBACKS, $rollbck;

    # Init the DB
    {
        local $@;
        eval {
            my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('postgres');
            $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/initdb", '-D', "/var/lib/pgsql/$ver2install/data/" );
        };
        $err = $@;
    }
    if($err) {
        print $lh "[ERROR] $err\n";
        return _cleanup('255');
    }
    return _cleanup("$exit") if $exit;
    # probably shouldn't do it this way. Whatever
    my $rd_rllr = sub { _saferun( $lh, qw{rm -rf}, "/var/lib/pgsql/$ver2install/data" ) };
    push @ROLLBACKS, $rd_rllr;

    require File::Slurper;
    # Move some bullcrap out of the way if we're on old PGs
    require Cpanel::PostgresUtils;
    my @cur_ver = ( Cpanel::PostgresUtils::get_version() );
    my $str_ver = join( '.', @cur_ver );
    if( $str_ver + 0 < 9.4 ) {
        print $lh "\n\nInstalled version is less than 9.4 ($str_ver), Implementing workaround in pg_ctl to ensure pg_upgrade works...\n";
        require File::Copy;
        print $lh "Backing up /usr/bin/pg_ctl to /usr/bin/pg_ctl.orig\n";
        File::Copy::copy('/usr/bin/pg_ctl','/usr/bin/pg_ctl.orig') or do {
            print $lh "Backup of /usr/bin/pg_ctl to /usr/bin/pg_ctl.orig failed: $!\n";
            return _cleanup("255");
        };
        my $rb = sub { File::Copy::move('/usr/bin/pg_ctl.orig','/usr/bin/pg_ctl'); };
        push @ROLLBACKS, $rb;

        local $@;
        my $pg_ctl_contents = "#!/bin/bash\n\"\$0\".orig \"\${@/unix_socket_directory/unix_socket_directories}\"";
        eval {
            File::Slurper::write_binary( "/usr/bin/pg_ctl", $pg_ctl_contents );
            chmod( 0755, '/usr/bin/pg_ctl' );
        };
        if($@) {
            print $lh "[ERROR] Write to /usr/bin/pg_ctl failed: $@\n";
            return _cleanup('255');
        }
        print $lh "Workaround should be in place now. Proceeding with pg_upgrade.\n\n";
    }

    require Cpanel::Chdir;
    # Upgrade the cluster
    # /usr/pgsql-9.6/bin/pg_upgrade --old-datadir /var/lib/pgsql/data/ --new-datadir /var/lib/pgsql/9.6/data/ --old-bindir /usr/bin/ --new-bindir /usr/pgsql-9.6/bin/
    my ( $old_datadir, $old_bindir ) = ( $str_ver + 0 < 9.5 ) ? ( '/var/lib/pgsql/data', '/usr/bin' ) : ( "/var/lib/pgsql/$str_ver/data/", "/usr/pgsql-$str_ver/bin/" );
    {
        local $@;
        eval {
            my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('postgres');
            my $cd_obj = Cpanel::Chdir->new('/var/lib/pgsql');
            $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/pg_upgrade",
                    '-d', $old_datadir,
                    '-D', "/var/lib/pgsql/$ver2install/data/",
                    '-b', $old_bindir,
                    '-B', "/usr/pgsql-$ver2install/bin/",
            );
        };
        $err = $@;
    }
    if($err) {
        print $lh "[ERROR] $err\n";
        return _cleanup('255');
    }
    return _cleanup("$exit") if $exit;


    # Start the server.
    $exit = _saferun( $lh, qw{systemctl start}, "postgresql-$ver2install" );
    return _cleanup("$exit") if $exit;

    if( $ccs_installed ) {
        print $lh "\n\nNow upgrading PG cluster for cpanel-ccs-calendarserver...\n";
        my $ccs_pg_datadir = '/opt/cpanel-ccs/data/Data/Database/cluster';
        print $lh "Old PG datadir is being moved to '$ccs_pg_datadir.old'...\n";
        File::Copy::move( $ccs_pg_datadir, "$ccs_pg_datadir.old" );
        mkdir($ccs_pg_datadir);
        my $rb = sub { File::Copy::move( "$ccs_pg_datadir.old", $ccs_pg_datadir ); };
        push @ROLLBACKS, $rb;

        # Init the DB
        {
            local $@;
            eval {
                my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('cpanel-ccs');

                local $ENV{'PGSETUP_INITDB_OPTIONS'} = "-U caldav --locale=C -E=UTF8";
                $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/initdb", '-D', $ccs_pg_datadir );
            };
            $err = $@;
        }
        if($err) {
            print $lh "[ERROR] $err\n";
            return _cleanup('255');
        }
        return _cleanup("$exit") if $exit;

        # Upgrade the DB
        {
            local $@;
            eval {
                my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('cpanel-ccs');
                my $cd_obj = Cpanel::Chdir->new('/opt/cpanel-ccs');

                $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/pg_upgrade",
                    '-d', "$ccs_pg_datadir.old",
                    '-D', $ccs_pg_datadir,
                    '-b', $old_bindir,
                    '-B', "/usr/pgsql-$ver2install/bin/",
                    qw{-c -U caldav},
                );
            };
            $err = $@;
        }
        if($err) {
            print $lh "[ERROR] $err\n";
            return _cleanup('255');
        }
        return _cleanup("$exit") if $exit;
    }

    # At this point we're at the point where we don't need to restore. Just clean up.
    @ROLLBACKS = ();
    if( $str_ver + 0 < 9.4 ) {
        print $lh "\n\nWorkaround resulted in successful start of the server. Reverting workaround changes to pg_ctl...\n\n";
        rename( '/usr/bin/pg_ctl.orig', '/usr/bin/pg_ctl' ) or do {
            print $lh "Restore of /usr/bin/pg_ctl.orig to /usr/bin/pg_ctl failed: $!\n";
            return _cleanup("255");
        };
    }

    print $lh "\n\nNow cleaning up old postgresql version...\n";
    my $svc2remove = ( $str_ver + 0 < 9.5 ) ? 'postgresql' : "postgresql-$str_ver";
    $exit = _saferun( $lh, qw{systemctl disable}, $svc2remove );
    return _cleanup("$exit") if $exit;
    $exit = _saferun( $lh, qw{yum -y remove}, $svc2remove );
    return _cleanup("$exit") if $exit;

    print $lh "\n\nNow enabling postgresql-$ver2install on startup...\n";
    $exit = _saferun( $lh, qw{systemctl enable}, "postgresql-$ver2install" );
    return _cleanup("$exit") if $exit;

    # Update alternatives. Should be fine to use --auto, as no other alternatives will exist for the installed version.
    # Create alternatives for pg_ctl, etc. as those don't get made by the RPM.
    print $lh "\n\nUpdating alternatives to ensure the newly installed version is considered canonical...\n";
    my @normie_alts = qw{pg_ctl initdb pg_config pg_upgrade};
    my @manual_alts = qw{clusterdb createdb createuser dropdb droplang dropuser pg_basebackup pg_dump pg_dumpall pg_restore psql psql-reindexdb vaccumdb};
    foreach my $alt ( @normie_alts ) {
        $exit = _saferun( $lh, qw{update-alternatives --install}, "/usr/bin/$alt", "pgsql-$alt", "/usr/pgsql-$ver2install/bin/$alt", "50" );
        return _cleanup("$exit") if $exit;
        $exit = _saferun( $lh, qw{update-alternatives --auto}, "pgsql-$alt" );
        return _cleanup("$exit") if $exit;
    }
    foreach my $alt ( @manual_alts ) {
        $exit = _saferun( $lh, qw{update-alternatives --auto}, "pgsql-$alt" );
        return _cleanup("$exit") if $exit;
        $exit = _saferun( $lh, qw{update-alternatives --auto}, "pgsql-${alt}man" );
        return _cleanup("$exit") if $exit;
    }

    print $lh "\n\nWriting new .bash_profile for the 'postgres' user...\n";
    my $bash_profile = "[ -f /etc/profile ] && source /etc/profile
PGDATA=/var/lib/pgsql/$ver2install/data
export PGDATA
[ -f /var/lib/pgsql/.pgsql_profile ] && source /var/lib/pgsql/.pgsql_profile
export PATH=\$PATH:/usr/pgsql-$ver2install/bin\n";
    File::Slurper::write_text( '/var/lib/pgsql/.bash_profile', $bash_profile );

    if($ccs_installed) {
        File::Slurper::write_text( '/opt/cpanel-ccs/.bash_profile', $bash_profile );
        print $lh "\nRe-Enabling cpanel-ccs-calendarserver...\n\n";
        require Whostmgr::Services;
        Whostmgr::Services::enable('cpanel-ccs');
    }

    return _cleanup("0");
}

sub _saferun {
    my ( $lh, $prog, @args ) = @_;
    my $run_result = Cpanel::SafeRun::Object->new(
        'program' => $prog,
        'args'    => [ @args ],
        'stdout'  => $lh,
        'stderr'  => $lh,
    );
    my $exit = $run_result->error_code() || 0;
    return $exit;
}

sub _cleanup {
    my ( $code ) = @_;

    # Do rollbacks in reverse order
    foreach my $rb ( reverse @ROLLBACKS ) {
        local $@;
        eval { $rb->(); };
        my $exit = $@ ? 255 : 0;
        if($exit) {
            $code = $exit;
            last;
        }
    }

    # Signal completion
    eval { symlink( $code, "$dir/INSTALL_EXIT_CODE" ); };
    unlink("$dir/INSTALL_IN_PROGRESS");
    return;
}

# Elegance??? Websocket??? Nah. EZ mode actibated
sub get_latest_upgradelog_messages {
    my ( $args_hr ) = @_;
    my $child_exit;
    my $in_progress = -l "$dir/INSTALL_IN_PROGRESS";
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
    my $pos = tell($rh);
    close($rh);

    return {
        'in_progress' => $in_progress,
        'child_exit'  => $child_exit,
        'next'        => $pos,
        'new_content' => $content,
    }
}

1;
