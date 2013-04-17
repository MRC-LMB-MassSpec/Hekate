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

print_page_top_bootstrap("Fragment");
my $version = version();
my $dbh     = connect_conf_db;
print '<div class="row">
<div class="span8 offset2">
   <div class="page-header">
  <h1>Hekate <small>Fragment</small></h1>
</div></div></div>';
print <<ENDHTML;
<div class="row">
<div class="span8 offset2">
<form method="POST" enctype="multipart/form-data" action="product.pl" >
<fieldset>
<legend>Crosslinking Reagent</legend>
<div class="row">
<div class="span8"> 
<label>Linker mass<label>
<div class="input-append"><input type="text" name="xlinker_mass" size="10" maxlength="10" value="96.0211296"/><span class="add-on">ppm</span></div><br/>
<label>Reactive amino acid</label>
<input type="text" name="reactive_site" size="10" maxlength="10" value="K"/><br/>
</div>
</div>
<legend>Sequence</legend>
<div class="row">
<div class="span8">
<input type="text" name="sequence" size="20" value ="KKPEEMAK-TAPLVKK"/>
<center><input class="btn btn-primary" type="submit" value="Perform Fragmentation" /></center>
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
