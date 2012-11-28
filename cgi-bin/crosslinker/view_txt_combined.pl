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
my @table;

my $order;

if ( defined $query->param('order') ) {
   $order = $query->param('order');
}

########################
#                      #
# Connect to database  #
#                      #
########################

my $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

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

my $settings = $settings_dbh->prepare("SELECT name FROM settings");
$settings->execute();
my $combined_tables;

print "Content-type: text/plain\n";
print "Content-Disposition: attachment; filename=combined.csv\n";
print "Pragma: no-cache\n\n";

while ( ( my $data_set = $settings->fetchrow_hashref ) ) {
   if ( defined $query->param( $data_set->{'name'} ) ) {
      push @table, $data_set->{'name'};
   }
}

my $results_dbh;

my $SQL_query;
for ( my $table_no = 0 ; $table_no < @table ; $table_no++ ) {

  my $settings_sql = $settings_dbh->prepare( "SELECT name FROM settings WHERE name = ?" );
   $settings_sql->execute($table[$table_no]);
   my @data = $settings_sql->fetchrow_array();
   if (@data[0] != $table[$table_no])
   {
    print "Content-Type: text/plain\n\n";
    print "Cannont find results database";
    exit;
    }

  if (!defined $results_dbh) {  $results_dbh= DBI->connect( "dbi:SQLite:dbname=db/results-$table[$table_no]",  "", "", { RaiseError => 1, AutoCommit => 1 } )}
   my $sql_attach_command =  "attach database './db/results-$table[$table_no]' as db$table[$table_no]";
   $results_dbh->do ( $sql_attach_command);
   $SQL_query = $SQL_query . "SELECT * FROM settings WHERE name = ? UNION ";
}
$SQL_query = substr( $SQL_query, 0, -6 );

$settings = $settings_dbh->prepare($SQL_query);
$settings->execute(@table);

my ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished );
my $protein_sequences_combined;
while ( ( my @settings = $settings->fetchrow_array ) ) {
   ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished ) = @settings;
   $protein_sequences_combined = $protein_sequences_combined . $protein_sequences;
   if ( $is_finished != '-1' ) {
      print "****Warning: Data analysis not finished - $name ****";
   }
}

$settings->finish();
$settings_dbh->disconnect();

my $top_hits;
$SQL_query = "";


print "\nCrosslinks\n";
for ( my $table_no = 0 ; $table_no < @table ; $table_no++ ) {
   $SQL_query = $SQL_query . "SELECT * FROM db$table[$table_no].results WHERE name=? AND score > 0 UNION ALL ";
}
$SQL_query = substr( $SQL_query, 0, -10 );
$top_hits = $results_dbh->prepare( "SELECT * FROM (" . $SQL_query . ") ORDER BY score DESC " );    #nice injection problem here, need to sort
$top_hits->execute(@table);
print_results_text( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences_combined,
                    $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, 'table', 0, 2, 0 );

print "\nMonolinks\n";
$top_hits->execute(@table);
print_results_text( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences_combined,
                    $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, 'table', 0, 1, 0 );

$top_hits->finish();
$results_dbh->disconnect();
exit;
