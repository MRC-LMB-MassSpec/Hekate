#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;

use lib 'lib';
use Crosslinker::HTML;
use Crosslinker::Data;

my $dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

create_settings($dbh);

my $table_list = $dbh->prepare("SELECT name, desc, finished FROM settings  ORDER BY length(name) DESC, name DESC ");
$table_list->execute();


print_page_top_bootstrap('Results');

print_heading('Results');
print "<br/><table class='table table-striped'><tr><td colspan='4'>Results ID</td><td colspan='7'></td></tr>";

print '<form name="combined" action="view_combined.pl" method="GET">';

while (my $table_name = $table_list->fetchrow_hashref) {
    my $state;
    if ($table_name->{'finished'} == -1) {
        $state = '<span class="label label-success">Done</span>';
    } elsif ($table_name->{'finished'} == -2) {
        $state = '<span class="label">Waiting...</span>';
    } elsif ($table_name->{'finished'} == -3) {
        $state = '<span class="label label-info">Starting...</span>';
    } elsif ($table_name->{'finished'} == -4) {
        $state = '<span class="label label-warning">Aborted</span>';
    } elsif ($table_name->{'finished'} == -5) {
        $state = '<span class="label label-important">Failed</span>';
    } elsif ($table_name->{'finished'} == -6) {
        $state = '<span class="label label-info">Importing...</span>';
    }

    else {
        $state =  '<span class="label">' . $table_name->{'finished'} * 100 . "%</span>";
    }

    print '<tr><td><input type="checkbox" name="' . $table_name->{'name'} . '" value="true"></input></td><td>',
      $table_name->{'name'},
      '</td><td><a href="rename.pl?table=' . $table_name->{'name'} . '">' . $table_name->{'desc'} . "</td><td>";

#     if ($table_name->{'finished'} != -1 && $table_name->{'finished'} != -4 && $table_name->{'finished'} != -5) {
#         print '<iframe style="border: 0px; width:8em; height:1.29em; overflow-y: hidden;" src="status-iframe.pl?table=',
#           $table_name->{'name'}, '">', $state, '</iframe>',
#           ;
#     } else {
        print $state;
#     }

    print
"</td><td> <a href='view_summary.pl?table=$table_name->{'name'}'>Summary</a> </td><td> <a href='view_pymol.pl?table=$table_name->{'name'}'>Pymol</a> </td><td> <a href='view_paper.pl?table=$table_name->{'name'}'>Sorted</a> </td><td> <a href='view_all.pl?table=$table_name->{'name'}' >Full</a> </td><td> <a href='view_report.pl?table=$table_name->{'name'}' >Report</a></td><td><a href='view_txt.pl?table=$table_name->{'name'}'>CSV</a></td><td><a class='btn btn-danger' href='delete.pl?table=$table_name->{'name'}' >Delete</a> <a class='btn btn-warning' href='abort.pl?table=$table_name->{'name'}' >Abort</a></td></tr>";
}

print "</table>";

print
'<div style="width: 20em; margin: auto; padding:1em;"> <input class="btn btn-primary" type="submit" value="Combine">&nbsp<a class="btn" href="view_log.pl">View Log</a>';
print '&nbsp<a class="btn" href="clear_log.pl">Clear Log</a></form></div>';
print_page_bottom_bootstrap;
$dbh->disconnect();
exit;
