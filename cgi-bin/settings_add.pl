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

if ( !defined $query->param('type') ) {
   print 'Required Information Not Supplied';
} elsif ( $query->param('type') eq 'enzyme' ) {

   my $dbh = connect_conf_db;
   add_conf( $dbh, $query->param('type'), $query->param('name'), $query->param('setting1'), $query->param('setting2'), 0, 0, 0 );

   print "<p>Setting added return to <a href='settings.pl?page=" . $query->param('type') . "s'>previous page?</a></p>";

} elsif ( $query->param('type') eq 'sequence' ) {

   my $dbh = connect_conf_db;
   add_conf( $dbh, $query->param('type'), $query->param('name'), $query->param('setting1'), 0, 0, 0, 0 );

   print "<p>Setting added return to <a href='settings.pl?page=" . $query->param('type') . "s'>previous page?</a></p>";

} elsif ( $query->param('type') eq 'crosslinker' ) {

   my $dbh = connect_conf_db;
   add_conf( $dbh,                      $query->param('type'),     $query->param('name'),     $query->param('setting1'),
             $query->param('setting2'), $query->param('setting3'), $query->param('setting4'), $query->param('setting5') );

   print "<p>Setting added return to <a href='settings.pl?page=" . $query->param('type') . "s'>previous page?</a></p>";

} elsif ( $query->param('type') eq 'fixed_mod' ) {

   my $dbh = connect_conf_db;
   add_conf( $dbh, $query->param('type'), $query->param('name'), $query->param('setting1'), $query->param('setting2'), 0, 0, 0 );

   print "<p>Setting added return to <a href='settings.pl?page=" . $query->param('type') . "s'>previous page?</a></p>";

} elsif ( $query->param('type') eq 'dynamic_mod' ) {

   my $dbh = connect_conf_db;
   add_conf( $dbh, $query->param('type'), $query->param('name'), $query->param('setting1'), $query->param('setting2'), $query->param('setting3'), 0, 0 );

   print "<p>Setting added return to <a href='settings.pl?page=" . $query->param('type') . "s'>previous page?</a></p>";

}

print_page_bottom_fancy;
exit;
