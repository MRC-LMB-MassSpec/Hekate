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

########################
#                      #
# Code	               #
#                      #
########################

my $query = new CGI;
my $table = $query->param('table');

my $results_dbh  = DBI->connect("dbi:SQLite:dbname=db/results",  "", "", { RaiseError => 1, AutoCommit => 1 });
my $settings_dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

print_page_top_fancy('Rename');

my $table_list = $settings_dbh->prepare(
                        "SELECT name, desc, finished FROM settings WHERE name=? ORDER BY length(name) DESC, name DESC");
$table_list->execute($table);

my $table_settings = $table_list->fetchrow_hashref;

if ($table_settings->{'finished'} != -1) {
    my $settings_sql = $settings_dbh->prepare("
					UPDATE settings 
					SET finished=-4
					WHERE name=?
					");
    $settings_sql->execute($table);
} else {

    print "<p>Can't abort, processing already finished!</p>";

}

print "<p>Return to <a href='results.pl'>results</a>?</p>";

print_page_bottom_fancy;
$results_dbh->disconnect();
exit;
