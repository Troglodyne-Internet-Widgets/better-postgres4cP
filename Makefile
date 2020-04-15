.PHONY: all install test uninstall
all: install

install:
	/usr/local/cpanel/3rdparty/bin/perl install/install.pl
	chmod +x /usr/local/cpanel/whostmgr/docroot/cgi/troglodyne/pgupgrade.cgi
	chmod +x /usr/local/cpanel/whostmgr/docroot/cgi/troglodyne/api.cgi
	/usr/local/cpanel/bin/register_appconfig ./plugin/better_postgres.conf
	/usr/local/cpanel/bin/register_appconfig ./plugin/troglodyne_api.conf

uninstall:
	/usr/local/cpanel/bin/unregister_appconfig troglodyne_api
	/usr/local/cpanel/bin/unregister_appconfig better_postgres
	rm -rf /var/cpanel/perl/Troglodyne
	rm -rf /var/cpanel/templates/troglodyne
	rm -rf /usr/local/cpanel/whostmgr/docroot/templates/troglodyne
	rm -rf /usr/local/cpanel/whostmgr/docroot/cgi/troglodyne
	rm -f /usr/local/cpanel/whostmgr/docroot/addon_plugins/troglophant.png

test:
	[ ! -x /usr/local/cpanel/3rdparty/bin/prove ] || /usr/local/cpanel/3rdparty/bin/prove t/*.t
	[ -x /usr/local/cpanel/3rdparty/bin/prove ] || prove t/*.t

rpm:
	rm -rf SOURCES/*
	mkdir -p SOURCES/BetterPostgres4cP-1.0
	ln -s $(shell pwd)/bin SOURCES/BetterPostgres4cP-1.0/bin
	ln -s $(shell pwd)/cgi SOURCES/BetterPostgres4cP-1.0/cgi
	ln -s $(shell pwd)/img SOURCES/BetterPostgres4cP-1.0/img
	ln -s $(shell pwd)/install SOURCES/BetterPostgres4cP-1.0/install
	ln -s $(shell pwd)/js SOURCES/BetterPostgres4cP-1.0/js
	ln -s $(shell pwd)/lib SOURCES/BetterPostgres4cP-1.0/lib
	ln -s $(shell pwd)/plugin SOURCES/BetterPostgres4cP-1.0/plugin
	ln -s $(shell pwd)/t SOURCES/BetterPostgres4cP-1.0/t
	ln -s $(shell pwd)/templates SOURCES/BetterPostgres4cP-1.0/templates
	cp $(shell pwd)/Makefile SOURCES/BetterPostgres4cP-1.0/Makefile
	cp $(shell pwd)/configure SOURCES/BetterPostgres4cP-1.0/configure
	cd SOURCES && tar --exclude="*.swp" --exclude="*.swn" --exclude="*.swo" -ch BetterPostgres4cP-1.0 | gzip > ~/rpmbuild/SOURCES/BetterPostgres4cP-1.0.tar.gz
	rpmbuild -ba --clean SPECS/BetterPostgres.spec
	rm -rf SOURCES/*
