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

if (defined $query->param('order')) {
    $order = $query->param('order');
}

########################
#                      #
# Connect to database  #
#                      #
########################

my $settings_dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

########################
#                      #
# Constants            #
#                      #
########################

my (
    $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton,     $mass_of_carbon12,
    $mass_of_carbon13,  $no_of_fractions,  $min_peptide_length, $scan_width
) = constants;
my %protein_residuemass = protein_residuemass();

########################
#                      #
# Summary Gen          #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT name FROM settings");
$settings->execute();
my $combined_tables;
my $param;

while ((my $data_set = $settings->fetchrow_hashref)) {
    if (defined $query->param($data_set->{'name'})) {
        push @table, $data_set->{'name'};
        $param = $param . "&$data_set->{'name'}=true";
    }
}

my $results_dbh;

my $SQL_query;
for (my $table_no = 0 ; $table_no < @table ; $table_no++) {

    my $settings_sql = $settings_dbh->prepare("SELECT name FROM settings WHERE name = ?");
    $settings_sql->execute($table[$table_no]);
    my @data = $settings_sql->fetchrow_array();
    if (@data[0] != $table[$table_no]) {
        print "Content-Type: text/plain\n\n";
        print "Cannont find results database";
        exit;
    }

    $SQL_query = $SQL_query . "SELECT * FROM settings WHERE name = ? UNION ";
    if (!defined $results_dbh) {
        $results_dbh =
          DBI->connect("dbi:SQLite:dbname=db/results-$table[$table_no]", "", "", { RaiseError => 1, AutoCommit => 1 });
    }
    my $sql_attach_command = "attach database './db/results-$table[$table_no]' as db$table[$table_no]";
    $results_dbh->do($sql_attach_command);
}

print_page_top_bootstrap('Summary');

$SQL_query = substr($SQL_query, 0, -6);

$settings = $settings_dbh->prepare($SQL_query);
$settings->execute(@table);

my %error;
my %names;

foreach my $table_name (@table) {
    my $sequences = $results_dbh->prepare(
"SELECT DISTINCT seq FROM (Select distinct sequence1_name as seq, name from db$table_name.results where name=? union select distinct sequence2_name, name as seq from results WHERE name=?)"
    );
    $sequences->execute($table_name, $table_name);
    while ((my $sequences_results = $sequences->fetchrow_hashref)) {
        my $settings_sql = $settings_dbh->prepare("SELECT value FROM pymol_settings WHERE experiment=? AND setting=?");
        $settings_sql->execute($table_name, substr($sequences_results->{'seq'}, 1));
        my $row = $settings_sql->fetch;

        if (exists $row->[0]) {
            my $error_value = $row->[0];
            $error{$table_name}{ substr($sequences_results->{'seq'}, 1) } = $row->[0];
        } else {
            $error{$table_name}{ substr($sequences_results->{'seq'}, 1) } = 0;
        }
        $settings_sql = $settings_dbh->prepare("SELECT value FROM pymol_settings WHERE experiment=? AND setting=?");
        $settings_sql->execute($table_name, substr($sequences_results->{'seq'}, 1) . "_name");
        $row = $settings_sql->fetch;
        if (exists $row->[0]) {
            my $names_value = $row->[0];
            $names{$table_name}{ substr($sequences_results->{'seq'}, 1) } = $row->[0];
        } else {
            $names{$table_name}{ substr($sequences_results->{'seq'}, 1) } = substr($sequences_results->{'seq'}, 1);
        }
    }
}

print_heading('Combined Results');

my %mass_seperation_hash;

print "<br/><h4>Settings</h4>";

my (
    $name,         $desc,  $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff,
    $xlinker_mass, $decoy, $ms2_da,       $ms1_ppm,           $is_finished,   $mass_seperation
);
my $protein_sequences_combined;
print "<table class='table table-striped'>";

while ((my @settings = $settings->fetchrow_array)) {
    (
     $name,         $desc,  $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff,
     $xlinker_mass, $decoy, $ms2_da,       $ms1_ppm,           $is_finished,   $mass_seperation
    ) = @settings;
    $protein_sequences_combined = $protein_sequences_combined . $protein_sequences;
    $mass_seperation_hash{$name} = $mass_seperation;

if ($is_finished != '-1') {
print "<div class='alert alert-error'>
  <h4>Warning</h4>Data Analysis not finished
</div>";

}

    print "
<tr><td style='font-weight: bold;'>Name:</td><td>$name</td><td style='font-weight: bold;'>Description</td><td>$desc</td></tr>
<tr><td style='font-weight: bold;'>Cut:</td><td>$cut_residues</td><td style='font-weight: bold;'>Xlink Site</td><td>$reactive_site</td></tr>
<tr><td style='font-weight: bold;'>Xlinker Mass:</td><td>$xlinker_mass</td><td style='font-weight: bold;'>Monolink</td><td>$mono_mass_diff</td></tr>
<tr><td style='font-weight: bold;'>MS1 tollerance:</td><td>$ms1_ppm PPM</td><td style='font-weight: bold;'>MS2 tollerance</td><td>$ms2_da Da</td></tr>
";

}
print "</table>";

$settings->finish();
$settings_dbh->disconnect();

print "<br/><h4>Crosslink Matches</h4>";
my $top_hits;
$SQL_query = "";

if (defined $order) {
    for (my $table_no = 0 ; $table_no < @table ; $table_no++) {
        $SQL_query = $SQL_query
          . "SELECT * FROM (SELECT * FROM db$table[$table_no].results WHERE name=? ORDER BY score DESC) UNION ALL ";
    }
    $SQL_query = substr($SQL_query, 0, -10);
    $top_hits = $results_dbh->prepare($SQL_query . " ORDER BY sequence1_name, sequence2_name LIMIT 50"); 
} else {
    for (my $table_no = 0 ; $table_no < @table ; $table_no++) {
        $SQL_query =
          $SQL_query . "SELECT * FROM db$table[$table_no].results WHERE name=? AND fragment LIKE '%-%' UNION ALL ";
    }
    $SQL_query = substr($SQL_query, 0, -10);
    $top_hits = $results_dbh->prepare("SELECT * FROM (" . $SQL_query . ") ORDER BY score DESC ");    
}
$top_hits->execute(@table);
print_pymol(
            $top_hits,         $mass_of_hydrogen, $mass_of_deuterium,          $mass_of_carbon12,
            $mass_of_carbon13, $cut_residues,     $protein_sequences_combined, $reactive_site,
            $results_dbh,      $xlinker_mass,     $mono_mass_diff,             \%mass_seperation_hash,
            0,                 \%error,           \%names,                     2
);

$SQL_query = "";
print "<br/><h4>Monolink Matches</h4>";
if (defined $order) {
    for (my $table_no = 0 ; $table_no < @table ; $table_no++) {
        $SQL_query = $SQL_query . "SELECT * FROM (SELECT * FROM results WHERE name=?  ORDER BY score DESC) UNION ALL ";
    }
    $SQL_query = substr($SQL_query, 0, -10);
    $top_hits = $results_dbh->prepare($SQL_query . " ORDER BY sequence1_name, sequence2_name"); 
} else {
    for (my $table_no = 0 ; $table_no < @table ; $table_no++) {
        $SQL_query = $SQL_query . "SELECT * FROM results WHERE name=? AND fragment NOT LIKE '%-%' UNION ALL ";
    }
    $SQL_query = substr($SQL_query, 0, -10);
    $top_hits = $results_dbh->prepare($SQL_query . " ORDER BY score DESC"); 
}
$top_hits->execute(@table);
print_pymol(
            $top_hits,         $mass_of_hydrogen, $mass_of_deuterium,          $mass_of_carbon12,
            $mass_of_carbon13, $cut_residues,     $protein_sequences_combined, $reactive_site,
            $results_dbh,      $xlinker_mass,     $mono_mass_diff,             \%mass_seperation_hash,
            0,                 \%error,           \%names,                     1
);

print_page_bottom_bootstrap;
$top_hits->finish();
$results_dbh->disconnect();
exit;
