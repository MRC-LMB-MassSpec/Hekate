use strict;

package Crosslinker::HTML;
use lib 'lib';
use Crosslinker::Links;
use Crosslinker::Data;
use Crosslinker::Proteins;
use Crosslinker::Scoring;
use Crosslinker::Constants;
use base 'Exporter';
our @EXPORT = ( 'generate_page', 'print_heading', 'print_subheading', 'print_page_top', 'print_page_bottom', 'print_page_top_fancy', 'print_page_bottom_fancy' );
######
#
# Creates html for page
#
######

sub generate_page {

    my ( $protien_sequences, $dbh, $results_dbh, $settings_dbh, $results_table, $no_of_fractions, $upload_filehandle_ref, $csv_filehandle_ref, $missed_clevages, $cut_residues, $nocut_residues, $protein_residuemass_ref, $reactive_site, $scan_width, $sequence_names_ref, $match_ppm, $min_peptide_length, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $modifications_ref, $query, $mono_mass_diff, $xlinker_mass, $isotope, $seperation, $ms2_error, $state, $ms2_fragmentation_ref, $threshold) = @_;

    while ( $state == -2 ) {
        sleep(10);
        $state = check_state( $settings_dbh, $results_table );
    }

    if ( $state == -4 ) {
        return $state;
    }

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
        @sequence_fragments = digest_proteins( $missed_clevages, $sequence, $cut_residues, $nocut_residues );
        @fragments = ( @fragments, @sequence_fragments );
        warn "Sequence $count = $sequence_names[$count] \n";
        warn "Digested peptides size:", scalar(@fragments), " \n";

        #  foreach (@sequence_fragments) {
        #	if ($_ eq "YSALFLGMAYGAKR"){ warn "YSALFLGMAYGAKR , $_ , $sequence_names[$count]"; }
        #        $fragment_source{$_} = $sequence_names[$count];
        #    }

        %fragment_source = ( ( map { $_ => $count } @fragments ), %fragment_source );
        $count++;
    }

    my %fragment_masses = digest_proteins_masses( \@fragments, \%protein_residuemass, \%fragment_source );

    my ( $xlink_fragment_masses_ref, $xlink_fragment_sources_ref ) = crosslink_peptides( \%fragment_masses, \%fragment_source, $reactive_site, $min_peptide_length, $xlinker_mass, $missed_clevages, $cut_residues );
    my %xlink_fragment_masses = %{$xlink_fragment_masses_ref};
    %xlink_fragment_masses = ( %xlink_fragment_masses, %fragment_masses );
    my %xlink_fragment_sources = ( %{$xlink_fragment_sources_ref}, %fragment_source );

    my @peaklist = loaddoubletlist_db( $query->param('ms_ppm'), $seperation, $isotope, $dbh, $scan_width, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, );

    my $doublets_found = @peaklist;
    set_doublets_found ($results_table, $settings_dbh, $doublets_found);

    warn "Starting Peak Matches...\n";
    my %fragment_score = matchpeaks( \@peaklist, \%xlink_fragment_masses, \%xlink_fragment_sources, $protien_sequences, $match_ppm, $dbh, $results_dbh, $settings_dbh, $results_table, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $cut_residues, $nocut_residues, \@sequence_names, $mono_mass_diff, $xlinker_mass, $seperation, $isotope, $reactive_site, \%modifications, $ms2_error, \%protein_residuemass, \%ms2_fragmentation, $threshold );

    give_permission($settings_dbh);
    if ( check_state( $settings_dbh, $results_table ) == -4 ) {
        return '-4';
    }
    return '-1';
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
    print <<ENDHTML;
Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>CrossLinker</title>
<meta http-equiv="content-type" content="text/html; charset=iso-8859-1">
<link rel="stylesheet" type="text/css" href="/v$version/css/xlink.css" media="screen">
<link rel="stylesheet" type="text/css" href="/v$version/css/print.css" media="print">
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
<script src="/v$version/java/jquery.js" type="text/javascript"></script>
<script src="/v$version/java/main.js" type="text/javascript"></script>

</head>
<body>
<div id="container">
<div id="heading">
<h1>Crosslinker v$version</h1>
</div>
<div id="menu">
    <ul id="nav">
        <li id="home"><a id="home" href="/cgi-bin/v$version/index.pl">Home</a></li>
        <li id="results"><a id="results" href="/cgi-bin/v$version/results.pl">Results</a></li>
        <li id="results"><a id="results" href="/cgi-bin/v$version/settings.pl">Settings</a></li>
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
