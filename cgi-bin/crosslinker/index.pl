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

print_page_top_fancy("Home");
my $version = version();
print_heading('Crosslinker');
print <<ENDHTML;
<form method="POST" enctype="multipart/form-data" action="crosslinker.pl" target="_blank">
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
my $enzymes = get_conf( $dbh, 'enzyme' );

while ( ( my $enzyme = $enzymes->fetchrow_hashref ) ) {
   print "<option value='" . $enzyme->{'rowid'} . "'>" . $enzyme->{'name'} . "</option>";
}

$enzymes->finish();

print <<ENDHTML;
    </select><br/>
    
        MS2 accurracy (Da) <input type="text" name="ms2_da" size="2" maxlength="3" value="0.8"/><br/>
     Doublet Spacing Tollerance (ppm) <input type="text" name="ms_ppm" size="4" maxlength="4" value="50"/><br/>
     Threshold (% of max intensity) <input type="text" name="threshold" size="3" maxlength="3" value="2"/><br/> 
    Intensity Match: <input type="checkbox" name="intensity_match" value="true"><br/>
    </td>
  <td class="half"  >
    Max. Missed Cleavages    <input type="text" name="missed_cleavages" size="2" maxlength="3" value="2"/><br/>
    MS1 accurracy (ppm) <input type="text" name="ms1_ppm" size="2" maxlength="2" value="2"/><br/>
     Max scan seperation<input type="text" name="scan_width" size="4" maxlength="4" value="60"/><br/>
    Decoy Search: <input type="checkbox" name="decoy" value="true"><br/>       
    Require Charge Match: <input type="checkbox" name="charge_match" value="true"><br/>    
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

my $mods = get_conf( $dbh, 'dynamic_mod' );
while ( ( my $mod = $mods->fetchrow_hashref ) ) {
   my $selected = '';
   if ( $mod->{'setting3'} == 1 ) { $selected = 'selected="true"' }
   print "<option $selected value='" . $mod->{'rowid'} . "'>" . $mod->{'name'} . "</option>";
}
print <<ENDHTML;
  </select>
</td><td>
    Fixed Modifications:
    <select style="width: 20em;" multiple="multiple" size="5"  name="fixed_mod">
ENDHTML

$mods = get_conf( $dbh, 'fixed_mod' );
while ( ( my $mod = $mods->fetchrow_hashref ) ) {
   my $selected = '';
   if ( $mod->{'setting3'} == 1 ) { $selected = 'selected="true"' }
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

my $crosslinkers = get_conf( $dbh, 'crosslinker' );
while ( ( my $crosslinker = $crosslinkers->fetchrow_hashref ) ) {
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
<tr>
  <td class="half"  style="background: white;">
    Fragment Ions (Label):
   </td>
</tr>
<tr>
  <td class="half">
    <input type="checkbox" name="aions" checked="checked"  value="1"/> A-ions
    <input type="checkbox" name="bions" checked="checked"  value="1"/> B-ions
    <input type="checkbox" name="yions" checked="checked"  value="1"/> Y-ions
</td>
<td class="half">
   <input type="checkbox" name="waterloss" checked="checked" value="1">Water Loss
   <input type="checkbox" name="ammonialoss"checked="checked" value="1"> Ammonia Loss
</td>
</tr>
<tr>
  <td class="half"  style="background: white;">
    Fragment Ions (Score):
   </td>
</tr>
<tr>
  <td class="half">
    <input type="checkbox" name="aions-score" value="1"/> A-ions
    <input type="checkbox" name="bions-score" checked="checked"  value="1"/> B-ions
    <input type="checkbox" name="yions-score" checked="checked"  value="1"/> Y-ions
</td>
<td class="half">
   <input type="checkbox" name="waterloss-score"  value="1">Water Loss
   <input type="checkbox" name="ammonialoss-score" value="1"> Ammonia Loss
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

my $sequences = get_conf( $dbh, 'sequence' );
while ( ( my $sequence = $sequences->fetchrow_hashref ) ) {
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
<tr>
<td colspan="2"  style="background: white;text-align: center";>
<p>Description: <input style=" border:1px solid black;" type="text" name="user_desc" size="26" maxlength="32" value="None"/></p>    
</td>
</tr>
<tr><td  style="background: white;">

    <center><input type="submit" value="Perform Xlink" /></center>
</td>
</tr>
<tr><td  style="background: white; margin:0">
<table>
  <tr><td style="background: white; padding:0">Fraction 1:</td><td style="background: white;padding:0"> <input type="file" name="mgf"/><br/></td></tr>
  <tr><td style="background: white; padding:0">Fraction 2:</td><td style="background: white;padding:0"> <input type="file" name="mgf2" /><br/></td></tr>
  <tr><td style="background: white; padding:0">Fraction 3:</td><td style="background: white;padding:0"> <input type="file" name="mgf3" /><br/></td></tr>
  <tr><td style="background: white; padding:0">Fraction 4:</td><td style="background: white;padding:0"> <input type="file" name="mgf4" /><br/></td></tr>
  <tr><td style="background: white; padding:0">Fraction 5:</td><td style="background: white;padding:0"> <input type="file" name="mgf5" /><br/></td></tr>
  <tr><td style="background: white; padding:0">Fraction 6:</td><td style="background: white;padding:0"> <input type="file" name="mgf6" /><br/></td></tr>
  <tr><td style="background: white; padding:0">Fraction 7:</td><td style="background: white;padding:0"> <input type="file" name="mgf7" /><br/></td></tr>
  <tr><td style="background: white; padding:0">Fraction 8:</td><td style="background: white;padding:0"> <input type="file" name="mgf8" /><br/></td></tr>
  
</table>
</td></tr>

</table>
</form>

ENDHTML

$dbh->disconnect();

print_page_bottom_fancy;
exit;
