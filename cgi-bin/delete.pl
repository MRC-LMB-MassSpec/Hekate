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

my $query      = new CGI;
my $table      = $query->param('table');
my $areyousure = $query->param('areyousure');

########################
#                      #
# Drop Table!          #
#                      #
########################

my $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results",  "", "", { RaiseError => 1, AutoCommit => 1 } );
my $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

print_page_top_fancy('Delete');

if ( $areyousure eq 'yes' ) {
   my $drop_table = $settings_dbh->prepare("DELETE FROM settings WHERE name = ?");
   $drop_table->execute($table);
   $drop_table = $settings_dbh->prepare("DELETE FROM modifications WHERE run_id = ?");
   $drop_table->execute($table);
   $drop_table = $results_dbh->prepare("DELETE FROM results WHERE name = ?");
   $drop_table->execute($table);
   print_heading("Deleting $table ...");
   print "<p>Sucess: Results '$table' deleted.</p>";
} else {
   print "<p>Are you sure you want to delete $table?</p>";
   print "<p><a href='delete.pl?table=$table&areyousure=yes'>Yes</a>  or <a href='results.pl'>No</a></p>";
}
print_page_bottom_fancy;
$results_dbh->disconnect();
exit;
