#!/usr/bin/perl -w
######################################################
#   ____                   _ _       _               #
#  / ___|_ __ ___  ___ ___| (_)_ __ | | _____ _ __   #
# | |   | '__/ _ \/ __/ __| | | '_ \| |/ / _ \ '__|  #
# | |___| | | (_) \__ \__ \ | | | | |   <  __/ |     #
#  \____|_|  \___/|___/___/_|_|_| |_|_|\_\___|_|     #
#                                             v0.9.2 #
######################################################

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use POSIX 'setsid';
use lib 'lib';
use Crosslinker::Constants;

$SIG{CHLD} = 'IGNORE';
defined( my $child = fork ) or die "Cannot fork: $!\n";
if ($child) {
   print "Content-type: text/plain \n\n";
   print "Parent $$ has finished, Child's PID: $child\n";
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
   my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length, $scan_width ) =
     constants;

   # Connect to databases
   my ( $dbh, $results_dbh, $settings_dbh ) = connect_db;

   my (
        $protien_sequences, $sequence_names_ref, $missed_clevages,       $upload_filehandle_ref, $csv_filehandle_ref, $reactive_site,
        $cut_residues,      $nocut_residues,     $fasta,                 $desc,                  $decoy,              $match_ppm,
        $ms2_error,         $mass_seperation,    $isotope,               $seperation,            $mono_mass_diff,     $xlinker_mass,
        $dynamic_mods_ref,  $fixed_mods_ref,     $ms2_fragmentation_ref, $threshold
   ) = import_cgi_query( $query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12 );
   my @sequence_names    = @{$sequence_names_ref};
   my @upload_filehandle = @{$upload_filehandle_ref};
   my @csv_filehandle    = @{$csv_filehandle_ref};
   my @dynamic_mods      = @{$dynamic_mods_ref};
   my @fixed_mods        = @{$fixed_mods_ref};
   my %ms2_fragmentation = %{$ms2_fragmentation_ref};

   # Generate Results Name
   my $results_table = find_free_tablename $settings_dbh;

   # Save Settings
   my $state = is_ready($settings_dbh);
   save_settings( $settings_dbh, $results_table, $cut_residues, $fasta,     $reactive_site,   $mono_mass_diff, $xlinker_mass, $state,
                  $desc,         $decoy,         $ms2_error,    $match_ppm, $mass_seperation, \@dynamic_mods,  \@fixed_mods,  $threshold );

   # Setup Modifications

   my %protein_residuemass = protein_residuemass($results_table);
   my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $results_table );

   #Output page

   $state = generate_page(
                           $protien_sequences,  $dbh,              $results_dbh,      $settings_dbh,   $results_table,      $no_of_fractions,
                           \@upload_filehandle, \@csv_filehandle,  $missed_clevages,  $cut_residues,   $nocut_residues,     \%protein_residuemass,
                           $reactive_site,      $scan_width,       \@sequence_names,  $match_ppm,      $min_peptide_length, $mass_of_deuterium,
                           $mass_of_hydrogen,   $mass_of_carbon13, $mass_of_carbon12, \%modifications, $query,              $mono_mass_diff,
                           $xlinker_mass,       $isotope,          $seperation,       $ms2_error,      $state,              \%ms2_fragmentation,
                           $threshold
   );

   #Tidy up
   if ( $state == -1 ) { set_finished( $results_table, $settings_dbh ) }
   disconnect_db( $dbh, $settings_dbh, $results_dbh );
   warn "completed\n";
   CORE::exit(0);    # terminate the forked process cleanly
}
exit;

