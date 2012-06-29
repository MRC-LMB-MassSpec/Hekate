use strict;

package Crosslinker::HTML;
use lib 'lib';
use Crosslinker::Links;
use Crosslinker::Data;
use Crosslinker::Proteins;
use Crosslinker::Scoring;
use Crosslinker::Constants;
use base 'Exporter';
our @EXPORT =
  ( 'generate_page', 'print_heading', 'print_subheading', 'print_page_top', 'print_page_bottom', 'print_page_top_fancy', 'print_page_bottom_fancy',
    'mgf_doublet_search', 'crosslink_digest', 'mgf_doublet_search_mgf_output', 'generate_page_single_scan');
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
        $protien_sequences,     $dbh,                $results_dbh,        $settings_dbh,      $results_table,      $no_of_fractions,
        $upload_filehandle_ref, $csv_filehandle_ref, $missed_clevages,    $cut_residues,      $nocut_residues,     $protein_residuemass_ref,
        $reactive_site,         $scan_width,         $sequence_names_ref, $match_ppm,         $min_peptide_length, $mass_of_deuterium,
        $mass_of_hydrogen,      $mass_of_carbon13,   $mass_of_carbon12,   $modifications_ref, $query,              $mono_mass_diff,
        $xlinker_mass,          $isotope,            $seperation,         $ms2_error,         $state,              $ms2_fragmentation_ref,
        $threshold,		$n_or_c,	     $match_charge,	  $match_intensity,   $no_xlink_at_cut_site, $ms1_intensity_ratio 
   ) = @_;

   while ( $state == -2 ) {
      sleep(10);
      $state = check_state( $settings_dbh, $results_table );
   }

   if ( $state == -4 ) {
      return $state;
   }

#     die;
   
   my %protein_residuemass = %{$protein_residuemass_ref};
   my @csv_filehandle      = @{$csv_filehandle_ref};
   my @upload_filehandle   = @{$upload_filehandle_ref};
   my @sequence_names      = @{$sequence_names_ref};
   my %modifications       = %{$modifications_ref};
   my %ms2_fragmentation   = %{$ms2_fragmentation_ref};

   my $fragment;
   my @fragments;
   my %fragment_source;
   my @sequence_fragments;
   my @sequences = split '>', $protien_sequences;
   my $count = 0;

   create_table($dbh);

   for ( my $n = 1 ; $n <= $no_of_fractions ; $n++ ) {
      if ( defined( $upload_filehandle[$n] ) ) {
         import_mgf( $n, $upload_filehandle[$n], $dbh );
      }

      #   	import_csv($n,$csv_filehandle[$n], $dbh);
   }

   foreach my $sequence (@sequences) {
      @sequence_fragments = digest_proteins( $missed_clevages, $sequence, $cut_residues, $nocut_residues, $n_or_c );
      @fragments = ( @fragments, @sequence_fragments );
      warn "Sequence $count = $sequence_names[$count] \n";
      warn "Digested peptides:", scalar(@fragments), " \n";

      #  foreach (@sequence_fragments) {
      #	if ($_ eq "YSALFLGMAYGAKR"){ warn "YSALFLGMAYGAKR , $_ , $sequence_names[$count]"; }
      #        $fragment_source{$_} = $sequence_names[$count];
      #    }

      %fragment_source = ( ( map { $_ => $count } @fragments ), %fragment_source );
      $count++;
   }

   warn "Calulating masses...  \n";
   my %fragment_masses = digest_proteins_masses( \@fragments, \%protein_residuemass, \%fragment_source );

   warn "Crosslinking peptides...  \n";
   my ( $xlink_fragment_masses_ref, $xlink_fragment_sources_ref ) =
     crosslink_peptides( \%fragment_masses, \%fragment_source, $reactive_site, $min_peptide_length, $xlinker_mass, $missed_clevages, $cut_residues );
   my %xlink_fragment_masses = %{$xlink_fragment_masses_ref};
   %xlink_fragment_masses = ( %xlink_fragment_masses, %fragment_masses );
   my %xlink_fragment_sources = ( %{$xlink_fragment_sources_ref}, %fragment_source );

   warn "Finding doublets...  \n";
   my @peaklist = loaddoubletlist_db( $query->param('ms_ppm'), $seperation,       $isotope,          $dbh, $scan_width,
                                      $mass_of_deuterium,      $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12,
				      $match_charge, 	       $match_intensity,  $ms1_intensity_ratio );

   my $doublets_found = @peaklist;
   set_doublets_found( $results_table, $settings_dbh, $doublets_found );

   warn "Starting Peak Matches...\n";
   my %fragment_score = matchpeaks(
                                    \@peaklist,          \%xlink_fragment_masses, \%xlink_fragment_sources, $protien_sequences,
                                    $match_ppm,          $dbh,                    $results_dbh,             $settings_dbh,
                                    $results_table,      $mass_of_deuterium,      $mass_of_hydrogen,        $mass_of_carbon13,
                                    $mass_of_carbon12,   $cut_residues,           $nocut_residues,          \@sequence_names,
                                    $mono_mass_diff,     $xlinker_mass,           $seperation,              $isotope,
                                    $reactive_site,      \%modifications,         $ms2_error,               \%protein_residuemass,
                                    \%ms2_fragmentation, $threshold,		  $no_xlink_at_cut_site
   );

   give_permission($settings_dbh);
   if ( check_state( $settings_dbh, $results_table ) == -4 ) {
      return '-4';
   }
   return '-1';
}


sub generate_page_single_scan {
  


   my (
        $protien_sequences,     $dbh,                $results_dbh,        $settings_dbh,      $results_table,      $no_of_fractions,
        $upload_filehandle_ref, $csv_filehandle_ref, $missed_clevages,    $cut_residues,      $nocut_residues,     $protein_residuemass_ref,
        $reactive_site,         $scan_width,         $sequence_names_ref, $match_ppm,         $min_peptide_length, $mass_of_deuterium,
        $mass_of_hydrogen,      $mass_of_carbon13,   $mass_of_carbon12,   $modifications_ref, $query,              $mono_mass_diff,
        $xlinker_mass,          $isotope,            $seperation,         $ms2_error,         $state,              $ms2_fragmentation_ref,
        $threshold,		$n_or_c,	     $match_charge,	  $match_intensity,   $no_xlink_at_cut_site,
	$light_scan,		$heavy_scan,	   $precursor_charge, $precursor_mass, $mass_seperation, $mass_of_proton  
   ) = @_;


   my %protein_residuemass = %{$protein_residuemass_ref};
   my @csv_filehandle      = @{$csv_filehandle_ref};
   my @upload_filehandle   = @{$upload_filehandle_ref};
   my @sequence_names      = @{$sequence_names_ref};
   my %modifications       = %{$modifications_ref};
   my %ms2_fragmentation   = %{$ms2_fragmentation_ref};

   my $fragment;
   my @fragments;
   my %fragment_source;
   my @sequence_fragments;
   my @sequences = split '>', $protien_sequences;
   my $count = 0;

   create_table($dbh);

   
    import_scan( $light_scan,		$heavy_scan,	   $precursor_charge, $precursor_mass, $mass_seperation, $mass_of_proton  , $dbh );
   
   foreach my $sequence (@sequences) {
      @sequence_fragments = digest_proteins( $missed_clevages, $sequence, $cut_residues, $nocut_residues, $n_or_c );
      @fragments = ( @fragments, @sequence_fragments );
#       warn "Sequence $count = $sequence_names[$count] \n";
#       warn "Digested peptides:", scalar(@fragments), " \n";

      #  foreach (@sequence_fragments) {
      #	if ($_ eq "YSALFLGMAYGAKR"){ warn "YSALFLGMAYGAKR , $_ , $sequence_names[$count]"; }
      #        $fragment_source{$_} = $sequence_names[$count];
      #    }

      %fragment_source = ( ( map { $_ => $count } @fragments ), %fragment_source );
      $count++;
   }

#    warn "Calulating masses...  \n";
   my %fragment_masses = digest_proteins_masses( \@fragments, \%protein_residuemass, \%fragment_source );

#    warn "Crosslinking peptides...  \n";
   my ( $xlink_fragment_masses_ref, $xlink_fragment_sources_ref ) =
     crosslink_peptides( \%fragment_masses, \%fragment_source, $reactive_site, $min_peptide_length, $xlinker_mass, $missed_clevages, $cut_residues );
   my %xlink_fragment_masses = %{$xlink_fragment_masses_ref};
   %xlink_fragment_masses = ( %xlink_fragment_masses, %fragment_masses );
   my %xlink_fragment_sources = ( %{$xlink_fragment_sources_ref}, %fragment_source );

#    warn "Finding doublets...  \n";
   my @peaklist = loaddoubletlist_db( 10, $seperation,       $isotope,          $dbh, $scan_width,
                                      $mass_of_deuterium,      $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12,
				      $match_charge, 	       $match_intensity );

   my $doublets_found = @peaklist;
   set_doublets_found( $results_table, $settings_dbh, $doublets_found );

   my %fragment_score = matchpeaks(
                                    \@peaklist,          \%xlink_fragment_masses, \%xlink_fragment_sources, $protien_sequences,
                                    $match_ppm,          $dbh,                    $results_dbh,             $settings_dbh,
                                    $results_table,      $mass_of_deuterium,      $mass_of_hydrogen,        $mass_of_carbon13,
                                    $mass_of_carbon12,   $cut_residues,           $nocut_residues,          \@sequence_names,
                                    $mono_mass_diff,     $xlinker_mass,           $seperation,              $isotope,
                                    $reactive_site,      \%modifications,         $ms2_error,               \%protein_residuemass,
                                    \%ms2_fragmentation, $threshold, $no_xlink_at_cut_site
   );
  
 
}

sub crosslink_digest {
  
   my (
        $protien_sequences,     $dbh,                $results_dbh,        $settings_dbh,      $results_table,      $no_of_fractions,
        $upload_filehandle_ref, $csv_filehandle_ref, $missed_clevages,    $cut_residues,      $nocut_residues,     $protein_residuemass_ref,
        $reactive_site,         $scan_width,         $sequence_names_ref, $match_ppm,         $min_peptide_length, $mass_of_deuterium,
        $mass_of_hydrogen,      $mass_of_carbon13,   $mass_of_carbon12,   $modifications_ref, $query,              $mono_mass_diff,
        $xlinker_mass,          $isotope,            $seperation,         $ms2_error,         $state,              $ms2_fragmentation_ref,
        $threshold,		$n_or_c,	     $max_peptide_mass,	  $min_peptide_mass
   ) = @_;

   
   my %protein_residuemass = %{$protein_residuemass_ref};
   my @csv_filehandle      = @{$csv_filehandle_ref};
   my @upload_filehandle   = @{$upload_filehandle_ref};
   my @sequence_names      = @{$sequence_names_ref};
   my %modifications       = %{$modifications_ref};
   my %ms2_fragmentation   = %{$ms2_fragmentation_ref};

   my $fragment;
   my @fragments;
   my %fragment_source;
   my @sequence_fragments;
   my @sequences = split '>', $protien_sequences;
   my $count = 0;

   create_table($dbh);

   for ( my $n = 1 ; $n <= $no_of_fractions ; $n++ ) {
      if ( defined( $upload_filehandle[$n] ) ) {
         import_mgf( $n, $upload_filehandle[$n], $dbh );
      }

      #   	import_csv($n,$csv_filehandle[$n], $dbh);
   }

   foreach my $sequence (@sequences) {
      @sequence_fragments = digest_proteins( $missed_clevages, $sequence, $cut_residues, $nocut_residues, $n_or_c );
      @fragments = ( @fragments, @sequence_fragments );

    

      %fragment_source = ( ( map { $_ => $count } @fragments ), %fragment_source );
      $count++;
   }

   my %fragment_masses = digest_proteins_masses( \@fragments, \%protein_residuemass, \%fragment_source );

   my ( $xlink_fragment_masses_ref, $xlink_fragment_sources_ref ) =
     crosslink_peptides( \%fragment_masses, \%fragment_source, $reactive_site, $min_peptide_length, $xlinker_mass, $missed_clevages, $cut_residues );
   my %xlink_fragment_masses = %{$xlink_fragment_masses_ref};
   %xlink_fragment_masses = ( %xlink_fragment_masses, %fragment_masses );
   my %xlink_fragment_sources = ( %{$xlink_fragment_sources_ref}, %fragment_source );

  my $n = 1;
  print "<h2>Crosslinks</h2>";
  print "<table>";
  my %line;
       foreach (sort { $xlink_fragment_masses{$a} <=> $xlink_fragment_masses{$b} } keys  %xlink_fragment_masses) {
	if ($_ =~ /-/   )
	{
	    foreach my $modification ( reverse sort( keys %modifications ) ) {
		my $location = $modifications{$modification}{Location};
		my $rxn_residues = @{ [ $_ =~ /$location/g ] };
		if ($location eq $reactive_site)
		  { $rxn_residues = $rxn_residues -2};
	    if (    !( $modifications{$modification}{Name} eq "loop link" )
                 && !( $modifications{$modification}{Name} eq "mono link" )
		)   
	{
	     
	      for ( my $x = 1 ; $x <=  $rxn_residues  ; $x++ ) {
	      if ( ($xlink_fragment_masses{$_}+1.00728 +$modifications{$modification}{Delta} *$x) > $min_peptide_mass && ($xlink_fragment_masses{$_}+1.00728 +$modifications{$modification}{Delta} *$x)  <$max_peptide_mass) {
	       if ($x > 1) {
		      my $source = substr($sequence_names[substr($xlink_fragment_sources{$_},0,1)],1);
		      $source = $source ."-" . substr($sequence_names[substr($xlink_fragment_sources{$_},-1)],1);
		      my $mass =  $xlink_fragment_masses{$_}+1.00728+$modifications{$modification}{Delta} *$x ;
		      $line{$xlink_fragment_masses{$_}+1.00728 +$modifications{$modification}{Delta} *$x} =
		      "</td><td>$_ </td><td>$modifications{$modification}{Name} x $x</td><td>$mass</td><td> $source </td></tr>";

	       } else { 
		      my $source = substr($sequence_names[substr($xlink_fragment_sources{$_},0,1)],1);
		      $source = $source ."-" . substr($sequence_names[substr($xlink_fragment_sources{$_},-1)],1);
		      my $mass =  $xlink_fragment_masses{$_}+1.00728 +$modifications{$modification}{Delta} *$x ;
		      $line{$xlink_fragment_masses{$_}+1.00728+$modifications{$modification}{Delta} *$x} =
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
     $n=0;
     foreach (sort keys %line)
      { $n++; print "<tr><td>$n.".$line{$_}; }
     print "</table>";



my @monolink_masses = split( ",", $mono_mass_diff );
$n = 1;

print "<h2>Monolinks</h2>"; 
  print "<table>";
 
       foreach (sort { $xlink_fragment_masses{$a} <=> $xlink_fragment_masses{$b} } keys  %xlink_fragment_masses) {
	    foreach my $modification ( reverse sort( keys %modifications ) ) {
		my $location = $modifications{$modification}{Location};
		my $rxn_residues = @{ [ $_ =~ /$location/g ] };
	    if (    !( $modifications{$modification}{Name} eq "loop link" && @{ [ substr($_,-1) =~ /$location/g ] }< 2 )
                 && !( $modifications{$modification}{Name} eq "mono link" )
		)   
            {
	  if ($location eq $reactive_site)
		  { $rxn_residues = $rxn_residues - 1};
	      if ($_ !~ /-/ && substr($_,0,-1) =~ /$reactive_site/  )
	      {
	      for ( my $x = 1 ; $x <=  $rxn_residues  ; $x++ ) {
	      foreach my $monolink_mass (@monolink_masses){
	      if ( ($xlink_fragment_masses{$_}+1.00728 +$monolink_mass+$modifications{$modification}{Delta} *$x) > $min_peptide_mass && ($xlink_fragment_masses{$_}+1.00728 +$monolink_mass+$modifications{$modification}{Delta} *$x)  <$max_peptide_mass) {
	       if ($x > 1) {
		      my $source = substr($sequence_names[$xlink_fragment_sources{$_}],1);
		      my $mass =  $xlink_fragment_masses{$_}+1.00728 +$monolink_mass+$modifications{$modification}{Delta} *$x ;
		      $line{$xlink_fragment_masses{$_}+1.00728 +$monolink_mass+$modifications{$modification}{Delta} *$x} =
		      "</td><td>$_ </td><td>$modifications{$modification}{Name} x $x</td><td>$mass</td><td> $source </td></tr>";

	       } else { 
		      my $source = substr($sequence_names[$xlink_fragment_sources{$_}],1);
		      my $mass =  $xlink_fragment_masses{$_}+1.00728 +$monolink_mass+$modifications{$modification}{Delta} *$x ;
		      $line{$xlink_fragment_masses{$_}+1.00728 +$monolink_mass+$modifications{$modification}{Delta} *$x} =
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
     $n=0;
     foreach (sort keys %line)
      { $n++; print "<tr><td>$n.".$line{$_}; }
     print "</table>";

}



sub mgf_doublet_search {
   
   my (
        $upload_filehandle_ref, $doublet_tolerance,   $seperation, $isotope, $linkspacing, $dbh,
	$mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $scan_width,
	$match_charge,  $match_intensity, $ms1_intensity_ratio
    ) = @_;

 
   
   
   my @upload_filehandle   = @{$upload_filehandle_ref};
   
  
   create_table($dbh);

  
      if ( defined( $upload_filehandle[1] ) ) {
         import_mgf( 1, $upload_filehandle[1], $dbh );
      }
   
   my @peaklist = loaddoubletlist_db( $doublet_tolerance, $seperation,       $isotope,          $dbh, $scan_width,
                                      $mass_of_deuterium,      $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $match_charge,  $match_intensity, $ms1_intensity_ratio );

#   print "Match charge: $match_charge";

  print "<table><tr><td>mz</td><td>Monoisoptic mass</td><td>Charge</td><td>Scan 1</td><td>Scan 2</td></tr>";
  foreach my $peak (@peaklist) {
    print "<tr><td>$peak->{'mz'} </td><td> $peak->{monoisotopic_mw} </td><td> $peak->{charge}+ </td><td> $peak->{scan_num}</td><td> $peak->{d2_scan_num} </td></tr>"
  }
  print "</table>";

}


sub mgf_doublet_search_mgf_output {
   
   my (
        $upload_filehandle_ref, $doublet_tolerance,   $seperation, $isotope, $linkspacing, $dbh,
	$mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $scan_width,
	$match_charge,  $match_intensity, $ms1_intensity_ratio
    ) = @_;


   my @upload_filehandle   = @{$upload_filehandle_ref};
   
  
   create_table($dbh);

  
      if ( defined( $upload_filehandle[1] ) ) {
         import_mgf( 1, $upload_filehandle[1], $dbh );
      }
   
   my @peaklist = loaddoubletlist_db( $doublet_tolerance, $seperation,       $isotope,          $dbh, $scan_width,
                                      $mass_of_deuterium,      $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $match_charge,  $match_intensity, $ms1_intensity_ratio );

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
   my $path = installed();
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
        <li id="home"><a id="home" href="/cgi-bin/$path/index.pl">Crosslinker Full Search</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/results.pl">Results</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/singlescan.pl">Score Scan</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/doublet_search.pl">Doublet</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/crosslink_digest.pl">Digest</a></li>
 <!--       <li id="results"><a id="results" href="/cgi-bin/$path/crosslink_fragment.pl">Fragment</a></li>
       <li id="results"><a id="results" href="/cgi-bin/$path/crosslink_score.pl">Score</a></li> -->
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

1;
