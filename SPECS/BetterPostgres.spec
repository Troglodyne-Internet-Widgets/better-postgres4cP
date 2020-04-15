Name: BetterPostgres4cP
Version: 1.0
Release:	1%{?dist}
Summary: Better PostgreSQL management for cPanel hosts

Group: Plugins
License: Troglodyne
URL: https://troglodyne.net/betterpostgres
Source0: BetterPostgres4cP-%{version}.tar.gz

BuildRequires: make perl
Requires: perl

%description
Plugin for more advanced management of PostgreSQL on cPanel systems

%prep
%setup -q


%build
%configure
make %{?_smp_mflags}


%install
make install DESTDIR=%{buildroot}


%files
%{DESTDIR}/usr/local/cpanel/whostmgr/templates/troglodyne/ui/pgupgrade.tmpl
%{DESTDIR}/usr/local/cpanel/whostmgr/templates/troglodyne/config/main.default
%{DESTDIR}/usr/local/cpanel/whostmgr/cgi/troglodyne/js/pgupgrade.js
%{DESTDIR}/usr/local/cpanel/whostmgr/cgi/troglodyne/img/troglophant.png
%{DESTDIR}/usr/local/cpanel/whostmgr/cgi/troglodyne/pgupgrade.cgi
%{DESTDIR}/usr/local/cpanel/whostmgr/cgi/troglodyne/api.cgi
%{DESTDIR}/var/cpanel/perl/Troglodyne/CGI/PgUpgrade.pm
%{DESTDIR}/var/cpanel/perl/Troglodyne/CGI/API.pm
%{DESTDIR}/var/cpanel/perl/Troglodyne/CpPostgreSQL.pm
%{DESTDIR}/var/cpanel/perl/Troglodyne/API/Postgres.pm
%{DESTDIR}/var/cpanel/perl/Troglodyne/CGI.pm
%{DESTDIR}/var/cpanel/apps/troglodyne_api.conf
%{DESTDIR}/var/cpanel/apps/better_postgres.conf


%changelog

* Tue Apr 14 2020 George S. Baugh <george@troglodyne.net> - 1.0.1
- Initial Release
