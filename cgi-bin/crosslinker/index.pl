#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;

use lib 'lib';
use Crosslinker::HTML;
use Crosslinker::Constants;
use Crosslinker::Data;
use Crosslinker::Config;

my $path = installed;

########################
#                      #
# Summary Gen          #
#                      #
########################

print_page_top_bootstrap("Home");
my $version = version();
    my $path    = installed();
print <<ENDHTML;
<div class="row">
<div class="span8 offset2">
<img class="span2" style="max-width: 240px" src="/$path/bootstrap/img/crosslinker.png"/>
   <div class="page-header">
  <h1>Crosslinker <small>for the analysis of XCMS data</small></h1>
</div>
  <p>The details of this software are in preparation for publication. Once published there details will be placed here.</p>
<form method="POST" enctype="multipart/form-data" action="crosslinker.pl" target="_blank">
<fieldset>
<legend>Settings</legend><br/>
<div class="row">
<div class="span4"> 
   <label>Digest</label>
    <select name="enzyme"> 
ENDHTML

my $dbh = connect_conf_db;
my $enzymes = get_conf($dbh, 'enzyme');

while ((my $enzyme = $enzymes->fetchrow_hashref)) {
    print "<option value='" . $enzyme->{'rowid'} . "' ";
    if ($enzyme->{'name'} eq 'Trypsin') { print "selected='true'" }
    print ">" . $enzyme->{'name'} . " </option>";
}
$enzymes->finish();

print <<ENDHTML;
     </select> 
    <br/><label class="checkbox inline" ><input type="checkbox" name="proteinase_k" value="true" >
    No&nbsp;enzyme</label>
    <label>MS2 accurracy (Da)</label>
    <input type="text" name="ms2_da" size="2" maxlength="3" value="0.8"/> 
    <label>Doublet Spacing Tollerance</label>
    <div class="input-append"><input type="text" name="ms_ppm" size="4" maxlength="4" value="50"/><span class="add-on">ppm</span></div>
    <label>Threshold</label>
    <input type="text" name="threshold" size="3" maxlength="3" value="2"/> 
    <span class="help-block">as a % of the maximum intensity</span>
</div>
<div class="span4">
    <label>Maximum Missed Cleavages</label>
    <input type="text" name="missed_cleavages" size="2" maxlength="3" value="3"/>
    <label>MS1 accurracy</label>
    <div class="input-append"><input type="text" name="ms1_ppm" size="2" maxlength="2" value="2"/><span class="add-on">ppm</span></div>
    <label>Max scan seperation</label>
    <input type="text" name="scan_width" size="4" maxlength="4" value="60"/><br/>
    <label class="checkbox inline" ><input type="checkbox" name="decoy" value="true">Decoy&nbsp;Search</label><br/>  
    <label class="checkbox inline" ><input type="checkbox" name="charge_match"  checked="checked" value="true">Require&nbsp;Charge&nbsp;Match</label><br/>
    <label class="checkbox inline" ><input type="checkbox" name="allow_xlink_at_cut_site" value="true" >Allow&nbsp;cross&#8209;linking&nbsp;at&nbsp;cut&nbsp;site</label><br/>
    <label class="checkbox inline" ><input type="checkbox" name="detailed_scoring"  value="true">Detailed&nbsp;scoring</label><br/>
     <span class="help-block">these are found in the csv output only</span>
</div>
</div>

<div class="row">
<div class="span4">
  <label class="checkbox inline" ><input type="checkbox" name="intensity_match" value="true" >Intensity&nbsp;Match&nbsp;(MS1)</label>
</div>
<div class="span4">
    <label>Maximum intensity ratio</label><input type="text" name="ms1_intensity_ratio" size="4" maxlength="4" value="0.8"/>
</div>
</div>

<legend>Modifications</legend>
<div class="row">
<div class="span4">
    <label>Dynamic Modifications</label>
    <select style="width: 20em;" multiple="multiple" size="5"  name="dynamic_mod"> 
ENDHTML

my $mods = get_conf($dbh, 'dynamic_mod');
while ((my $mod = $mods->fetchrow_hashref)) {
    my $selected = '';
    if ($mod->{'setting3'} == 1) { $selected = 'selected="true"' }
    print "<option $selected value='" . $mod->{'rowid'} . "'>" . $mod->{'name'} . "</option>";
}
print <<ENDHTML;
 </select> 
</div>
<div class="span4">
    <label>Fixed Modifications</label>
    <select style="width: 20em;" multiple="multiple" size="5"  name="fixed_mod"> 
ENDHTML

$mods = get_conf($dbh, 'fixed_mod');
while ((my $mod = $mods->fetchrow_hashref)) {
    my $selected = '';
    if ($mod->{'setting3'} == 1) { $selected = 'selected="true"' }
    print "<option $selected value='" . $mod->{'rowid'} . "'>" . $mod->{'name'} . "</option>";
}
$mods->finish();
print <<ENDHTML;
   </select> 
</div>
</div>
<legend>Crosslinking Reagent</legend>
<div class="row">
<div class="span8">
  <label>Crosslinking Reagent<label>
  <select name='crosslinker'> 
ENDHTML

my $crosslinkers = get_conf($dbh, 'crosslinker');
while ((my $crosslinker = $crosslinkers->fetchrow_hashref)) {
    print "<option value='" . $crosslinker->{'rowid'} . "'>" . $crosslinker->{'name'} . "</option>";
}
$crosslinkers->finish();
print "<option value='-1' selected='true'>Custom (enter below)</option></select>";
print <<ENDHTML;
</div>
</div>
<div class="row">
<div class="span4">
  <label>Linker mass</label>
  <div class="input-append"><input type="text" name="xlinker_mass" size="10" maxlength="10" value="96.0211296"/><span class="add-on">Da</span></div><br/> 
  <label>Isotope type</label> 
  <select name="isotope"><option>deuterium</option><option>carbon-13</option><option>none</option></select> 
  <label>Number of labelled atoms in isotopic form</label>
  <input type="text" name="seperation" size="2" maxlength="5" value="4"/> 
</div>
<div class="span4">
 <label>Monolink mass</label>
 <div class="input-append"><input type="text" name="mono_mass_diff" size="10" maxlength="21" value="114.0316942"/><span class="add-on">Da</span></div>
 <label>Reactive amino acid</label>
 <input type="text" name="reactive_site" size="10" maxlength="10" value="K"/>
</div>
</div>
<legend>Amber Codon Mode</legend>
<div class="row">
<div class="span8">
  <label class="checkbox inline span8" ><input type="checkbox" name="amber_codon"   value="1"/>Enable use of amber codon settings.</label><br/><br/>
</div>
<div class="span4">      
  <label>Mass change on crosslinking</label>
  <input type="text" name="amber_xlink" size="10" maxlength="10" value="0"/>Da<br/> 
  <label>Isotope type</label>
  <select name="amber_isotope"><option>deuterium</option><option>carbon-13</option><option>none</option></select> 
  <label>Number of labelled atoms in isotopic form</label>
  <input type="text" name="amber_seperation" size="2" maxlength="5" value="11"/> 
</div>
<div class="span4">  
    Amino acid residue mass: <input type="text" name="amber_residue_mass" size="10" maxlength="21" value="251.0946254"/>Da<br/> 
    Amber codon (Z) peptide sequence: <input type="text" name="amber_peptide" size="10" maxlength="20" value="FZPVINKPAK"/><br/> 
</div>
</div>
<Legend>Fragment Ions</legend>
<div class="row">
<div class="span3"> 
  <h4>Label ions on figures</h4> 
</div>
<div class="span3 ">
 <h4>Use ions to calculate score</h4>
</div>
</div>
<div class="row">
<div class="span2 offset1">
    <label class="span2 checkbox" ><input type="checkbox" name="aions" checked="checked"  value="1"/>A-ions</label>
    <label class="span2 checkbox" ><input type="checkbox" name="bions" checked="checked"  value="1"/> B-ions</label>
    <label class="span2 checkbox" ><input type="checkbox" name="yions" checked="checked"  value="1"/> Y-ions</label>
    <label class="span2 checkbox" ><input type="checkbox" name="waterloss" checked="checked" value="1">Water Loss</label>
    <label class="span2 checkbox" ><input type="checkbox" name="ammonialoss"checked="checked" value="1"> Ammonia Loss</label>
</div>
   
<div class="span2 offset1">
    <label class="span2 checkbox" ><input type="checkbox" name="aions-score" value="1"/> A-ions</label>
    <label class="span2 checkbox" ><input type="checkbox" name="bions-score" checked="checked"  value="1"/> B-ions</label>
    <label class="span2 checkbox" ><input type="checkbox" name="yions-score" checked="checked"  value="1"/> Y-ions</label>
    <label class="span2 checkbox" ><input type="checkbox" name="waterloss-score"  value="1">Water Loss</label>
    <label class="span2 checkbox" ><input type="checkbox" name="ammonialoss-score" value="1"> Ammonia Loss</label>
</div>
</div>
<legend>Protein Sequences</legend>
<div class="row">
<div class="span8">
<label>Sequence</label>
<select name="sequence"> 
ENDHTML

my $sequences = get_conf($dbh, 'sequence');
while ((my $sequence = $sequences->fetchrow_hashref)) {
    print "<option value='" . $sequence->{'rowid'} . "'>" . $sequence->{'name'} . "</option>";
}
$sequences->finish();
print "<option value='-1' selected='true'>Custom (enter below in FASTA format)</option>";
print <<ENDHTML;
</select> 
</div>
</div>
<div class="row">
<div class="span8">
<textarea name="user_protein_sequence" rows="12" class="span8">>PolIII
MGSSHHHHHHSSGLEVLFQGPHMSEPRFVHLRVHSDYSMIDGLAKTAPLVKKAAALGMPALAITDFTNLCGLVKFYGAGHGAGIKPIVGADFNVQCDLLGDELTHLTVLAANNTGYQNLTLLISKAYQRGYGAAGPIIDRDWLIELNEGLILLSGGRMGDVGRSLLRGNSALVDECVAFYEEHFPDRYFLELIRTGRPDEESYLHAAVELAEARGLPVVATNDVRFIDSSDFDAHEIRVAIHDGFTLDDPKRPRNYSPQQYMRSEEEMCELFADIPEALANTVEIAKRCNVTVRLGEYFLPQFPTGDMSTEDYLVKRAKEGLEERLAFLFPDEEERLKRRPEYDERLETELQVINQMGFPGYFLIVMEFIQWSKDNGVPVGPGRGSGAGSLVAYALKITDLDPLEFDLLFERFLNPERVSMPDFDVDFCMEKRDQVIEHVADMYGRDAVSQIITFGTMAAKAVIRDVGRVLGHPYGFVDRISKLIPPDPGMTLAKAFEAEPQLPEIYEADEEVKALIDMARKLEGVTRNAGKHAGGVVIAPTKITDFAPLYCDEEGKHPVTQFDKSDVEYAGLVKFDFLGLRTLTIINWALEMINKRRAKNGEPPLDIAAIPLDDKKSFDMLQRSETTAVFQLESRGMKDLIKRLQPDCFEDMIALVALFRPGPLQSGMVDNFIDRKHGREEISYPDVQWQHESLKPVLEPTYGIILYQEQVMQIAQVLSGYTLGGADMLRRAMGKKKPEEMAKQRSVFAEGAEKNGINAELAMKIFDLVEKFAGYGFNKSHSAAYALVSYQTLWLKAHYPAEFMAAVMTADMDNTEKVVGLVDECWRMGLKILPPDINSGLYHFHVNDDGEIVYGIGAIKGVGEGPIEAIIEARNKGGYFRELFDLCARTDTKKLNRRVLEKLIMSGAFDRLGPHRAALMNSLGDALKAADQHAKAEAIGQADMFGVLAEEPEQIEQSYASCQPWPEQVVLDGERETLGLYLTGHPINQYLKEIERYVGGVRLKDMHPTERGKVITAAGLVVAARVMVTKRGNRIGICTLDDRSGRLEVMLFTDALDKYQQLLEKDRILIVSGQVSFDDFSGGLKMTAREVMDIDEAREKYARGLAISLTDRQIDDQLLNRLRQSLEPHRSGTIPVHLYYQRADARARLRFGATWRVSPSDRLLNDLRGLIGSEQVELEFD 
    </textarea> 
</div>
</div>
<legend>Search</legend>
<div class="row">
<div class="span4 offset1">
  <label>Description</label>
  <input type="text" name="user_desc" size="26" maxlength="32" value="None"/>
</div>
<div class="span3 ">
  <label>Crosslinker Search</label><input type="submit" class="btn btn-primary" value="Upload and search data" />
</div>
</div>
<Legend>Format</legend> 
<div class="row">
<div class="span4 offset1">
  <label class="inline checkbox"><input type="radio" name="data_format" value="MGF" checked> MGF</label>
</div>
<div class="span3"> 
  <label class="inline checkbox"><input type="radio" name="data_format" value="mzXML" > mzXML (32-bit precision)</label>
</div> 
</div> 
<legend>Files</legend>
<div class="row">
<div class="offset2 span4">
  <label>Fraction 1 <input type="file" name="mgf"/></label>
  <label>Fraction 2 <input type="file" name="mgf2"/></label>
  <label>Fraction 3 <input type="file" name="mgf3"/></label>
  <label>Fraction 4 <input type="file" name="mgf4"/></label>
  <label>Fraction 5 <input type="file" name="mgf5"/></label>
  <label>Fraction 6 <input type="file" name="mgf6"/></label>
  <label>Fraction 7 <input type="file" name="mgf7"/></label>
  <label>Fraction 8 <input type="file" name="mgf8"/></label>
</div>
</div>
</fieldset> 
</form> 
</div> 
</div> 
 
ENDHTML

$dbh->disconnect();

print_page_bottom_bootstrap;
exit;
