#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;

use lib 'lib';
use Crosslinker::Constants;

my $path = installed;

my $dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

my $query = new CGI;
my $table = $query->param('table');

my $table_list =
  $dbh->prepare("SELECT name, desc, finished FROM settings WHERE name = ? ORDER BY length(name) DESC, name DESC ");
$table_list->execute($table);

my $table_name = $table_list->fetchrow_hashref;

my $state;

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


if ($table_name->{'finished'} > -1 || $table_name->{'finished'} > -6 ) {
    print "Refresh: 30\n";
} elsif ($table_name->{'finished'} != -1 && $table_name->{'finished'} != -4 && $table_name->{'finished'} != -5) {
    print "Refresh: 600\n";
}

print "Content-type: text/html\n\n";

print '<html>
<head>
 <link href="/'.$path.'/bootstrap/css/bootstrap.css" rel="stylesheet"> 
 <link href="/'.$path.'/bootstrap/css/bootstrap-responsive.css" rel="stylesheet">
</head>
<style type="text/css">
body {
  background:none transparent;
  overflow:hidden;
  margin: 0 0 0 0;
}
</style>
<body><div style="text-align:left"';

print $state;

print "</div></body></html>";
