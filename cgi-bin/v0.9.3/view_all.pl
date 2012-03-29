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
use Crosslinker::Links;
use Crosslinker::Scoring;
use Crosslinker::Constants;

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

my $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results",  "", "", { RaiseError => 1, AutoCommit => 1 } );
my $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

########################
#                      #
# Load Settings        #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT * FROM settings WHERE name = ?");
$settings->execute($table);

my ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished, $mass_seperation ) = $settings->fetchrow_array;

$settings->finish();
$settings_dbh->disconnect();

########################
#                      #
# Constants            #
#                      #
########################

my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length, $scan_width ) = constants;

########################
#                      #
# Summary Gen          #
#                      #
########################

print_page_top_fancy('All Results');

if ( $is_finished != '-1' ) { print '<div style="text-align:center"><h2 style="color:red;">Warning: Data analysis not finished</h2></div>'; }

print_heading('All Matches');
my $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND SCORE > 0 ORDER BY score+0 DESC");    
$top_hits->execute($table);
print_results( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences, $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, $table, $mass_seperation, 1, 0 ,0,0,1);

print_page_bottom_fancy;
$top_hits->finish();
$results_dbh->disconnect();
exit;
