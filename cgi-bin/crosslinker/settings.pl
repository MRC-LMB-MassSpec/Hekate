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

########################
#                      #
# Summary Gen          #
#                      #
########################

print_page_top_fancy("Settings");
my $version = version();

my $query = new CGI;
if ( !defined $query->param('page') ) {
   print <<ENDHTML;
	
	<h1>Crosslinker Settings</h1>
	<p>
	<ul>
	<li><a href="settings.pl?page=enzymes">Enzymes</a></li>
	<li>Modifications
	<ul>
	<li><a href="settings.pl?page=dynamic_mods">Dynamic</a></li>
	<li><a href="settings.pl?page=fixed_mods">Fixed</a></li>
	</ul>
	</li>
	<li><a href="settings.pl?page=sequences">Sequences</a></li>	
	<li><a href="settings.pl?page=crosslinkers">Crosslink Reagents</a></li>
	</p>
	
ENDHTML
} elsif ( $query->param('page') eq 'enzymes' ) {
   my $dbh = connect_conf_db;
   my $enzymes = get_conf( $dbh, 'enzyme' );
   print '<form method="POST" enctype="multipart/form-data" action="settings_add.pl" >';
   print "<h2>Enzymes</h2>";
   print "<table><tr><td>Enzyme</td><td>Cleave at</td><td>Restrict</td><td>N or C</td><td>Edit/Delete</td></tr>";

   while ( ( my $enzyme = $enzymes->fetchrow_hashref ) ) {
      print
"<tr><td>$enzyme->{'name'}</td><td>$enzyme->{'setting1'}</td><td>$enzyme->{'setting2'}</td><td>$enzyme->{'setting3'}</td><td><a href='settings_edit.pl?id=$enzyme->{'rowid'}&type=$enzyme->{'type'}'>Edit</a>/<a href='settings_delete.pl?ID=$enzyme->{'rowid'}&type=$enzyme->{'type'}'>Delete</a></td></tr>";
   }

   print
"<tr><td><input type='hidden' name='type' size='10' maxlength='10' value='enzyme'/><input type='text' name='name' size='10' maxlength='20' value='Name'/></td><td><input type='text' name='setting1' size='10' maxlength='25' value='KR'/></td><td><input type='text' name='setting2' size='5' maxlength='1' value='P'/></td><td><select name='setting3'><option>C</option><option>N</option></select></td><td><input type='submit' value='Add' /></td></tr>";
   print "</table></form>";
   $enzymes->finish;
   $dbh->disconnect;

} elsif ( $query->param('page') eq 'sequences' ) {
   my $dbh = connect_conf_db;
   my $sequences = get_conf( $dbh, 'sequence' );
   print '<form method="POST" enctype="multipart/form-data" action="settings_add.pl" >';
   print "<h2>Sequences</h2>";
   print "<table><tr><td>Sequence Database Name</td><td>Edit/Delete</td></tr>";

   while ( ( my $sequence = $sequences->fetchrow_hashref ) ) {
      print
"<tr><td>$sequence->{'name'}</td><td><a href='settings_edit.pl?id=$sequence->{'rowid'}&type=$sequence->{'type'}'>Edit</a>/<a href='settings_delete.pl?ID=$sequence->{'rowid'}&type=$sequence->{'type'}'>Delete</a></td></tr>";
   }

   print
"<tr><td><input type='hidden' name='type' size='10' maxlength='20' value='sequence'/><input type='text' name='name' size='10' maxlength='10' value='Name'/></td><td><input type='submit' value='Add' /></td></tr>";
   print "</table>";
   print '<div style="margin:auto; width:55em"><p>New sequence:</p><p><textarea  name="setting1" rows="12" cols="80">
>PolIII
MGSSHHHHHHSSGLEVLFQGPHMSEPRFVHLRVHSDYSMIDGLAKTAPLVKKAAALGMPALAITDFTNLCGLVKFYGAGHGAGIKPIVGADFNVQCDLLGDELTHLTVLAANNTGYQNLTLLISKAYQRGYGAAGPIIDRDWLIELNEGLILLSGGRMGDVGRSLLRGNSALVDECVAFYEEHFPDRYFLELIRTGRPDEESYLHAAVELAEARGLPVVATNDVRFIDSSDFDAHEIRVAIHDGFTLDDPKRPRNYSPQQYMRSEEEMCELFADIPEALANTVEIAKRCNVTVRLGEYFLPQFPTGDMSTEDYLVKRAKEGLEERLAFLFPDEEERLKRRPEYDERLETELQVINQMGFPGYFLIVMEFIQWSKDNGVPVGPGRGSGAGSLVAYALKITDLDPLEFDLLFERFLNPERVSMPDFDVDFCMEKRDQVIEHVADMYGRDAVSQIITFGTMAAKAVIRDVGRVLGHPYGFVDRISKLIPPDPGMTLAKAFEAEPQLPEIYEADEEVKALIDMARKLEGVTRNAGKHAGGVVIAPTKITDFAPLYCDEEGKHPVTQFDKSDVEYAGLVKFDFLGLRTLTIINWALEMINKRRAKNGEPPLDIAAIPLDDKKSFDMLQRSETTAVFQLESRGMKDLIKRLQPDCFEDMIALVALFRPGPLQSGMVDNFIDRKHGREEISYPDVQWQHESLKPVLEPTYGIILYQEQVMQIAQVLSGYTLGGADMLRRAMGKKKPEEMAKQRSVFAEGAEKNGINAELAMKIFDLVEKFAGYGFNKSHSAAYALVSYQTLWLKAHYPAEFMAAVMTADMDNTEKVVGLVDECWRMGLKILPPDINSGLYHFHVNDDGEIVYGIGAIKGVGEGPIEAIIEARNKGGYFRELFDLCARTDTKKLNRRVLEKLIMSGAFDRLGPHRAALMNSLGDALKAADQHAKAEAIGQADMFGVLAEEPEQIEQSYASCQPWPEQVVLDGERETLGLYLTGHPINQYLKEIERYVGGVRLKDMHPTERGKVITAAGLVVAARVMVTKRGNRIGICTLDDRSGRLEVMLFTDALDKYQQLLEKDRILIVSGQVSFDDFSGGLKMTAREVMDIDEAREKYARGLAISLTDRQIDDQLLNRLRQSLEPHRSGTIPVHLYYQRADARARLRFGATWRVSPSDRLLNDLRGLIGSEQVELEFD 
    </textarea></p></div></form>';
   $sequences->finish;
   $dbh->disconnect;

} elsif ( $query->param('page') eq 'crosslinkers' ) {
   my $dbh = connect_conf_db;
   my $crosslinkers = get_conf( $dbh, 'crosslinker' );
   print '<form method="POST" enctype="multipart/form-data" action="settings_add.pl" >';
   print "<h2>Crosslinking Reagents</h2>";
   print "<table><tr><td>Name</td><td>Reactivity</td><td>Mass</td><td>MonoLink Mass</td><td>Isotope</td><td>Seperation</d><td>Edit/Delete</td></tr>";

   while ( ( my $crosslinker = $crosslinkers->fetchrow_hashref ) ) {
      print
"<tr><td>$crosslinker->{'name'}</td><td>$crosslinker->{'setting1'}</td><td>$crosslinker->{'setting2'}</td><td>$crosslinker->{'setting3'}</td><td>$crosslinker->{'setting4'}</td><td>$crosslinker->{'setting5'}</td><td><a href='settings_edit.pl?id=$crosslinker->{'rowid'}&type=$crosslinker->{'type'}'>Edit</a>/<a href='settings_delete.pl?ID=$crosslinker->{'rowid'}&type=$crosslinker->{'type'}'>Delete</a></td></tr>";
   }

   print
"<tr><td><input type='hidden' name='type' size='10' maxlength='10' value='crosslinker'/><input type='text' name='name' size='10' maxlength='20' value='Name'/></td>
<td><input type='text' name='setting1' size='10' maxlength='1' value='K'/></td>
<td><input type='text' name='setting2' size='10' maxlength='10' value='96.0211296'/></td>
<td><input type='text' name='setting3' size='10' maxlength='50' value='114.0316942'/></td>
<td><select name='setting4'><option>deuterium</option><option>carbon-13</option><option>none</option></select></td>
<td><input type='text' name='setting5' size='10' maxlength='10' value='4'/></td>
<td><input type='submit' value='Add' /></td></tr>";
   print "</table></form>";
   $crosslinkers->finish;
   $dbh->disconnect;

} elsif ( $query->param('page') eq 'fixed_mods' ) {
   my $dbh = connect_conf_db;
   my $fixed_mods = get_conf( $dbh, 'fixed_mod' );
   print '<form method="POST" enctype="multipart/form-data" action="settings_add.pl" >';
   print "<input type='hidden' name='type' value='fixed_mod'/>";
   print "<h2>Fixed Modifications</h2>";
   print "<table>";
   print "<tr><td>Name</td><td>Mass</td><td>Residue</td><td>Default</td><td>Edit/Delete</td></tr>";
   while ( ( my $fixed_mod = $fixed_mods->fetchrow_hashref ) ) {
      my $YesNo;
      if ( $fixed_mod->{'setting3'} == 0 ) {
         $YesNo = 'No';
      } else {
         $YesNo = 'Yes';
      }
      print
"<tr><td>$fixed_mod->{'name'}</td><td>$fixed_mod->{'setting1'}</td><td>$fixed_mod->{'setting2'}</td><td>$YesNo</td><td><a href='settings_edit.pl?id=$fixed_mod->{'rowid'}&type=$fixed_mod->{'type'}'>Edit</a>/<a href='settings_delete.pl?ID=$fixed_mod->{'rowid'}&type=$fixed_mod->{'type'}'>Delete</a></td></tr>";
   }
   print
"<tr><td><input type='text' name='name' size='20' maxlength='20' value='Carbamidomethyl'/></td><td><input type='text' name='setting1' size='10' maxlength='10' value='57.02146'/></td><td><input type='text' name='setting2' size='10' maxlength='1' value='C' /></td><td><input type='checkbox' name='setting3'  value='1' /></td><td><input type='submit' value='Add' /></td></tr>";
   print "</table></form>";
   $fixed_mods->finish;
   $dbh->disconnect;

} elsif ( $query->param('page') eq 'dynamic_mods' ) {
   my $dbh = connect_conf_db;
   my $dynamic_mods = get_conf( $dbh, 'dynamic_mod' );
   print '<form method="POST" enctype="multipart/form-data" action="settings_add.pl" >';
   print "<input type='hidden' name='type' value='dynamic_mod'/>";
   print "<h2>Dynamic Modifications</h2>";
   print "<table>";
   print "<tr><td>Name</td><td>Mass</td><td>Residue</td><td>Default?</td><td>Edit/Delete</td></tr>";
   while ( ( my $dynamic_mod = $dynamic_mods->fetchrow_hashref ) ) {
      my $YesNo;
      if ( $dynamic_mod->{'setting3'} == 0 ) {
         $YesNo = 'No';
      } else {
         $YesNo = 'Yes';
      }
      print
"<tr><td>$dynamic_mod->{'name'}</td><td>$dynamic_mod->{'setting1'}</td><td>$dynamic_mod->{'setting2'}</td><td>$YesNo</td><td><a href='settings_edit.pl?id=$dynamic_mod->{'rowid'}&type=$dynamic_mod->{'type'}'>Edit</a>/<a href='settings_delete.pl?ID=$dynamic_mod->{'rowid'}&type=$dynamic_mod->{'type'}'>Delete</a></td></tr>";
   }
   print
"<tr><td><input type='name' name='name'  size='20' maxlength='20' value='Oxidation (M)'/></td><td><input type='text' name='setting1' size='10' maxlength='10' value='15.994915'/></td><td><input type='text' name='setting2' size='10' maxlength='1' value='M' /></td><td><input type='checkbox' name='setting3'  value='1'/></td><td><input type='submit' value='Add' /></td></tr>";
   print "</table></form>";
   $dynamic_mods->finish;
   $dbh->disconnect;

}
print_page_bottom_fancy;
exit;
