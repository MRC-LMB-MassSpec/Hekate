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

my $settings_dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

my $settings_sql = $settings_dbh->prepare("SELECT name FROM settings WHERE name = ?");
$settings_sql->execute($table);
my @data = $settings_sql->fetchrow_array();
if (@data[0] != $table) {
    print "Content-Type: text/plain\n\n";
    print "Cannont find results database";
    exit;
}

my $results_dbh = DBI->connect("dbi:SQLite:dbname=db/results-$table", "", "", { RaiseError => 1, AutoCommit => 1 });

########################
#                      #
# Load Settings        #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT * FROM settings WHERE name = ?");
$settings->execute($table);
my (
    $name,         $desc,           $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff,
    $xlinker_mass, $decoy,          $ms2_da,       $ms1_ppm,           $is_finished,   $mass_seperation,
    $threshold,    $doublets_found, $match_charge, $match_intensity,   $scored_ions
) = $settings->fetchrow_array;
$settings->finish();
$settings_dbh->disconnect();

########################
#                      #
# Constants            #
#                      #
########################

my (
    $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton,     $mass_of_carbon12,
    $mass_of_carbon13,  $no_of_fractions,  $min_peptide_length, $scan_width
) = constants;

########################
#                      #
# Summary Gen          #
#                      #
########################

print_page_top('Report');

if   (defined $decoy && $decoy eq "true") { $decoy = "Yes" }
else                                      { $decoy = "No" }

print "<Table>
<tr><td style='font-weight: bold;'>Name:</td><td>$name</td><td style='font-weight: bold;'>Description</td><td>$desc</td></tr>
<tr><td style='font-weight: bold;'>Cut:</td><td>$cut_residues</td><td style='font-weight: bold;'>Xlink Site</td><td>$reactive_site</td></tr>
<tr><td style='font-weight: bold;'>Xlinker Mass:</td><td>$xlinker_mass</td><td style='font-weight: bold;'>Monolink</td><td>$mono_mass_diff</td></tr>
<tr><td style='font-weight: bold;'>MS1 tollerance:</td><td>$ms1_ppm PPM</td><td style='font-weight: bold;'>MS2 tollerance</td><td>$ms2_da Da</td></tr>
<tr><td style='font-weight: bold;'>Threshold:</td><td>$threshold %</td><td style='font-weight: bold;'>Doublets Found: </td><td>$doublets_found </td></tr>
<tr><td style='font-weight: bold;'>Matched Charge:</td><td>$match_charge</td><td style='font-weight: bold;'>Matched Intensity: </td><td>$match_intensity</td></tr>
<tr><td style='font-weight: bold;'>Ions Scored:</td><td>$scored_ions</td><td style='font-weight: bold;'>Decoy</td><td>$decoy</td></tr>
</table>";

if ($is_finished != '-1') {
    print '<div style="text-align:center"><h2 style="color:red;">Warning: Data analysis not finished '
      . $is_finished
      . '</h2></div>';
}

my $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND fragment LIKE '%-%' ORDER BY score DESC");
$top_hits->execute($table);
print_report(
             $top_hits,       $mass_of_hydrogen,  $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13,
             $cut_residues,   $protein_sequences, $reactive_site,     $results_dbh,      $xlinker_mass,
             $mono_mass_diff, $table,             1
);

print_page_bottom;
$top_hits->finish();
$results_dbh->disconnect();
exit;
