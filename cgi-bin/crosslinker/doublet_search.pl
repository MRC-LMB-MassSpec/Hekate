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
print_heading('Doublet Search');
print <<ENDHTML;
<form method="POST" enctype="multipart/form-data" action="find_doublets.pl" target="_blank">
<table>

<tr cellspacing="3">
  <td  style="background: white;" > 
  <table >
 <tr>
  <td>Doublet Spacing Tollerance (ppm) <input type="text" name="ms_ppm" size="4" maxlength="4" value="50"/></td>
 <td>Max Scan seperation<input type="text" name="scan_width" size="4" maxlength="4" value="60"/></td>
 </tr><tr>
  <td class="half"  style="background: white;">
    Crosslinking Reagent:<select name='crosslinker'>
ENDHTML

my $dbh = connect_conf_db;
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
      Atoms on  <select
name="isotope"><option>deuterium</option><option>carbon-13</option><option>none</option></select>
 
in heavy form: <input type="text" 
name="seperation" size="2" maxlength="5" 
value="4"/> 
</td>
</tr>

<tr><td  style="background: white; margin:0">
<table>
  <tr><td style="background: white; padding:0">Mascot&nbsp;File:</td><td style="background: white;padding:0"> <input type="file" name="mgf"/><br/></td></tr>
</table>
</td></tr>
<tr><td  style="background: white;">

    <center><input type="submit" value="Search..." /></center>
</td>
</tr>
</table>
</form>

ENDHTML

$dbh->disconnect();

print_page_bottom_fancy;
exit;
