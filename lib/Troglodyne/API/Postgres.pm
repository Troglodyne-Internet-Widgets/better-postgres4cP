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
    unlink( "$dir/INSTALL_EXIT_CODE" );
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
    my $no_period_version = $ver2install =~ s/\.//r;
    my @RPMS = (
        "postgresql$no_period_version",
        "postgresql$no_period_version-libs",
        "postgresql$no_period_version-server",
        "postgresql$no_period_version-devel", # For CCS
    );
    # TODO: Use Cpanel::Yum::Install based module, let all that stuff handle this "for you".
    open( my $lh, ">", $log ) or return _cleanup("255");
    select $lh;
    $| = 1;
    select $lh;

    # So, since I can't know what all crap to eval here,
    # let's just catch all the dies and throw generic
    # errors in this event then trigger rollback.
    local $SIG{__DIE__} = sub {
        print $lh "# [ERROR] ", @_;
        require Devel::StackTrace;
        my $trace = Devel::StackTrace->new();
        print $lh $trace->as_string(), "\n";
        _cleanup('255', $lh);
        die @_;
    };

    print $lh "# [INFO] Beginning install...\n";

    my $exit;
    require Cpanel::AccessIds::ReducedPrivileges;
    require Cpanel::SafeRun::Object;
    require Cpanel::Services::Enabled;
    my $postgres_enabled = Cpanel::Services::Enabled::is_enabled('postgresql');
    if( Cpanel::Services::Enabled::is_enabled('postgresql') ) {
        print $lh "# [INFO] Disabling postgresql during the upgrade window since it is currently enabled...\n";
        # Don't use Whostmgr::Services, as that bungles the __DIE__ overwrite.
        $exit = _saferun( $lh, qw{/usr/local/cpanel/bin/whmapi1 configureservice service=postgresql enabled=0 monitored=0} );
        return _cleanup("$exit", $lh) if $exit;

        print $lh "# [INFO] Adding 're-enable postgresql' to \@ROLLBACKS stack...\n"; 
        my $rb = sub { _saferun( $lh, qw{/usr/local/cpanel/bin/whmapi1 configureservice service=postgresql enabled=1 monitored=1} ); };
        push @ROLLBACKS, $rb;
    }

    # Check for CCS. Temporarily disable it if so.
    require Cpanel::RPM;
    my $ccs_installed = Cpanel::RPM->new()->get_version('cpanel-ccs-calendarserver');
    $ccs_installed = $ccs_installed->{'cpanel-ccs-calendarserver'};
    my $ccs_enabled   = Cpanel::Services::Enabled::is_enabled('cpanel-ccs');
    if( $ccs_installed ) {
        print $lh "# [INFO] cpanel-ccs-calendarserver is installed.\nDisabling the service while the upgrade is in process.\n\n";
        $exit = _saferun( $lh, qw{/usr/local/cpanel/bin/whmapi1 configureservice service=cpanel-ccs enabled=0 monitored=0} );
        return _cleanup("$exit", $lh) if $exit;
        print $lh "# [INFO] Adding 're-enable cpanel-ccs' to \@ROLLBACKS stack...\n"; 
        my $rb = sub { _saferun( $lh, qw{/usr/local/cpanel/bin/whmapi1 configureservice service=cpanel-ccs enabled=1 monitored=1} ) };
        push @ROLLBACKS, $rb;
    }

    $exit = _saferun( $lh, 'yum', qw{install -y}, @RPMS );
    return _cleanup("$exit", $lh) if $exit;
    print $lh "# [INFO] Adding 'yum remove new pg version' to \@ROLLBACKS stack...\n"; 
    my $rollbck = sub { _saferun( $lh, 'yum', qw{remove -y}, @RPMS ) };
    push @ROLLBACKS, $rollbck;

    # Init the DB
    my $locale = $ENV{'LANG'} || 'en_US.UTF-8';
    {
        my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('postgres');
        $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/initdb", '--locale', $locale, '-E', 'UTF8', '-D', "/var/lib/pgsql/$ver2install/data/" );
    }
    return _cleanup("$exit", $lh) if $exit;
    # probably shouldn't do it this way. Whatever
    print $lh "# [INFO] Adding 'Clean up new pgdata dir' to \@ROLLBACKS stack...\n"; 
    my $rd_rllr = sub { _saferun( $lh, qw{rm -rf}, "/var/lib/pgsql/$ver2install/data" ) };
    push @ROLLBACKS, $rd_rllr;

    require File::Slurper;
    # Move some bullcrap out of the way if we're on old PGs
    require Cpanel::PostgresUtils;
    my @cur_ver = ( Cpanel::PostgresUtils::get_version() );
    my $str_ver = join( '.', @cur_ver );
    if( $str_ver + 0 < 9.4 ) {
        print $lh "# [INFO] Installed version is less than 9.4 ($str_ver), Implementing workaround in pg_ctl to ensure pg_upgrade works...\n";
        require File::Copy;
        print $lh "# [BACKUP] Backing up /usr/bin/pg_ctl to /usr/bin/pg_ctl.orig\n";
        File::Copy::cp('/usr/bin/pg_ctl','/usr/bin/pg_ctl.orig') or do {
            print $lh "Backup of /usr/bin/pg_ctl to /usr/bin/pg_ctl.orig failed: $!\n";
            return _cleanup("255", $lh);
        };
        chmod(0755, '/usr/bin/pg_ctl.orig');
        print $lh "# [INFO] Adding 'Restore old pg_ctl process to \@ROLLBACKS stack...\n";
        my $rb = sub { File::Copy::mv('/usr/bin/pg_ctl.orig','/usr/bin/pg_ctl'); };
        push @ROLLBACKS, $rb;

        my $pg_ctl_contents = "#!/bin/bash\n\"\$0\".orig \"\${@/unix_socket_directory/unix_socket_directories}\"";
        File::Slurper::write_binary( "/usr/bin/pg_ctl", $pg_ctl_contents );
        chmod( 0755, '/usr/bin/pg_ctl' );

        print $lh "# [INFO] Workaround should be in place now. Proceeding with pg_upgrade.\n\n";
    }

    print $lh "# [INFO] Setting things up for pg_upgrade -- delete postmaster.pid, ensure .pgpass in place.\n";
    require Cpanel::Chdir;
    # Upgrade the cluster
    # /usr/pgsql-9.6/bin/pg_upgrade --old-datadir /var/lib/pgsql/data/ --new-datadir /var/lib/pgsql/9.6/data/ --old-bindir /usr/bin/ --new-bindir /usr/pgsql-9.6/bin/
    my ( $old_datadir, $old_bindir ) = ( $str_ver + 0 < 9.5 ) ? ( '/var/lib/pgsql/data', '/usr/bin' ) : ( "/var/lib/pgsql/$str_ver/data/", "/usr/pgsql-$str_ver/bin/" );
    unlink '/var/lib/pgsql/data/postmaster.pid';

    # Copy over the .pgpass file for the postgres user so that it knows how to connect as itself (oof)
    File::Copy::cp('/root/.pgpass', '/var/lib/pgsql/.pgpass');
    print $lh "# [INFO] Adding 'cleanup .pgpass file to \@ROLLBACKS stack...\n";
    my $reb = sub { unlink '/var/lib/pgsql/.pgpass' };
    push @ROLLBACKS, $reb;
    require Cpanel::SafetyBits::Chown;
    Cpanel::SafetyBits::Chown::safe_chown( 'postgres', 'postgres', '/var/lib/pgsql/.pgpass' );
    chmod( 0600, '/var/lib/pgsql/.pgpass' );

    print "# [INFO] Now running pg_upgrade on the default cluster...\n";
    {
        my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('postgres');
        my $cd_obj = Cpanel::Chdir->new('/var/lib/pgsql');
        $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/pg_upgrade",
                '-d', $old_datadir,
                '-D', "/var/lib/pgsql/$ver2install/data/",
                '-b', $old_bindir,
                '-B', "/usr/pgsql-$ver2install/bin/",
        );
    }
    return _cleanup("$exit", $lh) if $exit;


    # Start the server.
    print $lh "# [INFO] Starting up postgresql-$ver2install...\n";
    $exit = _saferun( $lh, qw{systemctl start}, "postgresql-$ver2install" );
    return _cleanup("$exit", $lh) if $exit;

    if( $ccs_installed ) {
        my $ccs_pg_datadir = '/opt/cpanel-ccs/data/Data/Database/cluster';
        print $lh "# [INFO] Old PG datadir is being moved to '$ccs_pg_datadir.old'...\n";
        File::Copy::mv( $ccs_pg_datadir, "$ccs_pg_datadir.old" );
        mkdir($ccs_pg_datadir);
        chmod( 0700, $ccs_pg_datadir );
        Cpanel::SafetyBits::Chown::safe_chown( 'cpanel-ccs', 'cpanel-ccs', $ccs_pg_datadir );
       
        print $lh "# [INFO] Adding 'restore old CCS cluster' to \@ROLLBACKS stack...\n";
        my $rb = sub {
            require File::Path;
            File::Path::remove_tree($ccs_pg_datadir, { 'error' => \my $err } );
            print $lh join( "\n", @$err ) if ( $err && @$err );
            File::Copy::mv( "$ccs_pg_datadir.old", $ccs_pg_datadir ); 
        };
        push @ROLLBACKS, $rb;

        print $lh "# [INFO] Now initializing the new PG cluster for cpanel-ccs-calendarserver...\n";
        unlink '/opt/cpanel-ccs/data/Data/Database/cluster/postmaster.pid';

        # Init the DB
        {
            my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('cpanel-ccs');
            $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/initdb", '-D', $ccs_pg_datadir, '-U', 'caldav', '--locale', $locale, '-E', 'UTF8' );
        }
        return _cleanup("$exit", $lh) if $exit;

        print $lh "# [INFO] Now upgrading the PG cluster for cpanel-ccs-calendarserver...\n";
        # Upgrade the DB
        {
            my $pants_on_the_ground = Cpanel::AccessIds::ReducedPrivileges->new('cpanel-ccs');
            my $cd_obj = Cpanel::Chdir->new('/opt/cpanel-ccs');

            $exit = _saferun( $lh, "/usr/pgsql-$ver2install/bin/pg_upgrade",
                '-d', "$ccs_pg_datadir.old",
                '-D', $ccs_pg_datadir,
                '-b', $old_bindir,
                '-B', "/usr/pgsql-$ver2install/bin/",
                qw{-U caldav},
            );
        }
        return _cleanup("$exit", $lh) if $exit;
    }

    # At this point we're at the point where we don't need to restore. Just clean up.
    print $lh "# [INFO] Clearing \@ROLLBACKS stack, as we have cleared the necessary checkpoint.\n";
    @ROLLBACKS = ();
    if( $str_ver + 0 < 9.4 ) {
        print $lh "# [INFO] Workaround resulted in successful start of the server. Reverting workaround changes to pg_ctl...\n\n";
        rename( '/usr/bin/pg_ctl.orig', '/usr/bin/pg_ctl' ) or do {
            print $lh "# [ERROR] Restore of /usr/bin/pg_ctl.orig to /usr/bin/pg_ctl failed: $!\n";
            return _cleanup("255", $lh);
        };
    }

    print $lh "# [INFO] Now cleaning up old postgresql version...\n";
    my $svc2remove = ( $str_ver + 0 < 9.5 ) ? 'postgresql' : "postgresql-$str_ver";
    $exit = _saferun( $lh, qw{systemctl disable}, $svc2remove );
    return _cleanup("$exit", $lh) if $exit;
    $exit = _saferun( $lh, qw{yum -y remove}, $svc2remove );
    return _cleanup("$exit", $lh) if $exit;

    print $lh "# [INFO] Now enabling postgresql-$ver2install on startup...\n";
    $exit = _saferun( $lh, qw{systemctl enable}, "postgresql-$ver2install" );
    return _cleanup("$exit", $lh) if $exit;

    # Update alternatives. Should be fine to use --auto, as no other alternatives will exist for the installed version.
    # Create alternatives for pg_ctl, etc. as those don't get made by the RPM.
    print $lh "# [INFO] Updating alternatives to ensure the newly installed version is considered canonical...\n";
    my @normie_alts = qw{pg_ctl initdb pg_config pg_upgrade};
    my @manual_alts = qw{clusterdb createdb createuser dropdb droplang dropuser pg_basebackup pg_dump pg_dumpall pg_restore psql};
    foreach my $alt ( @normie_alts ) {
        my @cmd = ( qw{update-alternatives --install}, "/usr/bin/$alt", "pgsql-$alt", "/usr/pgsql-$ver2install/bin/$alt", "50" );
        print $lh join( " ", @cmd ) . "\n";
        $exit = _saferun( $lh, @cmd );
        return _cleanup("$exit", $lh) if $exit;
        @cmd = ( qw{update-alternatives --auto}, "pgsql-$alt" );
        print $lh join( " ", @cmd ) . "\n";
        $exit = _saferun( $lh, @cmd );
        return _cleanup("$exit", $lh) if $exit;
    }
    foreach my $alt ( @manual_alts ) {
        my @cmd = ( qw{update-alternatives --auto}, "pgsql-$alt" );
        print $lh join( " ", @cmd ) . "\n";
        $exit = _saferun( $lh, @cmd );
        return _cleanup("$exit", $lh) if $exit;
        @cmd = ( qw{update-alternatives --auto}, "pgsql-${alt}man" );
        print $lh join( " ", @cmd ) . "\n";
        $exit = _saferun( $lh, @cmd );
        return _cleanup("$exit", $lh) if $exit;
    }

    print $lh "# [INFO] Writing new .bash_profile for the 'postgres' user...\n";
    my $bash_profile = "[ -f /etc/profile ] && source /etc/profile
PGDATA=/var/lib/pgsql/$ver2install/data
export PGDATA
[ -f /var/lib/pgsql/.pgsql_profile ] && source /var/lib/pgsql/.pgsql_profile
export PATH=\$PATH:/usr/pgsql-$ver2install/bin\n";
    File::Slurper::write_text( '/var/lib/pgsql/.bash_profile', $bash_profile );
    if($ccs_installed && $ccs_enabled) {
        print $lh "# [INFO] Re-Enabling cpanel-ccs-calendarserver...\n";
        $exit = _saferun( $lh, qw{/usr/local/cpanel/bin/whmapi1 configureservice service=cpanel-ccs enabled=1 monitored=1} );
        return _cleanup("$exit", $lh) if $exit;
    }

    # XXX Now the postgres service appears as "disabled" for cPanel's sake. Frowny faces everywhere.
    # Not sure how to fix yet.
    if($postgres_enabled) {
        print $lh "# [INFO] Re-Enabling postgres services for cPanel...\n";
        print $lh "# [TODO] Actually do this!\n";
    }

    local $SIG{__DIE__} = 'DEFAULT';
    return _cleanup("0", $lh);
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
    my ( $code, $lh ) = @_;

    # Do rollbacks in reverse order
    if($lh) {
        print $lh "# [ERROR] Encountered failure during install!\n" if $code;
        print $lh "# [INFO]  Now executing rollbacks...\n" if( $code && @ROLLBACKS);
    }
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
