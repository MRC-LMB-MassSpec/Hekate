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

print_page_top_bootstrap("Settings");
my $version    = version();
my $query      = new CGI;
my $areyousure = $query->param('areyousure');

if (!defined $query->param('ID')) {
    print 'Required Information Not Supplied';
} elsif (defined $areyousure && $areyousure eq 'yes') {
    my $dbh = connect_conf_db;
    delete_conf($dbh, $query->param('ID'));
    print "<p>Setting deleted return to <a href='settings.pl?page="
      . $query->param('type')
      . "s'>previous page?</a></p>";
} else {
    print "<p>Are you sure you want to delete this " . $query->param('type') . "?</p>";
    print "<p><a class='btn btn-danger' href='settings_delete.pl?ID="
      . $query->param('ID')
      . "&type="
      . $query->param('type')
      . "&areyousure=yes'>Yes</a>  or <a class='btn' href='settings.pl?page="
      . $query->param('type')
      . "s'>No</a></p>";
}

print_page_bottom_bootstrap;
exit;
