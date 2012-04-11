use strict;

package Crosslinker::Data;
use base 'Exporter';
use lib 'lib';
use Crosslinker::Scoring;
use Crosslinker::Links;
use Crosslinker::Config;

our @EXPORT = ( 'connect_db', 'check_state', 'give_permission', 'is_ready', 'disconnect_db', 'set_finished', 'save_settings', 'update_state', 'import_cgi_query', 'find_free_tablename', 'matchpeaks', 'create_table', 'import_mgf', 'import_csv', 'loaddoubletlist_db', 'generate_decoy', 'set_doublets_found' );
######
#
# Data import functions
#
######

sub generate_decoy {
    my ($fasta) = @_;

    $fasta =~ s/[^A-z>\n]//g;

    my @sequences = split( '>', $fasta );
    $fasta = $fasta . "\n";

    for ( my $n = 1 ; $n < @sequences ; $n++ ) {
        my ( $sequence_name, $sequence ) = split( '\n', $sequences[$n], 2 );
        my $decoy = reverse $sequence;
        $sequence_name =~ s/[^A-z1-9]//g;
        $decoy         =~ s/[^A-Z]//g;
        $fasta = $fasta . ">r" . $sequence_name . "\r\n" . $decoy . "\n\n";
    }

    return $fasta;
}

sub connect_db {
    my $dbh          = DBI->connect( "dbi:SQLite:dbname=:memory:",    "", "", { RaiseError => 1, AutoCommit => 1 } );
    my $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results",  "", "", { RaiseError => 1, AutoCommit => 1 } );
    my $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

    $results_dbh->do(
        "CREATE TABLE IF NOT EXISTS results (
						      name,
						      MSn_string,
						      d2_MSn_string,
						      mz,
						      charge,
						      fragment,    
						      sequence1,
						      sequence2,
						      sequence1_name,
						      sequence2_name,
						      score REAL,
						      fraction,
						      scan,
						      d2_scan,
						      modification,
						      no_of_mods,
						      best_x,
						      best_y,
						      unmodified_fragment,
						      ppm,
						      top_10,
						      d2_top_10,
						      matched_abundance,
						      d2_matched_abundance,
						      total_abundance,
						      d2_total_abundance,
						      matched_common,
     						      matched_crosslink,
						      d2_matched_common,
						      d2_matched_crosslink,
						      monolink_mass) "
    );

    return ( $dbh, $results_dbh, $settings_dbh );
}

sub disconnect_db {
    my ( $dbh, $settings_dbh, $results_dbh ) = @_;

    $settings_dbh->disconnect();
    $dbh->disconnect();
    $results_dbh->disconnect();
}

sub set_finished {
    my ( $results_table, $settings_dbh ) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET finished = -1 WHERE  name = ?;");
    $settings_sql->execute($results_table);

    return;
}

sub set_doublets_found {
    my ( $results_table, $settings_dbh, $doublets_found) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET doublets_found = ? WHERE  name = ?;");
    $settings_sql->execute($doublets_found, $results_table);

    return;
}

sub update_state {

    my ( $settings_dbh, $results_table, $state ) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET finished =? WHERE name=?;");

    $settings_sql->execute( $state, $results_table );

    return;
}

sub check_state {
    my ( $settings_dbh, $results_table ) = @_;

    my $settings_sql = $settings_dbh->prepare("SELECT finished FROM settings WHERE name = ?");
    $settings_sql->execute($results_table);
    my @data  = $settings_sql->fetchrow_array();
    my $state = $data[0];

    return $state;
}

sub give_permission {
    my ($settings_dbh) = @_;

    my $settings_sql = $settings_dbh->prepare("SELECT name, finished FROM  settings WHERE finished = '-2' ORDER BY length(name) DESC, name ASC ");
    $settings_sql->execute();
    my @data = $settings_sql->fetchrow_array();
    if ( defined $data[0] ) {
        my $results_table = $data[0];

        warn "Giving Permission to $results_table ($data[1]) to start...", "\n";
        update_state( $settings_dbh, $results_table, -3 );
    } else {
        warn "Queue empty", "\n";
    }
    return;
}

sub is_ready {
    my ($settings_dbh) = @_;

    $settings_dbh->do(
        "CREATE TABLE IF NOT EXISTS settings (
						      name,
						      desc,
						      cut_residues,
						      protein_sequences,
						      reactive_site,
						      mono_mass_diff,
						      xlinker_mass,
						      decoy,
						      ms2_da,
						      ms1_ppm,
						      finished,
						      isotoptic_shift,
						      threshold,
						      doublets_found
						) "
    );

    my $settings_sql = $settings_dbh->prepare("SELECT count(finished) FROM settings WHERE finished = -2 or finished = -3 or finished > -1");
    $settings_sql->execute();
    my @data = $settings_sql->fetchrow_array();

    my $state;

    if ( $data[0] > 0 ) {
        $state = -2;
    } else {
        $state = 0;
    }
    return $state;
}

sub save_settings {

    my ( $settings_dbh, $results_table, $cut_residues, $protien_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $state, $desc, $decoy, $ms2_da, $ms1_ppm, $mass_seperation, $dynamic_mods_ref, $fixed_mods_ref, $threshold ) = @_;

    if ( defined $fixed_mods_ref ) {
        my $conf_dbh = connect_conf_db;
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS modifications (
						      run_id,
						      mod_id,
						      mod_name,
						      mod_mass,
						      mod_residue,
						      mod_type
						) "
        );
        my $settings_sql = $settings_dbh->prepare(
            "INSERT INTO modifications 
						(
						      run_id,
						      mod_id,
						      mod_name,
						      mod_mass,
						      mod_residue,
						      mod_type
						) VALUES (?,?,?,?,?,?)"
        );
        my @fixed_mods = @{$fixed_mods_ref};
        foreach my $mod (@fixed_mods) {
            my $fixed_mod = get_conf_value( $conf_dbh, $mod );
            my $fixed_mod_data = $fixed_mod->fetchrow_hashref();
            $settings_sql->execute( $results_table, $mod, $fixed_mod_data->{'name'}, $fixed_mod_data->{'setting1'}, $fixed_mod_data->{'setting2'}, 'fixed' );
            warn "Fixed mod selected: $mod: $fixed_mod_data->{'name'} \n";
	    $fixed_mod->finish;
        }
	$conf_dbh->disconnect();
    }

    if ( defined $dynamic_mods_ref ) {
        my $conf_dbh = connect_conf_db;
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS modifications (
						      run_id,
						      mod_id,
						      mod_name,
						      mod_mass,
						      mod_residue,
						      mod_type
						) "
        );
        my $settings_sql = $settings_dbh->prepare(
            "INSERT INTO modifications 
						(
						      run_id,
						      mod_id,
						      mod_name,
						      mod_mass,
						      mod_residue,
						      mod_type
						) VALUES (?,?,?,?,?,?)"
        );
        my @dynamic_mods = @{$dynamic_mods_ref};
        foreach my $mod (@dynamic_mods) {
            my $dynamic_mod = get_conf_value( $conf_dbh, $mod );
            my $dynamic_mod_data = $dynamic_mod->fetchrow_hashref();
            $settings_sql->execute( $results_table, $mod, $dynamic_mod_data->{'name'}, $dynamic_mod_data->{'setting1'}, $dynamic_mod_data->{'setting2'}, 'dynamic' );	    
            warn "Dynamic mod selected: $mod: $dynamic_mod_data->{'name'} \n";	
	    $dynamic_mod->finish;
        }
	$conf_dbh->disconnect();
    }

    $settings_dbh->do(
        "CREATE TABLE IF NOT EXISTS settings (
						      name,
						      desc,
						      cut_residues,
						      protein_sequences,
						      reactive_site,
						      mono_mass_diff,
						      xlinker_mass,
						      decoy,
						      ms2_da,
						      ms1_ppm,
						      finished,
						      isotoptic_shift,
						      threshold,
						      doublets_found			
						) "
    );

    my $settings_sql = $settings_dbh->prepare(
        "INSERT INTO settings 
						(
						      name,
						      desc,
						      cut_residues,
						      protein_sequences,
						      reactive_site,
						      mono_mass_diff,
						      xlinker_mass,
						      decoy,
						      ms2_da,
						      ms1_ppm,
						      finished,
						      isotoptic_shift,	     
						      threshold
						 ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)"
    );

    $settings_sql->execute( $results_table, $desc, $cut_residues, $protien_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $state, $mass_seperation, $threshold );
    
    return;
}

sub import_cgi_query {
    my ( $query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12 ) = @_;
    my $fasta = $query->param('user_protein_sequence');
    my $decoy = $query->param('decoy');
   

    my $protien_sequences;
    my $conf_dbh = connect_conf_db;

    if ( $query->param('sequence') == -1 ) {
        $protien_sequences = $fasta;
    } else {
        my $sequences = get_conf_value( $conf_dbh, $query->param('sequence') );
        my $sequence = $sequences->fetchrow_hashref();
        $protien_sequences = $sequence->{'setting1'};
        $fasta             = $sequence->{'setting1'};
	$sequences->finish;
    }

    if ( defined $query->param('decoy') ) {
        $protien_sequences = generate_decoy($protien_sequences);
	$fasta = $protien_sequences;
        warn "Generating Decoy Database....\n";
    }

    $protien_sequences =~ s/\r//g;
    my $desc = $query->param('user_desc');
    my @sequence_names = $protien_sequences =~ m/^>.*$/mg;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;
    my $missed_clevages = $query->param('missed_cleavages');
    my @upload_filehandle;
    $upload_filehandle[1] = $query->upload("mgf");
    $upload_filehandle[2] = $query->upload("mgf2");
    $upload_filehandle[3] = $query->upload("mgf3");
    $upload_filehandle[4] = $query->upload("mgf4");
    $upload_filehandle[5] = $query->upload("mgf5");
    $upload_filehandle[6] = $query->upload("mgf6");
    $upload_filehandle[7] = $query->upload("mgf7");
    $upload_filehandle[8] = $query->upload("mgf8");
    my @csv_filehandle;
    $csv_filehandle[1] = $query->upload("csv");
    $csv_filehandle[2] = $query->upload("csv2");
    $csv_filehandle[3] = $query->upload("csv3");
    $csv_filehandle[4] = $query->upload("csv4");

    my $match_ppm = $query->param("ms1_ppm");
    my $ms2_error = $query->param("ms2_da");

    my $enzymes        = get_conf_value( $conf_dbh, $query->param('enzyme') );
    my $enzyme         = $enzymes->fetchrow_hashref();
    my $cut_residues   = $enzyme->{'setting1'};
    my $nocut_residues = $enzyme->{'setting2'};
    $enzymes->finish;

    my @dynamic_mods   = $query->param('dynamic_mod');
    my @fixed_mods     = $query->param('fixed_mod');

    my $mono_mass_diff = $query->param('mono_mass_diff');
    my $xlinker_mass   = $query->param('xlinker_mass');
    my $reactive_site  = $query->param('reactive_site');
    my $isotope        = $query->param("isotope");
    my $linkspacing    = $query->param('seperation');
    my $threshold      = $query->param('threshold');

    my %ms2_fragmentation;
    if   ( defined $query->param('aions') ) { $ms2_fragmentation{'aions'} = '1' }
    else                                    { $ms2_fragmentation{'aions'} = '0' }
    if   ( defined $query->param('bions') ) { $ms2_fragmentation{'bions'} = '1' }
    else                                    { $ms2_fragmentation{'bions'} = '0' }
    if   ( defined $query->param('yions') ) { $ms2_fragmentation{'yions'} = '1' }
    else                                    { $ms2_fragmentation{'yions'} = '0' }

    if   ( defined $query->param('waterloss') ) { $ms2_fragmentation{'waterloss'} = '1' }
    else                                        { $ms2_fragmentation{'waterloss'} = '0' }
    if   ( defined $query->param('ammonialoss') ) { $ms2_fragmentation{'ammonialoss'} = '1' }
    else                                          { $ms2_fragmentation{'ammonialoss'} = '0' }

    if ( $query->param('crosslinker') != -1 ) {

        my $crosslinkers = get_conf_value( $conf_dbh, $query->param('crosslinker') );
        my $crosslinker = $crosslinkers->fetchrow_hashref();

        warn "Reagent: $crosslinker->{'name'} \n";
        $mono_mass_diff = $crosslinker->{'setting3'};
        $xlinker_mass   = $crosslinker->{'setting2'};
        $reactive_site  = $crosslinker->{'setting1'};
        $isotope        = $crosslinker->{'setting4'};
        $linkspacing    = $crosslinker->{'setting5'};
    }

    my $mass_seperation;
    if ( $isotope eq "deuterium" ) {
        $mass_seperation = $linkspacing * ( $mass_of_deuterium - $mass_of_hydrogen );
    } else {
        $mass_seperation = $linkspacing * ( $mass_of_carbon13 - $mass_of_carbon12 );
    }

    $conf_dbh->disconnect();
    return ( $protien_sequences, \@sequence_names, $missed_clevages, \@upload_filehandle, \@csv_filehandle, $reactive_site, $cut_residues, $nocut_residues, $fasta, $desc, $decoy, $match_ppm, $ms2_error, $mass_seperation, $isotope, $linkspacing, $mono_mass_diff, $xlinker_mass, \@dynamic_mods, \@fixed_mods, \%ms2_fragmentation, $threshold );
}

sub find_free_tablename {
    my ($settings_dbh) = @_;

    $settings_dbh->do(
        "CREATE TABLE IF NOT EXISTS settings (
						      name,
						      desc,
						      cut_residues,
						      protein_sequences,
						      reactive_site,
						      mono_mass_diff,
						      xlinker_mass,
						      decoy,
						      ms2_da,
						      ms1_ppm,
						      finished,
						      isotoptic_shift,
						      threshold,
						      doublets_found
						) "
    );

    my $table_list = $settings_dbh->prepare("SELECT DISTINCT name FROM settings ORDER BY length(name) DESC, name DESC");
    $table_list->execute();
    my $table_name = $table_list->fetchrow_hashref;
    my $results_table;
    if ( $table_name->{'name'} ) {
        my @new_table = split( 'R', $table_name->{'name'} );
        $results_table = "R" . ( $new_table[1] + 1 );
    } else {
        $results_table = "R1";
    }

    return $results_table;
}

sub matchpeaks {
    my ( $peaklist_ref, $fragment_masses_ref, $fragment_sources_ref, $protien_sequences, $match_ppm, $dbh, $results_dbh, $settings_dbh, $results_table, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $cut_residues, $nocut_residues, $sequence_names_ref, $mono_mass_diff, $xlinker_mass, $linkspacing, $isotope, $reactive_site, $modifications_ref, $ms2_error, $protein_residuemass_ref, $ms2_fragmentation_ref, $threshold ) = @_;
    my %fragment_masses     = %{$fragment_masses_ref};
    my %fragment_sources    = %{$fragment_sources_ref};
    my %modifications       = %{$modifications_ref};
    my %protein_residuemass = %{$protein_residuemass_ref};
    my %ms2_fragmentation   = %{$ms2_fragmentation_ref};
    my @sequences           = split( '>', $protien_sequences );
    my @sequence_names      = @{$sequence_names_ref};
    my $max_delta           = 1 + ( $match_ppm / 1000000 );
    my $TIC;
    my %fragment_score;
    my @peaklist = @{$peaklist_ref};
    my $xlinker;
    my $codensation;

    my $seperation = 0;
    if ( $isotope eq "deuterium" ) {
        $seperation = $linkspacing * ( $mass_of_deuterium - $mass_of_hydrogen );
    } else {
        $seperation = $linkspacing * ( $mass_of_carbon13 - $mass_of_carbon12 );
    }

    foreach my $fragment ( keys %fragment_masses ) {
        $fragment_score{$fragment} = 0;
    }
   
    my $ms2 = $dbh->prepare("SELECT MSn_string, scan_num FROM msdata WHERE mz between ? +0.00005 and ? -0.00005 and scan_num between ? - 20 and ? + 20 and fraction = ? and msorder = 2 LIMIT 0,1");

    my $peak_no = 0;

######
    #
    # Connect to results DB and create a table
    #
######

    my $results_sql = $results_dbh->prepare(
        "INSERT INTO results (
						      name,
						      MSn_string,
						      d2_MSn_string,
						      mz,
						      charge,
						      fragment,
						      sequence1,
						      sequence2,
						      sequence1_name,
						      sequence2_name,
						      score,
						      fraction,
						      scan,
						      d2_scan,
						      modification,
						      no_of_mods,
						      best_x,
						      best_y,
						      unmodified_fragment,
						      ppm,
						      top_10,
  						      d2_top_10,
						      matched_abundance,
						      d2_matched_abundance,
						      total_abundance,
						      d2_total_abundance,
						      matched_common,
     						      matched_crosslink,
						      d2_matched_common,
						      d2_matched_crosslink, 
						      monolink_mass
						      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
    );

#######
    #
    #
    #
#######

    foreach my $peak (@peaklist) {
        $peak_no = $peak_no + 1;
        my $percent_done = sprintf( "%.2f", $peak_no / @peaklist );
        warn $percent_done * 100, " % Peak mz = " . sprintf( "%.5f", $peak->{'mz'} ) . "\n";

        if ( check_state( $settings_dbh, $results_table ) == -4 ) {
            return %fragment_score;
        }
        update_state( $settings_dbh, $results_table, $percent_done );
        my $MSn_string    = "";
        my $d2_MSn_string = "";
        my $round         = sprintf( "%.5f", $peak->{'mz'} );

        #  if ($peak->{'MSn_string'} eq "")
        # 		      {
        # 		      my $round = sprintf ("%.5f", $peak->{'mz'});
        # 		      $ms2->execute($round, $round, $peak->{'scan_num'}, $peak->{'scan_num'} , $peak->{'fraction'});
        # 		      my $results = $ms2->fetchrow_hashref;
        # 		      $MSn_string =$results->{'MSn_string'};
        # 		     }
        # 		  else
        # 		    {
        $MSn_string = $peak->{'MSn_string'};

        # 		    }
        # 		  if ($peak->{'d2_MSn_string'} eq "")
        # 		    {
        # 		      my $round = sprintf ("%.5f", $peak->{'d2_mz'});
        # 		      $ms2->execute($round,$round, $peak->{'scan_num'}, $peak->{'scan_num'} , $peak->{'fraction'});
        # 		      my $results = $ms2->fetchrow_hashref;
        # 		      $d2_MSn_string =$results->{'MSn_string'};
        # 		     }
        # 		  else
        # 		    {
        $d2_MSn_string = $peak->{'d2_MSn_string'};

        # 		    }

        # 	 print_xquest_link(
        # 				$MSn_string,
        # 				$d2_MSn_string,
        # 				$peak->{'mz'},
        # 				$peak->{'charge'},
        # 				$protien_sequences,
        # 				$query->param('seperation'),
        # 				$query->param('isotope'),
        # 				$mass_of_deuterium,
        # 				$mass_of_hydrogen,
        # 				$mass_of_carbon13,
        # 				$mass_of_carbon12,
        # 				$cut_residues,
        # 				$query->param('xlinker_mass'),
        # 				$query->param('mono_mass_diff'),
        # 				$query->param('reactive_site'),
        # 				$query->param('user_protein_sequence'));

        foreach my $fragment ( sort( keys %fragment_masses ) ) {
            foreach my $modification ( sort( keys %modifications ) ) {
                my $location = $modifications{$modification}{Location};
                my $rxn_residues = @{ [ $fragment =~ /$location/g ] };

                if ( !( $modifications{$modification}{Name} eq "loop link" && $fragment =~ /[-]/ ) && !( $modifications{$modification}{Name} eq "mono link")  )  #crosslink and loop link on the same peptide is a messy option and pretty unlikely, so remove them
                {
		    my @monolink_masses;
  
                    my $mass = $fragment_masses{$fragment};
                    if ( $fragment !~ /[-]/ ) {
                        @monolink_masses = split(",", $mono_mass_diff);
                    } else {
		      @monolink_masses = ('0');
		    }
		    

		    foreach my $monolink_mass(@monolink_masses)
		    {
		    $mass = $fragment_masses{$fragment} + $monolink_mass;

                    #                     if ( $modifications{$modification}{Name} eq "mono link" ) {
                    #                         $rxn_residues = ( $rxn_residues - ( 2 * @{ [ $fragment =~ /[-]/g ] } ) );
                    #                     }

                    if ( $modifications{$modification}{Name} eq "loop link" ) {
                        $rxn_residues = ( $rxn_residues - ( 2 * @{ [ $fragment =~ /[-]/g ] } ) ) / 2;
                    }
                    for ( my $n = 1 ; $n <= $rxn_residues ; $n++ ) {
                        if (
                            ( $peak->{monoisotopic_mw} / $peak->{charge} < ( ( $mass + ( $modifications{$modification}{Delta} * $n ) ) / $peak->{charge} ) * $max_delta )    #Divide by charge to give PPM of detected species otherwise we are 4 times more stick on 4+ m/z
                            && ( $peak->{monoisotopic_mw} / $peak->{charge} > ( ( $mass + ( $modifications{$modification}{Delta} * $n ) ) / $peak->{charge} ) / $max_delta )
                          )
                        {
                            my $score = ( abs( ( $peak->{monoisotopic_mw} - ( $mass + ( $modifications{$modification}{Delta} * $n ) ) ) ) ) / ($mass) * 1000000;

                            # 	   	        my $d2_score = (abs(($peak->{d2_monoisotopic_mw} - ($fragment_masses{$fragment}+$seperation+($modifications{$modification}{Delta}*$n)))))/($fragment_masses{$fragment})*1000000;
                            my $rounded = sprintf( "%.3f", $score );
                            {

                                #                                 warn $fragment, $modifications{$modification}{Name}, "\n";
                                # 				if ( $modifications{$modification}{Name} eq "loop link" ) { warn "loop link ";	}

                                my ( $ms2_score, $modified_fragment, $best_x, $best_y, $top_10, $d2_top_10,$matched_abundance,$d2_matched_abundance,$total_abundance,$d2_total_abundance, $matched_common, $matched_crosslink, $d2_matched_common, $d2_matched_crosslink   ) = calc_score( \%protein_residuemass, $MSn_string, $d2_MSn_string, $fragment, \%modifications, $n, $modification, $mass_of_hydrogen, $xlinker_mass, $monolink_mass, $seperation, $reactive_site, $peak->{'charge'}, $ms2_error, \%ms2_fragmentation, $threshold );

                                # 		       my ($d2_ms2_score,$d2_modified_fragment,$d2_best_x,$d2_best_y, $d2_top_10) = calc_score($d2_MSn_string,$d2_MSn_string,$fragment, \%modifications, $n,$modification, $mass_of_hydrogen,$xlinker_mass+$seperation,$mono_mass_diff,  $seperation, $reactive_site,$peak->{'charge'}, $best_x, $best_y);

                                my ( $fragment1_source, $fragment2_source ) = split "-", $fragment_sources{$fragment};
                                if ( $fragment !~ m/[-]/ ) { $fragment2_source = "0" }
                                $results_sql->execute( $results_table, $MSn_string, $d2_MSn_string, $peak->{'mz'}, $peak->{'charge'}, $modified_fragment, $sequences[$fragment1_source], $sequences[$fragment2_source], $sequence_names[$fragment1_source], $sequence_names[$fragment2_source], $ms2_score, $peak->{'fraction'}, $peak->{'scan_num'}, $peak->{'d2_scan_num'}, $modification, $n, $best_x, $best_y, $fragment, $score, $top_10, $d2_top_10,$matched_abundance,$d2_matched_abundance,$total_abundance,$d2_total_abundance, $matched_common, $matched_crosslink, $d2_matched_common, $d2_matched_crosslink,$monolink_mass  );

                                # 		       $results_sql->execute($d2_MSn_string,$d2_MSn_string,$peak->{'d2_mz'},$peak->{'d2_charge'},$d2_modified_fragment, @sequences[(substr($fragment_sources{$fragment},0,1)-1)],@sequences[(substr($fragment_sources{$fragment},-1,1)-1)],$sequence_names[(substr($fragment_sources{$fragment},0,1)-1)],$sequence_names[(substr($fragment_sources{$fragment},-1,1)-1)],$d2_ms2_score, $peak->{'fraction'},"d2_".$peak->{'scan_num'},"d2_".$peak->{'d2_scan_num'}, $modification,$n,$d2_best_x,$d2_best_y,$fragment, $d2_score, $d2_top_10);
                            };

                        }

                    }
		  }
                }
            }
        }
    }

    return %fragment_score;

}

sub create_table    #Creates the working table in the SQLite database
{

    my ($dbh) = @_;

    my $masslist = $dbh->prepare("DROP TABLE IF EXISTS msdata;");
    $masslist->execute();
    $dbh->do("CREATE TABLE msdata (scan_num number,fraction, title, charge number, mz number, monoisotopic_mw number, abundance number, MSn_string, msorder) ");

    #  $masslist=  $dbh->prepare("DROP TABLE IF EXISTS scans;");
    #  $masslist->execute();
    #  $dbh->do("CREATE TABLE scans (scan_num number, mz float, abundance float) ");
}

sub import_mgf    #Enters the uploaded MGF into a SQLite database
{

    my ( $fraction, $file, $dbh ) = @_;

    my %line;
    my $MSn_count = 0;
    my $dataset   = 0;
    my $MSn_string;

    $line{'fraction'} = $fraction;

    #  my $scan_data = $dbh->prepare("INSERT INTO scans (scan_num, mz, abundance ) VALUES (?, ?, ?)");

    while (<$file>) {
        if ( $_ =~ "BEGIN IONS" ) { $dataset = $dataset + 1; }
        elsif ( $_ =~ "PEPMASS" ) {
            my $mystring = $_;
            if ( $mystring =~ m/=(.*?) / )      { $line{'mz'}        = $1 }
            if ( $mystring =~ m/ (.*?)[\r\n]/ ) { $line{'abundance'} = $1 }
        } elsif ( $_ =~ "SCANS" ) {
            my $mystring = $_;
            if ( $mystring =~ m/=(.*?)[\r\n]/ ) { $line{'scan_num'} = $1 }
        } elsif ( $_ =~ "CHARGE" ) {
            my $mystring = $_;
            if ( $mystring =~ m/=(.*?)\+/ ) { $line{'charge'} = $1 }
        } elsif ( $_ =~ "TITLE" ) {
            my $mystring = $_;
            if ( $mystring =~ m/=(.*?)[\r\n]/ ) { $line{'title'} = $1 }
        }

        elsif ( $_ =~ "^.[0-9]" ) {
            my $MSn_row = $_;
            $MSn_count  = $MSn_count + 1;
            $MSn_string = $MSn_string . $MSn_row;
            my @MSn_split = split( / /, $MSn_row );
            my ( $ms2_mz, $ms2_abundance ) = @MSn_split;

            #       $scan_data->execute($line{'scan_num'},$ms2_mz, $ms2_abundance);
        }

        elsif ( $_ =~ "END IONS" ) {
            $line{'monoisoptic_mw'} = $line{'mz'} * $line{'charge'} - ( $line{'charge'} * 1.00728 );
            my $newline = $dbh->prepare("INSERT INTO msdata (scan_num, fraction, title, charge, mz, abundance, monoisotopic_mw, MSn_string, msorder) VALUES (? , ?, ?, ?, ?, ?, ?,?, 2)");
            $newline->execute( $line{'scan_num'}, $line{'fraction'}, $line{'title'}, $line{'charge'}, $line{'mz'}, $line{'abundance'}, $line{'monoisoptic_mw'}, $MSn_string );

            $line{'scan_num'} = $line{'monoisoptic_mw'} = $line{'abundance'} = $MSn_string = '';
            $MSn_count = 0;
        }
    }
}

sub import_csv    #Enters the uploaded CSV into a SQLite database
{
    my ( $fraction, $file, $dbh ) = @_;

    my $newline = $dbh->prepare("INSERT INTO msdata (scan_num, fraction, charge, mz, abundance, monoisotopic_mw, msorder) VALUES (? , ?, ?, ?, ?, ?, 1)");

    while ( my $line = <$file> ) {
        next if ( $. == 1 );
        $line =~ s/\"//g;
        $line =~ s/\r//g;
        chomp($line);
        my @columns = split( ",", $line );
        my $monoisoptic_mw = $columns[3] * $columns[1] - ( $columns[1] * 1.00728 );
        if ( $columns[1] > 1 ) {
            $newline->execute( $columns[0], $fraction, $columns[1], $columns[3], $columns[2], $columns[6] );
        }
    }
}

sub loaddoubletlist_db    #Used to get mass-doublets from the data.
{

    my ( $doublet_ppm_err, $linkspacing, $isotope, $dbh, $scan_width, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, ) = @_;

    my $mass_seperation = 0;
    if ( $isotope eq "deuterium" ) {
        $mass_seperation = $linkspacing * ( $mass_of_deuterium - $mass_of_hydrogen );
    } else {
        $mass_seperation = $linkspacing * ( $mass_of_carbon13 - $mass_of_carbon12 );
    }

    my $average_peptide_mass  = 750;
    my $mass_seperation_upper = $mass_seperation + $average_peptide_mass * ( 0 + ( $doublet_ppm_err / 1000000 ) );
    my $mass_seperation_lower = $mass_seperation + $average_peptide_mass * ( 0 - ( $doublet_ppm_err / 1000000 ) );
    my $isopairs;
    my @peaklist;

    my $masslist = $dbh->prepare("DROP INDEX IF EXISTS mz_data;");
    $masslist->execute();
    $masslist = $dbh->prepare("CREATE INDEX mz_data ON msdata ( monoisotopic_mw);");
    $masslist->execute();

    $masslist = $dbh->prepare(
        "DELETE from msdata where msdata.msorder =1 and  exists (SELECT d1.*
	                          FROM msdata d1 inner join msdata d2 on (d2.mz = d1.mz) 
					  and d2.scan_num = d1.scan_num 
        	                          and d2.fraction = d1.fraction
                        	          and d1.msorder = 1
					  and d2.msorder = 2
	                          )"
    );

    $masslist->execute();

    if ( $isotope ne "none" ) {
        $masslist = $dbh->prepare(
            "SELECT d1.*,
				  d2.scan_num as d2_scan_num,
				  d2.mz as d2_mz,
				  d2.MSn_string as d2_MSn_string,
				  d2.charge as d2_charge,
				  d2.monoisotopic_mw as d2_monoisotopic_mw,
				  d2.title as d2_title 
			  FROM msdata d1 inner join msdata d2 on (d2.monoisotopic_mw between d1.monoisotopic_mw + ? and d1.monoisotopic_mw + ? )
				  and d2.scan_num between d1.scan_num - ? 
				  and d1.scan_num + ? 
				  and d1.fraction = d2.fraction 
				  and d1.msorder = 2
			  ORDER BY d1.scan_num ASC "
        );
        warn "Exceuting Doublet Search\n";
        $masslist->execute( $mass_seperation_lower, $mass_seperation_upper, $scan_width, $scan_width );
        warn "Finished Doublet Search\n";
    } else {
        $masslist = $dbh->prepare(
            "SELECT *
  			  FROM msdata 
  			  ORDER BY scan_num ASC "
        );
        $masslist->execute();
    }
    while ( my $searchmass = $masslist->fetchrow_hashref ) {
        push( @peaklist, $searchmass );
    }    #pull all records from our database of scans.

    return @peaklist;
}

1;

