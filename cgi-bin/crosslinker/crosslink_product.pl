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

print_page_top_fancy("Crosslink Product");
my $version = version();
my $dbh = connect_conf_db;
print_heading('Crosslink Product');
print <<ENDHTML;
<form method="POST" enctype="multipart/form-data" action="product.pl" >
<table>

<tr cellspacing="3">
  <td  style="background: white;" > 
  <table >
   


 <tr>
  <td class="half"  style="background: white;">
    Crosslinking Reagent:
  </td><td style="background: white;"></td>
    </tr>
    <tr>
  <td class="half"  >
      Linker mass: <input type="text" name="xlinker_mass" size="10" maxlength="10" value="96.0211296"/>Da<br/>
     
</td><td>
 
    Reactive amino acid: <input type="text" name="reactive_site" size="10" maxlength="10" value="K"/><br/>
</td>
</tr>
</table>
<table>
<tr>
  <td  style="background: white;">
  Peptide Sequences
  </td>
</tr>
<tr>
  <td>

    <input type="text" name="sequence" size="20" value ="KKPEEMAK-TAPLVKK"/>

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
