use strict;

package Crosslinker::Constants;
use base 'Exporter';
use lib 'lib';
use Crosslinker::Config;

our @EXPORT = ('residue_mass', 'protein_residuemass', 'constants', 'version', 'installed');

######
#
# Constansts
#
# Defines constasts used by Crosslinker
#
######

sub residue_mass {
    my %RNA_residuemass = (
                           g => 345.04744,
                           u => 306.02530,
                           c => 305.04129,
                           a => 329.05252,
    );

    return %RNA_residuemass;
}

sub protein_residuemass {

    my ($table, $dbh) = @_;

    my %protein_residuemass = (
                               G => 57.02146,
                               A => 71.03711,
                               S => 87.03203,
                               P => 97.05276,
                               V => 99.06841,
                               T => 101.04768,
                               C => 103.00919,
                               L => 113.08406,
                               I => 113.08406,
                               X => 113.08406,    # (L or I)
                               N => 114.04293,
                               O => 114.07931,
                               B => 114.53494,    # (avg N+D)
                               D => 115.02694,
                               Q => 128.05858,
                               K => 128.09496,
                               Z => 128.55059,    #(avg Q+E)
                               E => 129.04259,
                               M => 131.04049,
                               H => 137.05891,
                               F => 147.06841,
                               R => 156.10111,
                               Y => 163.06333,
                               W => 186.07931
    );

    if (defined $table) {
        my $fixed_mods = get_mods($table, 'fixed', $dbh);
        while ((my $fixed_mod = $fixed_mods->fetchrow_hashref)) {
            $protein_residuemass{ $fixed_mod->{'mod_residue'} } =
              $protein_residuemass{ $fixed_mod->{'mod_residue'} } + $fixed_mod->{'mod_mass'};
        }

    }
    return %protein_residuemass;
}

sub constants {
    my $mass_of_deuterium = 2.01410178;
    my $mass_of_hydrogen  = 1.00783;
    my $mass_of_proton    = 1.00728;
    my $mass_of_carbon12  = 12;
    my $mass_of_carbon13  = 13.00335;

    my $no_of_fractions    = 20;
    my $min_peptide_length = '3';

    #    my $scan_width         = 60;

    return (
            $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12,
            $mass_of_carbon13,  $no_of_fractions,  $min_peptide_length
    );
}

sub version {
    return '0.9.3';
}

sub installed {
    return 'crosslinker';
}

1;

