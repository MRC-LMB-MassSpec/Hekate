use strict;

package Crosslinker::Results;
use lib 'lib';
use Crosslinker::Links;
use Crosslinker::Proteins;
use Crosslinker::Constants;
use Crosslinker::Config;
use base 'Exporter';
our @EXPORT = ( 'print_results', 'print_results_combined', 'print_report', 'print_pymol', 'print_results_text' );

sub print_pymol {

   my (
        $top_hits,       $mass_of_hydrogen,  $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13,
        $cut_residues,   $protien_sequences, $reactive_site,     $dbh,              $xlinker_mass,
        $mono_mass_diff, $table,             $repeats,           $error_ref,        $names_ref,
	$xlink_mono_or_all
   ) = @_;

   my %error = %{$error_ref};
   my %names = %{$names_ref};
   if ( !defined $xlink_mono_or_all ) 	{ $xlink_mono_or_all  = 0 }

   #     my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $table );

   my $fasta = $protien_sequences;
   $protien_sequences =~ s/^>.*$/>/mg;
   $protien_sequences =~ s/\n//g;
   $protien_sequences =~ s/^.//;
   $protien_sequences =~ s/ //g;

   my @hits_so_far;
   my @mz_so_far;
   my @scan_so_far;
   my $printed_hits = 0;

   print "<div style='margin: 2em'><textarea cols=80 rows=20>";

   my $new_line        = "\n";
   my $new_division    = "";
   my $finish_line     = "";
   my $finish_division = ", ";
   my $is_it_xlink     = 0;

   while ( ( my $top_hits_results = $top_hits->fetchrow_hashref ) ) {

#       if (
#            ( !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far ) && !( grep $_ eq $top_hits_results->{'mz'}, @mz_so_far ) && $repeats == 0 )
#            || ( $repeats == 1
#                 && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far ) )
#         )
      
      if (
           (
                !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far )
             && !( grep $_ eq $top_hits_results->{'mz'},   @mz_so_far )
             && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far )
             && $repeats == 0
	     &&    (( $top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2 ))
		|| ( $top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1 )))
           )
           || (    $repeats == 1
                && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far )
              )
              
        )
      {

         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'scan'};

         my @fragments = split( '-', $top_hits_results->{'fragment'} );
         my @unmodified_fragments =
           split( '-', $top_hits_results->{'unmodified_fragment'} );
         if ( $top_hits_results->{'fragment'} =~ '-' ) {
            $is_it_xlink = 1;
            print "$new_line$new_division" . "distance xl", $printed_hits + 1, "$finish_division$new_division";
            $printed_hits = $printed_hits + 1;
            my $protein = substr( $top_hits_results->{'sequence1_name'}, 1 );
            $protein =~ s/\s+$//g;
            print "$new_division", $names{ $top_hits_results->{'name'} }{$protein};
            print "///"
              . ( ( residue_position $unmodified_fragments[0], $protien_sequences ) +
                  $error{ $top_hits_results->{'name'} }{ substr( $top_hits_results->{'sequence1_name'}, 1 ) } +
                  $top_hits_results->{'best_x'} +
                  1 )
              . "/CA$finish_division";
            $protein = substr( $top_hits_results->{'sequence2_name'}, 1 );
            $protein =~ s/\s+$//g;
            print "$new_division", $names{ $top_hits_results->{'name'} }{$protein};
            print "///"
              . ( ( residue_position $unmodified_fragments[1], $protien_sequences ) +
                  $error{ $top_hits_results->{'name'} }{ substr( $top_hits_results->{'sequence2_name'}, 1 ) } +
                  $top_hits_results->{'best_y'} +
                  1 )
              . "/CA&nbsp;";

         } else {
            print "$new_line$new_division" . "create ml", $printed_hits + 1, "$finish_division$new_division";
            $printed_hits = $printed_hits + 1;
            my $protein = substr( $top_hits_results->{'sequence1_name'}, 1 );
            $protein =~ s/\s+$//g;
            print "$new_division", $names{ $top_hits_results->{'name'} }{$protein};
            print "///"
              . ( ( residue_position $unmodified_fragments[0], $protien_sequences ) +
                  $error{ $top_hits_results->{'name'} }{ substr( $top_hits_results->{'sequence1_name'}, 1 ) } +
                  $top_hits_results->{'best_x'} +
                  1 )
              . "/";
         }
         print "$finish_line";
      } else {
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'scan'};
      }
   }

   if ( $is_it_xlink == 1 ) {
      print "$new_line" . "set dash_width, 5$new_line";
      print "set dash_length, 0.5$new_line";
      print "color yellow, xl*$new_line";
      print '</textarea></div>';
   } else {
      print "$new_line" . "show sticks, ml*$new_line";
      print 'cmd.hide("((byres (ml*))&(n. c,o,h|(n. n&!r. pro)))")';
      print "$new_line" . "show spheres, ml*////NZ$new_line";
      print "orient *";
      print '</textarea></div>';
   }

}

sub print_results_text {

   my (
        $top_hits,      $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protien_sequences,
        $reactive_site, $dbh,              $xlinker_mass,      $mono_mass_diff,   $table,            $repeats
   ) = @_;

   my $fasta = $protien_sequences;
   $protien_sequences =~ s/^>.*$/>/mg;
   $protien_sequences =~ s/\n//g;
   $protien_sequences =~ s/^.//;
   $protien_sequences =~ s/ //g;

   my @hits_so_far;
   my @mz_so_far;
   my @scan_so_far;
   my $printed_hits = 0;

   my $new_line        = "";
   my $new_division    = "";
   my $finish_line     = "\n";
   my $finish_division = ",";
   my $is_it_xlink     = 0;

   # Chain 1	Chain 2	Position1	Position2	Fragment and Position	Score	Charge	Mass	PPM	Mod

   print "$new_line#"
     . $finish_division
     . $new_division
     . "Protein (A)"
     . $finish_division
     . $new_division
     . "Protein (B)"
     . $finish_division
     . $new_division
     . "Position (A)"
     . $finish_division
     . $new_division
     . "Position (B)"
     . $finish_division
     . $new_division
     . "Sequence (A)"
     . $finish_division
     . $new_division
     . "Sequence (B)"
     . $finish_division
     . $new_division . "Score"
     . $finish_division
     . $new_division . "Score (alpha chain)"
     . $finish_division
     . $new_division . "Score (beta chain)"
     . $finish_division 
    . $new_division . "PPM"
     . $finish_division
     . $new_division . "+"
     . $finish_division
     . $new_division
     . "Reaction"
     . $finish_division
     . $new_division . "Frac"
     . $finish_division
     . $new_division
     . "Scan  (L)"
     . $finish_division
     . $new_division
     . "Scan (H)"
     . $finish_division
     . $new_division
     . "Monolink Mass"
     . $finish_division
     . $new_division . "Mod"
     . $finish_division
     . $new_division
     . "Common Ions"
     . $finish_division
     . $new_division
     . "Cross-linked Ions"
     . $finish_division
     . $new_division
     . "Neutral Losses"
     . $finish_division
     . $new_division
     . "No. of Peptide-A Ions"
     . $finish_division
     . $new_division
     . "No. of Peptide-B Ions"
     . $finish_division
     . $new_division . "% TIC"
     . $finish_division
     . $finish_line;

   while ( ( my $top_hits_results = $top_hits->fetchrow_hashref ) ) {

      my $data   = $top_hits_results->{'MSn_string'};
      my $top_10 = $top_hits_results->{'top_10'};
      my @masses = split "\n", $data;

      if (
           (
                !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far )
             && !( grep $_ eq $top_hits_results->{'mz'}, @mz_so_far )
             && !( grep $_ eq $top_hits_results->{'name'} . $top_hits_results->{'scan'}, @scan_so_far )
             && $repeats == 0
           )
           || $repeats == 1
        )
      {

         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
         my $rounded = sprintf( "%.3f", $top_hits_results->{'ppm'} );
         my @fragments = split( '-', $top_hits_results->{'fragment'} );
         my @unmodified_fragments =
           split( '-', $top_hits_results->{'unmodified_fragment'} );
         if ( $top_hits_results->{'fragment'} =~ '-' ) {
            print "$new_line$new_division", $printed_hits + 1, "$finish_division$new_division";
            if ( substr( $top_hits_results->{'sequence1_name'}, 1 ) lt substr( $top_hits_results->{'sequence2_name'}, 1 ) ) {
               print "$new_division", substr( $top_hits_results->{'sequence1_name'}, 1 ), $finish_division;
               print "$new_division", substr( $top_hits_results->{'sequence2_name'}, 1 ), $finish_division;
               print $new_division, ( ( residue_position $unmodified_fragments[0], $protien_sequences ) + $top_hits_results->{'best_x'} + 1 ), $finish_division;
               print $new_division . ( ( residue_position $unmodified_fragments[1], $protien_sequences ) + $top_hits_results->{'best_y'} + 1 ),
                 $finish_division;
               print $new_division . $unmodified_fragments[0] . $finish_division;
               print $new_division . $unmodified_fragments[1] . "$finish_division";
            } else {
               print "$new_division", substr( $top_hits_results->{'sequence2_name'}, 1 ), $finish_division;
               print "$new_division", substr( $top_hits_results->{'sequence1_name'}, 1 ), $finish_division;
               print $new_division . ( ( residue_position $unmodified_fragments[1], $protien_sequences ) + $top_hits_results->{'best_y'} + 1 ),
                 $finish_division;
               print $new_division, ( ( residue_position $unmodified_fragments[0], $protien_sequences ) + $top_hits_results->{'best_x'} + 1 ), $finish_division;
               print $new_division . $unmodified_fragments[1] . "$finish_division";
               print $new_division . $unmodified_fragments[0] . $finish_division;
            }
            print "$top_hits_results->{'score'}$finish_division$new_division";
	    print "$top_hits_results->{'best_alpha'}$finish_division$new_division$top_hits_results->{'best_beta'}$finish_division$new_division";
	    print "$rounded$finish_division";
            print "$new_division$top_hits_results->{'charge'}$finish_division";
            print "$new_division$top_hits_results->{'name'}$finish_division";
            print "$new_division$top_hits_results->{'fraction'}$finish_division";
            print "$new_division$top_hits_results->{'scan'}$finish_division$new_division$top_hits_results->{'d2_scan'}$finish_division";
            print $new_division;

            print $new_division, $top_hits_results->{'monolink_mass'}, $finish_division;

            if ( $top_hits_results->{'no_of_mods'} > 1 ) {
               print "$top_hits_results->{'no_of_mods'} x ";

            }

            # 		warn "Scan = $top_hits_results->{'scan'} ";
            my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $top_hits_results->{'name'} );
            print $modifications{ $top_hits_results->{'modification'} }{Name};
            print $finish_division;

            print $new_division, $top_hits_results->{'matched_common'},    $finish_division;
            print $new_division, $top_hits_results->{'matched_crosslink'}, $finish_division;

            my $target = "H2O";
            my $count_h2o = () = $top_10 =~ /$target/g;
            $target = "NH3";
            my $count_nh3 = () = $top_10 =~ /$target/g;

            my $c;

            print $new_division, $count_nh3 + $count_h2o, $finish_division;
            if ( substr( $top_hits_results->{'sequence1_name'}, 1 ) lt substr( $top_hits_results->{'sequence2_name'}, 1 ) ) {
               $target = "&#945";
               $c = () = $top_10 =~ /$target/g;
               print $new_division. $c . $finish_division;
               $target = "&#946";
               $c = () = $top_10 =~ /$target/g;
               print $new_division. $c . $finish_division;
            } else {
               $target = "&#946";
               $c = () = $top_10 =~ /$target/g;
               print $new_division. $c . $finish_division;
               $target = "&#945";
               $c = () = $top_10 =~ /$target/g;
               print $new_division. $c . $finish_division;
            }
            my $rounded = sprintf( "%.2f",
                                   ( $top_hits_results->{'matched_abundance'} + $top_hits_results->{'d2_matched_abundance'} ) /
                                     ( $top_hits_results->{'total_abundance'} + $top_hits_results->{'d2_total_abundance'} ) ) * 100;
            print $new_division, $rounded, $finish_division;

         } else {
            print "$new_line$new_division", $printed_hits + 1, "$finish_division$new_division";
            print "$new_division", substr( $top_hits_results->{'sequence1_name'}, 1 ), $finish_division;
            print "$new_division", "N/A", $finish_division;
            print $new_division, ( ( residue_position $unmodified_fragments[0], $protien_sequences ) + $top_hits_results->{'best_x'} + 1 ), $finish_division;
            print "$new_division", "N/A", $finish_division;
            print $new_division . $unmodified_fragments[0] . $finish_division;
            print "$new_division", "N/A", $finish_division;
	    print "$top_hits_results->{'score'}$finish_division$new_division";
	    print "$top_hits_results->{'best_alpha'}$finish_division$new_division$top_hits_results->{'best_beta'}$finish_division$new_division";
	    print "$rounded$finish_division";
            print "$new_division$top_hits_results->{'charge'}$finish_division";
            print "$new_division$top_hits_results->{'name'}$finish_division";
            print "$new_division$top_hits_results->{'fraction'}$finish_division";
            print "$new_division$top_hits_results->{'scan'}$finish_division$new_division$top_hits_results->{'d2_scan'}$finish_division";
            print $new_division;

            print $new_division, $top_hits_results->{'monolink_mass'}, $finish_division;

            my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $top_hits_results->{'name'} );
            if ( $top_hits_results->{'no_of_mods'} > 1 ) {
               print "$top_hits_results->{'no_of_mods'} x ";

            }
            print "$modifications{$top_hits_results->{'modification'}}{Name}";
            print $finish_division;

            print $new_division, $top_hits_results->{'matched_common'},    $finish_division;
            print $new_division, $top_hits_results->{'matched_crosslink'}, $finish_division;

            my $target = "H2O";
            my $count_h2o = () = $top_10 =~ /$target/g;
            $target = "NH3";
            my $count_nh3 = () = $top_10 =~ /$target/g;

            my $c;

            print $new_division, $count_nh3 + $count_h2o, $finish_division;
            $target = "&#945";
            $c = () = $top_10 =~ /$target/g;
            print $new_division. $c . $finish_division;
            $target = "&#946";
            $c = () = $top_10 =~ /$target/g;
            print $new_division. $c . $finish_division;

            my $rounded = sprintf( "%.2f",
                                   ( $top_hits_results->{'matched_abundance'} + $top_hits_results->{'d2_matched_abundance'} ) /
                                     ( $top_hits_results->{'total_abundance'} + $top_hits_results->{'d2_total_abundance'} ) ) * 100;
            print $new_division, $rounded, $finish_division;

         }
         $printed_hits = $printed_hits + 1;
         print $finish_line;

      } else {
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
      }
   }

}

sub print_results {

   my (
        $top_hits,      $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13,  $cut_residues,      $protien_sequences,
        $reactive_site, $dbh,              $xlinker_mass,      $mono_mass_diff,   $table,             $mass_seperation,   $repeats,
        $scan_repeats,  $no_tables,        $max_hits,          $monolink,         $static_mod_string, $varible_mod_string,$xlink_mono_or_all
   ) = @_;

   if ( !defined $max_hits ) 		{ $max_hits  = 0 }
   if ( !defined $xlink_mono_or_all ) 	{ $xlink_mono_or_all  = 0 }
   if ( !$repeats )          		{ $repeats   = 0 }
   if ( !$no_tables )       		{ $no_tables = 0 }
   if ( !defined $monolink )		{ $monolink  = 0 }

   my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $table );

   my $fasta = $protien_sequences;
   $protien_sequences =~ s/^>.*$/>/mg;
   $protien_sequences =~ s/\n//g;
   $protien_sequences =~ s/^.//;
   $protien_sequences =~ s/ //g;

   my @hits_so_far;
   my @mz_so_far;
   my @scan_so_far;
   my $printed_hits = 0;

   if ( $no_tables == 0 ) {
      print '<table><tr><td></td><td>Score</td><td>MZ</td><td>Charge</td><td>PPM</td><td colspan="2">Fragment&nbsp;and&nbsp;Position</td>';
      if ( $monolink == 1 ) { print '<td>Monolink Mass</td>'; }
      print '<td>Modifications</td><td>Sequence&nbsp;Names</td><td>Fraction<td>Scan&nbsp;(Light)<br/>Scan&nbsp;(Heavy)</td></td></td><td>MS/2</td></tr>';
   }

   while (    ( my $top_hits_results = $top_hits->fetchrow_hashref )
           && ( $max_hits == 0 || $printed_hits < $max_hits ) )
   {
      if (
           (
                !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far )
             && !( grep $_ eq $top_hits_results->{'mz'},   @mz_so_far )
             && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far )
             && $repeats == 0
	     &&    (( $top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2 ))
		|| ( $top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1 )))
           )
           || (    $repeats == 1
                && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far )
                && $scan_repeats == 0 )
           || ( $repeats == 1 && $scan_repeats == 1 )
        )
      {
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'scan'};
         my $rounded = sprintf( "%.3f", $top_hits_results->{'ppm'} );

           print "<tr><td>", $printed_hits + 1, "</td><td>$top_hits_results->{'score'}</td><td><a href='view_scan.pl?table=$table&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}'>$top_hits_results->{'mz'}</a></td><td>$top_hits_results->{'charge'}+</td><td>$rounded</td>";
           my @fragments = split( '-', $top_hits_results->{'fragment'} );
           my @unmodified_fragments =
             split( '-', $top_hits_results->{'unmodified_fragment'} );
           if ( $top_hits_results->{'fragment'} =~ '-' ) {
              $printed_hits = $printed_hits + 1;
              print "<td><a href='view_peptide.pl?table=$table&peptide=$fragments[0]-$fragments[1]'>";
              print residue_position $unmodified_fragments[0], $protien_sequences;
              print ".", $fragments[0], "&#8209;";
              print residue_position $unmodified_fragments[1], $protien_sequences;
              print ".", $fragments[1] . "</td><td>", $top_hits_results->{'best_x'} + 1, "&#8209;", $top_hits_results->{'best_y'} + 1, "</a></td><td>";
           } else {
              $printed_hits = $printed_hits + 1;
              print "<td><a href='view_peptide.pl?table=$table&peptide=$fragments[0]'>";
              print residue_position $unmodified_fragments[0], $protien_sequences;
              print ".", $fragments[0];
              print "&nbsp;</td><td>", $top_hits_results->{'best_x'} + 1, "</a></td><td>";
           }
           if ( $monolink == 1 ) {
              if ( $top_hits_results->{'monolink_mass'} eq 0 ) {
                 print 'N/A</td><td>';
              } else {
                 print "$top_hits_results->{'monolink_mass'}</td><td>";
              }
           }
           if ( $top_hits_results->{'no_of_mods'} > 1 ) {
              print "$top_hits_results->{'no_of_mods'} x";
           }
           print " $modifications{$top_hits_results->{'modification'}}{Name}</td><td>",
           substr( $top_hits_results->{'sequence1_name'}, 1 );
           if ( $top_hits_results->{'fragment'} =~ '-' ) {
              print " - ", substr( $top_hits_results->{'sequence2_name'}, 1 );
           }
           print "</td><td> $top_hits_results->{'fraction'}</td><td>";
           print "<a  href='view_img.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>$top_hits_results->{'scan'}</a> <br/><a  href='view_img.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1'>$top_hits_results->{'d2_scan'}</a>";
           print "</td><td>";
           print_ms2_link(
                         $top_hits_results->{'MSn_string'},   $top_hits_results->{'d2_MSn_string'}, $top_hits_results->{'fragment'},
                         $top_hits_results->{'modification'}, $top_hits_results->{'best_x'},        $top_hits_results->{'best_y'},
                         $xlinker_mass,                       $mono_mass_diff,                      $top_hits_results->{'top_10'},
                         $reactive_site,                      $table
           );

           print_xquest_link(
                            $top_hits_results->{'MSn_string'}, $top_hits_results->{'d2_MSn_string'}, $top_hits_results->{'mz'},
                            $top_hits_results->{'charge'},     $top_hits_results->{'fragment'},      $mass_seperation,
                            $mass_of_deuterium,                $mass_of_hydrogen,                    $mass_of_carbon13,
                            $mass_of_carbon12,                 $cut_residues,                        $xlinker_mass,
                            $mono_mass_diff,                   $reactive_site,                       $fasta,
                            $static_mod_string,                $varible_mod_string
           );

           print "</td></tr>";
        } else {
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'scan'};
        }
   }
   print '</table>';

}

sub print_results_combined {

   my (
        $top_hits,          $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues,
        $protien_sequences, $reactive_site,    $dbh,               $xlinker_mass,     $mono_mass_diff,   $mass_seperation_ref,
        $table,             $repeats,          $scan_repeats,      $no_tables,	      $xlink_mono_or_all
   ) = @_;

   my %mass_seperation = %{$mass_seperation_ref};

   if ( !$repeats )   { $repeats   = 0 }
   if ( !$no_tables ) { $no_tables = 0 }
   if ( !defined $xlink_mono_or_all ) 	{ $xlink_mono_or_all  = 0 }

   my $fasta = $protien_sequences;
   $protien_sequences =~ s/^>.*$/>/mg;
   $protien_sequences =~ s/\n//g;
   $protien_sequences =~ s/^.//;
   $protien_sequences =~ s/ //g;

   my @hits_so_far;
   my @mz_so_far;
   my @scan_so_far;
   my $printed_hits = 0;

   if ( $no_tables == 0 ) {
      print
'<table><tr><td></td><td>Score</td><td>MZ</td><td>Charge</td><td>PPM</td><td colspan="2">Fragment&nbsp;and&nbsp;Position</td><td>Modifications</td><td>Sequence&nbsp;Names</td><td>Fraction<td>Scan&nbsp;(Light)<br/>Scan&nbsp;(Heavy)</td></td></td><td>MS/2</td></tr>';
   }

   while ( ( my $top_hits_results = $top_hits->fetchrow_hashref ) )    #&& ($printed_hits <= 50)
   {
      if (
           (
                !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far )
             && !( grep $_ eq $top_hits_results->{'mz'},   @mz_so_far )
             && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far )
             && $repeats == 0
	     &&    (( $top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2 ))
		|| ( $top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1 )))
           )
           || (    $repeats == 1
                && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far )
                && $scan_repeats == 0 )
           || ( $repeats == 1 && $scan_repeats == 1 )
        )
      {
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
         my $rounded = sprintf( "%.3f", $top_hits_results->{'ppm'} );
         print "<tr><td>", $printed_hits + 1,
"</td><td><a href='view_scan.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}'>$top_hits_results->{'score'}</a></td><td>$top_hits_results->{'mz'}</td><td>$top_hits_results->{'charge'}+</td><td>$rounded</td>";
         my @fragments = split( '-', $top_hits_results->{'fragment'} );
         my @unmodified_fragments =
           split( '-', $top_hits_results->{'unmodified_fragment'} );
         if ( $top_hits_results->{'fragment'} =~ '-' ) {
            $printed_hits = $printed_hits + 1;
            print "<td><a href='view_peptide.pl?table=$top_hits_results->{'name'}&peptide=$fragments[0]-$fragments[1]'>";
            print residue_position $unmodified_fragments[0], $protien_sequences;
            print ".", $fragments[0], "&#8209;";
            print residue_position $unmodified_fragments[1], $protien_sequences;
            print ".", $fragments[1] . "</td><td>", $top_hits_results->{'best_x'} + 1, "&#8209;", $top_hits_results->{'best_y'} + 1, "</a></td><td>";
         } else {
            $printed_hits = $printed_hits + 1;
            print "<td><a href='view_peptide.pl?table=$top_hits_results->{'name'}&peptide=$fragments[0]'>";
            print residue_position $unmodified_fragments[0], $protien_sequences;
            print ".", $fragments[0];
            print "&nbsp;</td><td>", $top_hits_results->{'best_x'} + 1, "</a></td><td>";
         }
         if ( $top_hits_results->{'no_of_mods'} > 1 ) {
            print "$top_hits_results->{'no_of_mods'} x";
         }
         my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $top_hits_results->{'name'} );
         print
           " $modifications{$top_hits_results->{'modification'}}{Name}</td><td>",
           substr( $top_hits_results->{'sequence1_name'}, 1 );
         if ( $top_hits_results->{'fragment'} =~ '-' ) {
            print " - ", substr( $top_hits_results->{'sequence2_name'}, 1 );
         }
         print "</td><td>$top_hits_results->{'name'},$top_hits_results->{'fraction'}</td><td>";
         print
"<a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>$top_hits_results->{'scan'}</a> <br/><a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1'>$top_hits_results->{'d2_scan'}</a>";
         print "</td><td>";
         print_ms2_link(
                         $top_hits_results->{'MSn_string'},   $top_hits_results->{'d2_MSn_string'}, $top_hits_results->{'fragment'},
                         $top_hits_results->{'modification'}, $top_hits_results->{'best_x'},        $top_hits_results->{'best_y'},
                         $xlinker_mass,                       $mono_mass_diff,                      $top_hits_results->{'top_10'},
                         $reactive_site,                      $reactive_site,                       $top_hits_results->{'name'}
         );

         my $varible_mod_string = '';
         my $dynamic_mods = get_mods( $top_hits_results->{'name'}, 'dynamic' );
         while ( ( my $dynamic_mod = $dynamic_mods->fetchrow_hashref ) ) {
            $varible_mod_string = $varible_mod_string . $dynamic_mod->{'mod_residue'} . ":" . $dynamic_mod->{'mod_mass'} . ",";
         }
         my $static_mod_string = '';
         my $fixed_mods = get_mods( $top_hits_results->{'name'}, 'fixed' );
         while ( ( my $fixed_mod = $fixed_mods->fetchrow_hashref ) ) {

            $static_mod_string = $static_mod_string . $fixed_mod->{'mod_residue'} . ":" . $fixed_mod->{'mod_mass'} . ",";
         }

         print_xquest_link(
                            $top_hits_results->{'MSn_string'}, $top_hits_results->{'d2_MSn_string'},
                            $top_hits_results->{'mz'},         $top_hits_results->{'charge'},
                            $top_hits_results->{'fragment'},   $mass_seperation{ $top_hits_results->{'name'} },
                            $mass_of_deuterium,                $mass_of_hydrogen,
                            $mass_of_carbon13,                 $mass_of_carbon12,
                            $cut_residues,                     $xlinker_mass,
                            $mono_mass_diff,                   $reactive_site,
                            $fasta,                            $static_mod_string,
                            $varible_mod_string
         );

         print "</td></tr>";
      } else {
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
      }
   }
   print '</table>';

}

sub print_report {

   my (
        $top_hits,      $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protien_sequences,
        $reactive_site, $dbh,              $xlinker_mass,      $mono_mass_diff,   $table,            $repeats
   ) = @_;

   my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $table );

   my $fasta = $protien_sequences;
   $protien_sequences =~ s/^>.*$/>/mg;
   $protien_sequences =~ s/\n//g;
   $protien_sequences =~ s/^.//;
   $protien_sequences =~ s/ //g;

   my @hits_so_far;
   my @mz_so_far;
   my @scan_so_far;
   my $printed_hits = 0;

   while ( ( my $top_hits_results = $top_hits->fetchrow_hashref ) ) {
      if (
           ( !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far ) && !( grep $_ eq $top_hits_results->{'mz'}, @mz_so_far ) && $repeats == 0 )
           || ( $repeats == 1
                && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far ) )
        )
      {
         print '<div style="page-break-inside: avoid; page-break-after: always;">';
         print
"<img src='view_img.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}'/><br/><br/>";
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'scan'};
         my $rounded = sprintf( "%.3f", $top_hits_results->{'ppm'} );
         my @fragments = split( '-', $top_hits_results->{'fragment'} );
         my @unmodified_fragments =
           split( '-', $top_hits_results->{'unmodified_fragment'} );

         if ( $top_hits_results->{'fragment'} =~ '-' ) {
            $printed_hits = $printed_hits + 1;
            print "Sequence: <a href='view_peptide.pl?table=$table&peptide=$fragments[0]-$fragments[1]'>";
            print residue_position $unmodified_fragments[0], $protien_sequences;
            print ".", $fragments[0], "&#8209;";
            print residue_position $unmodified_fragments[1], $protien_sequences;
            print ".", $fragments[1] . "</a><br/>Cross link position: ", $top_hits_results->{'best_x'} + 1, "-", $top_hits_results->{'best_y'} + 1, "</br>";
         } else {
            print "<td><a href='view_peptide.pl?table=$table&peptide=$fragments[0]'>";
            print residue_position $unmodified_fragments[0], $protien_sequences;
            print ".", $fragments[0];
            print "&nbsp;</td><td>", $top_hits_results->{'best_x'} + 1, "</a></td><td>";
         }
         print "Score: $top_hits_results->{'score'} <br/>M/Z: $top_hits_results->{'mz'}<br/>Charge: $top_hits_results->{'charge'}+<br/>PPM: $rounded<br/>";
         print "Modifications: ";
         if ( $top_hits_results->{'no_of_mods'} > 1 ) {
            print "$top_hits_results->{'no_of_mods'} x";
         }
         print " $modifications{$top_hits_results->{'modification'}}{Name}<br/>";
         print "Proteins: ", substr( $top_hits_results->{'sequence1_name'}, 1 );
         if ( $top_hits_results->{'fragment'} =~ '-' ) {
            print " - ", substr( $top_hits_results->{'sequence2_name'}, 1 );
         }
         print "<br/>Fraction: $top_hits_results->{'fraction'}<br/>";

         print "</div>";
      } else {
         push @hits_so_far, $top_hits_results->{'fragment'};
         push @mz_so_far,   $top_hits_results->{'mz'};
         push @scan_so_far, $top_hits_results->{'scan'};
      }

   }

}