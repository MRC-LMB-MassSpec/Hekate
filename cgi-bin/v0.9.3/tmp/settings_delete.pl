#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;

use lib 'lib';
use Crosslinker::HTML;
use Crosslinker::Constants;
use Crosslinker::Data;
use Crosslinker::Config;

########################
#                      #
# Summary Gen          #
#                      #
########################

print_page_top_fancy("Settings");
my $version = version();

my $query = new CGI;

if ( !defined $query->param('ID') ) {
    print 'Required Information Not Supplied';
} else {
    my $dbh = connect_conf_db;
    delete_conf( $dbh, $query->param('ID') );
    print "<p>Setting deleted return to <a href='settings.pl?page=" . $query->param('type') . "s'>previous page?</a></p>";
}

print_page_bottom_fancy;
exit;
