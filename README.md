Better PostgreSQL for cPanel & WHM
==================================

This Plugin aims to bring extended support for more recent PostgreSQL versions to cPanel & WHM.
The approach is very similar to what already exists for MySQL -- we will be installing from
community repositories which already build the server for CentOS.

INSTALLING
----------
Two methods exist for accomplishing installs.
### End user (stable) installs:
* Install the RPM:
`rpm -ivh $URL_I_HAVENT_GOT_YET_FOR_THE_RPM_RELEASE_HAHAHAHA`
* Enjoy. There should now be a "PostgreSQL Upgrade" page within WHM now for root under the 'Plugins' section.
* To uninstall:
`rpm -evh BetterPostgres4cP`
* To update to a newer version:
`rpm -Uvh $URL_I_HAVENT_GOT_YET_ROT_THE_RPM_RELEASE_HAHAHAHAH`

### Developer install:
* Clone the repository using the link in github:
`git clone https://github.com/Troglodyne-Internet-Widgets/better-postgres4cP.git`
* Move into the directory it cloned this to:
`cd better-postgres4cp`
* Run the makefile:
`make`
* To uninstall:
`make uninstall`

What do I do if I need help?
----------------------------
Go check out our FAQ/KB page [here](https://troglodyne.net/better-postgres-for-cpanel/).
If you can't find the answers you need, feel free to drop an issue in the tracker.

...and last of all, see license terms.

TODO
----
* Finish install.
* Ensure cpanel-ccs-calendarserver is compatible with all versions you can upgrade to.
* Testing. Lots of testing. Likely compatibility shims once upgraded.
* Copy rpmbuild artifacts to dist folder or whatever.
* Maybe a publish rule for yum repo?

Other Ambitions
---------------
Why not bring other useful extensions to postgres (like PostGIS)?
Why not facilitate clustering or at least PG connection pooling & remote PGSQL?
