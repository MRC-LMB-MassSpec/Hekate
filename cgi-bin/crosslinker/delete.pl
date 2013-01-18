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

my $settings_dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

print_page_top_bootstrap('Delete');

my $settings_sql = $settings_dbh->prepare("SELECT name FROM settings WHERE name = ?");
$settings_sql->execute($table);
my @data = $settings_sql->fetchrow_array();
if ($data[0] != $table) {
    print "<p> Cannont find results database </p>";
    print_page_bottom_fancy;
    exit;
}

my $results_dbh = DBI->connect("dbi:SQLite:dbname=db/results-$table ", "", "", { RaiseError => 1, AutoCommit => 1 });

$settings_sql = $settings_dbh->prepare("SELECT finished FROM settings WHERE name = ?");
$settings_sql->execute($table);
@data = $settings_sql->fetchrow_array();

if ($data[0] != -1 && $data[0] != -4 && $data[0] != -5) {
    print
"<p>Cannot currently delete that search as it is currently in progress. If you wish to delete this search then please abort it first.</p>";
} elsif (defined $areyousure && $areyousure eq 'yes') {
    my $drop_table = $settings_dbh->prepare("DELETE FROM settings WHERE name = ?");
    $drop_table->execute($table);
    $drop_table = $settings_dbh->prepare("DELETE FROM modifications WHERE run_id = ?");
    $drop_table->execute($table);
    $drop_table = $results_dbh->prepare("DROP TABLE IF EXISTS results");
    $drop_table->execute();
    $results_dbh->disconnect();
    unlink "db/results-$table" or die "Can't delete $table : $!";
    warn "mooooo";
    unlink "query_data/query-$table.txt" or die "Can't delete $table : $!";
    print_heading("Deleting $table ...");
    print "<p>Sucess: Results '$table' deleted.</p>";
} else {

    #    print $data[0];
    print "<p>Are you sure you want to delete $table?</p>";
    print "<p><a class='btn btn-danger' href='delete.pl?table=$table&areyousure=yes'>Yes</a>  or <a class='btn' href='results.pl'>No</a></p>";
    $results_dbh->disconnect();
}
print_page_bottom_bootstrap;
exit;
