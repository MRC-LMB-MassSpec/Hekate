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
use Crosslinker::Results;
use Crosslinker::Constants;
use Crosslinker::Config;

########################
#                      #
# Import CGI Varibles  #
#                      #
########################

my $query = new CGI;
my $table = $query->param('table');

########################
#                      #
# Connect to database  #
#                      #
########################

my $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

   my $settings_sql = $settings_dbh->prepare( "SELECT name FROM settings WHERE name = ?" );
   $settings_sql->execute($table);
   my @data = $settings_sql->fetchrow_array();
   if (@data[0] != $table)
   {
    print "Content-Type: text/plain\n\n";
    print "Cannont find results database";
    exit;
    }

my $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results-$table",  "", "", { RaiseError => 1, AutoCommit => 1 } );

########################
#                      #
# Load Settings        #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT * FROM settings WHERE name = ?");
$settings->execute($table);

my ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished ) =
  $settings->fetchrow_array;
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
# Summary Gen          #
#                      #
########################

print "Content-type: text/csv\n";
print "Content-Disposition: attachment; filename=$table.csv\n";
print "Pragma: no-cache\n\n";

if ( $is_finished != '-1' ) {
   print "** Warning: Data analysis not finished **\n";
}

my $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? and SCORE > 0 ORDER BY score DESC");    #nice injection problem here, need to sort
$top_hits->execute($table);
print_results_text( $top_hits,      $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences,
                    $reactive_site, $results_dbh,      $xlinker_mass,      $mono_mass_diff,   $table,            0 );

$top_hits->finish();
$results_dbh->disconnect();
exit;
