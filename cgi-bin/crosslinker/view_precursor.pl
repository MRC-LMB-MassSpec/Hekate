#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;

# use CGI::Carp qw ( fatalsToBrowser );
use DBI;
use Chart::Gnuplot;

use lib 'lib';
use Crosslinker::HTML;
use Crosslinker::Links;
use Crosslinker::Scoring;
use File::Temp qw/ tempfile tempdir /;
use Crosslinker::Constants;

########################
#                      #
# Import CGI Varibles  #
#                      #
########################

my $query    = new CGI;
my $table    = $query->param('table');
my $scan     = $query->param('scan');
my $parent_mass     = $query->param('mass');

########################
#                      #
# Connect to database  #
#                      #
########################
my $results_dbh;
my $settings_dbh;

if ($scan == -1) {
  $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results_single",  "", "", { RaiseError => 1, AutoCommit => 1 } );
  $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings_single", "", "", { RaiseError => 1, AutoCommit => 1 } );
} else {
 
   $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );  

   my $settings_sql = $settings_dbh->prepare( "SELECT name FROM settings WHERE name = ?" );
   $settings_sql->execute($table);
   my @data = $settings_sql->fetchrow_array();
   if ($data[0] != $table)
   {
    print "Content-Type: text/plain\n\n";
    print "Cannont find results database";
    exit;
    }
    $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results-$table",  "", "", { RaiseError => 1, AutoCommit => 1 } );

}



########################
#                      #
# Image	  Gen          #
#                      #
########################

  print "Content-Type: image/svg+xml\n\n";

#    print "Content-Type: text/plain\n\n";

my $top_hits;


   $top_hits =
   $results_dbh->prepare( "SELECT * FROM msdata WHERE scan_num = ?" ); 
   $top_hits->execute( $scan);


my $top_hits_results = $top_hits->fetchrow_hashref();

my $data;
my $top_10;
my @masses;
my $title;


$data   = $top_hits_results->{'MSn_string'};
@masses = split "\n", $data;



my $chart = Chart::Gnuplot->new(
                                 terminal   => 'svg',
				 encoding   => 'utf8',
#                                  output    => $filename,
                                 imagesize  => '1024, 768',
                                 xlabel     => "m/z",
                                 ylabel     => "relative abundance",
                                 tmargin    => "5",
                                 title      => "$title",
				 termoption => 'enhanced'
);

$chart->gnuplot('/usr/bin/gnuplot');

my @ions =  ( [ $parent_mass -10 , 1 ], [ $parent_mass + 10, 2 ] );

foreach my $mass_abundance (@masses) {
   my ( $mass, $abundance ) = split "\t", $mass_abundance;
   $mass =~ s/0*$//;

      if ($mass > $parent_mass - 10 && $mass < $parent_mass + 10) 
#        print $mass, $abundance;
	{push( @ions, [ $mass, $abundance ] )};
}

# foreach my $mass_abundance (@masses) {
#   my ($mass, $abundance) = split " ", $mass_abundance;
#   push(@unmatched,[$mass, $abundance]);
#
# }

my $impulses =
  Chart::Gnuplot::DataSet->new(
				title  => 'ions',
                                points => \@ions,
                                color  => 'black',
                                style  => "impulses",
  );

#Plot the graph
binmode STDOUT;
$chart->svg;

$chart->plot2d( $impulses );

# seek $fh, 0, 0;
# 
# while (<$fh>) {
#    print "$_";
# }

$top_hits->finish();
$results_dbh->disconnect();

exit;
