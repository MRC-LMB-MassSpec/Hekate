use strict;

package Crosslinker::Links;
use base 'Exporter';
our @EXPORT = ('print_ms2_link', 'print_xquest_link', 'print_ms2_img');
######
#
# Creates a link to other pages
#
######

sub print_ms2_link    #Creates link to ms/2
{

    my (
        $MSn_string,   $d2_MSn_string,  $sequence, $modification, $best_x, $best_y,
        $xlinker_mass, $mono_mass_diff, $top_10,   $xlink_res,    $table
    ) = @_;

    print '
<form method="post" target="_blank"  action="ms2.pl" enctype="multipart/form-data">
<input type="hidden" name="data" value="', $MSn_string, '"  />';
    if (defined $d2_MSn_string) {
        print '<input type="hidden" name="data2"  value="', $d2_MSn_string, '">';
    }
    print '
<input type="hidden" name="sequence" value="',     $sequence,       '" />
<input type="hidden" name="modification" value="', $modification,   '" />
<input type="hidden" name="xlinkermw" value="',    $xlinker_mass,   '" size="10" maxlength="15" />
<input type="hidden" name="monolinkermw" value="', $mono_mass_diff, '" size="10" maxlength="15" />
<input type="hidden" name="best_x" value="',       $best_x,         '" size="10" maxlength="15" />
<input type="hidden" name="best_y" value="',       $best_y,         '" size="10" maxlength="15" />
<input type="hidden" name="top_10" value="',       $top_10,         '" />
<input type="hidden" name="xlink_res" value="',    $xlink_res,      '" />
<input type="hidden" name="table" value="',        $table,          '" />


<input class="btn btn-info" type="submit" name="update" value="ms2" />
</form>
';

}

sub print_xquest_link    #Creates link to Xquest
{
    my (
        $MSn_string,       $d2_MSn_string,    $mz,                    $charge,
        $sequences,        $isotopic_shift,   $mass_of_deuterium,     $mass_of_hydrogen,
        $mass_of_carbon13, $mass_of_carbon12, $cut_residues,          $xlinker_mass,
        $mono_mass_diff,   $reactive_site,    $user_protein_sequence, $static_mod_string,
        $varible_mod_string
    ) = @_;
    print '
<form method="post" target="_blank"  action="http://prottools.ethz.ch/orinner/public/cgi-bin/xquest/xquest.cgi" enctype="multipart/form-data">
<input type="hidden" name="usepastedata" value="1"/>
<input type="hidden" name="define_enzyme" value="c@', $cut_residues,   '^P" size="10" maxlength="10" />
<input type="hidden" name="xlinkermw" value="',       $xlinker_mass,   '" size="10" maxlength="15" />
<input type="hidden" name="monolinkmw" value="',      $mono_mass_diff, '" size="30" maxlength="60" />
<input type="hidden" name="cp_isotopediff", value="', $isotopic_shift, '" size="8" maxlength="10" />
<input type="hidden" name="ionisation"  value="ESI">
<input type="hidden" name="AArequired" value="', $reactive_site,     '" size="10" maxlength="10" />
<input type="hidden" name="AAshift" value="',    $static_mod_string, '" size="20" maxlength="20" />
<input type="hidden" name="ms1tolerance" value="10" size="3" maxlength="10" align="left" />
<input type="hidden" name="tolerancemeasure" value="ppm"  />
<input type="hidden" name="ms2tolerance" value="1" size="5" maxlength="10" />
<input type="hidden" name="advanced" value="on" />
<input type="hidden" name="dataupload" value="paste text data"  />
<input type="hidden" name="mindigestlength" value="3" size="2" maxlength="3" />
<input type="hidden" name="maxdigestlength" value="40" size="2" maxlength="3" />
<input type="hidden" name="missed_cleavages" value="3" size="2" maxlength="3" /> 
<input type="hidden" name="cutatxlink" value="off" default="0" />
<input type="hidden" name="variable_mod" value="', $varible_mod_string, '" size="20" maxlength="20" />
<input type="hidden" name="xlink_ms2tolerance" value="1" size="2" maxlength="10" /> 
<input type="hidden" name="minionsize" value="200" size="2" maxlength="10" />
<input type="hidden" name="maxionsize" value="1600" size="2" maxlength="10" />
<input type="hidden" name="ionseries_b" value="1" />
<input type="hidden" name="ionseries_y" value="1"  />
<input type="hidden" name="ionseries_a" value="1"/>
<input type="hidden" name="cp_threshold" value="1" size="2" maxlength="3" /> 
<input type="hidden" name="cp_dynamic_range" value="1000" size="2" maxlength="4" />
<input type="hidden" name="precursor_mz" value="', $mz, '" size="10" maxlength="15" />
<input type="hidden" name="precursor_charge" value="', $charge,
      '" size="10" maxlength="1" label="precursor charge   " />
<input type="hidden" name="pastedatabase" value="', $user_protein_sequence, '">
<input type="hidden" name="pastedta1"  value="',    $MSn_string,            '">';

    if (defined $d2_MSn_string) {
        print '<input type="hidden" name="pastedta2"  value="', $d2_MSn_string, '">';

    } else {
        print '<input type="hidden" name="pastedta2"  value="">';
    }

    print
'<input type="hidden" name=".cgifields" value="dataupload"  /><input type="hidden" name=".cgifields" value="ionseries_a"  /><input type="hidden" name=".cgifields" value="tolerancemeasure"  /><input type="hidden" name=".cgifields" value="decoy"  />
<input type="hidden" name=".cgifields" value="Iontagmode"  /><input type="hidden" name=".cgifields" value="ionseries_c"  /><input type="hidden" name=".cgifields" value="advanced"  /><input type="hidden" name=".cgifields" value="cutatxlink"  /><input type="hidden" name=".cgifields" value="ionseries_b"  /><input type="hidden" name=".cgifields" value="ionseries_z"  /><input type="hidden" name=".cgifields" value="ionseries_x"  /><input type="hidden" name=".cgifields" value="ionseries_y"  />
<input type="submit" name="update" value="xQuest" />
</form>
';

}

sub print_ms2_img    #Creates link to img
{
    my ($scan, $dbh) = @_;

    my $MS2_data = $dbh->prepare(
        "SELECT *
  			  FROM scans WHERE scan_num = ? 
  			  ORDER BY abundance*1 DESC LIMIT 50"
    );
    $MS2_data->execute($scan);
    my $MSn_string;
    my $n;

    while ((my $MS2_row = $MS2_data->fetchrow_hashref)) {    #&& $n <= 100
        $n++;
        $MSn_string = $MSn_string . "-" . $MS2_row->{'mz'} . " " . $MS2_row->{'abundance'};
    }    #pull all records from our database of scans.

    # $MSn_string =~ s/\n/-/g;
    print '<img src="img/gnuplot4.pl?data=' . $MSn_string . '"/>';
}

1;

