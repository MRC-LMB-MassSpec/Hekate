#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;

use lib 'lib';
use Crosslinker::Constants;

my $path = installed;



my $dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

my $query = new CGI;
my $table = $query->param('table');

my $table_list = $dbh->prepare( "SELECT name, desc, finished FROM settings WHERE name = ? ORDER BY length(name) DESC, name DESC " );
$table_list->execute($table);

my $table_name = $table_list->fetchrow_hashref;

my $state;


   if ( $table_name->{'finished'} == -1 ) {
      $state = 'Done';
   } elsif ( $table_name->{'finished'} == -2 ) {
      $state = 'Waiting...';
   } elsif ( $table_name->{'finished'} == -3 ) {
      $state = 'Starting...';
   } elsif ( $table_name->{'finished'} == -4 ) {
      $state = 'Aborted';
   } elsif ( $table_name->{'finished'} == -5 ) {
      $state = 'Failed';
   }


   else {
      $state = $table_name->{'finished'} * 100 . "%";
   }


if ( $table_name->{'finished'} > -1   ) {
   print "Refresh: 30\n";
} elsif ( $table_name->{'finished'} != -1 && $table_name->{'finished'} != -4  && $table_name->{'finished'} != -5){
   print "Refresh: 600\n";
}

print "Content-type: text/html\n\n";

print '<html>
<head>
<link rel="stylesheet" type="text/css" href="/'.  $path .'/css/xlink.css" media="screen">
<link rel="stylesheet" type="text/css" href="/' . $path . '/css/print.css" media="print">
</head>
<style type="text/css">
body {
  background: d0d0d0;
  overflow:hidden;
}
</style>
<body>';


   print $state;

print "</body></html>";