#!/usr/bin/perl -w
use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use POSIX 'setsid';
use lib 'lib';
use Crosslinker::Constants;



   # Import CGI Varibles
   my $query = new CGI;
   $CGI::POST_MAX = 1024 * 50000;

   use DBI;

   use lib 'lib';
   use Crosslinker::Links;
   use Crosslinker::HTML;
   use Crosslinker::Data;
   use Crosslinker::Proteins;
   use Crosslinker::Scoring;
   use Crosslinker::Config;

print_page_top_fancy("Crosslink Digest");
my $version = version();
print_heading('Results');

   # Constants
   my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length ) =
     constants;

   # Connect to databases
   my ( $dbh, $results_dbh, $settings_dbh ) = connect_db;

   # Generate Results Name
   my $results_table = find_free_tablename $dbh; #No need to use settings_dbh as we can just dump it at the end of the run
  

   my (
        $protien_sequences, $sequence_names_ref, $missed_clevages,       $upload_filehandle_ref, $csv_filehandle_ref, $reactive_site,
        $cut_residues,      $nocut_residues,     $fasta,                 $desc,                  $decoy,              $match_ppm,
        $ms2_error,         $mass_seperation,    $isotope,               $seperation,            $mono_mass_diff,     $xlinker_mass,
        $dynamic_mods_ref,  $fixed_mods_ref,     $ms2_fragmentation_ref, $threshold,		 $n_or_c,	      $scan_width
   ) = import_cgi_query( $query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12 );

   my @sequence_names    = @{$sequence_names_ref};
   my @upload_filehandle = @{$upload_filehandle_ref};
   my @csv_filehandle    = @{$csv_filehandle_ref};
   my @dynamic_mods      = @{$dynamic_mods_ref};
   my @fixed_mods        = @{$fixed_mods_ref};
   my %ms2_fragmentation = %{$ms2_fragmentation_ref};

   save_settings( $dbh, $results_table, $cut_residues, $fasta,     $reactive_site,   $mono_mass_diff, $xlinker_mass, 1,
                  $desc,         $decoy,         $ms2_error,    $match_ppm, $mass_seperation, \@dynamic_mods,  \@fixed_mods,  $threshold );

   my %protein_residuemass = protein_residuemass($results_table);
   my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $results_table, $dbh );

   #Output page

    crosslink_digest(
                            $protien_sequences,  $dbh,              $dbh,      $dbh,   $results_table,      $no_of_fractions,
                            \@upload_filehandle, \@csv_filehandle,  $missed_clevages,  $cut_residues,   $nocut_residues,     \%protein_residuemass,
                            $reactive_site,      $scan_width,       \@sequence_names,  $match_ppm,      $min_peptide_length, $mass_of_deuterium,
                            $mass_of_hydrogen,   $mass_of_carbon13, $mass_of_carbon12, \%modifications, $query,              $mono_mass_diff,
			      $xlinker_mass,       $isotope,          $seperation,       $ms2_error,      1,              \%ms2_fragmentation,
                            $threshold,		$n_or_c,	$query->param('max_peptide_mass'), $query->param('min_peptide_mass')
    );

   disconnect_db( $dbh, $settings_dbh, $results_dbh );

  print_page_bottom_fancy;

exit;

