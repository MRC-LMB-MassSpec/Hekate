use strict;

package Crosslinker::Proteins;
use base 'Exporter';
use lib 'lib';
use Crosslinker::Config;

our @EXPORT = (
               'modifications',      'residue_position',
               'digest_proteins',    'digest_proteins_masses',
               'crosslink_peptides', 'calculate_peptide_masses',
               'calculate_crosslink_peptides', 'calculate_amber_crosslink_peptides',
	       'generate_monolink_peptides', 'generate_modified_peptides',
	       'no_enzyme_digest_proteins',
);

sub no_enzyme_digest_proteins {

my ($min_length, $max_length, $reactive_site, $sequence) = @_;
my @peptides;

$reactive_site =~ s/,//g; 

for (my $x=$min_length; $x <= $max_length; $x++)
{
for (my $y=$min_length; $y <= $max_length; $y++)
{

while ($sequence =~ m/(.{$x})(?=([$reactive_site].{$y}))/g) {
    push @peptides, "$1$2";

}
#  @peptides = (@peptides, $sequence =~ m/.{$x}$reactive_site.{$y}/g);
}
}

return \@peptides 

}

sub generate_modified_peptides {

my ($results_dbh,  $results_table, $modifications_ref ) = @_;
  my %modifications       = %{$modifications_ref};


    
    my $modify = $results_dbh->prepare("
	  INSERT INTO peptides
	  SELECT 
		 results_table,
		 sequence,
 		 source,
		 linear_only,
		 mass + ? as mass, 
		 ? as modifications,
		 monolink,
		 xlink,
		 ? as no_of_mods
		 FROM peptides
 			  WHERE modifications = '' and  (LENGTH(sequence) - LENGTH(REPLACE(sequence, ?, ''))) >= (? + 0)
    ");

#  and (LENGTH(sequence) - LENGTH(REPLACE(sequence, ?, ''))) >= ? ;

    my $monolinks = $results_dbh->prepare("
	  INSERT INTO peptides
	  SELECT 
		 results_table,
		 sequence,
 		 source,
		 linear_only,
		 mass + ? as mass, 
		 ? as modifications,
		 monolink,
		 xlink,
		 ? as no_of_mods
		 FROM peptides
 			  WHERE  sequence LIKE ? and xlink = 0 and monolink > 0 and modifications = '' ;
    ");



foreach my $modification (sort(keys %modifications)) {


                if (   !($modifications{$modification}{Name} eq "loop link" )
                    && !($modifications{$modification}{Name} eq "mono link" ) 
		    && !($modifications{$modification}{Name} eq " ")
                  ) 
                {
		    for (my $n = 1; $n <= 3; $n++) {
# 		    warn  "Modification:" . $modification;
		    $modify->execute($modifications{$modification}{Delta}*$n,$modification, $n, $modifications{$modification}{Location}, $n+0)
		    }
		} elsif ($modifications{$modification}{Name} eq "loop link" ) {
		    $monolinks->execute($modifications{$modification}{Delta},$modification, 1, "%".$modifications{$modification}{Location}."%")
		}
}



}
sub generate_monolink_peptides {

my ($results_dbh,  $results_table,   $reactive_site, $mono_mass_diff) = @_;
my @monolink_masses = split(",", $mono_mass_diff);



    my $monolinks = $results_dbh->prepare("
	  INSERT INTO peptides
	  SELECT 
		 results_table,
		 sequence,
 		 source,
		 linear_only,
		 mass + ? as mass, 
		 '' as modifications,
		 ? as monolink,
		 0 as xlink,
		 0 as no_of_mods
		 FROM peptides
 			  WHERE sequence LIKE ? and xlink = 0 and monolink = 0 and results_table = ?;
    ");

  my @reactive_sites = split ( ',' , $reactive_site);

  foreach my $monolink_mass (@monolink_masses) {
      $monolinks->execute($monolink_mass, $monolink_mass, "%".$reactive_sites[0]."%", $results_table);
  }


return;
}

sub modifications {

    my ($mono_mass_diff, $xlinker_mass, $reactive_site, $table, $dbh) = @_;

        if ($reactive_site =~ /[^,]/) {  $reactive_site = $reactive_site . ',' . $reactive_site};
    my @reactive_sites = split (',',$reactive_site);

    my %modifications = (

        #                           MethOx => {
        #                                       Name     => 'M(ox)',
        #                                       Location => 'M',
        #                                       Delta    => 15.994915,
        #                           },

        MonoLink => {
                      Name     => 'mono link',
                      Location => $reactive_sites[0],
                      Delta    => $mono_mass_diff,
        },
        LoopLink => {
            Name     => 'loop link',
            Location => $reactive_sites[1],
            Delta    => -18.0105646
            ,    #Loop links are treated as a modified monolink (loop link on an xlink is too complicated, and wierd)
        },
        NoMod => {
                   Name     => ' ',
                   Location => '^.',
                   Delta    => 0,
        },
    );

    #      my $n= 0;
    #      foreach my $monolink_mass (split(",",$modifications{MonoLink}{Delta})) {
    # 	     $n=$n+1;
    #              $modifications{ "MonoLink".$n }{'Name'}     = 'mono link';
    #              $modifications{ "MonoLink".$n }{'Location'} =  $reactive_site;
    #              $modifications{ "MonoLink".$n }{'Delta'}    = $monolink_mass;
    #          }

    if (defined $table) {
        my $dynamic_mods = get_mods($table, 'dynamic', $dbh);
        while ((my $dynamic_mod = $dynamic_mods->fetchrow_hashref)) {
            $modifications{ $dynamic_mod->{'mod_id'} }{'Name'}     = $dynamic_mod->{'mod_name'};
            $modifications{ $dynamic_mod->{'mod_id'} }{'Location'} = $dynamic_mod->{'mod_residue'};
            $modifications{ $dynamic_mod->{'mod_id'} }{'Delta'}    = $dynamic_mod->{'mod_mass'};
        }
    }

#    foreach my $modification ( sort( keys %modifications ) )
#    {
#     warn "$modification,     $modifications{$modification}{'Name'} .  $modifications{$modification}{'Location'},    $modifications{$modification}{'Delta'} \n";
#    }

    return %modifications;
}

sub residue_position    #locates peptides in proteins
{
    my ($fragment, $protien_sequences) = @_;
    my @sequences = split('>', $protien_sequences);
    my $sequence_no;
    my $residue_no = 0 ;

    for (my $n = 0 ; $n < @sequences ; $n++) {
        if (index($sequences[$n], $fragment) != -1) {
            $residue_no = index($sequences[$n], $fragment);
            $sequence_no = $n;
            last;
        }
    }
    return ($residue_no);
}

sub digest_proteins    #Digest a string into an array of peptides
{
    my ($missed_clevages, $protein_sequences, $cut_residues, $nocut_residues, $n_or_c) = @_;
    my @protein_fragments;
    $protein_sequences =~ s/[^A-Z]//g;
    my $protein = $protein_sequences;
    $protein =~ s/[^\w\d>]//g;
    if ($nocut_residues eq '') { $nocut_residues = '9' }
    ;                  #Numbers don't appear in sequences so this just works, easier than having a second regex

    #    warn "No Cut:", $nocut_residues, "\n";
    my @digest;
    my @digest_not_for_crosslinking;
    if ($n_or_c eq 'C') {

        #      warn "Protease type:", $n_or_c, "\n";
        @digest = $protein =~
          m/(?:(?:[^$cut_residues]|[$cut_residues]$nocut_residues)*(?:[$cut_residues](?!$nocut_residues)|.(?=$))){1}/g;
        my @single_digest = @digest;
        for (my $i = 2 ; $i < ($missed_clevages * 2 + 1) + 2 ; $i++) {
            my @single_digest_trimmed =
              @single_digest;    #need to include missed cleavages for each possible missed position
            my @parts = $protein =~
m/(?:(?:[^$cut_residues]|[$cut_residues]$nocut_residues)*(?:[$cut_residues](?!$nocut_residues)|.(?=$))){$i}/g;
            if ($i < $missed_clevages + 2) {
                push(@digest, @parts);
            } else {
                push(@digest_not_for_crosslinking, @parts);
            }
            for (my $j = 1 ; $j < $i ; $j++) {
                shift @single_digest_trimmed;
                @parts =
                  join("", @single_digest_trimmed) =~
m/(?:(?:[^$cut_residues]|[$cut_residues]$nocut_residues)*(?:[$cut_residues](?!$nocut_residues)|.(?=$))){$i}/g;
                if ($i < $missed_clevages + 2) {
                    push(@digest, @parts);
                } else {
                    push(@digest_not_for_crosslinking, @parts);
                }
            }
        }

#      }
#      elsif ($n_or_c eq 'C..N') {
# #      warn "Protease type:", $n_or_c, "\n";
#      my $cut_residues_c = chop $cut_residues;
# #       $cut_residues = 'RK';
#
#      @digest = $protein =~ m/(?:(?:[$cut_residues_c](?!$nocut_residues)|^.)(?:[^$cut_residues_c]|[$cut_residues_c]$nocut_residues)*){1}/g;
#      my @single_digest = @digest;
#       for ( my $i = 2 ; $i < ($missed_clevages*2+1)+2 ; $i++ ) {
#          my @single_digest_trimmed = @single_digest;
#          my @parts = $protein =~ m/(?:(?:[$cut_residues_c](?!$nocut_residues)|^.)(?:[^$cut_residues_c]|[$cut_residues_c]$nocut_residues)*){1}/g;
# 	    push( @digest, @parts );
#          for ( my $j = 1 ; $j < $i ; $j++ ) {
#             shift @single_digest_trimmed;
#             @parts =
#               join( "", @single_digest_trimmed ) =~ m/(?:(?:[$cut_residues_c](?!$nocut_residues)|^.)(?:[^$cut_residues_c]|[$cut_residues_c]$nocut_residues)*){1}/g;
# 	      push( @digest, @parts );
#          }
#        }
#
#      my @double_digest = @digest;
#
#       foreach my $double_digest_peptide (@double_digest) {
#       my @single_digest = $double_digest_peptide =~ m/(?:(?:[^$cut_residues]|[$cut_residues]$nocut_residues)*(?:[$cut_residues](?!$nocut_residues)|.(?=$))){1}/g;
# #       foreach (@single_digest)
# #       {
# #  	warn $_;
# #       }
#
#       push @digest, @single_digest;
#       for ( my $i = 2 ; $i < ($missed_clevages*2+1)+2 ; $i++ ) {
#          my @single_digest_trimmed = @single_digest;    #need to include missed cleavages for each possible missed position
#          my @parts = $protein =~ m/(?:(?:[^$cut_residues_c]|[$cut_residues_c]$nocut_residues)*(?:[$cut_residues_c](?!$nocut_residues)|.(?=$))){$i}/g;
# #          push( @digest, @parts );
#          for ( my $j = 1 ; $j < $i ; $j++ ) {
#             shift @single_digest_trimmed;
#             @parts =
#               join( "", @single_digest_trimmed ) =~ m/(?:(?:[^$cut_residues_c]|[$cut_residues_c]$nocut_residues)*(?:[$cut_residues_c](?!$nocut_residues)|.(?=$))){$i}/g;
# #            push( @digest, @parts );
#          }
#        }
#        }
    } else {

        #      warn "Protease type:", $n_or_c, "\n";
        @digest = $protein =~
          m/(?:(?:[$cut_residues](?!$nocut_residues)|^.)(?:[^$cut_residues]|[$cut_residues]$nocut_residues)*){1}/g;
        my @single_digest = @digest;
        for (my $i = 2 ; $i < ($missed_clevages * 2 + 1) + 2 ; $i++) {
            my @single_digest_trimmed = @single_digest;
            my @parts                 = $protein =~
              m/(?:(?:[$cut_residues](?!$nocut_residues)|^.)(?:[^$cut_residues]|[$cut_residues]$nocut_residues)*){1}/g;
            if ($i < $missed_clevages + 2) {
                push(@digest, @parts);
            } else {
                push(@digest_not_for_crosslinking, @parts);
            }
            for (my $j = 1 ; $j < $i ; $j++) {
                shift @single_digest_trimmed;
                @parts =
                  join("", @single_digest_trimmed) =~
m/(?:(?:[$cut_residues](?!$nocut_residues)|^.)(?:[^$cut_residues]|[$cut_residues]$nocut_residues)*){1}/g;
                if ($i < $missed_clevages + 2) {
                    push(@digest, @parts);
                } else {
                    push(@digest_not_for_crosslinking, @parts);
                }
            }
        }
    }
    return \@digest, \@digest_not_for_crosslinking;
}

sub digest_proteins_masses    #Calculates the mass of a list of peptides
{
    my ($protein_fragments_ref, $protein_residuemass_ref, $fragment_source_ref) = @_;
    my @protein_fragments   = @{$protein_fragments_ref};
    my %protein_residuemass = %{$protein_residuemass_ref};
    my %fragment_source     = %{$fragment_source_ref};
    my $peptide_mass        = 0;
    my $terminalmass        = 1.0078250 * 2 + 15.9949146 * 1;
    my %protein_fragments_masses;
    my @protein_fragments_masses;

    foreach my $peptide (@protein_fragments) {
        if ($peptide =~ /[ARNDCEQGHILKMFPSTWYV]/) {
            my @residues = split //, $peptide;

            foreach my $residue (@residues) {    #split the peptide in indivual amino acids
                $peptide_mass =
                  $peptide_mass + $protein_residuemass{$residue};    #tally the masses of each amino acid one at a time
            }

            $protein_fragments_masses{$peptide} = $peptide_mass + $terminalmass;

#  	 warn "," ,$peptide," , " ,$peptide_mass +$terminalmass ," , " ,($peptide_mass +$terminalmass)/2 , ",",($peptide_mass +$terminalmass)/3 , "\n";
            $peptide_mass = 0;
        }

    }

    return %protein_fragments_masses;
}

sub calculate_peptide_masses {
    my ($results_dbh, $results_table, $protein_residuemass_ref, $fragment_source_ref) = @_;
    my %protein_residuemass = %{$protein_residuemass_ref};
    my %fragment_source     = %{$fragment_source_ref};
    my $peptide_mass        = 0;
    my $terminalmass        = 1.0078250 * 2 + 15.9949146 * 1;

    my $peptidelist = $results_dbh->prepare("SELECT * FROM peptides WHERE results_table = ?");

    my $update_mass = $results_dbh->prepare("UPDATE peptides SET mass = ? WHERE  results_table = ? AND sequence = ?;");

    $peptidelist->execute($results_table);

    while (my $peptides = $peptidelist->fetchrow_hashref) {
        my $peptide = $peptides->{'sequence'};
        if ($peptide =~ /[ARNDCEQGHILKMFPSTWYV]/) {
            my @residues = split //, $peptide;

            foreach my $residue (@residues) {    #split the peptide in indivual amino acids
                $peptide_mass =
                  $peptide_mass + $protein_residuemass{$residue};    #tally the masses of each amino acid one at a time
            }

            #          $protein_fragments_masses{$peptide} = $peptide_mass + $terminalmass;
            $update_mass->execute($peptide_mass + $terminalmass, $results_table, $peptide);
            $peptide_mass = 0;
        }

    }

}

sub crosslink_peptides                                               #Calculates all the possible xlinks
{

    #This is slightly missleading in name as it also returns all the linear peptides too.
    my (
        $peptides_ref, $fragment_source_ref, $reactive_site, $min_peptide_length,
        $xlinker_mass, $missed_clevages,     $cut_residues
    ) = @_;
    my %peptides        = %{$peptides_ref};
    my %fragment_source = %{$fragment_source_ref};
    my $xlink;
    my %xlink_fragment_masses = %peptides;
    my %xlink_fragment_sources;

    foreach my $peptide_1 (sort keys %peptides) {
        if ($min_peptide_length <= length($peptide_1)) {
            foreach my $peptide_2 (sort keys %peptides) {    #Add \B to stop xlinks being on terminal residue
                if (   $min_peptide_length <= length($peptide_2)
                    && $peptide_1 =~ m/[$reactive_site]\B/
                    && $peptide_2 =~ m/[$reactive_site]\B/
                    && defined $xlink_fragment_masses{ $peptide_1 . '-' . $peptide_2 } == 0
                    && defined $xlink_fragment_masses{ $peptide_2 . '-' . $peptide_1 } == 0)
                {
                    $xlink                          = $peptide_1 . '-' . $peptide_2;
                    $xlink_fragment_masses{$xlink}  = $peptides{$peptide_1} + $peptides{$peptide_2} + $xlinker_mass;
                    $xlink_fragment_sources{$xlink} = $fragment_source{$peptide_1} . "-" . $fragment_source{$peptide_2};

#    	 warn "," ,$xlink," , " ,$xlink_fragment_masses{$xlink} ," , " ,$xlink_fragment_masses{$xlink}/2 , ",",$xlink_fragment_masses{$xlink}/3 , "\n";
                }
            }
        }
    }

    return (\%xlink_fragment_masses, \%xlink_fragment_sources);
}

sub calculate_crosslink_peptides {

    my (
        $results_dbh,  $results_table,   $reactive_site, $min_peptide_length,
        $xlinker_mass, $missed_clevages, $cut_residues
    ) = @_;

    my $xlink;
    my $xlink_fragment_mass;
    my $xlink_fragment_sources;

    my $stop_duplicates = 'AND p1.rowid >= p2.rowid';


    my @reactive_sites = split (',',$reactive_site);

    if ($reactive_sites[0] ne $reactive_sites[1]) {$stop_duplicates = ''};

    my $peptidelist = $results_dbh->prepare("
	  INSERT INTO peptides
	  SELECT
		 p1.results_table as results_table,
		 p1.sequence || '-' || p2.sequence as sequence,
 		 p1.source   || '-' || p2.source as source,
		 0 as linear_only,
		 p1.mass + p2.mass as mass, 
		 '' as modifications,
		 0 as monolink,
		 1 as xlink,
		 0 as no_of_mods
	
			  FROM peptides p1 inner join peptides p2 on (p1.results_table = p2.results_table)
 			  WHERE p1.linear_only = '0' AND p2.linear_only = '0' AND p1.xlink ='0' and p2.xlink = '0' AND p1.sequence LIKE ? AND p2.sequence LIKE ?
			  $stop_duplicates
    ");

    my $index = $results_dbh->prepare("CREATE INDEX peptide_index ON peptides (sequence);");
    $index->execute();


    foreach my $reactive_site_chain_1 (split //, $reactive_sites[0]) 
      {
      foreach my $reactive_site_chain_2 (split //, $reactive_sites[1]) 
	{
# 	warn "%".$reactive_site_chain_1."_%","%".$reactive_site_chain_2."_%";
 	$peptidelist->execute("%".$reactive_site_chain_1."_%","%".$reactive_site_chain_2."_%");
	$results_dbh->commit;
	}
      }
      
    my $correct_xlink_mass =
      $results_dbh->prepare("UPDATE peptides SET mass = mass + ? WHERE  xlink = 1 and results_table = ?;");
    $correct_xlink_mass->execute($xlinker_mass, $results_table);

    #Need to add xlinker mass to all xlinks with UPDATE statments.

}

sub calculate_amber_crosslink_peptides {

    my (
        $results_dbh,  $results_table,   $amber_peptide, $min_peptide_length,
        $amber_xlink_delta, $missed_clevages, $cut_residues, $amber_residue_mass,
	$protein_residuemass_ref
    ) = @_;

    
    my $xlink;
    my $xlink_fragment_mass;
    my $xlink_fragment_sources;
    my %protein_residuemass = %{$protein_residuemass_ref};
    my $terminal_mass        = 1.0078250 * 2 + 15.9949146 * 1;

    my $peptidelist = $results_dbh->prepare("
	  INSERT INTO peptides
	  SELECT
		 results_table as results_table,
		 sequence || '-' || ? as sequence,
 		 source || '-' || '0'  as source,
		 0 as linear_only,
		 mass + ? as mass, 
		 '' as modifications,
		 0 as monolink,
		 1 as xlink,
		 0 as no_of_mods
	
			  FROM peptides
 			  WHERE linear_only = '0'
    ");

    my $index = $results_dbh->prepare("CREATE INDEX peptide_index ON peptides (sequence);");
    $index->execute();


	    my $amber_peptide_mass = 0;
            my @residues = split //, $amber_peptide;
	    $protein_residuemass{'Z'} = $amber_residue_mass;

            foreach my $residue (@residues) {    
                $amber_peptide_mass =
                  $amber_peptide_mass + $protein_residuemass{$residue};   
            }
        
    $peptidelist->execute($amber_peptide, $amber_peptide_mass+ $terminal_mass);

    my $correct_xlink_mass =
      $results_dbh->prepare("UPDATE peptides SET mass = mass + ? WHERE  xlink = 1 and results_table = ?;");
    $correct_xlink_mass->execute($amber_xlink_delta, $results_table);


}
1;
