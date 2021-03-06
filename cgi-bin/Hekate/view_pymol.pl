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

my $results_dbh = DBI->connect("dbi:SQLite:dbname=db/results-$table", "", "", { RaiseError => 1, AutoCommit => 1 });
########################
#                      #
# Load Settings        #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT * FROM settings WHERE name = ?");
$settings->execute($table);
my (
    $name,         $desc,  $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff,
    $xlinker_mass, $decoy, $ms2_da,       $ms1_ppm,           $is_finished
) = $settings->fetchrow_array;

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

if ($is_finished != -1) {
print "<div class='alert alert-error'>
  <h4>Warning</h4>Data Analysis not finished
</div>";
}

print '<div class="row"><div class="offset2 span8"><h4>Sample details</h4></div></div>';
print "<Table class='table offset2 table-striped span8'>
<tr><td style='font-weight: bold;'>Name</td><td>$name</td><td style='font-weight: bold;'>Description</td><td>$desc</td></tr>
<tr><td style='font-weight: bold;'>Cut</td><td>$cut_residues</td><td style='font-weight: bold;'>Xlink Site</td><td>$reactive_site</td></tr>
<tr><td style='font-weight: bold;'>Xlinker Mass</td><td>$xlinker_mass</td><td style='font-weight: bold;'>Monolink</td><td>$mono_mass_diff</td></tr></table>";

my $sequences = $results_dbh->prepare(
"SELECT DISTINCT seq FROM (Select distinct sequence1_name as seq, name from results where name=? union select distinct sequence2_name, name as seq from results WHERE name=?)"
);
$sequences->execute($table, $table);

print '<br/><div class="row"><div class="offset2 span8"><h4>Set Alignment Correction and Name</h4></div></div>
	<form name="input" action="" method="post">
	<table class="table offset2 tabel-strped span8">';
print '<input class="input-small" type="hidden" name="table" value="' . $table . '"/>';

my %error;
my %names;

while ((my $sequences_results = $sequences->fetchrow_hashref)) {

    if (defined $query->param(substr($sequences_results->{'seq'}, 1))) {
        $error{$name}{ substr($sequences_results->{'seq'}, 1) } = $query->param(substr($sequences_results->{'seq'}, 1));
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS pymol_settings (
								experiment,
								setting,
								value
								)"
        );
        $settings_dbh->do("CREATE UNIQUE INDEX IF NOT EXISTS pymol_index ON  pymol_settings (experiment, setting)");

        my $settings_sql = $settings_dbh->prepare("
					INSERT OR REPLACE INTO pymol_settings (experiment, setting, value)
					VALUES (?,?,?)");

        $settings_sql->execute($name,
                               substr($sequences_results->{'seq'}, 1),
                               $error{$name}{ substr($sequences_results->{'seq'}, 1) });

    } else {

        $error{$name}{ substr($sequences_results->{'seq'}, 1) } = $query->param(substr($sequences_results->{'seq'}, 1));
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS pymol_settings (
								experiment,
								setting,
								value
								)"
        );
        $settings_dbh->do("CREATE UNIQUE INDEX IF NOT EXISTS pymol_index ON  pymol_settings (experiment, setting)");

        my $settings_sql = $settings_dbh->prepare("SELECT value FROM pymol_settings WHERE experiment=? AND setting=?");
        $settings_sql->execute($name, substr($sequences_results->{'seq'}, 1));
        my $row = $settings_sql->fetch;

        if (exists $row->[0]) {
            my $error_value = $row->[0];
            $error{$name}{ substr($sequences_results->{'seq'}, 1) } = $row->[0];
        } else {
            $error{$name}{ substr($sequences_results->{'seq'}, 1) } = 0;
        }

    }

    if (defined $query->param(substr($sequences_results->{'seq'}, 1) . "_name")) {
        $names{$name}{ substr($sequences_results->{'seq'}, 1) } =
          $query->param(substr($sequences_results->{'seq'}, 1) . "_name");
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS pymol_settings (
								experiment,
								setting,
								value
								)"
        );
        $settings_dbh->do("CREATE UNIQUE INDEX IF NOT EXISTS pymol_index ON  pymol_settings (experiment, setting)");

        my $settings_sql = $settings_dbh->prepare("
					INSERT OR REPLACE INTO pymol_settings (experiment, setting, value)
					VALUES (?,?,?)");

        $settings_sql->execute($name,
                               substr($sequences_results->{'seq'}, 1) . "_name",
                               $names{$name}{ substr($sequences_results->{'seq'}, 1) });
    } else {
        my $settings_sql = $settings_dbh->prepare("SELECT value FROM pymol_settings WHERE experiment=? AND setting=?");
        $settings_sql->execute($name, substr($sequences_results->{'seq'}, 1) . "_name");
        my $row = $settings_sql->fetch;
        if (exists $row->[0]) {
            my $names_value = $row->[0];
            $names{$name}{ substr($sequences_results->{'seq'}, 1) } = $row->[0];
        } else {
            $names{$name}{ substr($sequences_results->{'seq'}, 1) } = substr($sequences_results->{'seq'}, 1);
        }
    }

    print '<tr><td><label class="checkbox inline">'
      . substr($sequences_results->{'seq'}, 1)
      . '</label></td><td><input class="input-small" type="text" name="'
      . substr($sequences_results->{'seq'}, 1)
      . '_name" value="'
      . $names{$name}{ substr($sequences_results->{'seq'}, 1) }
      . '"/></td><td><input ="input-small" type="text" name='
      . substr($sequences_results->{'seq'}, 1)
      . ' value="'
      . $error{$name}{ substr($sequences_results->{'seq'}, 1) }
      . '"/></td></tr>';
}
$settings->finish();
$settings_sql->finish();
$settings_dbh->disconnect();

print '</table><div class="row"><div class="span1 offset9"><input class="btn btn-primary" type="submit" value="Submit" /></div></div></from>';
$sequences->finish();

print '<div class="row"><div class="span8 offset2"><h4>Pymol Scripts</h4></div></div>';

print "<div style='row'><div class='offset2 span8'>";

my $top_hits;
if (defined $order) {
    $top_hits = $results_dbh->prepare(
"SELECT * FROM (SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score DESC) ORDER BY sequence1_name, sequence2_name"
    );    #nice injection problem here, need to sort
} else {
    $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score DESC");
}
$top_hits->execute($table);
print_pymol(
            $top_hits,         $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12,
            $mass_of_carbon13, $cut_residues,     $protein_sequences, $reactive_site,
            $results_dbh,      $xlinker_mass,     $mono_mass_diff,    $table,
            0,                 \%error,           \%names,            2
);

if (defined $order) {
    $top_hits = $results_dbh->prepare(
         "SELECT * FROM (SELECT * FROM results AND score > 0 WHERE name=?  ORDER BY score DESC) ORDER BY sequence1_name");     
} else {
    $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score DESC");   
}



$top_hits->execute($table);
print_pymol(
            $top_hits,         $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12,
            $mass_of_carbon13, $cut_residues,     $protein_sequences, $reactive_site,
            $results_dbh,      $xlinker_mass,     $mono_mass_diff,    $table,
            0,                 \%error,           \%names,            1
);

print "</div></div>";

print_page_bottom_bootstrap;
$top_hits->finish();
$results_dbh->disconnect();
exit;
