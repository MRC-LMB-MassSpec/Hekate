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
use Crosslinker::Proteins;

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
# $settings_dbh->disconnect();

########################
#                      #
# Constants            #
#                      #
########################

my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length, $scan_width ) = constants;


sub print_results_paper {

    my ( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protien_sequences, $reactive_site, $dbh, $xlinker_mass, $mono_mass_diff, $table, $mass_seperation, $repeats, $scan_repeats,  $error_ref, $names_ref ) = @_;

    my $max_hits;
    my $no_tables;
   

    my %error         = %{$error_ref};
    my %names         = %{$names_ref};
    
    if ( !defined $max_hits ) { $max_hits  = 0 }
    if ( !$repeats )          { $repeats   = 0 }
    if ( !$no_tables )        { $no_tables = 0 }

    my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $table );

    my $fasta = $protien_sequences;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;

    my @hits_so_far;
    my @mz_so_far;
    my @scan_so_far;
    my $printed_hits = 0;

    if ( $no_tables == 0 ) {
        print '<table><tr><td></td><td>Chain 1</td><td>Chain 2</td><td>Position1</td><td>Position2</td><td>Fragment&nbsp;and&nbsp;Position</td><td>Score</td><td>Charge</td><td>Mass<td>PPM</td></td></td><td>Mod</td></tr>';
    }

    while ( ( my $top_hits_results = $top_hits->fetchrow_hashref ) && ( $max_hits == 0 || $printed_hits < $max_hits ) ) {
# 	if ($top_hits_results->{'fragment'} =~ '-')
#  	{
        if (    ( !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far ) && !( grep $_ eq $top_hits_results->{'mz'}, @mz_so_far ) && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far ) && $repeats == 0 )
             || ( $repeats == 1 && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far ) && $scan_repeats == 0 )
             || ( $repeats == 1 && $scan_repeats == 1 ) )
        {
            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'scan'};
            my $rounded = sprintf( "%.3f", $top_hits_results->{'ppm'} );
            print "<tr><td>", $printed_hits + 1, "</td>";
	    
	    my $flip_order = 0;
	    my @fragments            = split( '-', $top_hits_results->{'fragment'} );
            my @unmodified_fragments = split( '-', $top_hits_results->{'unmodified_fragment'} );
	
	     
	    
	    
            if ( $top_hits_results->{'fragment'} =~ '-' ) {
		if (substr( $top_hits_results->{'sequence1_name'}, 1 ) lt substr( $top_hits_results->{'sequence2_name'}, 1 ) ) {
		  print "<td>", substr( $top_hits_results->{'sequence1_name'}, 1 );
		  print " </td><td> ", substr( $top_hits_results->{'sequence2_name'}, 1 );
		} elsif (substr( $top_hits_results->{'sequence1_name'}, 1 ) gt substr( $top_hits_results->{'sequence2_name'}, 1 ) ) {
		  print "<td>", substr( $top_hits_results->{'sequence2_name'}, 1 );
		  print " </td><td> ", substr( $top_hits_results->{'sequence1_name'}, 1 );
		  $flip_order = 1;
 		} elsif ( substr( $top_hits_results->{'sequence1_name'}, 1 ) eq substr( $top_hits_results->{'sequence2_name'}, 1 )  && residue_position ($unmodified_fragments[0], $protien_sequences) > residue_position ($unmodified_fragments[1], $protien_sequences)) {
 		  $flip_order = 1;
		  print "<td>", substr( $top_hits_results->{'sequence2_name'}, 1 );
		  print " </td><td> ", substr( $top_hits_results->{'sequence1_name'}, 1 );
		} else {
		  print "<td>", substr( $top_hits_results->{'sequence1_name'}, 1 );
		  print " </td><td> ", substr( $top_hits_results->{'sequence2_name'}, 1 );
		  $flip_order = 0;
		}
            } else {
# 				print "<td>", substr( $top_hits_results->{'sequence1_name'}, 1 );
	    }
            print "</td>";

	     if ( $top_hits_results->{'fragment'} =~ '-' ) {
                $printed_hits = $printed_hits + 1;
                print "<td>";

		if ($flip_order == 0) {
		  print residue_position ($unmodified_fragments[0], $protien_sequences) + $top_hits_results->{'best_x'}+1+ $error{ substr( $top_hits_results->{'sequence1_name'}, 1 ) };
		  print "</td><td>"; #, $fragments[0], "&#8209;";
		  print residue_position ($unmodified_fragments[1], $protien_sequences) +$top_hits_results->{'best_y'}+ 1+ $error{ substr( $top_hits_results->{'sequence2_name'}, 1 ) };
# 		  print "."; #, $fragments[1] .
		  print "</td>";
#  <td> ", $top_hits_results->{'best_x'} + 1, "&#8209;", $top_hits_results->{'best_y'} + 1, "</td>";
		  print "<td>$unmodified_fragments[0]&#8209;$unmodified_fragments[1]</td>";
		  } else {
		  print residue_position ($unmodified_fragments[1], $protien_sequences) + $top_hits_results->{'best_y'} +1 + $error{ substr( $top_hits_results->{'sequence2_name'}, 1 ) };
		  print "</td><td>";#, $fragments[1], "&#8209;";
		  print residue_position ($unmodified_fragments[0], $protien_sequences) + $top_hits_results->{'best_x'} +1 + $error{ substr( $top_hits_results->{'sequence1_name'}, 1 ) };
# 		  print ".";#, $fragments[0] . 
		  print "</td>";
# <td> ", $top_hits_results->{'best_x'} + 1, "&#8209;", $top_hits_results->{'best_y'} + 1, "</td>";
		  print "<td>$unmodified_fragments[1]&#8209;$unmodified_fragments[0]</td>";
		  }
            } else {
                $printed_hits = $printed_hits + 1;
                print "<td>";
                print residue_position $unmodified_fragments[0], $protien_sequences;
#                 print ".", $fragments[0];
                print "&nbsp;</td><td></td><td>", $top_hits_results->{'best_x'} + 1, "</a></td>";
            }
	    print "<td>$top_hits_results->{'score'}</td><td>$top_hits_results->{'mz'}</td><td>$top_hits_results->{'charge'}+</td><td>$rounded</td>";
            print "<td>";
            if ( $top_hits_results->{'no_of_mods'} > 1 ) {
                print "$top_hits_results->{'no_of_mods'} x";
            }
            print " $modifications{$top_hits_results->{'modification'}}{Name}</td>";
            
# 	    print "<td> $top_hits_results->{'fraction'}</td><td>";
#             print "<a  href='view_img.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>$top_hits_results->{'scan'}</a> <br/><a  href='view_img.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1'>$top_hits_results->{'d2_scan'}</a>";
#             print "</td><td>";
            

            print "</td></tr>";
        }
	}
#     }
    print '</table>';

}




########################
#                      #
# Summary Gen          #
#                      #
########################

print_page_top_fancy('All Results');
print_heading('Sorted Crosslink Data');

my $sequences = $results_dbh->prepare("SELECT DISTINCT seq FROM (Select distinct sequence1_name as seq, name from results where name=? union select distinct sequence2_name, name as seq from results WHERE name=?)");
$sequences->execute( $table, $table );

print '<br/><form name="input" action="" method="post"><table>';
print '<tr><td style="font-weight: bold;" colspan="3">Set Alignment Correction and Name:</td></tr>';
print '<input type="hidden" name="table" value="' . $table . '"/>';

my $settings = $settings_dbh->prepare("SELECT * FROM settings WHERE name = ?");
$settings->execute($table);
my ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished ) = $settings->fetchrow_array;


my %error;
my %names;

while ( ( my $sequences_results = $sequences->fetchrow_hashref ) ) {

    if ( defined $query->param( substr( $sequences_results->{'seq'}, 1 ) ) ) {
        $error{ substr( $sequences_results->{'seq'}, 1 ) } = $query->param( substr( $sequences_results->{'seq'}, 1 ) );
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS pymol_settings (
								experiment,
								setting,
								value
								)"
        );
        $settings_dbh->do("CREATE UNIQUE INDEX IF NOT EXISTS pymol_index ON  pymol_settings (experiment, setting)");

        my $settings_sql = $settings_dbh->prepare( "
					INSERT OR REPLACE INTO pymol_settings (experiment, setting, value)
					VALUES (?,?,?)" );

        $settings_sql->execute( $name, substr( $sequences_results->{'seq'}, 1 ), $error{ substr( $sequences_results->{'seq'}, 1 ) } );

    } else {

        $error{ substr( $sequences_results->{'seq'}, 1 ) } = $query->param( substr( $sequences_results->{'seq'}, 1 ) );
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS pymol_settings (
								experiment,
								setting,
								value
								)"
        );
        $settings_dbh->do("CREATE UNIQUE INDEX IF NOT EXISTS pymol_index ON  pymol_settings (experiment, setting)");

        my $settings_sql = $settings_dbh->prepare("SELECT value FROM pymol_settings WHERE experiment=? AND setting=?");
        $settings_sql->execute( $name, substr( $sequences_results->{'seq'}, 1 ) );
        my $row = $settings_sql->fetch;

        if ( exists $row->[0] ) {
            my $error_value = $row->[0];
            $error{ substr( $sequences_results->{'seq'}, 1 ) } = $row->[0];
        } else {
            $error{ substr( $sequences_results->{'seq'}, 1 ) } = 0;
        }

    }

    if ( defined $query->param( substr( $sequences_results->{'seq'}, 1 ) . "_name" ) ) {
        $names{ substr( $sequences_results->{'seq'}, 1 ) } = $query->param( substr( $sequences_results->{'seq'}, 1 ) . "_name" );
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS pymol_settings (
								experiment,
								setting,
								value
								)"
        );
        $settings_dbh->do("CREATE UNIQUE INDEX IF NOT EXISTS pymol_index ON  pymol_settings (experiment, setting)");

        my $settings_sql = $settings_dbh->prepare( "
					INSERT OR REPLACE INTO pymol_settings (experiment, setting, value)
					VALUES (?,?,?)" );

        $settings_sql->execute( $name, substr( $sequences_results->{'seq'}, 1 ) . "_name", $names{ substr( $sequences_results->{'seq'}, 1 ) } );
    } else {
        my $settings_sql = $settings_dbh->prepare("SELECT value FROM pymol_settings WHERE experiment=? AND setting=?");
        $settings_sql->execute( $name, substr( $sequences_results->{'seq'}, 1 ) . "_name" );
        my $row = $settings_sql->fetch;
        if ( exists $row->[0] ) {
            my $names_value = $row->[0];
            $names{ substr( $sequences_results->{'seq'}, 1 ) } = $row->[0];
        } else {
            $names{ substr( $sequences_results->{'seq'}, 1 ) } = substr( $sequences_results->{'seq'}, 1 );
        }
    }

    print '<tr><td>' . substr( $sequences_results->{'seq'}, 1 ) . '</td><td><input type="text" name="' . substr( $sequences_results->{'seq'}, 1 ) . '_name" value="' . $names{ substr( $sequences_results->{'seq'}, 1 ) } . '"/></td><td><input type="text" name=' . substr( $sequences_results->{'seq'}, 1 ) . ' value="' . $error{ substr( $sequences_results->{'seq'}, 1 ) } . '"/></td></tr>';
}
$settings->finish();
$settings_dbh->disconnect();

print '<tr><td colspan="3"><input type="submit" value="Submit" /></td></tr></table></from>';
$sequences->finish();

if ( $is_finished != '-1' ) { print '<div style="text-align:center"><h2 style="color:red;">Warning: Data analysis not finished</h2></div>'; }

my $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND fragment LIKE '%-%' AND SCORE > 0 ORDER BY score+0 DESC");    
$top_hits->execute($table);
print_results_paper ( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences, $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, $table, $mass_seperation, 0, 0 , \%error, \%names);


# my $top_hits = $results_dbh->prepare("SELECT * FROM results WHERE name=? AND fragment NOT LIKE '%-%' AND SCORE > 0 ORDER BY score+0 DESC");    
# $top_hits->execute($table);
# print_results_paper ( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences, $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, $table, $mass_seperation, 0, 0 , \%error, \%names);


print_page_bottom_fancy;
$top_hits->finish();
$results_dbh->disconnect();
exit;
