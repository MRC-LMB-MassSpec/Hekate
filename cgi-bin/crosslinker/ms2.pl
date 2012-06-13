#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;                                 #used for collecting parameters from webbrowser
use CGI::Carp qw ( fatalsToBrowser );    #send fatal errors to webbrowser
use Data::Dumper;                        #used for debugging
use DBI;
use lib 'lib';
use Crosslinker::Constants;
use Crosslinker::Proteins;

#loads database modules

########################
#                      #
# Varibles             #
#                      #
########################

my $query        = new CGI;
my $data         = $query->param('data');
my $data2        = $query->param('data2');
my $sequence     = $query->param('sequence');
my $xlink        = $query->param('xlinkermw');
my $monolink     = $query->param('monolinkermw');
my $modification = $query->param('modification');
my $top_10       = $query->param('top_10');
my $table        = $query->param('table');
my $xlink_res    = $query->param('xlink_res');
my @masses       = split "\n", $data;
my @d2_masses    = split "\n", $data2;
my %ms2_masses;
my $data_java     = "";
my $data_green    = "";
my $data_match    = "";
my $data_red      = "";
my $max_abundance = 0;
my $d2_max_abundance = 0;
my $total_ion_current_corrected;
my $total_ion_current = 0;
my $path = installed;

# Constants
my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length, $scan_width ) =
  constants;
my %residuemass = protein_residuemass($table);
warn $monolink;

my %modifications = modifications( $monolink, $xlink, $xlink_res, $table );

my $terminalmass = 1.0078250 * 2 + 15.9949146 * 1;
my $ms2_error    = 1;                                #Dalton error for assigin an ion to a pair of ions between the two spectra
my $xlink_d      = 4;
my $match_tol    = 0.5;                              #used for finding pairs between spectra in Daltons
my @xlink_pos;

# my@xlink_pos[0];	#alpha chain xlink position
# my @xlink_pos[1];	#beta chain xlink position

########################
#                      #
# Main Program         #
#                      #
########################

#
print "Content-type: text/html\n\n";
print <<ENDHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>
ENDHTML

print $sequence;

my $version = version();
print <<ENDHTML;
</title>
    <link href="/$path/flot/layout.css" rel="stylesheet" type="text/css"></link>
    <!--[if IE]><script language="javascript" type="text/javascript" src="/$path/flot/excanvas.min.js"></script><![endif]-->
    <script language="javascript" type="text/javascript" src="/$path/flot/jquery.js"></script>
    <script language="javascript" type="text/javascript" src="/$path/flot/jquery.flot.js"></script>
    <script language="javascript" type="text/javascript" src="/$path/flot/jquery.flot.selection.js"></script>

 
<script type="text/javascript">
<!-- hide from old browsers
function getValue(varname)
{
  var url = window.location.href;
  var qparts = url.split("?");
  if (qparts.length == 0)
  {
    return "";
  }
  var query = qparts[1];
  var vars = query.split("&");
  var value = "";
  for (i=0;i<vars.length;i++)
  {
    var parts = vars[i].split("=");
    if (parts[0] == varname)
    {
      value = parts[1];
      break;
    }
  }
  value = unescape(value);
  value.replace(/\\+/g," ");
  return value;
}
// end hide -->
</script>
<link rel="stylesheet" type="text/css" href="/$path/css/xlink.css" media="screen">
<link rel="stylesheet" type="text/css" href="/$path/css/print.css" media="print">
<style type="text/css">
	table {
		margin:auto;
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
<div id="container">
<div id="heading">
<h1>MS/2</h1>
</div>
<div id="menu">
    <ul id="nav">
        <li id="home"><a id="home" href="/cgi-bin/$path/index.pl">Crosslinker Full Search</a></li>
        <li id="results"><a id="results" href="/cgi-bin/$path/results.pl">Crosslinker Results</a></li>
   </ul>
</div>
<div id="banner">
</div>

<!-- start of main content -->
<div id="title"><h1>

ENDHTML

print $sequence;

print <<ENDHTML;
</h1></div>
<div id="content">



<br/><br/>
    

    <div id="placeholder" style="margin: auto; width:800px;height:800px"></div>

  <div id="overview" style="margin: auto;width:400px;height:50px"></div>
<table><tr><td colspan="2"><span style="font-weight: bold">Key</span></td></tr>
<tr><td> Yellow</td><td>Peaks in Both Spectra</td></tr>
<tr><td>  Purple</td><td>  Shifted Peaks between Spectra</td></tr>
<tr><td> Black dot</td><td>Matched</td></tr>
</table>
</p>
ENDHTML

######
#
# Xlink position finder
#
#######

my @peptides = split /-/, $sequence;
for ( my $i = 0 ; $i < @peptides ; $i++ ) {
   my $peptide = $peptides[$i];
   my @residues = split //, $peptide;
   my @tmp;
   for ( my $n = 0 ; $n < @residues ; $n++ ) {
      if ( $residues[$n] eq $xlink_res ) {
         $xlink_pos[$i] = $n;
         last;
      }
   }

}

######
#
# Create_modification mass as needed, (scoring in BSG-Digest.pl should have corrected the sequence)
#
#######

if ( $modification ne 'NoMod' && $modification ne 'MonoLink' ) {
   $residuemass{'X'} = $residuemass{ $modifications{$modification}{Location} } + $modifications{$modification}{Delta};
}

#######
#
# Create DB
#
#######

my $dbh = DBI->connect( "dbi:SQLite:dbname=:memory:", "", "", { RaiseError => 1, AutoCommit => 1 } );
my $masslist = $dbh->prepare("DROP TABLE IF EXISTS masses;");
$masslist->execute();
my $TIC = 0;

my %unsorted_data;

$dbh->do("CREATE TABLE masses  (mass REAL, abundance REAL)");
my $newline = $dbh->prepare("INSERT INTO masses (mass , abundance) VALUES (?, ?)");
foreach my $mass_abundance (@masses) {
   my ( $mass, $abundance ) = split " ", $mass_abundance;
   if ( $abundance > $max_abundance ) { $max_abundance = $abundance }
   $unsorted_data{$mass} = $abundance;
   $TIC                  = $TIC + $abundance;
   $ms2_masses{$mass}    = $abundance;
   $newline->execute( $mass, $abundance );
   $total_ion_current = $total_ion_current + $abundance;
   $data_java         = $data_java . '[' . $mass . ',' . $abundance . '],';
}

if ( $data2 ne "" ) {
   $dbh->do("CREATE TABLE d2_masses  (mass REAL, abundance REAL)");
   my $newline = $dbh->prepare("INSERT INTO d2_masses (mass, abundance) VALUES (?, ?)");
   my %pre_normalised_d2_data;
   foreach my $mass_abundance (@d2_masses) {
      my ( $mass, $abundance ) = split " ", $mass_abundance;
      if ( $abundance > $d2_max_abundance ) { $d2_max_abundance = $abundance }
      $newline->execute( $mass, $abundance );
      $pre_normalised_d2_data{$mass} = $abundance;
   }
   foreach my $mass (keys %pre_normalised_d2_data)
    {
      $data_java = $data_java . '[' . $mass . ',' . -$pre_normalised_d2_data{$mass} * $max_abundance / $d2_max_abundance . '],';
    }
} else {
   $dbh->do("CREATE TABLE d2_masses AS SELECT * FROM masses");
}


my $mass_seperation_upper = +$ms2_error;
my $mass_seperation_lower = -$ms2_error;
my $matchlist = $dbh->prepare(
   "SELECT masses.*, d2_masses.mass as d2_mass, d2_masses.abundance 
    as d2_abundance FROM masses inner join d2_masses on (d2_masses.mass between masses.mass -  ? and masses.mass + ? AND d2_masses.abundance between masses.abundance*0.5*? and masses.abundance*2* ? )"
);
my %matched_common;
my %d2_matched_common;
my %matched_xlink;
$matchlist->execute( $match_tol, $match_tol,$d2_max_abundance/$max_abundance , $d2_max_abundance/$max_abundance  );

while ( my $searchmass = $matchlist->fetchrow_hashref ) {
   $matched_common{ $searchmass->{'mass'} }       = $searchmass->{'abundance'};
   $d2_matched_common{ $searchmass->{'d2_mass'} } = $searchmass->{'d2_abundance'};

   #   $total_ion_current_corrected = $total_ion_current_corrected + $searchmass->{'abundance'};
   $data_green = $data_green . '[' . $searchmass->{'mass'} . ',' . $searchmass->{'abundance'} . '],';
   if ( $data2 ne "" ) {
      $data_green = $data_green . '[' . $searchmass->{'d2_mass'} . ',' . -$searchmass->{'d2_abundance'}* $max_abundance / $d2_max_abundance . '],';
   }
}



$matchlist = $dbh->prepare(
   "SELECT masses.*, d2_masses.mass as d2_mass, d2_masses.abundance 
    as d2_abundance FROM masses inner join d2_masses on (d2_masses.mass between masses.mass +  (?) and masses.mass + (?) AND d2_masses.abundance between masses.abundance*0.5* ? and masses.abundance*2 * ?) "
);
for ( my $i = 1 ; $i < 4 ; $i++ ) {
   $matchlist->execute( ( $xlink_d / $i ) - $match_tol, ( $xlink_d / $i ) + $match_tol, $d2_max_abundance/$max_abundance ,$d2_max_abundance/$max_abundance );
   while ( my $searchmass = $matchlist->fetchrow_hashref ) {
      $matched_xlink{ $searchmass->{'mass'} } = $searchmass->{'abundance'};

      # 	if (!(grep $_ eq $searchmass->{'mass'}, keys %matched_common))
      # 	  {$total_ion_current_corrected = $total_ion_current_corrected + $searchmass->{'abundance'};}
      if (    defined $matched_common{ $searchmass->{'mass'} } == 0
           && defined $d2_matched_common{ $searchmass->{'d2_mass'} } == 0 )
      {    #Purely for cosmetic reasons don't add overlapping peaks
         $data_red = $data_red . '[' . $searchmass->{'mass'} . ',' . $searchmass->{'abundance'} . '],';
         if ( $data2 ne "" ) {
            $data_red = $data_red . '[' . $searchmass->{'d2_mass'} . ',' . -$searchmass->{'d2_abundance'}* $max_abundance / $d2_max_abundance . '],';
         }
      }
   }
}

my $matched_TIC = 0;
@peptides = split /-/, $sequence;
my @xlink_half;
for ( my $i = 0 ; $i < @peptides ; $i++ ) {
   my $peptide      = $peptides[$i];
   my @residues     = split //, $peptide;
   my $peptide_mass = 0;
   foreach my $residue (@residues) {    #split the peptide in indivual amino acids
      $peptide_mass = $peptide_mass + $residuemass{ $residue };    #tally the masses of each amino acid one at a time
   }
   $xlink_half[$i] = $peptide_mass + $terminalmass;
}

if ( !defined $xlink_half[1] ) {
   $xlink_half[1] = 0;
}

for ( my $i = 0 ; $i < @peptides ; $i++ ) {
   if   ( $i == 0 ) { print "<h2>alpha-chain</h2>"; }
   else             { print "<h2>beta-chain</h2>"; }
   my $peptide = $peptides[$i];
   print "<br/><br/><table border=0 cellpadding=4><tr>";
   for ( my $n = 0 ; $n < @peptides ; $n++ ) {
      for ( my $charge = 1 ; $charge < 4 ; $charge++ ) {
         print "<td class='table-heading'>";
         if ( $n > 0 ) { print " xlink-"; }
         print "b-ion+$charge</td>";
         my @residues   = split //, $peptide;
         my $ion_mass   = 0;
         my $residue_no = 0;
         foreach my $residue (@residues) {
            $residue_no = $residue_no + 1;
            print "<td";
            $ion_mass = $ion_mass + $residuemass{$residue};
            if ( $residue_no == $xlink_pos[$i] + 1 && $sequence =~ m/^[^-]*$/ ) {
               $ion_mass = $ion_mass + $monolink;
            }
            my $mz = ( ( $ion_mass + ( $charge * $mass_of_hydrogen ) + ( $n * ( $xlink + $xlink_half[ abs( $i - 1 ) ] ) ) ) / $charge );
            my $match = 0;
            if ( $n == 0 ) {
               foreach my $ms2_mass ( keys %unsorted_data ) {
                  if (    $ms2_mass < ( $mz + $ms2_error )
                       && $ms2_mass > ( $mz - $ms2_error ) )
                  {
                     if ( abs( $match - $mz ) > abs( $mz - $ms2_mass ) ) {
                        $match = $ms2_mass;
                     }
                  }
               }
            } else {
               foreach my $ms2_mass ( keys %unsorted_data ) {
                  if (    $ms2_mass < ( $mz + $ms2_error )
                       && $ms2_mass > ( $mz - $ms2_error ) )
                  {
                     if ( abs( $match - $mz ) > abs( $mz - $ms2_mass ) ) {
                        $match = $ms2_mass;
                     }
                  }
               }
            }

            if ( $n == 0 && $residue_no <= $xlink_pos[$i] && $match != 0 ) {
               $data_match = $data_match . '[' . ($match) . ',' . $unsorted_data{$match} . '],';

               # 	    $matched_TIC = $matched_TIC+ $matched_common{$match};
               if ( $unsorted_data{$match} / $max_abundance < 0.001 ) {
                  print " style='background-color:#888800' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.01 ) {
                  print " style='background-color:#AAAA00' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.1 ) {
                  print " style='background-color:#DDDD00' >";
               } else {
                  print " style='background-color:#FFFF00' >";
               }
            } elsif (    $n == 0
                      && $residue_no > $xlink_pos[$i]
                      && $sequence =~ m/^[^-]*$/
                      && $match != 0 )
            {
               $data_match = $data_match . '[' . ($match) . ',' . $unsorted_data{$match} . '],';

               # 	     $matched_TIC = $matched_TIC+ $unsorted_data{$match};
               if ( $unsorted_data{$match} / $max_abundance < 0.001 ) {
                  print " style='background-color:#880088' >";
               } elsif ( $matched_common{$match} / $max_abundance < 0.01 ) {
                  print " style='background-color:#AA00AA' >";
               } elsif ( $matched_common{$match} / $max_abundance < 0.1 ) {
                  print " style='background-color:#DD00DD' >";
               } else {
                  print " style='background-color:#FF00FF' >";
               }
            } elsif ( $n == 1 && $residue_no > $xlink_pos[$i] && $match != 0 ) {

               # 	      $matched_TIC = $matched_TIC+ $unsorted_data{$match};
               $data_match = $data_match . '[' . ($match) . ',' . $unsorted_data{$match} . '],';
               if ( $unsorted_data{$match} / $max_abundance < 0.001 ) {
                  print " style='background-color:#880088' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.01 ) {
                  print " style='background-color:#AA00AA' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.1 ) {
                  print " style='background-color:#DD00DD' >";
               } else {
                  print " style='background-color:#FF00FF' >";
               }
            } elsif (    $residue_no > $xlink_pos[$i]
                      && $sequence =~ /\-/
                      && $n == 0 )
            {
               print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
            } elsif ( $residue_no <= $xlink_pos[$i] && $n == 1 ) {
               print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
            } else {
               print ">";
            }
            printf "<B>%.2f</B>", $mz;
            if ( $match != 0 ) { printf "<br/>(%.2f)", $match; }
            print "</td>";
         }
         print "</tr>\n<tr>";
      }
   }

   print "<td class='table-heading'>AA</td>";
   my @residues = split //, $peptide;
   foreach my $residue (@residues) {
      print "<td class='table-heading'>$residue</td>";
   }
   print "</tr>\n<tr>";

   for ( my $n = 0 ; $n < @peptides ; $n++ ) {

      for ( my $charge = 1 ; $charge < 4 ; $charge++ ) {
         print "<td class='table-heading'>";
         if ( $n > 0 ) { print " xlink-"; }
         print "y-ion+$charge</td><td style='background-color:#F0F0F0; color:#D0D0D0;'></td>";
         my @residues = split //, $peptide;
         my $peptide_mass = 0;
         foreach my $residue (@residues) {    #split the peptide in indivual amino acids
            $peptide_mass = $peptide_mass + $residuemass{ $residue };    #tally the masses of each amino acid one at a time
         }
         if ( $sequence =~ m/^[^-]*$/ ) {
            $peptide_mass = $peptide_mass + $monolink;
         }
         my $ion_mass   = $peptide_mass;
         my $residue_no = 0;
         foreach my $residue (@residues) {
            $residue_no = $residue_no + 1;
            if ( $residue_no == @residues ) { last; }
            print "<td";
            $ion_mass = $ion_mass - $residuemass{$residue};
            if ( $residue_no == $xlink_pos[$i] + 1 && $sequence =~ m/^[^-]*$/ ) {
               $ion_mass = $ion_mass - $monolink;
            }
            my $mz = ( ( $ion_mass + $terminalmass + ( $charge * $mass_of_hydrogen ) + ( $n * ( $xlink + $xlink_half[ abs( $i - 1 ) ] ) ) ) / $charge );

            my $match = 0;
            if ( $n == 0 ) {

               foreach my $ms2_mass ( keys %unsorted_data ) {
                  if (    $ms2_mass < ( $mz + $ms2_error )
                       && $ms2_mass > ( $mz - $ms2_error ) )
                  {
                     if ( abs( $match - $mz ) > abs( $mz - $ms2_mass ) ) {
                        $match = $ms2_mass;
                     }
                  }
               }
            } else {
               foreach my $ms2_mass ( keys %unsorted_data ) {
                  if (    $ms2_mass < ( $mz + $ms2_error )
                       && $ms2_mass > ( $mz - $ms2_error ) )
                  {
                     if ( abs( $match - $mz ) > abs( $mz - $ms2_mass ) ) {
                        $match = $ms2_mass;
                     }
                  }
               }
            }
            if ( $n == 0 && $residue_no - 1 >= $xlink_pos[$i] && $match != 0 ) {

               # 	    $matched_TIC = $matched_TIC + $matched_common{$match};
               $data_match = $data_match . '[' . ($match) . ',' . $unsorted_data{$match} . '],';
               if ( $unsorted_data{$match} / $max_abundance < 0.001 ) {
                  print " style='background-color:#888800' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.01 ) {
                  print " style='background-color:#AAAA00' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.1 ) {
                  print " style='background-color:#DDDD00' >";
               } else {
                  print " style='background-color:#FFFF00' >";
               }
            } elsif (    $n == 0
                      && $residue_no - 1 < $xlink_pos[$i]
                      && $sequence =~ m/^[^-]*$/
                      && $match != 0 )
            {
               $data_match = $data_match . '[' . ($match) . ',' . $unsorted_data{$match} . '],';

               # 	    $matched_TIC = $matched_TIC+ $matched_common{$match};
               if ( $unsorted_data{$match} / $max_abundance < 0.001 ) {
                  print " style='background-color:#880088' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.01 ) {
                  print " style='background-color:#AA00AA' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.1 ) {
                  print " style='background-color:#DD00DD' >";
               } else {
                  print " style='background-color:#FF00FF' >";
               }
            } elsif (    $n == 1
                      && $residue_no - 1 < $xlink_pos[$i]
                      && $match != 0 )
            {
               $data_match = $data_match . '[' . ($match) . ' ,' . $unsorted_data{$match} . '],';

               # 	      $matched_TIC = $matched_TIC+ $unsorted_data{$match};
               if ( $unsorted_data{$match} / $max_abundance < 0.001 ) {
                  print " style='background-color:#880088' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.01 ) {
                  print " style='background-color:#AA00AA' >";
               } elsif ( $unsorted_data{$match} / $max_abundance < 0.1 ) {
                  print " style='background-color:#DD00DD' >";
               } else {
                  print " style='background-color:#FF00FF' >";
               }
            } elsif (    $residue_no - 1 < $xlink_pos[$i]
                      && $sequence =~ /\-/
                      && $n == 0 )
            {
               print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
            } elsif ( $residue_no - 1 >= $xlink_pos[$i] && $n == 1 ) {
               print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
            } else {
               print ">";
            }
            printf "<B>%.2f</B>", $mz;
            if ( $match != 0 ) { printf "<br/>(%.2f)", $match; }
            print "</td>";
         }
         print "</tr>\n<tr>";
      }
   }

   print "</tr></table>";
}

#
# if ( $total_ion_current_corrected !=0)
#   {print "<BR><font size=+5>Score:", sprintf ("%.0f", ($matched_TIC/$total_ion_current_corrected *100)), "</font>"};


# print "<br/><h2>Crosslinker Ion matches (by intensity) </h2>";
# print "<p>$top_10</p>";

print <<ENDHTML;
<script id="source" language="javascript" type="text/javascript">
\$(function () {

ENDHTML

print "  var sin = [";
print $data_java;
print "];\n";

print "  var match = [";
print $data_match;
print "];\n";

print "  var green = [";
print $data_green;
print "];\n";

print "  var red = [";
print $data_red;
print "];\n";

print <<ENDHTML




    var options = {
 
               series: {
 		   bars: {show: true, lineWidth: 0.75},
 		   shadowSize: 0    

                },
		selection: { mode: "x" },
                grid: { hoverable: true, clickable: false },
    };


     var plot = \$.plot(\$("#placeholder"),
            [ { data: sin, color: '#d0d0d0'}, {data:red,  color: '#9900ff'},{data:green, color: '#ff9900'}, {data:match,points: {show: true}, bars: {show: false}, color: '#000000'} ], options);
 
     function showTooltip(x, y, contents) {
         \$('<div id="tooltip">' + contents + '</div>').css( {
             position: 'absolute',
             display: 'none',
             top: y + 5,
             left: x + 5,
             border: '1px solid #fdd',
             padding: '2px',
             'background-color': '#fee',
             opacity: 0.80
         }).appendTo("body").fadeIn(200);
     }
 
     var previousPoint = null;
     \$("#placeholder").bind("plothover", function (event, pos, item) {
         \$("#x").text(pos.x.toFixed(2));
         \$("#y").text(pos.y.toFixed(2));
 
         
             if (item) {
                 if (previousPoint != item.datapoint) {
                     previousPoint = item.datapoint;
                     
                     \$("#tooltip").remove();
                     var x = item.datapoint[0].toFixed(2),
                         y = item.datapoint[1].toFixed(2);
                     
                     showTooltip(item.pageX, item.pageY, x);
                 }
             
             else {
                \$("#tooltip").remove();
                 previousPoint = null;            
             }
         }
     });
	




 var overview = \$.plot(\$("#overview"), [{ data: sin, color: '#d0d0d0'}, {data:red,  color: '#9900ff'},{data:green,  color: '#ff9900'}], {
        series: {
            bars: { show: true, lineWidth: 1 },
	    
            shadowSize: 0
        },
	
        xaxis: { ticks: []},
        yaxis: { ticks: [], min: 0, autoscaleMargin: 0.1 },
        selection: { mode: "x" }
    });

    // now connect the two
    
    \$("#placeholder").bind("plotselected", function (event, ranges) {
        // do the zooming
        plot = \$.plot(\$("#placeholder"), [{ data: sin, color: '#d0d0d0'},{data:red,  color: '#9900ff'}, {data:green, color: '#ff9900'},{data:match,points: {show: true}, bars: {show: false}, color: '#000000'} ],
                      \$.extend(true, {}, options, {
                          xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to }
                      }));

        // don't fire event on the overview to prevent eternal loop
        overview.setSelection(ranges, true);
    });
    
    \$("#overview").bind("plotselected", function (event, ranges) {
        plot.setSelection(ranges);
    });


    
   
   
});
</script>
<br/><br/>
</div>
<!-- close main content -->
<div id="footer">
Last update: 19-May-2011, &copy; Andrew N Holding, <br/>LTQ Orbitrap image CC <a class="footer" href="http://www.emsl.pnl.gov/">EMSL</a>

</div> <!--close footer -->
</div> <!-- close container -->

</body>
</html>

ENDHTML

