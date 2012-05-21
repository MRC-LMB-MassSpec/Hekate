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

print_page_top_fancy("Doublet Search");
my $version = version();
print_heading('Results');

   # Constants
   my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length ) =
     constants;

   # Connect to databases
   my ( $dbh, $results_dbh, $settings_dbh ) = connect_db;

   my (
         $upload_filehandle_ref, $doublet_tolerance,  $mass_seperation, $isotope, $linkspacing, $scan_width
   ) = import_mgf_doublet_query( $query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12 );

   my @upload_filehandle = @{$upload_filehandle_ref}; 

   #Output page

    mgf_doublet_search(
                        \@upload_filehandle, $doublet_tolerance,   $mass_seperation, $isotope, $linkspacing, $dbh,
			$mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $scan_width
   );

   #Tidy up
    disconnect_db( $dbh, $settings_dbh, $results_dbh );
  print_page_bottom_fancy;

exit;

