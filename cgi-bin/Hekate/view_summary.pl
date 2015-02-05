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

my $order;

if (defined $query->param('order')) {
    $order = $query->param('order');
}


my $short = 1;
if (defined $query->param('more')) {
    $short = 0;
}

########################
#                      #
# Connect to database  #
#                      #
########################

my $settings_dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

my $settings_sql = $settings_dbh->prepare("SELECT name FROM settings WHERE name = ?");
$settings_sql->execute($table);
my @data = $settings_sql->fetchrow_array();
if ($data[0] != $table) {
    print "Content-Type: text/plain\n\n";
    print "Cannont find results database";
    exit;
}
$settings_sql->finish();

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
    $threshold,    $doublets_found, $match_charge, $match_intensity,   $scored_ions,   $amber,
    $time, 	   $proteinase_k,   $no_enzyme_min,$no_enzyme_max
    
) = $settings->fetchrow_array;


$settings->finish();
$settings_dbh->disconnect();

if (defined $query->param('decoy')) { $decoy = $query->param('decoy') }

########################
#                      #
# Connect to results DB#
#                      #
########################

my $results_dbh = DBI->connect("dbi:SQLite:dbname=db/results-$name", "", "", { RaiseError => 1, AutoCommit => 1 });

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

print_page_top_bootstrap('Summary');


print_heading('Results');

if ($is_finished != '-1') {
print "<div class='alert alert-error'>
  <h4>Warning</h4>Data Analysis not finished
</div>";

}

print "<br/><h4>Settings</h4>";

if   (defined $decoy && $decoy eq "true") { $decoy = "Yes" }
else                                      { $decoy = "No" }

print "<Table class='table table-striped'>
<tr><td style='font-weight: bold;'>Name:</td><td>$name</td><td style='font-weight: bold;'>Description</td><td>$desc</td></tr>";
if ($proteinase_k == 0) { print "<tr><td style='font-weight: bold;'>Cut:</td><td>$cut_residues</td>";} else { print "<tr><td style='font-weight: bold;'>Cut:</td><td>No Enzyme</td>";}
print " <td style='font-weight: bold;'>Xlink Site</td><td>$reactive_site</td></tr>
<tr><td style='font-weight: bold;'>Xlinker Mass:</td><td>$xlinker_mass</td><td style='font-weight: bold;'>Monolink</td><td>$mono_mass_diff</td></tr>
<tr><td style='font-weight: bold;'>MS1 tollerance:</td><td>$ms1_ppm PPM</td><td style='font-weight: bold;'>MS2 tollerance</td><td>$ms2_da Da</td></tr>
<tr><td style='font-weight: bold;'>Threshold:</td><td>$threshold %</td><td style='font-weight: bold;'>Doublets Found: </td><td>$doublets_found </td></tr>
<tr><td style='font-weight: bold;'>Matched Charge:</td><td>$match_charge</td><td style='font-weight: bold;'>Matched Intensity: </td><td>$match_intensity</td></tr>
<tr><td style='font-weight: bold;'>Ions Scored:</td><td>$scored_ions</td><td style='font-weight: bold;'>Decoy</td><td>$decoy</td></tr>
</table>";

my $varible_mod_string = '';

print "<h4>Dynamic Modifications</h4>";
print "<table class='table table-striped'>";
print "<tr><td>ID</td><td>Name</td><td>Mass</td><td>Residue</td></tr>";
my $dynamic_mods = get_mods($table, 'dynamic');
while ((my $dynamic_mod = $dynamic_mods->fetchrow_hashref)) {
    print
"<tr><td>$dynamic_mod->{'mod_id'}</td><td>$dynamic_mod->{'mod_name'}</td><td>$dynamic_mod->{'mod_mass'}</td><td>$dynamic_mod->{'mod_residue'}</td></tr>";
    $varible_mod_string = $varible_mod_string . $dynamic_mod->{'mod_residue'} . ":" . $dynamic_mod->{'mod_mass'} . ",";
}
print "</table>";

my $static_mod_string = '';
print "<h4>Fixed Modifications</h4>";
print "<table class='table table-striped'>";
print "<tr><td>ID</td><td>Name</td><td>Mass</td><td>Residue</td></tr>";
my $fixed_mods = get_mods($table, 'fixed');
while ((my $fixed_mod = $fixed_mods->fetchrow_hashref)) {
    print
"<tr><td>$fixed_mod->{'mod_id'}</td><td>$fixed_mod->{'mod_name'}</td><td>$fixed_mod->{'mod_mass'}</td><td>$fixed_mod->{'mod_residue'}</td></tr>";
    $static_mod_string = $static_mod_string . $fixed_mod->{'mod_residue'} . ":" . $fixed_mod->{'mod_mass'} . ",";
}
print "</table>";

if ($short == 1) {
    print '<h4 class="inline">Top Scoring Crosslink Matches</h4> <a class="btn btn-primary offset10 span1" href="view_summary.pl?table=' . $name . '&more=1">View all</a><br/><br/>';
} else {
    print '<h4>Crosslink Matches</h4>';
}
my $top_hits;
if (defined $order) {
    $top_hits = $results_dbh->prepare(
"SELECT * FROM (SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score DESC) ORDER BY sequence1_name, sequence2_name "
    );
} else {
    $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score  DESC")
      ;    # min (best_alpha,best_beta)
}
$top_hits->execute($table);
print_results(
              $top_hits,         $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12,
              $mass_of_carbon13, $cut_residues,     $protein_sequences, $reactive_site,
              $results_dbh,      $xlinker_mass,     $mono_mass_diff,    $table,
              $mass_seperation,  0,                 0,                  0,
              50 * $short,       0,                 $static_mod_string, $varible_mod_string,
              2,                 $decoy
);

if ($short == 1) {
    print '<h4>Top Scoring Monolink Matches</h4> <a class="btn btn-primary offset10 span1" href="view_summary.pl?table=' . $name . '&more=1">View all</a><br/><br/>';
} else {
    print '<h4>Monolink Matches</h4>';
}
if (defined $order) {
    $top_hits = $results_dbh->prepare(
         "SELECT * FROM (SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score DESC) ORDER BY sequence1_name");    
} else {
    $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score DESC");   
}

$top_hits->execute($table);
print_results(
              $top_hits,         $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12,
              $mass_of_carbon13, $cut_residues,     $protein_sequences, $reactive_site,
              $results_dbh,      $xlinker_mass,     $mono_mass_diff,    $table,
              $mass_seperation,  0,                 0,                  0,
              50 * $short,       1,                 $static_mod_string, $varible_mod_string,
              1,                 $decoy
);

print_page_bottom_bootstrap;
$top_hits->finish();
$results_dbh->disconnect();
exit;
