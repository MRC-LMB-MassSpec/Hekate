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
use Crosslinker::Constants;
use File::Temp qw / tempfile tempdir/;

$ENV{GDFONTPATH} = '/usr/share/fonts/';

########################
#                      #
# Import CGI Varibles  #
#                      #
########################

my $query    = new CGI;
my $table    = $query->param('table');
my $scan     = $query->param('scan');
my $d2_scan  = $query->param('d2_scan');
my $fraction = $query->param('fraction');
my $score    = $query->param('score');



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
  $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results-$table",  "", "", { RaiseError => 1, AutoCommit => 1 } );
  $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );
}
#######################
#                     #
# Gen Temp File       #
#                     #
#######################

my ( $fh, $filename ) = tempfile();

########################
#                      #
# Load Settings        #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT * FROM settings WHERE name = ?");
$settings->execute($table);
my ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $is_finished ) = $settings->fetchrow_array;
$settings->finish();
$settings_dbh->disconnect();

########################
#                      #
# Constants            #
#                      #
########################

my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length, $scan_width ) =
  constants;

########################
#                      #
# Image	  Gen          #
#                      #
########################

print "Content-Type: image/png\n\n";

my $top_hits;
if ( defined $d2_scan && $d2_scan ne '' ) {
   $top_hits = $results_dbh->prepare( "SELECT * FROM results WHERE name=? AND scan = ? AND d2_scan = ? AND fraction = ? AND score = ?  " )
     ;    #nice injection problem here, need to sort
   $top_hits->execute( $table, $scan, $d2_scan, $fraction, $score );
} else {
   $top_hits =
     $results_dbh->prepare( "SELECT * FROM results WHERE name=? AND scan = ? AND fraction = ? AND score = ?  " );    #nice injection problem here, need to sort
   $top_hits->execute( $table, $scan, $fraction, $score );
}

my $top_hits_results = $top_hits->fetchrow_hashref();

my $data;
my $top_10;
my @masses;

if ( $query->param('heavy') == 0 ) {
   $data   = $top_hits_results->{'MSn_string'};
   $top_10 = $top_hits_results->{'top_10'};
   @masses = split "\n", $data;
} else {
   $data   = $top_hits_results->{'d2_MSn_string'};
   $top_10 = $top_hits_results->{'d2_top_10'};
   @masses = split "\n", $data;
}

# Chart object
my $chart = Chart::Gnuplot->new(
                                 terminal  => 'png',
                                 output    => $filename,
                                 imagesize => '320, 240',
                                 xtics     => { labelfmt => '', },
                                 ytics     => { labelfmt => '', },
);

$chart->gnuplot('/usr/bin/gnuplot');

my @unmatched = ( [ 1, 1 ], [ 2, 2 ] );
my @bions     = ( [ 1, 1 ] );
my @yions     = ( [ 1, 1 ] );
my @waterions = ( [ 1, 1 ] );

foreach my $mass_abundance (@masses) {
   my ( $mass, $abundance ) = split " ", $mass_abundance;
   $mass =~ s/0*$//;

   if ( $top_10 =~ /$mass\<br\/\>/ ) {

      $top_10 =~ m/(.);(Y|A|B)<sub>(\d*)<\/sub><sup>(\d)\+<\/sup> = $mass/;

      my $chain;
      if ( defined $1 ) {
         if   ( $1 eq '&#945' ) { $chain = 'a' }
         else                   { $chain = 'b' }
         if ( $2 eq 'Y' ) {
            push( @yions, [ $mass, $abundance ] );

         } elsif ( $2 eq 'A' || $2 eq 'B' ) {
            push( @bions, [ $mass, $abundance ] );    #a-ions get stuck with b-ions

            #  		print  "$chain $mass $2$3($4+) Th\n ";

         }
      } else    #Would rather a Y or B/A drawn before drawing a water loss...
      {
         $top_10 =~ m/(.);(Y\[-H2O]|A\[-H2O]|B\[-H2O])<sub>(\d*)<\/sub><sup>(\d)\+<\/sup> = $mass/;
         if   ( defined $1 && $1 eq '&#945' ) { $chain = 'a' }
         else                                 { $chain = 'b' }
         if ( defined $2
              && ( $2 eq 'A[-H2O]' || $2 eq 'B[-H2O]' || $2 eq 'Y[-H2O]' ) )
         {
            push( @waterions, [ $mass, $abundance ] );

         }
      }

   } else {
      push( @unmatched, [ $mass, $abundance ] );
   }
}

# foreach my $mass_abundance (@masses) {
#   my ($mass, $abundance) = split " ", $mass_abundance;
#   push(@unmatched,[$mass, $abundance]);
#
# }

my $impulses =
  Chart::Gnuplot::DataSet->new(
                                points => \@unmatched,
                                color  => 'black',
                                style  => "impulses",
  );

my $impulses2 =
  Chart::Gnuplot::DataSet->new(
                                points => \@bions,
                                color  => 'red',
                                style  => "impulses",
  );

my $impulses3 =
  Chart::Gnuplot::DataSet->new(
                                points => \@yions,
                                color  => 'green',
                                style  => "impulses",
  );

my $impulses4 =
  Chart::Gnuplot::DataSet->new(
                                points => \@waterions,
                                color  => 'blue',
                                style  => "impulses",
  );

# Plot the graph
binmode STDOUT;
$chart->svg;
$chart->plot2d( $impulses, $impulses2, $impulses3, $impulses4 );

seek $fh, 0, 0;

while (<$fh>) {
   print "$_";
}

$top_hits->finish();
$results_dbh->disconnect();
exit;
