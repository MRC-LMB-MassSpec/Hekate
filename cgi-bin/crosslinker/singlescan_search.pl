#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use POSIX 'setsid';
use lib 'lib';
use Crosslinker::Constants;
use Crosslinker::HTML;
# use Digest::MD5  qw(md5_hex);



   # Import CGI Varibles
   my $query = new CGI;
   $CGI::POST_MAX = 1024 * 50000;

#    warn "Started\n";


   use DBI;

   use lib 'lib';
   use Crosslinker::Links;
   use Crosslinker::HTML;
   use Crosslinker::Data;
   use Crosslinker::Proteins;
   use Crosslinker::Scoring;
   use Crosslinker::Config;
   use Crosslinker::Results;

print_page_top_fancy("Scan Search");
my $version = version();
print_heading('Scan Search');

   # Constants
   my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length ) =
     constants;

   # Connect to databases
   my ( $dbh, $results_dbh, $settings_dbh ) = connect_db_single; 

   my (
        $protien_sequences, $sequence_names_ref, $missed_clevages,       $upload_filehandle_ref, $csv_filehandle_ref, $reactive_site,
        $cut_residues,      $nocut_residues,     $fasta,                 $desc,                  $decoy,              $match_ppm,
        $ms2_error,         $mass_seperation,    $isotope,               $seperation,            $mono_mass_diff,     $xlinker_mass,
        $dynamic_mods_ref,  $fixed_mods_ref,     $ms2_fragmentation_ref, $threshold,		 $n_or_c,	      $scan_width,
	$match_charge,	    $match_intensity,    $scored_ions,		 $no_xlink_at_cut_site
   ) = import_cgi_query( $query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12 );


   my @sequence_names    = @{$sequence_names_ref};
   my @upload_filehandle = @{$upload_filehandle_ref};
   my @csv_filehandle    = @{$csv_filehandle_ref};
   my @dynamic_mods      = @{$dynamic_mods_ref};
   my @fixed_mods        = @{$fixed_mods_ref};
   my %ms2_fragmentation = %{$ms2_fragmentation_ref};

   my $light_scan = $query->param("light_scan");
   my $heavy_scan = $query->param("heavy_scan");
   my $precursor_charge = $query->param("precursor_charge");
   my $precursor_mass = $query->param("precursor_mass");

  # Generate Results Name
  my $results_table = find_free_tablename $settings_dbh;

#   my $link_code = md5_hex( $results_table );
  my $time = time;


   # Save Settings
   my $state = is_ready($settings_dbh);
   save_settings( $settings_dbh, $results_table, $cut_residues, $fasta,     $reactive_site,   $mono_mass_diff, $xlinker_mass, $state,
                  $desc,         $decoy,         $ms2_error,    $match_ppm, $mass_seperation, \@dynamic_mods,  \@fixed_mods,  $threshold,
		  $match_charge, $match_intensity, $scored_ions);

   # Setup Modifications

   my %protein_residuemass = protein_residuemass($results_table, $settings_dbh);
   my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $results_table, $settings_dbh );
   #Output page

   $state = generate_page_single_scan(
                           $protien_sequences,  $dbh,              $results_dbh,      $settings_dbh,   $results_table,      $no_of_fractions,
                           \@upload_filehandle, \@csv_filehandle,  $missed_clevages,  $cut_residues,   $nocut_residues,     \%protein_residuemass,
                           $reactive_site,      $scan_width,       \@sequence_names,  $match_ppm,      $min_peptide_length, $mass_of_deuterium,
                           $mass_of_hydrogen,   $mass_of_carbon13, $mass_of_carbon12, \%modifications, $query,              $mono_mass_diff,
                           $xlinker_mass,       $isotope,          $seperation,       $ms2_error,      $state,              \%ms2_fragmentation,
                           $threshold,		$n_or_c, 	   $match_charge,     $match_intensity,$no_xlink_at_cut_site,
			   $light_scan,		$heavy_scan,	   $precursor_charge, $precursor_mass, $mass_seperation, $mass_of_proton 
   );




my $varible_mod_string = '';
my $dynamic_mods = get_mods( $results_table, 'dynamic', $settings_dbh );
while ( ( my $dynamic_mod = $dynamic_mods->fetchrow_hashref ) ) {
   $varible_mod_string = $varible_mod_string . $dynamic_mod->{'mod_residue'} . ":" . $dynamic_mod->{'mod_mass'} . ",";
}

my $static_mod_string = '';
my $fixed_mods = get_mods( $results_table, 'fixed' , $settings_dbh);
while ( ( my $fixed_mod = $fixed_mods->fetchrow_hashref ) ) {
   $static_mod_string = $static_mod_string . $fixed_mod->{'mod_residue'} . ":" . $fixed_mod->{'mod_mass'} . ",";
}




   my $top_hits = $results_dbh->prepare( "SELECT * FROM results WHERE name=? AND score > 0 ORDER BY score DESC" );  
   $top_hits->execute($results_table);

print_heading('Results');

   print_results(
               $top_hits,          $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues,
               $fasta, $reactive_site,    $results_dbh,       $xlinker_mass,     $mono_mass_diff,   $results_table,
               $mass_seperation,   1,                 1,                  0,                 0,       1,
               $static_mod_string, $varible_mod_string, 0		 ,$decoy,		1, $settings_dbh
);

   #Tidy up

   disconnect_db( $dbh, $settings_dbh, $results_dbh );

print_page_bottom_fancy;
exit;

