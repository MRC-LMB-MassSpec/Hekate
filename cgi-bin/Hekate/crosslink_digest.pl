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

print_page_top_bootstrap("Digest");
my $version = version();
print '<div class="row">
<div class="span8 offset2">
   <div class="page-header">
  <h1>Hekate <small>Digest</small></h1>
</div></div></div>';
print <<ENDHTML;
<div class="row">
<div class="span8 offset2">
<form method="POST" enctype="multipart/form-data" action="digest.pl" ><fieldset>
<legend>Digest Conditions</legend><br/>
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
  <label>Min Peptide Mass</label>
  <input type="text" name="min_peptide_mass" size="5" maxlength="5" value="300"/>       
  </div>
  <div class="span4">
  <label>Maximum Missed Cleavages</label>    <input type="text" name="missed_cleavages" size="2" maxlength="3" value="1"/>
  <label>Max Peptide Mass</label>	    <input type="text" name="max_peptide_mass" size="5" maxlength="5" value="4000"/><br/>
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
<div class="span4">
<label>Crosslinking Reagent</label><select name='crosslinker'>
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
<div class="input-append"><input type="text" name="xlinker_mass" size="10" maxlength="10" value="96.0211296"/><span class="add-on">ppm</span></div><br/>
<label>Isotope</label>  <select
name="isotope"><option>deuterium</option><option>carbon-13</option><option>none</option></select>
<label>Number of labelled atoms</label> <input type="text" 
name="seperation" size="2" maxlength="5" 
value="4"/> 
</div><div class="span4"> 
<label> Monolink mass</label><div class="input-append"> <input type="text" name="mono_mass_diff" size="10" maxlength="21" value="114.0316942"/><span class="add-on">ppm</span></div><br/>
<label>Reactive amino acid</label> <input type="text" name="reactive_site" size="10" maxlength="10" value="K"/><br/>
</div>
</div>
<legend>Sequence</legend>
<div class="row">
<div class="span8"><label>Protein Sequences</label>
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
    <textarea class="span8" name="user_protein_sequence" rows="12" cols="72">
>PolIII
MGSSHHHHHHSSGLEVLFQGPHMSEPRFVHLRVHSDYSMIDGLAKTAPLVKKAAALGMPALAITDFTNLCGLVKFYGAGHGAGIKPIVGADFNVQCDLLGDELTHLTVLAANNTGYQNLTLLISKAYQRGYGAAGPIIDRDWLIELNEGLILLSGGRMGDVGRSLLRGNSALVDECVAFYEEHFPDRYFLELIRTGRPDEESYLHAAVELAEARGLPVVATNDVRFIDSSDFDAHEIRVAIHDGFTLDDPKRPRNYSPQQYMRSEEEMCELFADIPEALANTVEIAKRCNVTVRLGEYFLPQFPTGDMSTEDYLVKRAKEGLEERLAFLFPDEEERLKRRPEYDERLETELQVINQMGFPGYFLIVMEFIQWSKDNGVPVGPGRGSGAGSLVAYALKITDLDPLEFDLLFERFLNPERVSMPDFDVDFCMEKRDQVIEHVADMYGRDAVSQIITFGTMAAKAVIRDVGRVLGHPYGFVDRISKLIPPDPGMTLAKAFEAEPQLPEIYEADEEVKALIDMARKLEGVTRNAGKHAGGVVIAPTKITDFAPLYCDEEGKHPVTQFDKSDVEYAGLVKFDFLGLRTLTIINWALEMINKRRAKNGEPPLDIAAIPLDDKKSFDMLQRSETTAVFQLESRGMKDLIKRLQPDCFEDMIALVALFRPGPLQSGMVDNFIDRKHGREEISYPDVQWQHESLKPVLEPTYGIILYQEQVMQIAQVLSGYTLGGADMLRRAMGKKKPEEMAKQRSVFAEGAEKNGINAELAMKIFDLVEKFAGYGFNKSHSAAYALVSYQTLWLKAHYPAEFMAAVMTADMDNTEKVVGLVDECWRMGLKILPPDINSGLYHFHVNDDGEIVYGIGAIKGVGEGPIEAIIEARNKGGYFRELFDLCARTDTKKLNRRVLEKLIMSGAFDRLGPHRAALMNSLGDALKAADQHAKAEAIGQADMFGVLAEEPEQIEQSYASCQPWPEQVVLDGERETLGLYLTGHPINQYLKEIERYVGGVRLKDMHPTERGKVITAAGLVVAARVMVTKRGNRIGICTLDDRSGRLEVMLFTDALDKYQQLLEKDRILIVSGQVSFDDFSGGLKMTAREVMDIDEAREKYARGLAISLTDRQIDDQLLNRLRQSLEPHRSGTIPVHLYYQRADARARLRFGATWRVSPSDRLLNDLRGLIGSEQVELEFD 
    </textarea>
 </div>
</div>

    <center><input class="btn btn-primary" type="submit" value="Perform Digest" /></center>

</fieldset></form>
</div></div>

ENDHTML

$dbh->disconnect();

print_page_bottom_bootstrap;
exit;
