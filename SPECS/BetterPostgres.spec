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

%install
make install DESTDIR=%{buildroot}

%files
%defattr(0700,root,root,-)
/usr/local/cpanel/whostmgr/docroot/cgi/troglodyne/pgupgrade.cgi
/usr/local/cpanel/whostmgr/docroot/cgi/troglodyne/api.cgi
%defattr(0600,root,root,-)
/usr/local/cpanel/whostmgr/docroot/templates/troglodyne/ui/pgupgrade.tmpl
/var/cpanel/templates/troglodyne/config/main.default
/usr/local/cpanel/whostmgr/docroot/cgi/troglodyne/js/pgupgrade.js
/usr/local/cpanel/whostmgr/docroot/cgi/troglodyne/img/troglophant.png
/var/cpanel/perl/Troglodyne/CGI/PgUpgrade.pm
/var/cpanel/perl/Troglodyne/CGI/API.pm
/var/cpanel/perl/Troglodyne/CpPostgreSQL.pm
/var/cpanel/perl/Troglodyne/API/Postgres.pm
/var/cpanel/perl/Troglodyne/CGI.pm
%defattr(0755,root,root,0755)
/var/cpanel/apps/troglodyne_api.conf
/var/cpanel/apps/better_postgres.conf

%changelog
* Tue Apr 14 2020 George S. Baugh <george@troglodyne.net> - 1.0.1
- Initial Release
