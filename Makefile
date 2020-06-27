ulc  = /usr/local/cpanel
tmpl = /whostmgr/docroot/templates/troglodyne
cgi  = /whostmgr/docroot/cgi/troglodyne
vcp  = /var/cpanel/perl
vca  = /var/cpanel/apps
vct  = /var/cpanel/templates
pwd  = $(shell pwd)
 
.PHONY: all install register test uninstall rpm test-depend
all: install register

install: test
	mkdir -p $(DESTDIR)$(ulc)$(tmpl)/ui $(DESTDIR)$(ulc)$(tmpl)/config $(DESTDIR)$(ulc)$(cgi)/js $(DESTDIR)$(ulc)$(cgi)/img $(DESTDIR)$(vcp)/Troglodyne/CGI $(DESTDIR)$(vcp)/Troglodyne/API $(DESTDIR)$(vca) $(DESTDIR)$(vct)/troglodyne/config $(DESTDIR)$(ulc)/whostmgr/docroot/addon_plugins
	install $(pwd)/templates/ui/pgupgrade.tmpl $(DESTDIR)$(ulc)$(tmpl)
	install $(pwd)/templates/config/main.default $(DESTDIR)$(vct)/troglodyne/config
	install $(pwd)/js/pgupgrade.js $(DESTDIR)$(ulc)$(cgi)/js
	install $(pwd)/img/troglophant.png $(DESTDIR)$(ulc)$(cgi)/img
	install $(pwd)/img/troglophant.png $(DESTDIR)$(ulc)/whostmgr/docroot/addon_plugins
	install $(pwd)/cgi/pgupgrade.cgi $(DESTDIR)$(ulc)$(cgi)
	install $(pwd)/cgi/api.cgi $(DESTDIR)$(ulc)$(cgi)
	install $(pwd)/lib/Troglodyne/CGI/PgUpgrade.pm $(DESTDIR)$(vcp)/Troglodyne/CGI
	install $(pwd)/lib/Troglodyne/CGI/API.pm $(DESTDIR)$(vcp)/Troglodyne/CGI
	install $(pwd)/lib/Troglodyne/CpPostgreSQL.pm $(DESTDIR)$(vcp)/Troglodyne
	install $(pwd)/lib/Troglodyne/API/Postgres.pm $(DESTDIR)$(vcp)/Troglodyne/API
	install $(pwd)/lib/Troglodyne/CGI.pm $(DESTDIR)$(vcp)/Troglodyne
	install $(pwd)/plugin/troglodyne_api.conf $(DESTDIR)$(vca)
	install $(pwd)/plugin/better_postgres.conf $(DESTDIR)$(vca)
	chmod 0755 $(DESTDIR)$(vca)
	chmod +x $(DESTDIR)$(ulc)$(cgi)/pgupgrade.cgi
	chmod +x $(DESTDIR)$(ulc)$(cgi)/api.cgi

register:
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


test-depend:
	perl -MTest2::V0 -MTest::MockModule -MFile::Temp -MCapture::Tiny -e 'exit 0' || sudo cpan -i Test2::V0 Test::MockModule File::Temp Capture::Tiny

test: test-depend
	prove -mv t/*.t

rpm:
	rm -rf SOURCES/*
	mkdir -p SOURCES/BetterPostgres4cP-1.0
	ln -s $(pwd)/bin SOURCES/BetterPostgres4cP-1.0/bin
	ln -s $(pwd)/cgi SOURCES/BetterPostgres4cP-1.0/cgi
	ln -s $(pwd)/img SOURCES/BetterPostgres4cP-1.0/img
	ln -s $(pwd)/install SOURCES/BetterPostgres4cP-1.0/install
	ln -s $(pwd)/js SOURCES/BetterPostgres4cP-1.0/js
	ln -s $(pwd)/lib SOURCES/BetterPostgres4cP-1.0/lib
	ln -s $(pwd)/plugin SOURCES/BetterPostgres4cP-1.0/plugin
	ln -s $(pwd)/t SOURCES/BetterPostgres4cP-1.0/t
	ln -s $(pwd)/templates SOURCES/BetterPostgres4cP-1.0/templates
	cp $(pwd)/Makefile SOURCES/BetterPostgres4cP-1.0/Makefile
	cp $(pwd)/configure SOURCES/BetterPostgres4cP-1.0/configure
	mkdir -p ~/rpmbuild/SOURCES
	cd SOURCES && tar --exclude="*.swp" --exclude="*.swn" --exclude="*.swo" -ch BetterPostgres4cP-1.0 | gzip > ~/rpmbuild/SOURCES/BetterPostgres4cP-1.0.tar.gz
	rpmbuild -ba --clean --target noarch SPECS/BetterPostgres.spec
	rm -rf SOURCES/*
