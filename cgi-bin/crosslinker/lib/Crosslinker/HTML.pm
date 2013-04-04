use strict;

package Crosslinker::HTML;
use lib 'lib';
use Crosslinker::Links;
use Crosslinker::Data;
use Crosslinker::Proteins;
use Crosslinker::Scoring;
use Crosslinker::Constants;
use base 'Exporter';
our @EXPORT = (
               'generate_page',           'print_heading',
               'print_subheading',        'print_page_top',
               'print_page_bottom',       'print_page_top_fancy',
               'print_page_bottom_fancy', 'mgf_doublet_search',
               'crosslink_digest',        'mgf_doublet_search_mgf_output',
               'generate_page_single_scan', 'print_page_top_bootstrap',
               'print_page_bottom_bootstrap',
);
######
#
# Creates html for pages
#
# Functions for creating various pages
#
######

sub generate_page {

#This really should be in data or similar, but in the past it generated a page, now it insteads puts the results into the DB.
#much nicer, but hence the strange name.

    my (
        $protien_sequences,  $dbh,                   $results_dbh,           $settings_dbh,
        $results_table,      $no_of_fractions,       $upload_filehandle_ref, $csv_filehandle_ref,
        $missed_clevages,    $cut_residues,          $nocut_residues,        $protein_residuemass_ref,
        $reactive_site,      $scan_width,            $sequence_names_ref,    $match_ppm,
        $min_peptide_length, $mass_of_deuterium,     $mass_of_hydrogen,      $mass_of_carbon13,
        $mass_of_carbon12,   $modifications_ref,     $query,                 $mono_mass_diff,
        $xlinker_mass,       $isotope,               $seperation,            $ms2_error,
        $state,              $ms2_fragmentation_ref, $threshold,             $n_or_c,
        $match_charge,       $match_intensity,       $no_xlink_at_cut_site,  $ms1_intensity_ratio,
        $fast_mode,          $doublet_tolerance,     $amber_codon,	     $proteinase_k,
	$no_enzyme_min,	     $no_enzyme_max
    ) = @_;

    #     die;

    my %protein_residuemass = %{$protein_residuemass_ref};
    my @csv_filehandle      = @{$csv_filehandle_ref};
    my @upload_filehandle   = @{$upload_filehandle_ref};
    my @sequence_names      = @{$sequence_names_ref};
    my %modifications       = %{$modifications_ref};
    my %ms2_fragmentation   = %{$ms2_fragmentation_ref};

     my $fragment;
#     my @fragments;
#     my @fragments_linear_only;
    my %fragment_source;
    my %fragment_source_linear_only;
    my @sequence_fragments;
    my @sequences = split '>', $protien_sequences;
    my $count = 0;

    warn "Run $results_table: Generating page \n";

    create_peptide_table($results_dbh);

    foreach my $sequence (@sequences) {

	my $sequence_fragments_ref;		
	my $sequence_fragments_linear_only_ref;
	my @sequence_fragments;
	my @sequence_fragments_linear_only;


        if ($proteinase_k == 0) {
	  ($sequence_fragments_ref, $sequence_fragments_linear_only_ref) =
          digest_proteins($missed_clevages, $sequence, $cut_residues, $nocut_residues, $n_or_c);
	  @sequence_fragments             = @{$sequence_fragments_ref};
	  @sequence_fragments_linear_only = @{$sequence_fragments_linear_only_ref};
	} else {
	    ($sequence_fragments_ref) = no_enzyme_digest_proteins($no_enzyme_min, $no_enzyme_max, $reactive_site, $sequence);
	    @sequence_fragments             = @{$sequence_fragments_ref};
	}

#         @fragments             = (@fragments,             @sequence_fragments);
#         @fragments_linear_only = (@fragments_linear_only, @sequence_fragments_linear_only);
        warn "Run $results_table: Sequence $count = $sequence_names[$count] \n";
        warn "Run $results_table: Digested peptides:", scalar(@sequence_fragments), " \n";

        foreach $fragment (@sequence_fragments)

        {
            add_peptide($results_dbh, $results_table, $fragment, $count, 0, 0, '', 0, 0);
        }   

        foreach $fragment (@sequence_fragments_linear_only) {
            add_peptide($results_dbh, $results_table, $fragment, $count, 1, 0, '', 0, 0);
        }

        $count++;
    }

    warn "Run $results_table: Calulating masses...  \n";

    calculate_peptide_masses($results_dbh, $results_table, \%protein_residuemass, \%fragment_source);

    warn "Run $results_table: Crosslinking peptides...  \n";

    $results_dbh->disconnect;
    ($results_dbh) = connect_db_results($results_table, 0);


    if ($reactive_site =~ /[^,]/) {  $reactive_site = $reactive_site . ',' . $reactive_site};


    if ($amber_codon == 0) {
      calculate_crosslink_peptides($results_dbh,  $results_table,   $reactive_site, $min_peptide_length,
				   $xlinker_mass, $missed_clevages, $cut_residues);
    } else {
      calculate_amber_crosslink_peptides($results_dbh,  $results_table,   $reactive_site, $min_peptide_length,
					  $xlinker_mass, $missed_clevages, $cut_residues, $mono_mass_diff, \%protein_residuemass);
    }
    $results_dbh->commit;
    $results_dbh->disconnect;
    ($results_dbh) = connect_db_results($results_table);


    if ($amber_codon == 0) {
	generate_monolink_peptides($results_dbh,  $results_table,   $reactive_site, $mono_mass_diff);
    }
    generate_modified_peptides($results_dbh,  $results_table,   \%modifications);

    warn "Run $results_table: Finding doublets...  \n";
    my @peaklist = loaddoubletlist_db(
                                      $doublet_tolerance, $seperation,       $isotope,
                                      $results_dbh,       $scan_width,       $mass_of_deuterium,
                                      $mass_of_hydrogen,  $mass_of_carbon13, $mass_of_carbon12,
                                      $match_charge,      $match_intensity,  $ms1_intensity_ratio
    );

    my $doublets_found = @peaklist;
    set_doublets_found($results_table, $settings_dbh, $doublets_found);

    warn "Run $results_table: Starting Peak Matches...\n";
    my %fragment_score = matchpeaks(
                                    \@peaklist,            $protien_sequences,  $match_ppm,
                                    $results_dbh,          $results_dbh,        $settings_dbh,
                                    $results_table,        $mass_of_deuterium,  $mass_of_hydrogen,
                                    $mass_of_carbon13,     $mass_of_carbon12,   $cut_residues,
                                    $nocut_residues,       \@sequence_names,    $mono_mass_diff,
                                    $xlinker_mass,         $seperation,         $isotope,
                                    $reactive_site,        \%modifications,     $ms2_error,
                                    \%protein_residuemass, \%ms2_fragmentation, $threshold,
                                    $no_xlink_at_cut_site, $fast_mode,		$amber_codon
    );

    #    give_permission($settings_dbh);
    if (check_state($settings_dbh, $results_table) == -4) {
        return '-4';
    }
    return '-1';
}

sub generate_page_single_scan {

    my (
        $protien_sequences,  $dbh,                   $results_dbh,           $settings_dbh,
        $results_table,      $no_of_fractions,       $upload_filehandle_ref, $csv_filehandle_ref,
        $missed_clevages,    $cut_residues,          $nocut_residues,        $protein_residuemass_ref,
        $reactive_site,      $scan_width,            $sequence_names_ref,    $match_ppm,
        $min_peptide_length, $mass_of_deuterium,     $mass_of_hydrogen,      $mass_of_carbon13,
        $mass_of_carbon12,   $modifications_ref,     $query,                 $mono_mass_diff,
        $xlinker_mass,       $isotope,               $seperation,            $ms2_error,
        $state,              $ms2_fragmentation_ref, $threshold,             $n_or_c,
        $match_charge,       $match_intensity,       $no_xlink_at_cut_site,  $light_scan,
        $heavy_scan,         $precursor_charge,      $precursor_mass,        $mass_seperation,
        $mass_of_proton
    ) = @_;

    my %protein_residuemass = %{$protein_residuemass_ref};
    my @csv_filehandle      = @{$csv_filehandle_ref};
    my @upload_filehandle   = @{$upload_filehandle_ref};
    my @sequence_names      = @{$sequence_names_ref};
    my %modifications       = %{$modifications_ref};
    my %ms2_fragmentation   = %{$ms2_fragmentation_ref};

    my $fragment;
    my @fragments;
    my @fragments_linear_only;
    my %fragment_source;
    my %fragment_source_linear_only;
    my @sequence_fragments;
    my @sequences = split '>', $protien_sequences;
    my $count = 0;

    create_table($dbh);

    if ($state == -4) {
        return $state;
    }

    import_scan($light_scan, $heavy_scan, $precursor_charge, $precursor_mass, $mass_seperation, $mass_of_proton, $dbh);

    foreach my $sequence (@sequences) {
        my ($sequence_fragments_ref, $sequence_fragments_linear_only_ref) =
          digest_proteins($missed_clevages, $sequence, $cut_residues, $nocut_residues, $n_or_c);
        my @sequence_fragments             = @{$sequence_fragments_ref};
        my @sequence_fragments_linear_only = @{$sequence_fragments_linear_only_ref};

        @fragments             = (@fragments,             @sequence_fragments);
        @fragments_linear_only = (@fragments_linear_only, @sequence_fragments_linear_only);
        %fragment_source             = ((map { $_ => $count } @fragments),             %fragment_source);
        %fragment_source_linear_only = ((map { $_ => $count } @fragments_linear_only), %fragment_source_linear_only);
        $count++;
    }

    my %fragment_masses = digest_proteins_masses(\@fragments, \%protein_residuemass, \%fragment_source);
    my %fragment_masses_linear_only =
      digest_proteins_masses(\@fragments_linear_only, \%protein_residuemass, \%fragment_source_linear_only);

    my ($xlink_fragment_masses_ref, $xlink_fragment_sources_ref) =
      crosslink_peptides(\%fragment_masses, \%fragment_source, $reactive_site, $min_peptide_length,
                         $xlinker_mass,     $missed_clevages,  $cut_residues);
    my %xlink_fragment_masses = %{$xlink_fragment_masses_ref};
    %xlink_fragment_masses = (%xlink_fragment_masses, %fragment_masses, %fragment_masses_linear_only);
    my %xlink_fragment_sources = (%{$xlink_fragment_sources_ref}, %fragment_source, %fragment_source_linear_only);

    #    warn "Finding doublets...  \n";
    my @peaklist = loaddoubletlist_db(
                                      10,                $seperation,        $isotope,          $dbh,
                                      $scan_width,       $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13,
                                      $mass_of_carbon12, $match_charge,      $match_intensity
    );

    my $doublets_found = @peaklist;
    set_doublets_found($results_table, $settings_dbh, $doublets_found);

    my %fragment_score = matchpeaks_single(
                                           \@peaklist,               \%xlink_fragment_masses,
                                           \%xlink_fragment_sources, $protien_sequences,
                                           $match_ppm,               $dbh,
                                           $results_dbh,             $settings_dbh,
                                           $results_table,           $mass_of_deuterium,
                                           $mass_of_hydrogen,        $mass_of_carbon13,
                                           $mass_of_carbon12,        $cut_residues,
                                           $nocut_residues,          \@sequence_names,
                                           $mono_mass_diff,          $xlinker_mass,
                                           $seperation,              $isotope,
                                           $reactive_site,           \%modifications,
                                           $ms2_error,               \%protein_residuemass,
                                           \%ms2_fragmentation,      $threshold,
                                           $no_xlink_at_cut_site
    );

}

sub crosslink_digest {

    my (
        $protien_sequences,  $dbh,                   $results_dbh,           $settings_dbh,
        $results_table,      $no_of_fractions,       $upload_filehandle_ref, $csv_filehandle_ref,
        $missed_clevages,    $cut_residues,          $nocut_residues,        $protein_residuemass_ref,
        $reactive_site,      $scan_width,            $sequence_names_ref,    $match_ppm,
        $min_peptide_length, $mass_of_deuterium,     $mass_of_hydrogen,      $mass_of_carbon13,
        $mass_of_carbon12,   $modifications_ref,     $query,                 $mono_mass_diff,
        $xlinker_mass,       $isotope,               $seperation,            $ms2_error,
        $state,              $ms2_fragmentation_ref, $threshold,             $n_or_c,
        $max_peptide_mass,   $min_peptide_mass
    ) = @_;

    my %protein_residuemass = %{$protein_residuemass_ref};
    my @csv_filehandle      = @{$csv_filehandle_ref};
    my @upload_filehandle   = @{$upload_filehandle_ref};
    my @sequence_names      = @{$sequence_names_ref};
    my %modifications       = %{$modifications_ref};
    my %ms2_fragmentation   = %{$ms2_fragmentation_ref};

    my $fragment;
    my @fragments;
    my @fragments_linear_only;
    my %fragment_source;
    my %fragment_source_linear_only;
    my @sequence_fragments;
    my @sequences = split '>', $protien_sequences;
    my $count = 0;

    create_table($dbh);

    for (my $n = 1 ; $n <= $no_of_fractions ; $n++) {
        if (defined($upload_filehandle[$n])) {
            import_mgf($n, $upload_filehandle[$n], $dbh);
        }

        #   	import_csv($n,$csv_filehandle[$n], $dbh);
    }

    foreach my $sequence (@sequences) {
        my ($sequence_fragments_ref, $sequence_fragments_linear_only_ref) =
          digest_proteins($missed_clevages, $sequence, $cut_residues, $nocut_residues, $n_or_c);
        my @sequence_fragments             = @{$sequence_fragments_ref};
        my @sequence_fragments_linear_only = @{$sequence_fragments_linear_only_ref};

        @fragments             = (@fragments,             @sequence_fragments);
        @fragments_linear_only = (@fragments_linear_only, @sequence_fragments_linear_only);
        %fragment_source             = ((map { $_ => $count } @fragments),             %fragment_source);
        %fragment_source_linear_only = ((map { $_ => $count } @fragments_linear_only), %fragment_source_linear_only);
        $count++;
    }

    my %fragment_masses = digest_proteins_masses(\@fragments, \%protein_residuemass, \%fragment_source);
    my %fragment_masses_linear_only =
      digest_proteins_masses(\@fragments_linear_only, \%protein_residuemass, \%fragment_source_linear_only);

    my ($xlink_fragment_masses_ref, $xlink_fragment_sources_ref) =
      crosslink_peptides(\%fragment_masses, \%fragment_source, $reactive_site, $min_peptide_length,
                         $xlinker_mass,     $missed_clevages,  $cut_residues);
    my %xlink_fragment_masses = %{$xlink_fragment_masses_ref};
    %xlink_fragment_masses = (%xlink_fragment_masses, %fragment_masses, %fragment_masses_linear_only);
    my %xlink_fragment_sources = (%{$xlink_fragment_sources_ref}, %fragment_source, %fragment_source_linear_only);

    my $n = 1;
    print "<h2>Crosslinks</h2>";
    print "<table class='table table-striped'>";
    my %line;
    foreach (sort { $xlink_fragment_masses{$a} <=> $xlink_fragment_masses{$b} } keys %xlink_fragment_masses) {
        if ($_ =~ /-/) {
            foreach my $modification (reverse sort(keys %modifications)) {
                my $location = $modifications{$modification}{Location};
                my $rxn_residues = @{ [ $_ =~ /$location/g ] };
                if ($location eq $reactive_site) { $rxn_residues = $rxn_residues - 2 }
                if (   !($modifications{$modification}{Name} eq "loop link")
                    && !($modifications{$modification}{Name} eq "mono link"))
                {

                    for (my $x = 1 ; $x <= $rxn_residues ; $x++) {
                        if (($xlink_fragment_masses{$_} + 1.00728 + $modifications{$modification}{Delta} * $x) >
                            $min_peptide_mass
                            && ($xlink_fragment_masses{$_} + 1.00728 + $modifications{$modification}{Delta} * $x) <
                            $max_peptide_mass)
                        {
                            if ($x > 1) {
                                my $source = substr($sequence_names[ substr($xlink_fragment_sources{$_}, 0, 1) ], 1);
                                $source =
                                  $source . "-" . substr($sequence_names[ substr($xlink_fragment_sources{$_}, -1) ], 1);
                                my $mass =
                                  $xlink_fragment_masses{$_} + 1.00728 + $modifications{$modification}{Delta} * $x;
                                $line{ $xlink_fragment_masses{$_} + 1.00728 +
                                      $modifications{$modification}{Delta} * $x } =
"</td><td>$_ </td><td>$modifications{$modification}{Name} x $x</td><td>$mass</td><td> $source </td></tr>";

                            } else {
                                my $source = substr($sequence_names[ substr($xlink_fragment_sources{$_}, 0, 1) ], 1);
                                $source =
                                  $source . "-" . substr($sequence_names[ substr($xlink_fragment_sources{$_}, -1) ], 1);
                                my $mass =
                                  $xlink_fragment_masses{$_} + 1.00728 + $modifications{$modification}{Delta} * $x;
                                $line{ $xlink_fragment_masses{$_} + 1.00728 +
                                      $modifications{$modification}{Delta} * $x } =
"</td><td>$_ </td><td>$modifications{$modification}{Name} </td><td>$mass</td><td> $source </td></tr>";

                            }
                            $n++;

                            #              $fragment_source{$_} = $sequence_names[1];

                        }

                    }
                }
            }
        }
    }
    $n = 0;
    foreach (sort { $a <=> $b } keys %line) {
        $n++;
        print "<tr><td>$n." . $line{$_};
    }
    print "</table>";

    for (keys %line) {
        delete $line{$_};
    }

    my @monolink_masses = split(",", $mono_mass_diff);
    $n = 1;

    print "<h2>Monolinks</h2>";
    print "<table class='table table-striped'>";

    foreach (sort { $xlink_fragment_masses{$a} <=> $xlink_fragment_masses{$b} } keys %xlink_fragment_masses) {
        foreach my $modification (reverse sort(keys %modifications)) {
            my $location = $modifications{$modification}{Location};
            my $rxn_residues = @{ [ $_ =~ /$location/g ] };
            if (!($modifications{$modification}{Name} eq "mono link")) {
                if ($location eq $reactive_site) { $rxn_residues = $rxn_residues - 1 }
                if ($modifications{$modification}{Name} eq "loop link") { $rxn_residues = $rxn_residues / 2 }
                if ($_ !~ /-/ && substr($_, 0, -1) =~ /$reactive_site/) {
                    for (my $x = 1 ; $x <= $rxn_residues ; $x++) {
                        foreach my $monolink_mass (@monolink_masses) {
                            if (
                                (
                                 $xlink_fragment_masses{$_} + 1.00728 +
                                 $monolink_mass +
                                 $modifications{$modification}{Delta} * $x
                                ) > $min_peptide_mass
                                && ($xlink_fragment_masses{$_} + 1.00728 +
                                    $monolink_mass +
                                    $modifications{$modification}{Delta} * $x) < $max_peptide_mass
                              )
                            {
                                if ($x > 1) {
                                    my $source = substr($sequence_names[ $xlink_fragment_sources{$_} ], 1);
                                    my $mass =
                                      $xlink_fragment_masses{$_} + 1.00728 +
                                      $monolink_mass +
                                      $modifications{$modification}{Delta} * $x;
                                    $line{ $xlink_fragment_masses{$_} + 1.00728 +
                                          $monolink_mass +
                                          $modifications{$modification}{Delta} * $x } =
"</td><td>$_ </td><td>$modifications{$modification}{Name} x $x</td><td>$mass</td><td> $source </td></tr>";

                                } else {
                                    my $source = substr($sequence_names[ $xlink_fragment_sources{$_} ], 1);
                                    my $mass =
                                      $xlink_fragment_masses{$_} + 1.00728 +
                                      $monolink_mass +
                                      $modifications{$modification}{Delta} * $x;
                                    $line{ $xlink_fragment_masses{$_} + 1.00728 +
                                          $monolink_mass +
                                          $modifications{$modification}{Delta} * $x } =
"</td><td>$_ </td><td>$modifications{$modification}{Name} </td><td>$mass</td><td> $source </td></tr>";

                                }
                                $n++;
                            }
                        }
                    }

                    #              $fragment_source{$_} = $sequence_names[1];

                }

            }
        }
    }
    $n = 0;
    foreach (sort { $a <=> $b } keys %line) {
        $n++;
        print "<tr><td>$n." . $line{$_};
    }
    print "</table>";

}

sub mgf_doublet_search {

    my (
        $upload_filehandle_ref, $doublet_tolerance, $seperation,        $isotope,
        $linkspacing,           $dbh,               $mass_of_deuterium, $mass_of_hydrogen,
        $mass_of_carbon13,      $mass_of_carbon12,  $scan_width,        $match_charge,
        $match_intensity,       $ms1_intensity_ratio
    ) = @_;

    my @upload_filehandle = @{$upload_filehandle_ref};

    create_table($dbh);

    if (defined($upload_filehandle[1])) {
        import_mgf(1, $upload_filehandle[1], $dbh);
    }

    my @peaklist = loaddoubletlist_db(
                                      $doublet_tolerance, $seperation,       $isotope,
                                      $dbh,               $scan_width,       $mass_of_deuterium,
                                      $mass_of_hydrogen,  $mass_of_carbon13, $mass_of_carbon12,
                                      $match_charge,      $match_intensity,  $ms1_intensity_ratio
    );

    #   print "Match charge: $match_charge";

    print "<div class='row'><div class='span8 offset2'><table class='table table-striped'><tr><td>mz</td><td>Monoisoptic mass</td><td>Charge</td><td>Scan 1</td><td>Scan 2</td></tr>";
    foreach my $peak (@peaklist) {
        print
"<tr><td>$peak->{'mz'} </td><td> $peak->{monoisotopic_mw} </td><td> $peak->{charge}+ </td><td> $peak->{scan_num}</td><td> $peak->{d2_scan_num} </td></tr>";
    }
    print "</table></div></div>";

}

sub mgf_doublet_search_mgf_output {

    my (
        $upload_filehandle_ref, $doublet_tolerance, $seperation,        $isotope,
        $linkspacing,           $dbh,               $mass_of_deuterium, $mass_of_hydrogen,
        $mass_of_carbon13,      $mass_of_carbon12,  $scan_width,        $match_charge,
        $match_intensity,       $ms1_intensity_ratio
    ) = @_;

    my @upload_filehandle = @{$upload_filehandle_ref};

    create_table($dbh);

    if (defined($upload_filehandle[1])) {
        import_mgf(1, $upload_filehandle[1], $dbh);
    }

    my @peaklist = loaddoubletlist_db(
                                      $doublet_tolerance, $seperation,       $isotope,
                                      $dbh,               $scan_width,       $mass_of_deuterium,
                                      $mass_of_hydrogen,  $mass_of_carbon13, $mass_of_carbon12,
                                      $match_charge,      $match_intensity,  $ms1_intensity_ratio
    );

    #   print "Match charge: $match_charge";

    print "MASS=monoisotopic\n";
    foreach my $peak (@peaklist) {
        print "BEGIN IONS\n";
        print "TITLE=$peak->{title}\n";
        print "PEPMASS=$peak->{mz} $peak->{abundance}\n";
        print "CHARGE=$peak->{charge}+\n";
        print "SCANS=$peak->{scan_num}\n";
        print "$peak->{MSn_string}";
        print "END IONS\n\n";

        print "BEGIN IONS\n";
        print "TITLE=$peak->{d2_title}\n";
        print "PEPMASS=$peak->{d2_mz} $peak->{d2_abundance}\n";
        print "CHARGE=$peak->{d2_charge}+\n";
        print "SCANS=$peak->{d2_scan_num}\n";
        print "$peak->{d2_MSn_string}";
        print "END IONS\n\n";
    }

}

sub print_heading    #Prints HTML heading
{
    print "<br><br><h1>@_</h1>";
}

sub print_subheading    #Prints HTML subheading
{
    print "<h2>@_</h2>";
}

sub print_page_top      #Prints opening to HTML page
{
    print <<ENDHTML;
Content-type: text/html\n\n
<html>
<head>
<title>MS-Crosslink - Results</title>
<script language="javascript">
<!--
	var state = 'none';
	function showhide(layer_ref) {
	if (state == 'block') {
		state = 'none';
	}
	else {
		state = 'block';
	}
	if (document.all) { //IS IE 4 or 5 (or 6 beta)
		eval( "document.all." + layer_ref + ".style.display = state");
	}
	if (document.layers) { //IS NETSCAPE 4 or below
		document.layers[layer_ref].display = state;
	}
	if (document.getElementById &&!document.all) {
		hza = document.getElementById(layer_ref);
		hza.style.display = state;
	}
	}
//-->
</script> 
<script language="javascript">
	function onBeforeUnloadAction(){
   		return "Are you sure";
	}
 	window.onbeforeunload = function(){
   		if((window.event.clientX<0) ||
      			(window.event.clientY<0)){
     			return onBeforeUnloadAction();
   		}
 	}
</script>
<style type="text/css">
	table {
		margin:auto;
		width:80%;
		text-align: center;
	}
	.green {
	    	background-color: #50F05c;
	}
	.cyan {
    		background-color: #50F0Fc;
	}
	td {
    		border-color: #600;
    		text-align: left;
    		margin: 0;
    		padding: 10px;   
    		background-color:  #d0d0d0;
	}
	td.half {
  		width:50%;
	}
</style>
</head>
<body>
<h1>Crosslinker</h1>
<hr>


ENDHTML

}

sub print_page_bottom    #Prints the end of the HTML page
{
    print '<br/><br/>
</body>
</html>';
}

sub print_page_top_fancy    #Prints the end of the HTML page
{
    my $version = version();
    my $path    = installed();
    print <<ENDHTML;
Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>CrossLinker</title>
<meta http-equiv="content-type" content="text/html; charset=iso-8859-1">
<link rel="stylesheet" type="text/css" href="/$path/css/xlink.css" media="screen">
<link rel="stylesheet" type="text/css" href="/$path/css/print.css" media="print">
<style type="text/css">
	table {
		margin:auto;
		width:80%;
		text-align: center;
	}
	.green {
	    	background-color: #50F05c;
	}
	.cyan {
    		background-color: #50F0Fc;
	}
	td {
    		border-color: #600;
    		text-align: left;
    		margin: 0;
    		padding: 10px;   
    		background-color:  #d0d0d0;
	}
	td.half {
  		width:50%;
	}
	#preview{
		position:absolute;
		border:1px solid #ccc;
		background:#fff;
		padding:5px;
		display:none;
		color:#fff;
	}

	#screenshot{
		position:absolute;
		border:1px solid #aaa;
		background:#fff;
		padding:5px;
		display:none;
		color:#fff;
	}
</style>
<script src="/$path/java/jquery.js" type="text/javascript"></script>
<script src="/$path/java/main.js" type="text/javascript"></script>

</head>
<body>
<div id="container">
<div id="heading">
<h1>Crosslinker v$version</h1>
</div>
<div id="menu">
    <ul id="nav">
        <li id="home"><a id="home" href="/cgi-bin/$path/index.pl">Crosslinker Search</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/results.pl">Results</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/singlescan.pl">Score</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/doublet_search.pl">Doublet</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/crosslink_digest.pl">Digest</a></li>
	<li id="results"><a id="results" href="/cgi-bin/$path/crosslink_product.pl">Fragment</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/settings.pl">Settings</a></li>
   </ul>
</div>
<div id="banner">
</div>

<!-- start of main content -->
<div id="title"><h1>

ENDHTML
    print @_;
    print <<ENDHTML;
</h1></div>

<div id="content">
ENDHTML
}

sub print_page_bottom_fancy    #Prints the end of the HTML page
{
    print <<ENDHTML;
</div>
<!-- close main content -->
<div id="footer">
Last update: 02-Jan-2012, &copy; Andrew N Holding, <br/>LTQ Orbitrap image CC <a class="footer" href="http://www.emsl.pnl.gov/">EMSL</a>

</div> <!--close footer -->
</div> <!-- close container -->

</body>
</html>
ENDHTML

}

sub print_page_top_bootstrap    #Prints the end of the HTML page
{
    my ($page) = @_;


    my $version = version();
    my $path    = installed();
    print <<ENDHTML;
Content-type: text/html\n\n
<!DOCTYPE html> 
<html lang="en"> 
  <head> 
    <meta charset="utf-8"> 
    <title>Crosslinker</title> 
    <meta name="viewport" content="width=device-width, initial-scale=1.0"> 
    <meta name="description" content=""> 
    <meta name="author" content=""> 
    <script src="/$path/java/jquery.js" type="text/javascript"></script>
    <script src="/$path/bootstrap/js/bootstrap.js"></script> 
    <script src="/$path/java/main.js" type="text/javascript"></script> 

    <!-- Le styles --> 
    <link href="/$path/bootstrap/css/bootstrap.css" rel="stylesheet"> 
    <style> 
      body {
        padding-top: 60px; /* 60px to make the container go all the way to the bottom of the topbar */
      }
	.green {
	    	background-color: #50F05c;
	}
	.cyan {
    		background-color: #50F0Fc;
	}
	#preview{
		position:absolute;
		border:1px solid #ccc;
		background:#fff;
		padding:5px;
		display:none;
		color:#fff;
	}

	#screenshot{
		position:absolute;
		border:1px solid #aaa;
		background:#fff;
		padding:5px;
		display:none;
		color:#fff;
	}
</style>
    </style> 
    <link href="/$path/bootstrap/css/bootstrap-responsive.css" rel="stylesheet"> 
    <!-- HTML5 shim, for IE6-8 support of HTML5 elements --> 
    <!--[if lt IE 9]>
      <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]--> 
 
   
  </head> 
 
  <body> 
 
    <div class="navbar navbar-inverse navbar-fixed-top"> 
      <div class="navbar-inner"> 
        <div class="container"> 
          <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse"> 
            <span class="icon-bar"></span> 
            <span class="icon-bar"></span> 
            <span class="icon-bar"></span> 
          </a> 
          <a href="index.pl" class="brand inline" >Crosslinker</a> 
          <div class="nav-collapse collapse"> 
            <ul class="nav"> 
ENDHTML


print '              <li '; if ($page eq 'Home') {print 'class="active"' }; print '><a href="index.pl">Search</a></li>'; 
print '              <li '; if ($page eq 'Results') {print 'class="active"' }; print '><a href="results.pl">Results</a></li>'; 
print '              <li '; if ($page eq 'Doublet') {print 'class="active"' }; print '><a href="doublet_search.pl">Doublet</a></li>';
print '              <li '; if ($page eq 'Digest') {print 'class="active"' }; print '><a href="crosslink_digest.pl">Digest</a></li>';
print '              <li '; if ($page eq 'Fragment') {print 'class="active"' }; print '><a href="crosslink_product.pl">Fragment</a></li>';
print '              <li '; if ($page eq 'Score') {print 'class="active"' }; print '><a href="singlescan.pl">Score</a></li>'; 
print '              <li '; if ($page eq 'Settings') {print 'class="active"' }; print '><a href="settings.pl">Settings</a></li>'; 

print <<ENDHTML;
            </ul> 
          </div><!--/.nav-collapse --> 
        </div> 
      </div> 
    </div> 
 
    <div class="container"> 

ENDHTML

}

sub print_page_bottom_bootstrap    #Prints the end of the HTML page
{

   my $path    = installed();
    print <<ENDHTML;
</div> <!-- /container --> 
<div class="span8 offset2"> 
   <hr/><br/>
   <footer> 
        <p class="pull-right"><a href="#">Back to top</a></p> 
        <p>Developed by Andrew Holding at <strong>MRC Laboratory of Molecular Biology</strong>.</p> 
      </footer>
</div> 
  </body> 
</html> 

ENDHTML

}

1;
