#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;

use lib 'lib';
use Crosslinker::HTML;
use Crosslinker::Data;

my $dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

my $table_list = $dbh->prepare("SELECT name, desc, finished FROM settings  ORDER BY length(name) DESC, name DESC ");
$table_list->execute();

if (is_ready($dbh) == -2)
{
    print "Refresh: 10\n";
}
print_page_top_fancy('Results');

print "<br/><table><tr><td colspan='4'>Results ID</td><td colspan='6'></td></tr>";

print '<form name="combined" action="view_combined.pl" method="GET">';

while ( my $table_name = $table_list->fetchrow_hashref ) {
    my $state;
    if ( $table_name->{'finished'} == -1 ) {
        $state = 'Done';
    } elsif ( $table_name->{'finished'} == -2 ) {
        $state = 'Waiting...';
    } elsif ( $table_name->{'finished'} == -3 ) {
        $state = 'Starting...';
    } elsif ( $table_name->{'finished'} == -4 ) {
        $state = 'Aborted';
    }

    else {
        $state = $table_name->{'finished'} * 100 . "%";
    }

    print '<tr><td><input type="checkbox" name="' . $table_name->{'name'} . '" value="true"></input></td><td>', $table_name->{'name'}, '</td><td><a href="rename.pl?table=' . $table_name->{'name'} . '">' . $table_name->{'desc'} . "</td><td>", $state, "</td><td> <a href='view_summary.pl?table=$table_name->{'name'}'>Summary</a> </td><td> <a href='view_pymol.pl?table=$table_name->{'name'}'>Pymol</a> </td><td> <a href='view_all.pl?table=$table_name->{'name'}' >Full</a> </td><td> <a href='view_report.pl?table=$table_name->{'name'}' >Report</a></td><td><a href='view_txt.pl?table=$table_name->{'name'}'>CSV</a></td><td><a href='delete.pl?table=$table_name->{'name'}' >Delete</a>/<a href='abort.pl?table=$table_name->{'name'}' >Abort</a></td></tr>";
}

print "</table>";

print '<div style="width: 20em; margin: auto; padding:1em;"> <input type="submit" value="Combine"> - <a href="view_log.pl">View Log</a>';
print ' - <a href="clear_log.pl">Clear Log</a></form></div>';
print_page_bottom_fancy;
$dbh->disconnect();
exit;
