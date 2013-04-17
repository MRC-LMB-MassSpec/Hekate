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

print_page_top_bootstrap("Doublet");
my $version = version();
print '<div class="row">
<div class="span8 offset2">
   <div class="page-header">
  <h1>Hekate <small>Doublet</small></h1>
</div></div></div>';

print <<ENDHTML;
<form method="POST" enctype="multipart/form-data" action="find_doublets.pl">
<div class="row">
<div class="span4 offset2">
  <label>Doublet Spacing Tollerance (ppm)</label>
  <input type="text" name="ms_ppm" size="4" maxlength="4" value="50"/>
  <label>Max scan seperation</label>
  <input type="text" name="scan_width" size="4" maxlength="4" value="60"/>
<label class="checkbox inline">Require Charge Match</label> <input type="checkbox" name="charge_match"  checked="checked" value="true">
</div>
<div class="span4">
    <label>Crosslinking Reagent</label>
    <select name='crosslinker'>
ENDHTML

my $dbh = connect_conf_db;
my $crosslinkers = get_conf($dbh, 'crosslinker');
while ((my $crosslinker = $crosslinkers->fetchrow_hashref)) {
    print "<option value='" . $crosslinker->{'rowid'} . "'>" . $crosslinker->{'name'} . "</option>";
}
$crosslinkers->finish();
print "<option value='-1' selected='true'>Custom (enter right)</option></select>";
print <<ENDHTML;
  <label>Atoms</label>
  <select name="isotope"><option>deuterium</option><option>carbon-13</option><option>none</option></select>
  <label>In heavy form</label>
  <input type="text" name="seperation" size="2" maxlength="5" value="4"/> 
</div>
</div>
<div class="row">
<div class="span4 offset2">
  <label class="checkbox inline">Intensity Match</label> <input type="checkbox" name="intensity_match" value="true">
</div>
<div class="span4">
  <label>Max-ratio</label><input type="text" name="ms1_intensity_ratio" size="4" maxlength="4" value="0.8"/>
</div>
</div>
<div class="row">
<div class="span4 offset2">
<label class="checkbox inline">Output Format  HTML</label><input type="radio" name="output_format" value="HTML" checked="yes">
</div>
<div class="span4">
<label class="checkbox inline">MGF</label> <input type="radio" name="output_format" value="MGF"></td>
</div>
</div>
<div class="row">
<div class="span2 offset4">
  <br/><label> Mascot&nbsp;File</label> 
  <input  type="file" name="mgf"/>
</div>
</div>
<div class="row">
<div class="span1 offset7">
<input class="btn btn-primary" type="submit" value="Search..." />
</div>
</div>

ENDHTML

$dbh->disconnect();

print_page_bottom_bootstrap;
exit;
