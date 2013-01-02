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

print_page_top_fancy("Crosslink Digest");
my $version = version();
print_heading('Crosslink Digest');
print <<ENDHTML;
<form method="POST" enctype="multipart/form-data" action="digest.pl" >
<table>

<tr cellspacing="3">
  <td  style="background: white;" > 
  <table >
    <tr>
	<td  style="background: white;" >Settings:</td>
    </tr>
    <tr>
    <td class="half"  >
   Digest
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
    </select><br/>
     Min Peptide Mass	    <input type="text" name="min_peptide_mass" size="5" maxlength="5" value="300"/><br/>       
    </td>
  <td class="half"  >
    Max. Missed Cleavages    <input type="text" name="missed_cleavages" size="2" maxlength="3" value="1"/><br/>
    Max Peptide Mass	    <input type="text" name="max_peptide_mass" size="5" maxlength="5" value="4000"/><br/>
  </td>
</tr>
<tr>
  <td class="half"  style="background: white;">
      Modifcations:
</td><td style="background: white;"></td>
    </tr>
    <tr>
  <td class="half"  >
    Dynamic Modifications:
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
</td><td>
    Fixed Modifications:
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
</td>
</tr>
 <tr>
  <td class="half"  style="background: white;">
    Crosslinking Reagent:<select name='crosslinker'>
ENDHTML

my $crosslinkers = get_conf($dbh, 'crosslinker');
while ((my $crosslinker = $crosslinkers->fetchrow_hashref)) {
    print "<option value='" . $crosslinker->{'rowid'} . "'>" . $crosslinker->{'name'} . "</option>";
}
$crosslinkers->finish();
print "<option value='-1' selected='true'>Custom (enter below)</option></select>";
print <<ENDHTML;
  </td><td style="background: white;"></td>
    </tr>
    <tr>
  <td class="half"  >
      Linker mass: <input type="text" name="xlinker_mass" size="10" maxlength="10" value="96.0211296"/>Da<br/>
      Atoms on  <select
name="isotope"><option>deuterium</option><option>carbon-13</option><option>none</option></select>
 
in heavy form: <input type="text" 
name="seperation" size="2" maxlength="5" 
value="4"/> 
</td><td>
 Monolink:xlink: <input type="text" name="mono_mass_diff" size="10" maxlength="21" value="114.0316942"/>Da<br/>
    Reactive amino acid: <input type="text" name="reactive_site" size="10" maxlength="10" value="K"/><br/>
</td>
</tr>
</table>
<table>
<tr>
  <td  style="background: white;">
  Protein Sequences
  </td>
</tr>
<tr>
  <td>
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
    <textarea name="user_protein_sequence" rows="12" cols="72">
>PolIII
MGSSHHHHHHSSGLEVLFQGPHMSEPRFVHLRVHSDYSMIDGLAKTAPLVKKAAALGMPALAITDFTNLCGLVKFYGAGHGAGIKPIVGADFNVQCDLLGDELTHLTVLAANNTGYQNLTLLISKAYQRGYGAAGPIIDRDWLIELNEGLILLSGGRMGDVGRSLLRGNSALVDECVAFYEEHFPDRYFLELIRTGRPDEESYLHAAVELAEARGLPVVATNDVRFIDSSDFDAHEIRVAIHDGFTLDDPKRPRNYSPQQYMRSEEEMCELFADIPEALANTVEIAKRCNVTVRLGEYFLPQFPTGDMSTEDYLVKRAKEGLEERLAFLFPDEEERLKRRPEYDERLETELQVINQMGFPGYFLIVMEFIQWSKDNGVPVGPGRGSGAGSLVAYALKITDLDPLEFDLLFERFLNPERVSMPDFDVDFCMEKRDQVIEHVADMYGRDAVSQIITFGTMAAKAVIRDVGRVLGHPYGFVDRISKLIPPDPGMTLAKAFEAEPQLPEIYEADEEVKALIDMARKLEGVTRNAGKHAGGVVIAPTKITDFAPLYCDEEGKHPVTQFDKSDVEYAGLVKFDFLGLRTLTIINWALEMINKRRAKNGEPPLDIAAIPLDDKKSFDMLQRSETTAVFQLESRGMKDLIKRLQPDCFEDMIALVALFRPGPLQSGMVDNFIDRKHGREEISYPDVQWQHESLKPVLEPTYGIILYQEQVMQIAQVLSGYTLGGADMLRRAMGKKKPEEMAKQRSVFAEGAEKNGINAELAMKIFDLVEKFAGYGFNKSHSAAYALVSYQTLWLKAHYPAEFMAAVMTADMDNTEKVVGLVDECWRMGLKILPPDINSGLYHFHVNDDGEIVYGIGAIKGVGEGPIEAIIEARNKGGYFRELFDLCARTDTKKLNRRVLEKLIMSGAFDRLGPHRAALMNSLGDALKAADQHAKAEAIGQADMFGVLAEEPEQIEQSYASCQPWPEQVVLDGERETLGLYLTGHPINQYLKEIERYVGGVRLKDMHPTERGKVITAAGLVVAARVMVTKRGNRIGICTLDDRSGRLEVMLFTDALDKYQQLLEKDRILIVSGQVSFDDFSGGLKMTAREVMDIDEAREKYARGLAISLTDRQIDDQLLNRLRQSLEPHRSGTIPVHLYYQRADARARLRFGATWRVSPSDRLLNDLRGLIGSEQVELEFD 
    </textarea>
  </td>
</tr>
</table>
</td  style="background: white;">
</tr>
<tr><td  style="background: white;">

    <center><input type="submit" value="Perform Digest" /></center>
</td>
</tr>

</table>
</form>

ENDHTML

$dbh->disconnect();

print_page_bottom_fancy;
exit;
