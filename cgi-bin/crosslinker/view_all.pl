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

my $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results",  "", "", { RaiseError => 1, AutoCommit => 1 } );
my $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

########################
#                      #
# Load Settings        #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT * FROM settings WHERE name = ?");
$settings->execute($table);

my (
     $name,  $desc,   $cut_residues, $protein_sequences, $reactive_site,   $mono_mass_diff, $xlinker_mass,
     $decoy, $ms2_da, $ms1_ppm,      $is_finished,       $mass_seperation, $threshold,      $doublets_found,
     $match_charge,   $match_intensity,	$scored_ions
) = $settings->fetchrow_array;
$settings->finish();

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

print_page_top_fancy('All Results');

print "<Table>
<tr><td style='font-weight: bold;'>Name:</td><td>$name</td><td style='font-weight: bold;'>Description</td><td>$desc</td></tr>
<tr><td style='font-weight: bold;'>Cut:</td><td>$cut_residues</td><td style='font-weight: bold;'>Xlink Site</td><td>$reactive_site</td></tr>
<tr><td style='font-weight: bold;'>Xlinker Mass:</td><td>$xlinker_mass</td><td style='font-weight: bold;'>Monolink</td><td>$mono_mass_diff</td></tr>
<tr><td style='font-weight: bold;'>MS1 tollerance:</td><td>$ms1_ppm PPM</td><td style='font-weight: bold;'>MS2 tollerance</td><td>$ms2_da Da</td></tr>
<tr><td style='font-weight: bold;'>Threshold:</td><td>$threshold %</td><td style='font-weight: bold;'>Doublets Found: </td><td>$doublets_found </td></tr>
<tr><td style='font-weight: bold;'>Matched Charge:</td><td>$match_charge</td><td style='font-weight: bold;'>Matched Intensity: </td><td>$match_intensity</td></tr>
<tr><td style='font-weight: bold;'>Ions Scored:</td><td>$scored_ions</td><td style='font-weight: bold;'></td><td></td></tr>
</table>";


my $varible_mod_string = '';

print_heading('Dynamic Modifications');
print "<table>";
print "<tr><td>ID</td><td>Name</td><td>Mass</td><td>Residue</td></tr>";
my $dynamic_mods = get_mods( $table, 'dynamic' );
while ( ( my $dynamic_mod = $dynamic_mods->fetchrow_hashref ) ) {
   print
     "<tr><td>$dynamic_mod->{'mod_id'}</td><td>$dynamic_mod->{'mod_name'}</td><td>$dynamic_mod->{'mod_mass'}</td><td>$dynamic_mod->{'mod_residue'}</td></tr>";
   $varible_mod_string = $varible_mod_string . $dynamic_mod->{'mod_residue'} . ":" . $dynamic_mod->{'mod_mass'} . ",";
}
print "</table>";

my $static_mod_string = '';
print_heading('Fixed Modifications');
print "<table>";
print "<tr><td>ID</td><td>Name</td><td>Mass</td><td>Residue</td></tr>";
my $fixed_mods = get_mods( $table, 'fixed' );
while ( ( my $fixed_mod = $fixed_mods->fetchrow_hashref ) ) {
   print "<tr><td>$fixed_mod->{'mod_id'}</td><td>$fixed_mod->{'mod_name'}</td><td>$fixed_mod->{'mod_mass'}</td><td>$fixed_mod->{'mod_residue'}</td></tr>";
   $static_mod_string = $static_mod_string . $fixed_mod->{'mod_residue'} . ":" . $fixed_mod->{'mod_mass'} . ",";
}
print "</table>";

if ( $is_finished != '-1' ) {
   print '<div style="text-align:center"><h2 style="color:red;">Warning: Data analysis not finished</h2></div>';
}

print_heading('All Matches');
my $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND SCORE > 0 ORDER BY score+0 DESC");
$top_hits->execute($table);
print_results(
               $top_hits,          $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues,
               $protein_sequences, $reactive_site,    $results_dbh,       $xlinker_mass,     $mono_mass_diff,   $table,
               $mass_seperation,   0,                 0,                  0,                 0,                 1,
               $static_mod_string, $varible_mod_string
);
print_page_bottom_fancy;
$top_hits->finish();
$results_dbh->disconnect();
exit;
