Hekate
===========

Crosslinking Coupled Mass Spectroscopy Data Analysis Software based on Hekate. The projects were forked at time of publication, Hekate will receive no updates except for bug fixes. 

(c) Andrew N Holding

License
---------

GNU GENERAL PUBLIC LICENSE Version 3

Installation
------------

This is a brief guide to how to install Hekate and assumes a working knowledge of Linux. It is recommended that Hekate is run on a fresh [Debian Linux](http://debian.org) installation and the the server is not accessible via the internet. 

Required packages not included in the standard Debian installation are:

* apache2
* git
* libparallel-forkmanager-perl
* libdbd-sqlite3-perl
* libchart-gnuplot-perl

These can be installed with 'apt-get' or 'aptitude'.

	apt-get install apache2 

Make and change to directory '/srv/www'. 

	mkdir /srv/www
	cd /srv/www

Use Git to obtain the latest version of Hekate and download it into the current directory. 

	git clone git://github.com/MRC-LMB-MassSpec/Hekate.git

Change ownership of the folder to www-data with chown.

	chown www-data:www-data /srv/www -R

Update Apache's default site file or create a new site definintion to point to the Hekate install.

	nano /etc/apache2/sites-available/default

	Change following lines:

	DocumentRoot /var/www to DocumentRoot /srv/www/Hekate/html

	<Directory /var/www/> to <Directory /srv/www/Hekate/html>

 	ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
 	<Directory "/usr/lib/cgi-bin">
 	
		to		

	ScriptAlias /cgi-bin/ /srv/www/Hekate/cgi-bin/
 	<Directory "/srv/www/Hekate/cgi-bin">

Restart the web server

	/etc/init.d/apache2 restart


You should be now able to access Hekate by connecting to the server with a webrowser.

	http://localhost/
