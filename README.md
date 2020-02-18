Better PostgreSQL for cPanel & WHM
==================================

This Plugin aims to bring extended support for more recent PostgreSQL versions to cPanel & WHM.
The approach is very similar to what already exists for MySQL -- we will be installing from
community repositories which already build the server for CentOS.

The Plan
--------
* Add UI page for facilitating upgrades. Mimic the MySQL/MariaDB upgrade page,
  as this is what customers would expect.
* Implement the "bone stock" path in the UI as well, have it be default option
  for install.
* Testing. Lots of testing.

Other Ambitions
---------------
Why not bring other useful extensions to postgres (like PostGIS)?
Why not facilitate clustering or at least PG connection pooling?

Copyright
---------
For now, this code is Copyright 2020 Thomas A. Baugh.
Unauthorized copying is prohibited until such time I consider re-licensing this code.
