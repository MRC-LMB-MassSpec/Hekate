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
use Crosslinker::Config;

########################
#                      #
# Import CGI Varibles  #
#                      #
########################

my $query = new CGI;
my $table = $query->param('table');

my $order;

if ( defined $query->param('order') ) {
    $order = $query->param('order');
}

my $short = 1;
if ( defined $query->param('more') ) {
    $short = 0;
}

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
my ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished, $mass_seperation, $threshold, $doublets_found ) = $settings->fetchrow_array;
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

print_page_top_fancy('Summary');

if ( $is_finished != '-1' ) { print '<div style="text-align:center"><h2 style="color:red;">Warning: Data analysis not finished</h2></div>'; }

print_heading('Settings');

print "<Table>
<tr><td style='font-weight: bold;'>Name:</td><td>$name</td><td style='font-weight: bold;'>Description</td><td>$desc</td></tr>
<tr><td style='font-weight: bold;'>Cut:</td><td>$cut_residues</td><td style='font-weight: bold;'>Xlink Site</td><td>$reactive_site</td></tr>
<tr><td style='font-weight: bold;'>Xlinker Mass:</td><td>$xlinker_mass</td><td style='font-weight: bold;'>Monolink</td><td>$mono_mass_diff</td></tr>
<tr><td style='font-weight: bold;'>MS1 tollerance:</td><td>$ms1_ppm PPM</td><td style='font-weight: bold;'>MS2 tollerance</td><td>$ms2_da Da</td></tr>
<tr><td style='font-weight: bold;'>Threshold:</td><td>$threshold %</td><td style='font-weight: bold;'>Doublets Found: </td><td>$doublets_found </td></tr>
</table>";

my $varible_mod_string ='';

print_heading('Dynamic Modifications');
print "<table>";
print "<tr><td>ID</td><td>Name</td><td>Mass</td><td>Residue</td></tr>";
my $dynamic_mods = get_mods( $table, 'dynamic' );
while ( ( my $dynamic_mod = $dynamic_mods->fetchrow_hashref ) ) {
    print "<tr><td>$dynamic_mod->{'mod_id'}</td><td>$dynamic_mod->{'mod_name'}</td><td>$dynamic_mod->{'mod_mass'}</td><td>$dynamic_mod->{'mod_residue'}</td></tr>";
    $varible_mod_string = $varible_mod_string . $dynamic_mod->{'mod_residue'}. ":". $dynamic_mod->{'mod_mass'}. ",";
}
print "</table>";

my $static_mod_string ='';
print_heading('Fixed Modifications');
print "<table>";
print "<tr><td>ID</td><td>Name</td><td>Mass</td><td>Residue</td></tr>";
my $fixed_mods = get_mods( $table, 'fixed' );
while ( ( my $fixed_mod = $fixed_mods->fetchrow_hashref ) ) {
    print "<tr><td>$fixed_mod->{'mod_id'}</td><td>$fixed_mod->{'mod_name'}</td><td>$fixed_mod->{'mod_mass'}</td><td>$fixed_mod->{'mod_residue'}</td></tr>";
    $static_mod_string = $static_mod_string . $fixed_mod->{'mod_residue'}. ":". $fixed_mod->{'mod_mass'}. ",";
}
print "</table>";

if ( $short == 1 ) {
    print_heading( 'Top Scoring Crosslink Matches <a href="view_summary.pl?table=' . $name . '&more=1">View all</a>' );
} else {
    print_heading('Crosslink Matches');
}
my $top_hits;
if ( defined $order ) {
    $top_hits = $results_dbh->prepare("SELECT * FROM (SELECT * FROM results WHERE name=? AND fragment LIKE '%-%' ORDER BY score DESC) ORDER BY sequence1_name, sequence2_name");    #nice injection problem here, need to sort
} else {
    $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND fragment LIKE '%-%' ORDER BY score DESC");                                                            #nice injection problem here, need to sort
}
$top_hits->execute($table);
print_results( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences, $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, $table, $mass_seperation, 0, 0, 0, 50 * $short,0, $static_mod_string,$varible_mod_string );

if ( $short == 1 ) {
    print_heading( 'Top Scoring Monolink Matches <a href="view_summary.pl?table=' . $name . '&more=1">View all</a>' );
} else {
    print_heading('Monolink Matches');
}
if ( defined $order ) {
    $top_hits = $results_dbh->prepare("SELECT * FROM (SELECT * FROM results WHERE name=? AND fragment NOT LIKE '%-%' ORDER BY score DESC) ORDER BY sequence1_name");                #nice injection problem here, need to sort
} else {
    $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND fragment NOT LIKE '%-%' ORDER BY score DESC");                                                        #nice injection problem here, need to sort
}

$top_hits->execute($table);
print_results( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences, $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, $table, $mass_seperation, 0, 0, 0, 50 * $short, 1, $static_mod_string,$varible_mod_string);

print_page_bottom_fancy;
$top_hits->finish();
$results_dbh->disconnect();
exit;
