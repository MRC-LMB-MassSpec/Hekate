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


   # Constants
   my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length ) =
     constants;

   # Connect to databases
   my ( $dbh, $results_dbh, $settings_dbh ) = connect_db;

   my (
         $upload_filehandle_ref, $doublet_tolerance,  $mass_seperation, $isotope, $linkspacing, $scan_width, $match_charge, $output_format
   ) = import_mgf_doublet_query( $query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12 );

   my @upload_filehandle = @{$upload_filehandle_ref}; 

   #Output page

  if ($output_format eq 'HTML')
  {

    print_page_top_fancy("Doublet Search");
    my $version = version();	
    print_heading('Results');
 
     mgf_doublet_search(
                         \@upload_filehandle, $doublet_tolerance,    $linkspacing, $isotope, $linkspacing, $dbh,
 			$mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $scan_width,
 			$match_charge
    );
    print_page_bottom_fancy;
  }
  else{

    print "Content-type: text/plain\n\n";
    mgf_doublet_search_mgf_output(
                        \@upload_filehandle, $doublet_tolerance,    $linkspacing, $isotope, $linkspacing, $dbh,
			$mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $scan_width,
			$match_charge
   );
  }
   #Tidy up
    disconnect_db( $dbh, $settings_dbh, $results_dbh );
 

exit;

