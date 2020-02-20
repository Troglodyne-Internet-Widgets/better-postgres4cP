.PHONY: all install test uninstall
all: install

install:
	/usr/local/cpanel/3rdparty/bin/perl install/install.pl
	chmod +x /usr/local/cpanel/whostmgr/docroot/cgi/troglodyne/pgupgrade.cgi
	/usr/local/cpanel/bin/register_appconfig ./plugin/better_postgres.conf

uninstall:
	/usr/local/cpanel/bin/unregister_appconfig better_postgres
	rm -rf /var/cpanel/perl/Troglodyne
	rm -rf /var/cpanel/templates/troglodyne
	rm -rf /usr/local/cpanel/whostmgr/docroot/templates/troglodyne
	rm -rf /usr/local/cpanel/whostmgr/docroot/cgi/troglodyne
	rm -f /usr/local/cpanel/whostmgr/docroot/addon_plugins/troglophant.png

test:
	[ ! -x /usr/local/cpanel/3rdparty/bin/prove ] || /usr/local/cpanel/3rdparty/bin/prove t/*.t
	[ -x /usr/local/cpanel/3rdparty/bin/prove ] || prove t/*.t
