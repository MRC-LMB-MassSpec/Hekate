#!/usr/bin/perl -w
######################################################
#   ____                   _ _       _               #
#  / ___|_ __ ___  ___ ___| (_)_ __ | | _____ _ __   #
# | |   | '__/ _ \/ __/ __| | | '_ \| |/ / _ \ '__|  #
# | |___| | | (_) \__ \__ \ | | | | |   <  __/ |     #
#  \____|_|  \___/|___/___/_|_|_| |_|_|\_\___|_|     #
#                                                    #
######################################################

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use POSIX 'setsid';
use lib 'lib';
use Crosslinker::Constants;
use Crosslinker::HTML;

$SIG{CHLD} = 'IGNORE';
defined( my $child = fork ) or die "Cannot fork: $!\n";
if ($child) {
   print_page_top_fancy; 
   print_heading('File Upload');
#    print "<p>Parent $$ has finished, Child's PID: $child\n</p>";
  print "<p>File upload complete, your search has been added to the queue and should appear on the results page soon.</p>";



  print_page_bottom_fancy;
} else {

   # Import CGI Varibles
   my $query = new CGI;
   $CGI::POST_MAX = 1024 * 50000;

   #       chdir '/'                 or die "Can't chdir to /: $!";
   open STDIN,  '/dev/null'  or die "Can't read /dev/null: $!";
   open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
   open STDERR, '>>log'      or die "Can't write to /tmp/log: $!";
   setsid or die "Can't start a new session: $!";

   my $oldfh = select STDERR;
   local $| = 1;
   select $oldfh;

   warn "Started\n";

   # do something time-consuming
   #      warn "Parent Completed\n";
   #      warn $0;
   # Run our programme

   use DBI;

   use lib 'lib';
   use Crosslinker::Links;
   use Crosslinker::HTML;
   use Crosslinker::Data;
   use Crosslinker::Proteins;
   use Crosslinker::Scoring;
   use Crosslinker::Config;

   # Constants
   my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length ) =
     constants;

   # Connect to databases
   my ( $dbh, $settings_dbh ) = connect_db;

   my (
        $protien_sequences, $sequence_names_ref, $missed_clevages,       $upload_filehandle_ref, $csv_filehandle_ref, $reactive_site,
        $cut_residues,      $nocut_residues,     $fasta,                 $desc,                  $decoy,              $match_ppm,
        $ms2_error,         $mass_seperation,    $isotope,               $seperation,            $mono_mass_diff,     $xlinker_mass,
        $dynamic_mods_ref,  $fixed_mods_ref,     $ms2_fragmentation_ref, $threshold,		 $n_or_c,	      $scan_width,
	$match_charge,	    $match_intensity,    $scored_ions,           $no_xlink_at_cut_site,  $ms1_intensity_ratio,$fast_mode,
        $doublet_tolerance
   ) = import_cgi_query( $query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12 );
   my @sequence_names    = @{$sequence_names_ref};
   my @upload_filehandle = @{$upload_filehandle_ref};
   my @csv_filehandle    = @{$csv_filehandle_ref};
   my @dynamic_mods      = @{$dynamic_mods_ref};
   my @fixed_mods        = @{$fixed_mods_ref};
   my %ms2_fragmentation = %{$ms2_fragmentation_ref};

   my $state = is_ready($settings_dbh);

   my $results_table = save_settings( $settings_dbh, 

		  $cut_residues, $fasta,     	$reactive_site, $mono_mass_diff, 	$xlinker_mass, 	  $state,
                  $desc,         $decoy,        $ms2_error,    	$match_ppm, 		$mass_seperation, \@dynamic_mods,  
		 \@fixed_mods,   $threshold,	$match_charge, 	$match_intensity, 	$scored_ions);

   my ( $results_dbh ) = connect_db_results($results_table);

    
  #Save Query data

  open (OUT,'>',"query_data/query-$results_table.txt");
  $query->save(\*OUT);
  close OUT;

   create_table($results_dbh);

   for ( my $n = 1 ; $n <= $no_of_fractions ; $n++ ) {
      if ( defined( $upload_filehandle[$n] ) ) {
         import_mgf( $n, $upload_filehandle[$n], $results_dbh );
      }
    }
  
   while ( $state == -2 ) {
      sleep(100);
      $state = check_state( $settings_dbh, $results_table );
   }

   if ( $state == -4 ) {
      return $state;
   }
  
   # Setup Modifications
   my %protein_residuemass = protein_residuemass($results_table, $settings_dbh);
   my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $results_table, $settings_dbh );

  
   #Output page

   eval { $state = generate_page  (
                           $protien_sequences,  $dbh,              $results_dbh,      $settings_dbh,   $results_table,      $no_of_fractions,
                           \@upload_filehandle, \@csv_filehandle,  $missed_clevages,  $cut_residues,   $nocut_residues,     \%protein_residuemass,
                           $reactive_site,      $scan_width,       \@sequence_names,  $match_ppm,      $min_peptide_length, $mass_of_deuterium,
                           $mass_of_hydrogen,   $mass_of_carbon13, $mass_of_carbon12, \%modifications, 1,      		    $mono_mass_diff,
                           $xlinker_mass,       $isotope,          $seperation,       $ms2_error,      $state,              \%ms2_fragmentation,
                           $threshold,		$n_or_c, 	   $match_charge,     $match_intensity, $no_xlink_at_cut_site, $ms1_intensity_ratio,
			   $fast_mode,		$doublet_tolerance,
   )};
   if ($@) { 
	warn $@;
	set_failed ( $results_table, $settings_dbh );
        $state = -5;
	warn is_ready($settings_dbh, 1);
	if (is_ready($settings_dbh, 1) == 0) {give_permission($settings_dbh)};	 
     };

   #Tidy up
   if ( $state == -1 ) { set_finished( $results_table, $settings_dbh ) }
   disconnect_db( $dbh, $settings_dbh, $results_dbh );
   warn "completed\n";
   CORE::exit(0);    # terminate the forked process cleanly
}
exit;

