Better PostgreSQL for cPanel & WHM
==================================

This Plugin aims to bring extended support for more recent PostgreSQL versions to cPanel & WHM.
The approach is very similar to what already exists for MySQL -- we will be installing from
community repositories which already build the server for CentOS.

If you like this plugin, consider sending a a few dollars this way:
https://paypal.me/troglodyne

INSTALLING
----------
Two methods exist for accomplishing installs.
### End user (stable) installs:
* Add the *Troglodyne* yum repository to `/etc/yum.repos.d/troglodyne`:
```
[troglodyne]
name=Troglodyne Internet Widgets
mirrorlist=https://repos.troglodyne.net/CentOS/7/$basearch/mirrorlist
enabled=1
```
* Install the RPM:
`yum install BetterPostgres4cP`
* Enjoy. There should now be a "PostgreSQL Upgrade" page within WHM now for root under the 'Plugins' section.
* To uninstall:
`yum remove BetterPostgres4cP`

This way whenever I make a new release you'll get it via `yum update` without any real hassle.

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

BUGS
----
* Once you upgrade postgres, the global cache for cPanel will no longer think PostgreSQL is installed. I am currently not aware of a way to fix this, but I am looking into it.

Other Ambitions
---------------
Why not bring other useful extensions to postgres (like PostGIS)?
Why not facilitate clustering or at least PG connection pooling & remote PGSQL?
