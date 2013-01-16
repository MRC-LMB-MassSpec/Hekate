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
use Crosslinker::Scoring;
use Crosslinker::HTML;

#loads database modules

########################
#                      #
# Varibles             #
#                      #
########################

my $query     = new CGI;
my $sequence  = $query->param('sequence');
my $xlink     = $query->param('xlinker_mass');
my $xlink_res = $query->param('reactive_site');

my $modification;
my $monolink = 0;

my $path = installed;

# Constants
my (
    $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton,     $mass_of_carbon12,
    $mass_of_carbon13,  $no_of_fractions,  $min_peptide_length, $scan_width
) = constants;
my %residuemass = protein_residuemass();

my %modifications = modifications(0, $xlink, $xlink_res);

my $terminalmass = 1.0078250 * 2 + 15.9949146 * 1;
my @xlink_pos;

# my@xlink_pos[0];	#alpha chain xlink position
# my @xlink_pos[1];	#beta chain xlink position

########################
#                      #
# Main Program         #
#                      #
########################

#
print_page_top_bootstrap("Fragment");
my $version = version();
print '<div class="row">
<div class="span8 offset2">
   <div class="page-header">
  <h1>Crosslinker <small>Fragment</small></h1>
</div></div></div>';

my @peptides = split /-/, $sequence;
for (my $i = 0 ; $i < @peptides ; $i++) {
    my $peptide = $peptides[$i];
    my @residues = split //, $peptide;
    my @tmp;
    for (my $n = 0 ; $n < @residues ; $n++) {
        if ($residues[$n] eq $xlink_res) {
            $xlink_pos[$i] = $n;
            last;
        }
    }

}

@peptides = split /-/, $sequence;
my @xlink_half;
for (my $i = 0 ; $i < @peptides ; $i++) {
    my $peptide      = $peptides[$i];
    my @residues     = split //, $peptide;
    my $peptide_mass = 0;
    foreach my $residue (@residues) {    #split the peptide in indivual amino acids
        $peptide_mass = $peptide_mass + $residuemass{$residue};    #tally the masses of each amino acid one at a time
    }
    $xlink_half[$i] = $peptide_mass + $terminalmass;
}

if (!defined $xlink_half[1]) {
    $xlink_half[1] = 0;
}

for (my $i = 0 ; $i < @peptides ; $i++) {
    if   ($i == 0) { print "<h2>alpha-chain</h2>"; }
    else           { print "<h2>beta-chain</h2>"; }
    my $peptide = $peptides[$i];
    print "<br/><br/><table class='table table-striped' border=0 cellpadding=4><tr>";
    for (my $n = 0 ; $n < @peptides ; $n++) {
        for (my $charge = 1 ; $charge < 4 ; $charge++) {
            print "<td class='table-heading'>";
            if ($n > 0) { print " xlink-"; }
            print "b-ion+$charge</td>";
            my @residues   = split //, $peptide;
            my $ion_mass   = 0;
            my $residue_no = 0;
            foreach my $residue (@residues) {
                $residue_no = $residue_no + 1;
                print "<td";
                $ion_mass = $ion_mass + $residuemass{$residue};
                if ($residue_no == $xlink_pos[$i] + 1 && $sequence =~ m/^[^-]*$/) {
                    $ion_mass = $ion_mass + $monolink;
                }
                my $mz =
                  (($ion_mass + ($charge * $mass_of_hydrogen) + ($n * ($xlink + $xlink_half[ abs($i - 1) ]))) /
                    $charge);
                my $match = 0;

                if (   $residue_no > $xlink_pos[$i]
                    && $sequence =~ /\-/
                    && $n == 0)
                {
                    print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
                } elsif ($residue_no <= $xlink_pos[$i] && $n == 1) {
                    print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
                } else {
                    print ">";
                }
                printf "<B>%.2f</B>", $mz;
                if ($match != 0) { printf "<br/>(%.2f)", $match; }
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

    for (my $n = 0 ; $n < @peptides ; $n++) {

        for (my $charge = 1 ; $charge < 4 ; $charge++) {
            print "<td class='table-heading'>";
            if ($n > 0) { print " xlink-"; }
            print "y-ion+$charge</td><td style='background-color:#F0F0F0; color:#D0D0D0;'></td>";
            my @residues = split //, $peptide;
            my $peptide_mass = 0;
            foreach my $residue (@residues) {    #split the peptide in indivual amino acids
                $peptide_mass =
                  $peptide_mass + $residuemass{$residue};    #tally the masses of each amino acid one at a time
            }
            if ($sequence =~ m/^[^-]*$/) {
                $peptide_mass = $peptide_mass + $monolink;
            }
            my $ion_mass   = $peptide_mass;
            my $residue_no = 0;
            foreach my $residue (@residues) {
                $residue_no = $residue_no + 1;
                if ($residue_no == @residues) { last; }
                print "<td";
                $ion_mass = $ion_mass - $residuemass{$residue};
                if ($residue_no == $xlink_pos[$i] + 1 && $sequence =~ m/^[^-]*$/) {
                    $ion_mass = $ion_mass - $monolink;
                }
                my $mz = (
                          (
                           $ion_mass +
                             $terminalmass +
                             ($charge * $mass_of_hydrogen) +
                             ($n * ($xlink + $xlink_half[ abs($i - 1) ]))
                          ) / $charge
                );

                my $match = 0;

                if (   $residue_no - 1 < $xlink_pos[$i]
                    && $sequence =~ /\-/
                    && $n == 0)
                {
                    print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
                } elsif ($residue_no - 1 >= $xlink_pos[$i] && $n == 1) {
                    print " style='background-color:#F0F0F0; color:#D0D0D0;' >";
                } else {
                    print ">";
                }
                printf "<B>%.2f</B>", $mz;
                if ($match != 0) { printf "<br/>(%.2f)", $match; }
                print "</td>";
            }
            print "</tr>\n<tr>";
        }
    }

    print "</tr></table>";
}



print_page_bottom_bootstrap;
exit;
