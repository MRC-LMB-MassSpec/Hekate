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
defined(my $child = fork) or die "Cannot fork: $!\n";
if ($child) {
    print_page_top_bootstrap('Crosslinker');
    print_heading('File Upload');
    print
"<p>File upload complete, your search has been added to the queue and should appear on the results page soon.</p>";

    print_page_bottom_bootstrap;
} else {
    my $query = new CGI;
    $CGI::POST_MAX = 1024 * 50000;

    open STDIN,  '/dev/null'  or die "Can't read /dev/null: $!";
    open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
    open STDERR, '>>log'      or die "Can't write to /tmp/log: $!";
    setsid or die "Can't start a new session: $!";

    my $oldfh = select STDERR;
    local $| = 1;
    select $oldfh;

    use DBI;

    use lib 'lib';
    use Crosslinker::Links;
    use Crosslinker::HTML;
    use Crosslinker::Data;
    use Crosslinker::Proteins;
    use Crosslinker::Scoring;
    use Crosslinker::Config;

    # Constants
    my (
        $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12,
        $mass_of_carbon13,  $no_of_fractions,  $min_peptide_length
    ) = constants;

    # Connect to databases
    my ($dbh, $settings_dbh) = connect_db;

    my (
        $protien_sequences,     $sequence_names_ref, $missed_clevages,   $upload_filehandle_ref,
        $csv_filehandle_ref,    $reactive_site,      $cut_residues,      $nocut_residues,
        $fasta,                 $desc,               $decoy,             $match_ppm,
        $ms2_error,             $mass_seperation,    $isotope,           $seperation,
        $mono_mass_diff,        $xlinker_mass,       $dynamic_mods_ref,  $fixed_mods_ref,
        $ms2_fragmentation_ref, $threshold,          $n_or_c,            $scan_width,
        $match_charge,          $match_intensity,    $scored_ions,       $no_xlink_at_cut_site,
        $ms1_intensity_ratio,   $fast_mode,          $doublet_tolerance, $upload_format,
	$amber_codon,		$proteinase_k
    ) = import_cgi_query($query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12);
    my @sequence_names    = @{$sequence_names_ref};
    my @upload_filehandle = @{$upload_filehandle_ref};
    my @csv_filehandle    = @{$csv_filehandle_ref};
    my @dynamic_mods      = @{$dynamic_mods_ref};
    my @fixed_mods        = @{$fixed_mods_ref};
    my %ms2_fragmentation = %{$ms2_fragmentation_ref};

    my $results_table = save_settings(
        $settings_dbh,

        $cut_residues, $fasta,     $reactive_site, $mono_mass_diff,  $xlinker_mass,    -6,
        $desc,         $decoy,     $ms2_error,     $match_ppm,       $mass_seperation, \@dynamic_mods,
        \@fixed_mods,  $threshold, $match_charge,  $match_intensity, $scored_ions,	$amber_codon
    );

    my ($results_dbh) = connect_db_results($results_table, 0);

    warn "Run $results_table: Started \n";

    #Save Query data

    open(OUT, '>', "query_data/query-$results_table.txt");
    $query->save(\*OUT);
    close OUT;

    warn "Run $results_table: Query saved \n";

    create_table($results_dbh);   

    warn "Run $results_table: Table created for results \n";
    warn "Upload format: $upload_format \n";

    for (my $n = 1 ; $n <= $no_of_fractions ; $n++) {

        if (defined($upload_filehandle[$n])) {
            if ($upload_format eq 'MGF') { import_mgf($n, $upload_filehandle[$n], $results_dbh) }
            else                         { import_mzXML($n, $upload_filehandle[$n], $results_dbh) }
        }
    }
    $results_dbh->disconnect;
    ($results_dbh) = connect_db_results($results_table);

    warn "Run $results_table: Data Imported \n";

    my $next_run = -1;

    my $state = is_ready($settings_dbh);
    set_state($results_table, $settings_dbh, $state);

    if ($state == -2) {
        warn "Run $results_table: terminating as another in progress.\n";
        $next_run = 0;
    }

    while ($next_run != 0) {

        # Setup Modifications
        my %protein_residuemass = protein_residuemass($results_table, $settings_dbh);
        my %modifications =
          modifications($mono_mass_diff, $xlinker_mass, $reactive_site, $results_table, $settings_dbh);

        #Output page

        eval {
            $state = generate_page(
                                   $protien_sequences,  $dbh,                  $results_dbh,
                                   $settings_dbh,       $results_table,        $no_of_fractions,
                                   \@upload_filehandle, \@csv_filehandle,      $missed_clevages,
                                   $cut_residues,       $nocut_residues,       \%protein_residuemass,
                                   $reactive_site,      $scan_width,           \@sequence_names,
                                   $match_ppm,          $min_peptide_length,   $mass_of_deuterium,
                                   $mass_of_hydrogen,   $mass_of_carbon13,     $mass_of_carbon12,
                                   \%modifications,     1,                     $mono_mass_diff,
                                   $xlinker_mass,       $isotope,              $seperation,
                                   $ms2_error,          $state,                \%ms2_fragmentation,
                                   $threshold,          $n_or_c,               $match_charge,
                                   $match_intensity,    $no_xlink_at_cut_site, $ms1_intensity_ratio,
                                   $fast_mode,          $doublet_tolerance,    $amber_codon,
				   $proteinase_k
            );
        };

        if ($@) {
            warn "Run ", $results_table, ":", $@;
            set_failed($results_table, $settings_dbh);
            $state = -5;
        }

        $next_run = 0;

        if ($state == -1) { set_finished($results_table, $settings_dbh) }

        if (is_ready($settings_dbh, 1) == 0 && is_ready($settings_dbh, 0) == -2) {
            $next_run = give_permission($settings_dbh);
            warn "Run ", $results_table, ": - picking up data to process from Run $next_run. \n";
            open(OUT, '<', "query_data/query-$next_run.txt") or die "could not open query_data/query-$next_run.txt" ;
            $query = CGI->new(\*OUT);
            close OUT;

            (
             $protien_sequences,     $sequence_names_ref, $missed_clevages,   $upload_filehandle_ref,
             $csv_filehandle_ref,    $reactive_site,      $cut_residues,      $nocut_residues,
             $fasta,                 $desc,               $decoy,             $match_ppm,
             $ms2_error,             $mass_seperation,    $isotope,           $seperation,
             $mono_mass_diff,        $xlinker_mass,       $dynamic_mods_ref,  $fixed_mods_ref,
             $ms2_fragmentation_ref, $threshold,          $n_or_c,            $scan_width,
             $match_charge,          $match_intensity,    $scored_ions,       $no_xlink_at_cut_site,
             $ms1_intensity_ratio,   $fast_mode,          $doublet_tolerance, $upload_format,
	     $amber_codon,	     $proteinase_k
            ) = import_cgi_query($query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12);
            @sequence_names    = @{$sequence_names_ref};
            @upload_filehandle = @{$upload_filehandle_ref};
            @csv_filehandle    = @{$csv_filehandle_ref};
            @dynamic_mods      = @{$dynamic_mods_ref};
            @fixed_mods        = @{$fixed_mods_ref};
            %ms2_fragmentation = %{$ms2_fragmentation_ref};

            warn "Run ", $results_table, ":$cut_residues";

            $results_dbh->disconnect();
            $results_table = $next_run;
            $results_dbh   = connect_db_results($results_table);
        }

    }

    #Tidy up

    disconnect_db($dbh, $settings_dbh, $results_dbh);
    warn "Run ", $results_table, ": Process complete\n";
    CORE::exit(0);    # terminate the forked process cleanly
}
exit;

