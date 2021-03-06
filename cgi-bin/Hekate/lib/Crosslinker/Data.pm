use strict;

package Crosslinker::Data;
use base 'Exporter';
use lib 'lib';
use Crosslinker::Scoring;
use Crosslinker::Config;
use MIME::Base64;

our @EXPORT = (
               'connect_db',       'check_state',         'give_permission',          'is_ready',
               'disconnect_db',    'set_finished',        'save_settings',            'update_state',
               'import_cgi_query', 'find_free_tablename', 'matchpeaks',               'matchpeaks_single',
               'create_table',     'import_mgf',          'import_csv',               'loaddoubletlist_db',
               'generate_decoy',   'set_doublets_found',  'import_mgf_doublet_query', 'connect_db_single',
               'import_scan',      'create_settings',     'set_failed',               'connect_db_results',
               'set_state',        'create_results',      'import_mzXML',             'create_peptide_table',
               'add_peptide'
);
######
#
# Data import functions & database management
#
######

sub _retry {
    my ($retrys, $func, $ignore_if_fail) = @_;

  attempt: {
        my $result;

        # if it works, return the result
        return $result if eval { $result = $func->(); 1 };

        # nah, it failed, if failure reason is not a lock, croak
        die $@ unless $@ =~ /database is locked/;

        # if we have 0 remaining retrys, stop trying.
        last attempt if $retrys < 1;

        # sleep for 0.1 seconds, and then try again.
        sleep 100 / $retrys;
        $retrys--;
        redo attempt;
    }
    if (defined $ignore_if_fail) {
        return -1;
    } else {
        die "Attempts Exceeded $@";
    }
}

sub generate_decoy {
    my ($fasta) = @_;

    $fasta =~ s/[^A-z>\n]//g;

    my @sequences = split('>', $fasta);
    $fasta = $fasta . "\n";

    for (my $n = 1 ; $n < @sequences ; $n++) {
        my ($sequence_name, $sequence) = split('\n', $sequences[$n], 2);
        my $decoy = reverse $sequence;
        $sequence_name =~ s/[^A-z1-9]//g;
        $decoy         =~ s/[^A-Z]//g;
        $decoy         =~ tr/KR/RK/;
        $fasta = $fasta . ">decoy" . $sequence_name . "\r\n" . $decoy . "\n\n";
    }

    return $fasta;
}

sub create_results {

    my ($results_dbh) = @_;

    _retry 15, sub {
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
						      monolink_mass,
						      best_alpha REAL,
						      best_beta REAL,
						      min_chain_score,
						      time,
						      precursor_scan,
						      FDR) "
        );
    };

}

sub connect_db {
    my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:", "", "", { RaiseError => 1, AutoCommit => 1 });

  #    my $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results",  "", "", { RaiseError => 1, AutoCommit => 1 } );
    my $settings_dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

    return ($dbh, $settings_dbh);
}

sub connect_db_results {
    my ($name, $autocommit) = @_;

    if (!defined $autocommit) { $autocommit = 1 }
    my $results_dbh =
      DBI->connect("dbi:SQLite:dbname=db/results-$name", "", "", { RaiseError => 1, AutoCommit => $autocommit });
    create_results($results_dbh);

    return ($results_dbh);
}

sub create_settings {

    my ($settings_dbh) = @_;

    _retry 15, sub {
        $settings_dbh->do(
            "CREATE TABLE IF NOT EXISTS settings (
						      name INTEGER PRIMARY KEY,
						      desc,
						      cut_residues,
						      protein_sequences,
						      reactive_site,
						      mono_mass_diff,
						      xlinker_mass,
						      decoy,
						      ms2_da,
						      ms1_ppm,
						      finished NUMERIC,
						      isotoptic_shift,
						      threshold,
						      doublets_found,
						      charge_match,
						      intensity_match,
						      scored_ions,
						      amber,
						      time,
						      proteinase_k,
						      no_enzyme_min,
						      no_enzyme_max
						) "
        );
    };

}

sub connect_db_single {
    my $dbh         = DBI->connect("dbi:SQLite:dbname=:memory:",          "", "", { RaiseError => 1, AutoCommit => 1 });
    my $results_dbh = DBI->connect("dbi:SQLite:dbname=db/results_single", "", "", { RaiseError => 1, AutoCommit => 1 });
    my $settings_dbh =
      DBI->connect("dbi:SQLite:dbname=db/settings_single", "", "", { RaiseError => 1, AutoCommit => 1 });

    create_results($results_dbh);

    create_settings($settings_dbh);
    my $clean = $settings_dbh->prepare("DELETE from settings where time < ?");
    _retry 15, sub { $clean->execute(time - 84400) };    #Delete any scans over a day old.
    $clean = $results_dbh->prepare("DELETE from results where time < ?");
    _retry 15, sub { $clean->execute(time - 84400) };

    return ($dbh, $results_dbh, $settings_dbh);
}

sub disconnect_db {
    my ($dbh, $settings_dbh, $results_dbh) = @_;

    $settings_dbh->disconnect();
    $dbh->disconnect();
    $results_dbh->disconnect();
}

sub set_state {
    my ($results_table, $settings_dbh, $state) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET finished = ? WHERE  name = ?;");
    _retry 15, sub { $settings_sql->execute($state, $results_table) };

    return;
}

sub set_finished {
    my ($results_table, $settings_dbh) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET finished = -1 WHERE  name = ?;");
    _retry 15, sub { $settings_sql->execute($results_table) };

    return;
}

sub set_failed {
    my ($results_table, $settings_dbh) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET finished = -5 WHERE  name = ?;");
    _retry 15, sub { $settings_sql->execute($results_table) };

    return;
}

sub set_doublets_found {
    my ($results_table, $settings_dbh, $doublets_found) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET doublets_found = ? WHERE  name = ?;");
    _retry 15, sub { $settings_sql->execute($doublets_found, $results_table) };

    return;
}

sub update_state {

    my ($settings_dbh, $results_table, $state) = @_;

    my $settings_sql = $settings_dbh->prepare("UPDATE settings SET finished =? WHERE name=?;");

    _retry 15, sub { $settings_sql->execute($state, $results_table) }, 1;

    return;
}

sub check_state {
    my ($settings_dbh, $results_table) = @_;

    my $settings_sql = $settings_dbh->prepare("SELECT finished FROM settings WHERE name = ?");
    my $success = _retry 15, sub { $settings_sql->execute($results_table) }, 1;
    if ($success != -1) {
        my @data  = $settings_sql->fetchrow_array();
        my $state = $data[0];
        return $state;
    }

    return -2;
}

sub give_permission {
    my ($settings_dbh) = @_;

    my $settings_sql = $settings_dbh->prepare(
                     "SELECT name, finished FROM  settings WHERE finished = '-2' ORDER BY length(name) ASC, name ASC ");
    _retry 15, sub { $settings_sql->execute() };
    my @data = $settings_sql->fetchrow_array();
    if (defined $data[0]) {
        my $results_table = $data[0];

        warn "Giving Permission to $results_table ($data[1]) to start...", "\n";
        update_state($settings_dbh, $results_table, -3);
    } else {
        warn "Queue empty", "\n";
    }

    if (defined $data[0]) {
        return $data[0];
    }

    return -1;
}

sub is_ready {
    my ($settings_dbh, $ignore_waiting_searches) = @_;

    if (!defined $ignore_waiting_searches) { $ignore_waiting_searches = 0 }

    create_settings($settings_dbh);

    my $settings_sql;

    if ($ignore_waiting_searches == 0) {
        $settings_sql = $settings_dbh->prepare(
                       "SELECT count(finished) FROM settings WHERE finished = -2  or finished = -3   or finished > -1");
    } else {
        $settings_sql =
          $settings_dbh->prepare("SELECT count(finished) FROM settings WHERE  finished = -3 or finished > -1");
    }
    _retry 15, sub { $settings_sql->execute() };
    my @data = $settings_sql->fetchrow_array();

    my $state;

    if ($data[0] > 0 && $ignore_waiting_searches == 0) {

        #      warn $data[0], $data[1], $data[2];
        $state = -2;
    } elsif ($data[0] > 1 && $ignore_waiting_searches == 1) {
        $state = 0;
    } else {
        $state = 0;
    }
    return $state;
}

sub save_settings {

    my (
        $settings_dbh, $cut_residues,    $protien_sequences, $reactive_site,  $mono_mass_diff,
        $xlinker_mass, $state,           $desc,              $decoy,          $ms2_da,
        $ms1_ppm,      $mass_seperation, $dynamic_mods_ref,  $fixed_mods_ref, $threshold,
        $match_charge, $match_intensity, $scored_ions, $amber_codon ,
        $proteinase_k, $no_enzyme_min, $no_enzyme_max
    ) = @_;

    if (!defined $amber_codon) {$amber_codon = 0;};

    create_settings($settings_dbh);

    my $settings_sql = $settings_dbh->prepare(
        "INSERT INTO settings 
						(
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
						      charge_match,
						      intensity_match,
						      scored_ions,
						      amber,
						      time,
						      proteinase_k,
						      no_enzyme_min,
						      no_enzyme_max
						 ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
    );

    if   ($match_charge == '1') { $match_charge = 'Yes' }
    else                        { $match_charge = 'No' }
    if   ($match_intensity == '1') { $match_intensity = 'Yes' }
    else                           { $match_intensity = 'No' }

    _retry 15, sub {
        $settings_sql->execute(
                               $desc,           $cut_residues,    $protien_sequences, $reactive_site,
                               $mono_mass_diff, $xlinker_mass,    $decoy,             $ms2_da,
                               $ms1_ppm,        $state,           $mass_seperation,   $threshold,
                               $match_charge,   $match_intensity, $scored_ions,       $amber_codon,
				time,       	$proteinase_k, 	  $no_enzyme_min,     $no_enzyme_max
        );
    };

    my $results_table = $settings_dbh->func('last_insert_rowid');

    if (defined $fixed_mods_ref) {
        my $conf_dbh = connect_conf_db;
        _retry 15, sub {
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
        };
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
            my $fixed_mod = get_conf_value($conf_dbh, $mod);
            my $fixed_mod_data = $fixed_mod->fetchrow_hashref();
            _retry 15, sub {
                $settings_sql->execute($results_table, $mod,
                                       $fixed_mod_data->{'name'},
                                       $fixed_mod_data->{'setting1'},
                                       $fixed_mod_data->{'setting2'}, 'fixed');
            };
            $fixed_mod->finish;
        }
        $conf_dbh->disconnect();
    }

    if (defined $dynamic_mods_ref) {
        my $conf_dbh = connect_conf_db;
        _retry 15, sub {
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
        };
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
            my $dynamic_mod = get_conf_value($conf_dbh, $mod);
            my $dynamic_mod_data = $dynamic_mod->fetchrow_hashref();
            _retry 15, sub {
                $settings_sql->execute($results_table, $mod,
                                       $dynamic_mod_data->{'name'},
                                       $dynamic_mod_data->{'setting1'},
                                       $dynamic_mod_data->{'setting2'}, 'dynamic');
            };

            #          warn "Dynamic mod selected: $mod: $dynamic_mod_data->{'name'} \n";
            $dynamic_mod->finish;
        }
        $conf_dbh->disconnect();
    }

    return $results_table;
}

sub import_cgi_query {
    my ($query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12) = @_;
    my $fasta      = $query->param('user_protein_sequence');
    my $decoy      = $query->param('decoy');
    my $scan_width = $query->param('scan_width');
    if (!defined $scan_width) { $scan_width = 1 }

    my $protien_sequences;
    my $conf_dbh = connect_conf_db;

    if ($query->param('sequence') == -1) {
        $protien_sequences = $fasta;
    } else {
        my $sequences = get_conf_value($conf_dbh, $query->param('sequence'));
        my $sequence = $sequences->fetchrow_hashref();
        $protien_sequences = $sequence->{'setting1'};
        $fasta             = $sequence->{'setting1'};
        $sequences->finish;
    }

    if (defined $query->param('decoy')) {
        $protien_sequences = generate_decoy($protien_sequences);
        $fasta             = $protien_sequences;

        #       warn "Generating Decoy Database....\n";
    }

# 	warn $fasta;

    $protien_sequences =~ s/\r//g;
    my $desc = $query->param('user_desc');
    my @sequence_names = $protien_sequences =~ m/^>.*$/mg;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;
    my $missed_clevages = $query->param('missed_cleavages');
    my $upload_format   = $query->param('data_format');
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

    my $enzymes        = get_conf_value($conf_dbh, $query->param('enzyme'));
    my $enzyme         = $enzymes->fetchrow_hashref();
    my $cut_residues   = $enzyme->{'setting1'};
    my $nocut_residues = $enzyme->{'setting2'};
    my $n_or_c         = $enzyme->{'setting3'};
    $enzymes->finish;

    my @dynamic_mods = $query->param('dynamic_mod');
    my @fixed_mods   = $query->param('fixed_mod');

    my $mono_mass_diff;
    my $xlinker_mass;
    my $reactive_site;
    my $isotope;
    my $amber_codon;
    my $linkspacing;

    if (!defined $query->param('amber_codon'))
    {
      $mono_mass_diff       = $query->param('mono_mass_diff');
      $xlinker_mass         = $query->param('xlinker_mass');
      $reactive_site        = $query->param('reactive_site');
      $isotope              = $query->param("isotope");
      $linkspacing          = $query->param('seperation');
      $amber_codon = 0;
    } else {
      $mono_mass_diff       = $query->param('amber_residue_mass');
      $xlinker_mass         = $query->param('amber_xlink');
      $reactive_site        = $query->param('amber_peptide');
      $isotope              = $query->param("amber_isotope");
      $linkspacing          = $query->param('amber_seperation');
      $amber_codon =1;
    }



    my $doublet_tolerance    = $query->param("ms_ppm");
    my $threshold            = $query->param('threshold');
    my $match_charge         = 0;
    my $match_intensity      = 0;
    my $scored_ions          = '';
    my $no_xlink_at_cut_site = 1;
    my $ms1_intensity_ratio  = 1;
    my $fast_mode            = 1;
    my $proteinase_k	     = 0;
    my $no_enzyme_max	     = 6;
    my $no_enzyme_min	     = 0;


    if (defined $query->param('ms1_intensity_ratio')) { $ms1_intensity_ratio = $query->param('ms1_intensity_ratio') }
    if (defined $query->param('proteinase_k'))	      { $proteinase_k = 1; }
    if (defined $query->param('no_enzyme_min'))      { $no_enzyme_min = $query->param('no_enzyme_min'); }
    if (defined $query->param('no_enzyme_max'))      { $no_enzyme_max = $query->param('no_enzyme_max'); }
    if (defined $query->param('detailed_scoring'))    { $fast_mode           = 0 }

    if   (defined $query->param('charge_match')) { $match_charge = '1' }
    else                                         { $match_charge = '0' }
    if   (defined $query->param('intensity_match')) { $match_intensity = '1' }
    else                                            { $match_intensity = '0' }

    if   (defined $query->param('allow_xlink_at_cut_site')) { $no_xlink_at_cut_site = '0' }
    else                                                    { $no_xlink_at_cut_site = '1' }

    my %ms2_fragmentation;
    if   (defined $query->param('aions')) { $ms2_fragmentation{'aions'} = '1'; }
    else                                  { $ms2_fragmentation{'aions'} = '0' }
    if   (defined $query->param('bions')) { $ms2_fragmentation{'bions'} = '1' }
    else                                  { $ms2_fragmentation{'bions'} = '0' }
    if   (defined $query->param('yions')) { $ms2_fragmentation{'yions'} = '1' }
    else                                  { $ms2_fragmentation{'yions'} = '0' }

    if   (defined $query->param('waterloss')) { $ms2_fragmentation{'waterloss'} = '1'; }
    else                                      { $ms2_fragmentation{'waterloss'} = '0'; }
    if   (defined $query->param('ammonialoss')) { $ms2_fragmentation{'ammonialoss'} = '1'; }
    else                                        { $ms2_fragmentation{'ammonialoss'} = '0'; }

    if (defined $query->param('aions-score')) {
        $ms2_fragmentation{'aions-score'} = '1';
        $scored_ions = $scored_ions . 'A-ions, ';
    } else {
        $ms2_fragmentation{'aions-score'} = '0';
    }
    if (defined $query->param('bions-score')) {
        $ms2_fragmentation{'bions-score'} = '1';
        $scored_ions = $scored_ions . 'B-ions, ';
    } else {
        $ms2_fragmentation{'bions-score'} = '0';
    }
    if (defined $query->param('yions-score')) {
        $ms2_fragmentation{'yions-score'} = '1';
        $scored_ions = $scored_ions . 'Y-ions, ';
    } else {
        $ms2_fragmentation{'yions-score'} = '0';
    }

    if (defined $query->param('waterloss-score')) {
        $ms2_fragmentation{'waterloss-score'} = '1';
        $scored_ions = $scored_ions . 'water-loss ions, ';
    } else {
        $ms2_fragmentation{'waterloss-score'} = '0';
    }
    if (defined $query->param('ammonialoss-score')) {
        $ms2_fragmentation{'ammonialoss-score'} = '1';
        $scored_ions = $scored_ions . 'ammonia-loss ions ';
    } else {
        $ms2_fragmentation{'ammonialoss-score'} = '0';
    }

    #   warn "aions:". $query->param('aions-score'),",$ms2_fragmentation{'aions-score'}";
    #   warn "bions:". $query->param('bions-score'),",$ms2_fragmentation{'bions-score'}";
    #   warn "yions:". $query->param('yions-score'),",$ms2_fragmentation{'yions-score'}";
    #   warn "wions:". $query->param('waterloss-score'),",$ms2_fragmentation{'waterloss-score'}";
    #   warn "nions:". $query->param('ammonialoss-score'),",$ms2_fragmentation{'ammonialoss-score'}";

    if ($query->param('crosslinker') != -1) {

        my $crosslinkers = get_conf_value($conf_dbh, $query->param('crosslinker'));
        my $crosslinker = $crosslinkers->fetchrow_hashref();

        warn "Reagent: $crosslinker->{'name'} \n";
        $mono_mass_diff = $crosslinker->{'setting3'};
        $xlinker_mass   = $crosslinker->{'setting2'};
        $reactive_site  = $crosslinker->{'setting1'};
        $isotope        = $crosslinker->{'setting4'};
        $linkspacing    = $crosslinker->{'setting5'};
    }

    my $mass_seperation = 0;
    if ($isotope eq "deuterium") {
        $mass_seperation = $linkspacing * ($mass_of_deuterium - $mass_of_hydrogen);
    } elsif ($isotope eq "carbon-13") {
        $mass_seperation = $linkspacing * ($mass_of_carbon13 - $mass_of_carbon12);
    }

    $conf_dbh->disconnect();
    return (
            $protien_sequences,   \@sequence_names, $missed_clevages,   \@upload_filehandle,
            \@csv_filehandle,     $reactive_site,   $cut_residues,      $nocut_residues,
            $fasta,               $desc,            $decoy,             $match_ppm,
            $ms2_error,           $mass_seperation, $isotope,           $linkspacing,
            $mono_mass_diff,      $xlinker_mass,    \@dynamic_mods,     \@fixed_mods,
            \%ms2_fragmentation,  $threshold,       $n_or_c,            $scan_width,
            $match_charge,        $match_intensity, $scored_ions,       $no_xlink_at_cut_site,
            $ms1_intensity_ratio, $fast_mode,       $doublet_tolerance, $upload_format, $amber_codon, $proteinase_k,
	    $no_enzyme_min,	 $no_enzyme_max
    );
}

sub import_mgf_doublet_query {
    my ($query, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12) = @_;

    my $conf_dbh = connect_conf_db;

    my @upload_filehandle;
    $upload_filehandle[1] = $query->upload("mgf");

    my $doublet_tolerance = $query->param("ms_ppm");
    if (!defined $doublet_tolerance) { $doublet_tolerance = 10 }

    my $isotope     = $query->param("isotope");
    my $linkspacing = $query->param('seperation');
    my $scan_width  = $query->param('scan_width');
    if (!defined $scan_width) { $scan_width = 1 }
    my $output_format = $query->param('output_format');

    my $match_charge    = 0;
    my $match_intensity = 0;

    if   (defined $query->param('charge_match')) { $match_charge = '1' }
    else                                         { $match_charge = '0' }
    if   (defined $query->param('intensity_match')) { $match_intensity = '1' }
    else                                            { $match_intensity = '0' }

    if ($query->param('crosslinker') != -1) {

        my $crosslinkers = get_conf_value($conf_dbh, $query->param('crosslinker'));
        my $crosslinker = $crosslinkers->fetchrow_hashref();

        warn "Reagent: $crosslinker->{'name'} \n";
        $isotope     = $crosslinker->{'setting4'};
        $linkspacing = $crosslinker->{'setting5'};
    }

    my $mass_seperation = 0;
    if ($isotope eq "deuterium") {
        $mass_seperation = $linkspacing * ($mass_of_deuterium - $mass_of_hydrogen);
    } elsif ($isotope eq "carbon-13") {
        $mass_seperation = $linkspacing * ($mass_of_carbon13 - $mass_of_carbon12);
    }

    my $ms1_intensity_ratio = 1;
    if (defined $query->param('ms1_intensity_ratio')) { $ms1_intensity_ratio = $query->param('ms1_intensity_ratio') }

    $conf_dbh->disconnect();
    return (
            \@upload_filehandle, $doublet_tolerance, $mass_seperation, $isotope,
            $linkspacing,        $scan_width,        $match_charge,    $output_format,
            $match_intensity,    $ms1_intensity_ratio
    );
}

sub find_free_tablename {
    my ($settings_dbh) = @_;

    create_settings($settings_dbh);

    my $table_list = $settings_dbh->prepare("SELECT DISTINCT name FROM settings ORDER BY length(name) DESC, name DESC");
    _retry 15, sub { $table_list->execute() };
    my $table_name = $table_list->fetchrow_hashref;
    my $results_table;
    if ($table_name->{'name'}) {
        my @new_table = split('R', $table_name->{'name'});
        $results_table = "R" . sprintf("%04d", ($new_table[1] + 1));
    } else {
        $results_table = "R0001";
    }

    return $results_table;
}

sub matchpeaks {
    my (
        $peaklist_ref,         $protien_sequences,       $match_ppm,             $dbh,
        $results_dbh,          $settings_dbh,            $results_table,         $mass_of_deuterium,
        $mass_of_hydrogen,     $mass_of_carbon13,        $mass_of_carbon12,      $cut_residues,
        $nocut_residues,       $sequence_names_ref,      $mono_mass_diff,        $xlinker_mass,
        $linkspacing,          $isotope,                 $reactive_site,         $modifications_ref,
        $ms2_error,            $protein_residuemass_ref, $ms2_fragmentation_ref, $threshold,
        $no_xlink_at_cut_site, $fast_mode,		 $amber_codon
    ) = @_;

    #    my %fragment_masses     = %{$fragment_masses_ref};
    #    my %fragment_sources    = %{$fragment_sources_ref};
    my %modifications       = %{$modifications_ref};
    my %protein_residuemass = %{$protein_residuemass_ref};
    my %ms2_fragmentation   = %{$ms2_fragmentation_ref};
    my @sequences           = split('>', $protien_sequences);
    my @sequence_names      = @{$sequence_names_ref};
    my $max_delta           = 1 + ($match_ppm / 1000000);
    if (!defined $amber_codon) {$amber_codon = 0};
    my $TIC;
    my %fragment_score;
    my @peaklist = @{$peaklist_ref};
    my $xlinker;
    my $codensation;
    my $amber_peptide = $reactive_site;

    my $seperation = 0;
    if ($isotope eq "deuterium") {
        $seperation = $linkspacing * ($mass_of_deuterium - $mass_of_hydrogen);
    } elsif ($isotope eq "carbon-13") {
        $seperation = $linkspacing * ($mass_of_carbon13 - $mass_of_carbon12);
    }

    #    foreach my $fragment ( keys %fragment_masses ) {
    #       $fragment_score{$fragment} = 0;
    #    }

    my $ms2 = $dbh->prepare(
"SELECT MSn_string, scan_num FROM msdata WHERE mz between ? +0.00005 and ? -0.00005 and scan_num between ? - 20 and ? + 20 and fraction = ? and msorder = 2 LIMIT 0,1"
    );

    my $peak_no = 0;

######
    #
    # Connect to results DB and create a table
    #
######
    my $time = time;
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
						      monolink_mass,
						      best_alpha,
						      best_beta,	
						      time,
						      precursor_scan
						      )VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
    );

    my $peptides = $results_dbh->prepare("select * from peptides where results_table = ? AND (xlink = 1 or monolink <> 0) and mass between ? and ?");

#######
    #
    #
    #
#######

    foreach my $peak (@peaklist) {

        #        warn $peak->{'scan_num'};
        #        warn $peak->{'d2_scan_num'};
        $peak_no = $peak_no + 1;
        my $percent_done = 0;

        #        warn $percent_done * 100, " % Peak mz = " . sprintf( "%.5f", $peak->{'mz'} ) . "\n";

        if (check_state($settings_dbh, $results_table) == -4) {
            return %fragment_score;
        }

        if ($percent_done != sprintf("%.2f", $peak_no / @peaklist)) {
            $percent_done = sprintf("%.2f", $peak_no / @peaklist);
            update_state($settings_dbh, $results_table, $percent_done);
        }
        my $MSn_string    = "";
        my $d2_MSn_string = "";
        my $round         = sprintf("%.5f", $peak->{'mz'});
        $MSn_string = $peak->{'MSn_string'};
        $d2_MSn_string = $peak->{'d2_MSn_string'};


        $peptides->execute( $results_table,  $peak->{monoisotopic_mw} / $max_delta , $peak->{monoisotopic_mw} *$max_delta );

        while (my $peptide = $peptides->fetchrow_hashref) {
            my $fragment = $peptide->{'sequence'};

		my $modification;
	        if (defined $peptide->{'modifications'} && $peptide->{'modifications'} ne '')
		      { $modification = $peptide->{'modifications'}}
		else {  $modification = 'NoMod'}

                my $location = $modifications{$modification}{Location};
                my $rxn_residues = @{ [ $fragment =~ /$location/g ] };

                    my $monolink_mass = $peptide->{'monolink'};
		    if ($amber_codon == 1) {
			$monolink_mass = $mono_mass_diff;
		    }
                    my $mass = $peptide->{'mass'};

#                             if (
#                                 (
#                                  $peak->{monoisotopic_mw} / $peak->{charge} <
#                                  ($mass / $peak->{charge}) * $max_delta
#                                 ) #Divide by charge to give PPM of detected species otherwise we are 4 times more stick on 4+ m/z
#                                 && ($peak->{monoisotopic_mw} /
#                                     $peak->{charge} >
#                                     ($mass / $peak->{charge}) /
#                                     $max_delta)
#                               )
#                             {
                                my $score = (
                                             abs(
                                                 (
                                                  $peak->{monoisotopic_mw} -
                                                    ($mass)
                                                 )
                                             )
                                ) / ($mass) * 1000000;

# 	   	        my $d2_score = (abs(($peak->{d2_monoisotopic_mw} - ($fragment_masses{$fragment}+$seperation+($modifications{$modification}{Delta}*$n)))))/($fragment_masses{$fragment})*1000000;
                                my $rounded = sprintf("%.3f", $score);
                                {

 #                                                            warn $fragment, $modifications{$modification}{Name}, "\n";
 # 				if ( $modifications{$modification}{Name} eq "loop link" ) { warn "loop link ";	}
                                    my $abundance_ratio = -1;
                                    if (defined $peak->{'d2_abundance'} > 0) {
                                        if ($peak->{'abundance'} > 0 && $peak->{'d2_abundance'} > 0) {
                                            $abundance_ratio = $peak->{'abundance'} / $peak->{'d2_abundance'};
                                        }
                                    }

				    my $n = $peptide->{'no_of_mods'};

                                    my (
                                        $ms2_score,          $modified_fragment,    $best_x,
                                        $best_y,             $top_10,               $d2_top_10,
                                        $matched_abundance,  $d2_matched_abundance, $total_abundance,
                                        $d2_total_abundance, $matched_common,       $matched_crosslink,
                                        $d2_matched_common,  $d2_matched_crosslink, $best_alpha,
                                        $best_beta,          $min_chain_score
                                      )
                                      = calc_score(
                                                   \%protein_residuemass, $MSn_string,           $d2_MSn_string,
                                                   $fragment,             \%modifications,       $n,
                                                   $modification,         $mass_of_hydrogen,     $xlinker_mass,
                                                   $monolink_mass,        $seperation,           $reactive_site,
                                                   $peak->{'charge'},     $ms2_error,            \%ms2_fragmentation,
                                                   $threshold,            $no_xlink_at_cut_site, $abundance_ratio,
                                                   $fast_mode,		  $amber_codon
                                      );

# 		       my ($d2_ms2_score,$d2_modified_fragment,$d2_best_x,$d2_best_y, $d2_top_10) = calc_score($d2_MSn_string,$d2_MSn_string,$fragment, \%modifications, $n,$modification, $mass_of_hydrogen,$xlinker_mass+$seperation,$mono_mass_diff,  $seperation, $reactive_site,$peak->{'charge'}, $best_x, $best_y);

                                    my ($fragment1_source, $fragment2_source) =
                                      split "-", $peptide->{'source'};
                                    if ($fragment !~ m/[-]/) {
                                        $fragment2_source = "0";
                                    }

				    if ($amber_codon == 0) {
                                    _retry 15, sub {
                                        $results_sql->execute(
                                                 $results_table,                     $MSn_string,
                                                 $d2_MSn_string,                     $peak->{'mz'},
                                                 $peak->{'charge'},                  $modified_fragment,
                                                 $sequences[$fragment1_source],      $sequences[$fragment2_source],
                                                 $sequence_names[$fragment1_source], $sequence_names[$fragment2_source],
                                                 $ms2_score,                         $peak->{'fraction'},
                                                 $peak->{'scan_num'},                $peak->{'d2_scan_num'},
                                                 $modification,                      $n,
                                                 $best_x,                            $best_y,
                                                 $fragment,                          $score,
                                                 $top_10,                            $d2_top_10,
                                                 $matched_abundance,                 $d2_matched_abundance,
                                                 $total_abundance,                   $d2_total_abundance,
                                                 $matched_common,                    $matched_crosslink,
                                                 $d2_matched_common,                 $d2_matched_crosslink,
                                                 $monolink_mass,                     $best_alpha,
                                                 $best_beta,                         $time,
                                                 $peak->{'precursor_scan'}
                                        );};
                                    } else {
				    _retry 15, sub {
                                        $results_sql->execute(
                                                 $results_table,                     $MSn_string,
                                                 $d2_MSn_string,                     $peak->{'mz'},
                                                 $peak->{'charge'},                  $modified_fragment,
                                                 $sequences[$fragment1_source],      $amber_peptide,
                                                 $sequence_names[$fragment1_source], '>Peptide',
                                                 $ms2_score,                         $peak->{'fraction'},
                                                 $peak->{'scan_num'},                $peak->{'d2_scan_num'},
                                                 $modification,                      $n,
                                                 $best_x,                            $best_y,
                                                 $fragment,                          $score,
                                                 $top_10,                            $d2_top_10,
                                                 $matched_abundance,                 $d2_matched_abundance,
                                                 $total_abundance,                   $d2_total_abundance,
                                                 $matched_common,                    $matched_crosslink,
                                                 $d2_matched_common,                 $d2_matched_crosslink,
                                                 $monolink_mass,                     $best_alpha,
                                                 $best_beta,                         $time,
                                                 $peak->{'precursor_scan'}
                                        );
                                    };
				    }

# 		       $results_sql->execute($d2_MSn_string,$d2_MSn_string,$peak->{'d2_mz'},$peak->{'d2_charge'},$d2_modified_fragment, @sequences[(substr($fragment_sources{$fragment},0,1)-1)],@sequences[(substr($fragment_sources{$fragment},-1,1)-1)],$sequence_names[(substr($fragment_sources{$fragment},0,1)-1)],$sequence_names[(substr($fragment_sources{$fragment},-1,1)-1)],$d2_ms2_score, $peak->{'fraction'},"d2_".$peak->{'scan_num'},"d2_".$peak->{'d2_scan_num'}, $modification,$n,$d2_best_x,$d2_best_y,$fragment, $d2_score, $d2_top_10);
                                };

                            

        }
    }

    return %fragment_score;

}

sub matchpeaks_single {
    my (
        $peaklist_ref,          $fragment_masses_ref, $fragment_sources_ref, $protien_sequences,
        $match_ppm,             $dbh,                 $results_dbh,          $settings_dbh,
        $results_table,         $mass_of_deuterium,   $mass_of_hydrogen,     $mass_of_carbon13,
        $mass_of_carbon12,      $cut_residues,        $nocut_residues,       $sequence_names_ref,
        $mono_mass_diff,        $xlinker_mass,        $linkspacing,          $isotope,
        $reactive_site,         $modifications_ref,   $ms2_error,            $protein_residuemass_ref,
        $ms2_fragmentation_ref, $threshold,           $no_xlink_at_cut_site, $fast_mode
    ) = @_;
    my %fragment_masses     = %{$fragment_masses_ref};
    my %fragment_sources    = %{$fragment_sources_ref};
    my %modifications       = %{$modifications_ref};
    my %protein_residuemass = %{$protein_residuemass_ref};
    my %ms2_fragmentation   = %{$ms2_fragmentation_ref};
    my @sequences           = split('>', $protien_sequences);
    my @sequence_names      = @{$sequence_names_ref};
    my $max_delta           = 1 + ($match_ppm / 1000000);
    my $TIC;
    my %fragment_score;
    my @peaklist = @{$peaklist_ref};
    my $xlinker;
    my $codensation;

    my $seperation = 0;
    if ($isotope eq "deuterium") {
        $seperation = $linkspacing * ($mass_of_deuterium - $mass_of_hydrogen);
    } elsif ($isotope eq "carbon-13") {
        $seperation = $linkspacing * ($mass_of_carbon13 - $mass_of_carbon12);
    }

    foreach my $fragment (keys %fragment_masses) {
        $fragment_score{$fragment} = 0;
    }

    my $ms2 = $dbh->prepare(
"SELECT MSn_string, scan_num FROM msdata WHERE mz between ? +0.00005 and ? -0.00005 and scan_num between ? - 20 and ? + 20 and fraction = ? and msorder = 2 LIMIT 0,1"
    );

    my $peak_no = 0;

######
    #
    # Connect to results DB and create a table
    #
######
    my $time = time;
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
						      monolink_mass,
						      best_alpha,
						      best_beta,	
						      time
						      )VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
    );

#######
    #
    #
    #
#######

    foreach my $peak (@peaklist) {

        #        warn $peak->{'scan_num'};
        #        warn $peak->{'d2_scan_num'};
        $peak_no = $peak_no + 1;
        my $percent_done = 0;

        #        warn $percent_done * 100, " % Peak mz = " . sprintf( "%.5f", $peak->{'mz'} ) . "\n";

        if (check_state($settings_dbh, $results_table) == -4) {
            return %fragment_score;
        }

        if ($percent_done != sprintf("%.2f", $peak_no / @peaklist)) {
            $percent_done = sprintf("%.2f", $peak_no / @peaklist);
            update_state($settings_dbh, $results_table, $percent_done);
        }
        my $MSn_string    = "";
        my $d2_MSn_string = "";
        my $round         = sprintf("%.5f", $peak->{'mz'});

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

        foreach my $fragment (sort(keys %fragment_masses)) {

            foreach my $modification (sort(keys %modifications)) {
                my $location = $modifications{$modification}{Location};
                my $rxn_residues = @{ [ $fragment =~ /$location/g ] };

                if (   !($modifications{$modification}{Name} eq "loop link" && $fragment =~ /[-]/)
                    && !($modifications{$modification}{Name} eq "mono link")
                  ) #crosslink and loop link on the same peptide is a messy option,certainly shouldn't give a mass doublet, so remove them
                {
                    my @monolink_masses;

                    my $mass = $fragment_masses{$fragment};
                    if ($fragment !~ /[-]/) {
                        @monolink_masses = split(",", $mono_mass_diff);

                        #  		  push @monolink_masses, 0;
                    } else {
                        @monolink_masses = ('0');
                    }

                    foreach my $monolink_mass (@monolink_masses) {
                        $mass = $fragment_masses{$fragment} + $monolink_mass;

                     #                     if ( $modifications{$modification}{Name} eq "mono link" ) {
                     #                         $rxn_residues = ( $rxn_residues - ( 2 * @{ [ $fragment =~ /[-]/g ] } ) );
                     #                     }

                        if ($modifications{$modification}{Name} eq "loop link") {
                            $rxn_residues = ($rxn_residues - (2 * @{ [ $fragment =~ /[-]/g ] })) / 2;
                        }
                        for (my $n = 1 ; $n <= $rxn_residues ; $n++) {

                            if (
                                (
                                 $peak->{monoisotopic_mw} / $peak->{charge} <
                                 (($mass + ($modifications{$modification}{Delta} * $n)) / $peak->{charge}) * $max_delta
                                ) #Divide by charge to give PPM of detected species otherwise we are 4 times more stick on 4+ m/z
                                && ($peak->{monoisotopic_mw} /
                                    $peak->{charge} >
                                    (($mass + ($modifications{$modification}{Delta} * $n)) / $peak->{charge}) /
                                    $max_delta)
                              )
                            {
                                my $score = (
                                             abs(
                                                 (
                                                  $peak->{monoisotopic_mw} -
                                                    ($mass + ($modifications{$modification}{Delta} * $n))
                                                 )
                                             )
                                ) / ($mass) * 1000000;

# 	   	        my $d2_score = (abs(($peak->{d2_monoisotopic_mw} - ($fragment_masses{$fragment}+$seperation+($modifications{$modification}{Delta}*$n)))))/($fragment_masses{$fragment})*1000000;
                                my $rounded = sprintf("%.3f", $score);
                                {

 #                                                            warn $fragment, $modifications{$modification}{Name}, "\n";
 # 				if ( $modifications{$modification}{Name} eq "loop link" ) { warn "loop link ";	}
                                    my $abundance_ratio = -1;
                                    if (defined $peak->{'d2_abundance'} > 0) {
                                        if ($peak->{'abundance'} > 0 && $peak->{'d2_abundance'} > 0) {
                                            $abundance_ratio = $peak->{'abundance'} / $peak->{'d2_abundance'};
                                        }
                                    }

                                    my (
                                        $ms2_score,          $modified_fragment,    $best_x,
                                        $best_y,             $top_10,               $d2_top_10,
                                        $matched_abundance,  $d2_matched_abundance, $total_abundance,
                                        $d2_total_abundance, $matched_common,       $matched_crosslink,
                                        $d2_matched_common,  $d2_matched_crosslink, $best_alpha,
                                        $best_beta,          $min_chain_score
                                      )
                                      = calc_score(
                                                   \%protein_residuemass, $MSn_string,           $d2_MSn_string,
                                                   $fragment,             \%modifications,       $n,
                                                   $modification,         $mass_of_hydrogen,     $xlinker_mass,
                                                   $monolink_mass,        $seperation,           $reactive_site,
                                                   $peak->{'charge'},     $ms2_error,            \%ms2_fragmentation,
                                                   $threshold,            $no_xlink_at_cut_site, $abundance_ratio,
                                                   $fast_mode
                                      );

# 		       my ($d2_ms2_score,$d2_modified_fragment,$d2_best_x,$d2_best_y, $d2_top_10) = calc_score($d2_MSn_string,$d2_MSn_string,$fragment, \%modifications, $n,$modification, $mass_of_hydrogen,$xlinker_mass+$seperation,$mono_mass_diff,  $seperation, $reactive_site,$peak->{'charge'}, $best_x, $best_y);

                                    my ($fragment1_source, $fragment2_source) =
                                      split "-", $fragment_sources{$fragment};
                                    if ($fragment !~ m/[-]/) {
                                        $fragment2_source = "0";
                                    }
                                    _retry 15, sub {
                                        $results_sql->execute(
                                                 $results_table,                     $MSn_string,
                                                 $d2_MSn_string,                     $peak->{'mz'},
                                                 $peak->{'charge'},                  $modified_fragment,
                                                 $sequences[$fragment1_source],      $sequences[$fragment2_source],
                                                 $sequence_names[$fragment1_source], $sequence_names[$fragment2_source],
                                                 $ms2_score,                         $peak->{'fraction'},
                                                 $peak->{'scan_num'},                $peak->{'d2_scan_num'},
                                                 $modification,                      $n,
                                                 $best_x,                            $best_y,
                                                 $fragment,                          $score,
                                                 $top_10,                            $d2_top_10,
                                                 $matched_abundance,                 $d2_matched_abundance,
                                                 $total_abundance,                   $d2_total_abundance,
                                                 $matched_common,                    $matched_crosslink,
                                                 $d2_matched_common,                 $d2_matched_crosslink,
                                                 $monolink_mass,                     $best_alpha,
                                                 $best_beta,                         $time
                                        );
                                    };

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
    _retry 15, sub { $masslist->execute() };
    _retry 15, sub {
        $dbh->do(
"CREATE TABLE msdata (scan_num number,fraction, title, charge number, mz number, monoisotopic_mw number, abundance number, MSn_string, msorder number, precursor_scan) "
        );
    };

    #  $masslist=  $dbh->prepare("DROP TABLE IF EXISTS scans;");
    #  $masslist->execute();
    #  $dbh->do("CREATE TABLE scans (scan_num number, mz float, abundance float) ");
}

sub create_peptide_table {

    my ($dbh) = @_;

    _retry 15, sub {
        $dbh->do(
            "CREATE TABLE IF NOT EXISTS peptides ( 
					    results_table number,
					    sequence,
					    source,
					    linear_only number,
					    mass float,
					    modifications,
					    monolink number,
					    xlink number,
					    no_of_mods number) "
        );
    };

}

sub add_peptide {

    my ($dbh, $table, $sequence, $source, $linear_only, $mass, $modifications, $monolink, $xlink) = @_;

    my $newline = $dbh->prepare(
"INSERT INTO peptides (results_table, sequence, source, linear_only, mass, modifications, monolink, xlink, no_of_mods) VALUES (?,?,?,?,?,?,?,?, 0)"
    );

    _retry 15,
      sub { $newline->execute($table, $sequence, $source, $linear_only, $mass, $modifications, $monolink, $xlink); };

}

sub import_mgf    #Enters the uploaded MGF into a SQLite database
{

    my ($fraction, $file, $dbh) = @_;

    my %line;
    my $MSn_count = 0;
    my $dataset   = 0;
    my $MSn_string;

    $line{'fraction'} = $fraction;

    #  my $scan_data = $dbh->prepare("INSERT INTO scans (scan_num, mz, abundance ) VALUES (?, ?, ?)");

    while (<$file>) {
        if ($_ =~ "^BEGIN IONS") { 
		$dataset = $dataset + 1; 
		$line{'abundance'} = 0;
		$line{'scan_num'} = 0;
		}
        elsif ($_ =~ "^PEPMASS") {
            my $mystring = $_;
            if ($mystring =~ m/=(.*?) /)      { $line{'mz'}        = $1;}
	    elsif ($mystring =~ m/=(.*?)[\r\n]/) { $line{'mz'}     = $1;}
            if ($mystring =~ m/ (.*?)[\r\n]/) { $line{'abundance'} = $1 ;}
        } elsif ($_ =~ "^SCANS") {
            my $mystring = $_;
            if ($mystring =~ m/=(.*?)[\r\n]/) { $line{'scan_num'} = $1 }
        } elsif ($_ =~ "^CHARGE") {
            my $mystring = $_;
            if ($mystring =~ m/=(.*?)\+/) { $line{'charge'} = $1 }
        } elsif ($_ =~ "^TITLE") {
            my $mystring = $_;
            if ($mystring =~ m/=(.*?)[\r\n]/)  { $line{'title'} = $1 }
	    if ($mystring =~ m/scan=([0-9]*)/ ne '') { $line{'scan_num'} = $1}
        }

        elsif ($_ =~ "^.[0-9]") {
            my $MSn_row = $_;
            $MSn_count  = $MSn_count + 1;
            $MSn_string = $MSn_string . $MSn_row;
            my @MSn_split = split(/ /, $MSn_row);
            my ($ms2_mz, $ms2_abundance) = @MSn_split;
            #       $scan_data->execute($line{'scan_num'},$ms2_mz, $ms2_abundance);
        }

        elsif ($_ =~ "^END IONS") {
            $line{'monoisoptic_mw'} = $line{'mz'} * $line{'charge'} - ($line{'charge'} * 1.00728);
            my $newline = $dbh->prepare(
"INSERT INTO msdata (scan_num, fraction, title, charge, mz, abundance, monoisotopic_mw, MSn_string, msorder) VALUES (? , ?, ?, ?, ?, ?, ?,?, 2)"
            );
            _retry 15, sub {
                $newline->execute($line{'scan_num'}, $line{'fraction'}, $line{'title'}, $line{'charge'}, $line{'mz'},
                                  $line{'abundance'}, $line{'monoisoptic_mw'}, $MSn_string);
            };

            # 	 warn "Scan imported \n";

            $line{'scan_num'} = $line{'monoisoptic_mw'} = $line{'abundance'} = $MSn_string = '';
            $MSn_count = 0;
        }
    }

    $dbh->commit;
}

sub import_mzXML    #Adapted from mzXML cpan script
{

    my ($fraction, $file, $dbh) = @_;

    my %line;
    my $MSn_count  = 0;
    my $dataset    = 0;
    my $MSn_string = '';

    $line{'fraction'} = $fraction;

    #  my $scan_data = $dbh->prepare("INSERT INTO scans (scan_num, mz, abundance ) VALUES (?, ?, ?)");

    $/ = '</peaks>';
    while (<$file>) {
        if (s/(<peaks[^>]+>)(.*)$//) {
            $dataset = $dataset + 1;
            my ($tag, $data) = ($1, $2);
            s/\n$//;
            if (/scan num="(\d+)"/) {
                $line{'scan_num'} = $1;
                /msLevel="(\d+)"/;
                $line{'ms_order'} = $1;
                if ($1 > 1) {
                    /precursorScanNum="(\d+)"/;
                    $line{'precursor_scan'} = $1;
                    /precursorCharge="(\d+)"/;
                    $line{'charge'} = $1;
                    /precursorIntensity="(\d+).(\d+)"/;
                    if   (defined $2) { $line{'abundance'} = $1 . "." . $2 }
                    else              { $line{'abundance'} = $1 }
                    /(\d+).(\d+)\<\/precursorMz>/;
                    $line{'mz'}    = $1 . "." . $2;
                    $line{'title'} = "";
                }
                $data =~ s{</peaks>$}{};
                my @spec = unpack("f>*", decode_base64($data));
                foreach my $i (0 .. scalar @spec / 2 - 1) {
                    $MSn_count  = $MSn_count + 1;
                    $MSn_string = $MSn_string . $spec[ 2 * $i ] . "\t" . $spec[ 2 * $i + 1 ] . "\n";
                }
                if ($line{'ms_order'} > 1) {
                    $line{'monoisoptic_mw'} = $line{'mz'} * $line{'charge'} - ($line{'charge'} * 1.00728);
                } else {
                     $line{'monoisoptic_mw'} = '';
                }
                my $newline = $dbh->prepare(
"INSERT INTO msdata (scan_num, fraction, title, charge, mz, abundance, monoisotopic_mw, MSn_string, msorder, precursor_scan) VALUES (? , ?, ?, ?, ?, ?, ?,?, ?,?)"
                );
                _retry 15, sub {
                    $newline->execute(
                                      $line{'scan_num'},       $line{'fraction'}, $line{'title'},
                                      $line{'charge'},         $line{'mz'},       $line{'abundance'},
                                      $line{'monoisoptic_mw'}, $MSn_string,       $line{'ms_order'},
                                      $line{'precursor_scan'}
                    );
                };
                if ($line{'scan_num'} % 100 == 0) { warn "Scans imported : $line{'scan_num'}  \n" }

                $line{'scan_num'} = $line{'monoisoptic_mw'} = $line{'abundance'} = $MSn_string = '';
                $MSn_count = 0;
            } else {
                die "cannot determine scan number";
            }
        }
    }

    $dbh->commit;
}

sub import_scan    #Enters the uploaded MGF into a SQLite database
{

    my ($light_scan, $heavy_scan, $precursor_charge, $precursor_mass, $mass_seperation, $mass_of_proton, $dbh) = @_;

    my %line;
    my $MSn_count = 0;
    my $dataset   = 0;
    my $MSn_string;

    my $newline = $dbh->prepare(
"INSERT INTO msdata (scan_num, fraction, title, charge, mz, abundance, monoisotopic_mw, MSn_string, msorder) VALUES (? , ?, ?, ?, ?, ?, ?,?, 2)"
    );
    _retry 15, sub {
        $newline->execute(-1, 1, 'Light Scan', $precursor_charge, $precursor_mass, 1,
                          ($precursor_mass * $precursor_charge) - ($mass_of_proton * $precursor_charge), $light_scan);
    };
    _retry 15, sub {
        $newline->execute(-1, 1, 'Heavy Scan', $precursor_charge, 1, 1,
                       ($precursor_mass * $precursor_charge) + $mass_seperation - ($mass_of_proton * $precursor_charge),
                       $heavy_scan);
    };

# warn '1461.7439788'," ",$precursor_mass, " ", ($precursor_mass*$precursor_charge) - ($mass_of_proton*$precursor_charge)

}

sub import_csv    #Enters the uploaded CSV into a SQLite database
{
    my ($fraction, $file, $dbh) = @_;

    my $newline = $dbh->prepare(
"INSERT INTO msdata (scan_num, fraction, charge, mz, abundance, monoisotopic_mw, msorder) VALUES (? , ?, ?, ?, ?, ?, 1)"
    );

    while (my $line = <$file>) {
        next if ($. == 1);
        $line =~ s/\"//g;
        $line =~ s/\r//g;
        chomp($line);
        my @columns = split(",", $line);
        my $monoisoptic_mw = $columns[3] * $columns[1] - ($columns[1] * 1.00728);
        if ($columns[1] > 1) {
            _retry 15,
              sub { $newline->execute($columns[0], $fraction, $columns[1], $columns[3], $columns[2], $columns[6]) };
        }
    }
}

sub loaddoubletlist_db    #Used to get mass-doublets from the data.
{

    my (
        $doublet_ppm_err,  $linkspacing,       $isotope,          $dbh,
        $scan_width,       $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13,
        $mass_of_carbon12, $match_charge,      $match_intensity,  $ms1_intensity_ratio
    ) = @_;

#   warn "$doublet_ppm_err, $linkspacing, $isotope, $dbh, $scan_width, $mass_of_deuterium, $mass_of_hydrogen, $mass_of_carbon13, $mass_of_carbon12, $match_charge";

    my $mass_seperation = 0;
    if ($isotope eq "deuterium") {
        $mass_seperation = $linkspacing * ($mass_of_deuterium - $mass_of_hydrogen);
    } elsif ($isotope eq "carbon-13") {
        $mass_seperation = $linkspacing * ($mass_of_carbon13 - $mass_of_carbon12);
    }

    my $average_peptide_mass  = 750;
    my $mass_seperation_upper = $mass_seperation + $average_peptide_mass * (0 + ($doublet_ppm_err / 1000000));
    my $mass_seperation_lower = $mass_seperation + $average_peptide_mass * (0 - ($doublet_ppm_err / 1000000));
    my $isopairs;
    my @peaklist;

    my $masslist = $dbh->prepare("DROP INDEX IF EXISTS mz_data;");
    _retry 15, sub { $masslist->execute() };
    $masslist = $dbh->prepare("CREATE INDEX mz_data ON msdata ( monoisotopic_mw);");
    _retry 15, sub { $masslist->execute() };

    #    $masslist = $dbh->prepare(
    #       "DELETE from msdata where msdata.msorder =1 and  exists (SELECT d1.*
    # 	                          FROM msdata d1 inner join msdata d2 on (d2.mz = d1.mz)
    # 					  and d2.scan_num = d1.scan_num
    #         	                          and d2.fraction = d1.fraction
    #                         	          and d1.msorder = 1
    # 					  and d2.msorder = 2
    # 	                          )"
    #    );
    #
    #    $masslist->execute();

    if ($isotope ne "none") {
        my $charge_match_string = "";
        if ($match_charge == "1") {
            $charge_match_string = "and d1.charge = d2.charge ";
        }
        my $intensity_match_string = "";
        if ($match_intensity == "1") {
            $intensity_match_string = "and (d1.abundance > d2.abundance * ? and d1.abundance < d2.abundance * ?)  ";
        }
        $masslist = $dbh->prepare(
            "SELECT d1.*,
				  d2.scan_num as d2_scan_num,
				  d2.mz as d2_mz,
				  d2.MSn_string as d2_MSn_string,
				  d2.charge as d2_charge,
				  d2.monoisotopic_mw as d2_monoisotopic_mw,
				  d2.title as d2_title,
				  d2.abundance as d2_abundance,
				  d2.precursor_scan as d2_precursor_scan
			  FROM msdata d1 inner join msdata d2 on (d2.monoisotopic_mw between d1.monoisotopic_mw + ? and d1.monoisotopic_mw + ? )
				  and d2.scan_num between d1.scan_num - ? 
				  and d1.scan_num + ? " . $charge_match_string . $intensity_match_string . "and d1.fraction = d2.fraction 
				  and d1.msorder = 2 and d2.msorder = 2
			  ORDER BY d1.scan_num ASC "
        );

        #       warn "Exceuting Doublet Search\n";
        if ($match_intensity == "1") {
            if ($ms1_intensity_ratio == '0' or !defined $ms1_intensity_ratio) { $ms1_intensity_ratio = 1 }

            #         warn "intensity match:   $ms1_intensity_ratio";
            _retry 15, sub {
                $masslist->execute($mass_seperation_lower, $mass_seperation_upper, $scan_width, $scan_width,
                                   $ms1_intensity_ratio, 1 / $ms1_intensity_ratio);
            };
        } else {
            _retry 15,
              sub { $masslist->execute($mass_seperation_lower, $mass_seperation_upper, $scan_width, $scan_width) };
        }

        #       warn "Finished Doublet Search\n";
    } else {
        $masslist = $dbh->prepare(
            "SELECT *
  			  FROM msdata 
  			  ORDER BY scan_num ASC "
        );
        _retry 15, sub { $masslist->execute() };
    }
    while (my $searchmass = $masslist->fetchrow_hashref) {
        push(@peaklist, $searchmass);
    }    #pull all records from our database of scans.

    return @peaklist;
}

1;

