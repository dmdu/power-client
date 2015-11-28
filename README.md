# power-client

power-client.sh is a BASH script, which allows obtaining power measurements for CloudLab resources.
 
Basic use: `/bin/bash power-client.sh -s [utah|wisconsin|clemson] -l X[h|d]` 

Or: 	   `/bin/bash power-client.sh --site [utah|wisconsin|clemson] --last X[h|d]` 

This will obtain the power data for the specified site for the last X days or hours and save it into `/var/log/power`.

To obtain power data for the entire site, do: 

`/bin/bash power-client.sh -s [utah|wisconsin|clemson] -l X[h|d] -e`
(add "-e" at the end)

To obtain power data for all three sites, do: `/bin/bash power-client.sh -l X[h|d] -a`

(add "-a" at the end; "-s [site]" can be omitted)

Maintainer: Dmitry Duplyakin (dmitry.duplyakin@colorado.edu)
