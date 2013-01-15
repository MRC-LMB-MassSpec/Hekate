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

########################
#                      #
# Summary Gen          #
#                      #
########################

print_page_top_bootstrap("Settings");
my $version = version();

my $query = new CGI;

if (!defined $query->param('id')) {
    print <<ENDHTML;
Oops	
ENDHTML
} elsif ($query->param('type') eq 'enzyme') {
    if (!defined $query->param('confirmed')) {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;

        my $enzymes = get_conf_value($dbh, $row_id);
        print '<form method="POST" enctype="multipart/form-data" action="settings_edit.pl" >';
        print "<h2>Enzymes</h2>";
        print
"<table class='table table-striped'><tr><td>ID</td><td>Enzyme</td><td>Cleave at</td><td>Restrict</td><td>N or C</td><td>Edit/Delete</td></tr>";

        while ((my $enzyme = $enzymes->fetchrow_hashref)) {
            print
"<tr><td>$row_id</td><td><input type='text' name='name' size='10' maxlength='20' value='$enzyme->{'name'}'/></td><td><input type='text' name='setting1' size='10' maxlength='10' value='$enzyme->{'setting1'}'/></td><td><input type='text' name='setting2' size='5' maxlength='1' value='$enzyme->{'setting2'}'/></td><td><select name='setting3'><option>C</option><option>N</option></select><td><input class='btn btn-primary' type='submit' value='Save' /></td></tr>";
        }
        print
"</table><input type='hidden' name='type' value='enzyme'/><input type='hidden' name='id' value='$row_id'/><input type='hidden' name='confirmed' size='10' maxlength='10' value='yes'/></form>";
    } elsif ($query->param('confirmed') eq 'yes') {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;
        update_conf(
                    $dbh,                      $query->param('type'),
                    $query->param('name'),     $query->param('setting1'),
                    $query->param('setting2'), $query->param('setting3'),
                    0,                         0,
                    $row_id
        );

        print "<p>Setting edited return to <a href='settings.pl?page="
          . $query->param('type')
          . "s'>previous page?</a></p>";

    }
} elsif ($query->param('type') eq 'sequence') {
    if (!defined $query->param('confirmed')) {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;

        my $sequences = get_conf_value($dbh, $row_id);
        print '<form method="POST" enctype="multipart/form-data" action="settings_edit.pl" >';
        print "<h2>Sequence</h2>";
        print "<table class='table table-striped'><tr><td>ID</td><td>Protein</td><td>Sequence</td><td></td></tr>";

        while ((my $sequence = $sequences->fetchrow_hashref)) {
            print
"<tr><td>$row_id</td><td><input type='text' name='name' size='10' maxlength='20' value='$sequence->{'name'}'/></td><td><textarea class='span6 name='setting1' rows='12' cols='80'>$sequence->{'setting1'}</textarea></td><td><input class='btn btn-primary' type='submit' value='Save' /></td></tr>";
        }
        print
"</table><input type='hidden' name='type' value='sequence'/><input type='hidden' name='id' value='$row_id'/><input type='hidden' name='confirmed' size='10' maxlength='10' value='yes'/></form>";
    } elsif ($query->param('confirmed') eq 'yes') {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;
        update_conf($dbh, $query->param('type'), $query->param('name'), $query->param('setting1'), 0, 0, 0, 0, $row_id);

        print "<p>Setting edited return to <a href='settings.pl?page="
          . $query->param('type')
          . "s'>previous page?</a></p>";

    }
} elsif ($query->param('type') eq 'crosslinker') {
    if (!defined $query->param('confirmed')) {
        my $row_id       = $query->param('id');
        my $dbh          = connect_conf_db;
        my $crosslinkers = get_conf_value($dbh, $row_id);
        print '<form method="POST" enctype="multipart/form-data" action="settings_edit.pl" >';
        print "<h2>Crosslinking Reagent</h2>";
        print
"<table class='table table-striped'><tr><td>ID</td><td>Name</td><td>Reactivity</td><td>Mass</td><td>MonoLink Mass</td><td>Isotope</td><td>Seperation</d><td>Edit/Delete</td></tr>";

        while ((my $crosslinker = $crosslinkers->fetchrow_hashref)) {
            print
"<tr><td>$row_id</td><td><input type='text' name='name' size='10' maxlength='20' value='$crosslinker->{'name'}'/></td><td><input type='text' name='setting1' size='10' maxlength='20' value='$crosslinker->{'setting1'}'/></td><td><input type='text' name='setting2' size='10' maxlength='20' value='$crosslinker->{'setting2'}'/></td><td><input type='text' name='setting3' size='10' maxlength='50' value='$crosslinker->{'setting3'}'/></td><td><select name='setting4'><option>deuterium</option><option>carbon-13</option><option>none</option></select></td><td><input type='text' name='setting5' size='10' maxlength='20' value='$crosslinker->{'setting5'}'/></td><td><input class='btn btn-primary' type='submit' value='Save' /></td></tr>";
        }
        print
"</table><input type='hidden' name='type' value='crosslinker'/><input type='hidden' name='id' value='$row_id'/><input type='hidden' name='confirmed' size='10' maxlength='10' value='yes'/></form>";
    } elsif ($query->param('confirmed') eq 'yes') {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;
        update_conf(
                    $dbh,                      $query->param('type'),
                    $query->param('name'),     $query->param('setting1'),
                    $query->param('setting2'), $query->param('setting3'),
                    $query->param('setting4'), $query->param('setting5'),
                    $row_id
        );
        print "<p>Setting edited return to <a href='settings.pl?page="
          . $query->param('type')
          . "s'>previous page?</a></p>";

    }
} elsif ($query->param('type') eq 'fixed_mod') {
    if (!defined $query->param('confirmed')) {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;

        my $fixed_mods = get_conf_value($dbh, $row_id);
        print '<form method="POST" enctype="multipart/form-data" action="settings_edit.pl" >';
        print "<h2>Fixed Modifications</h2>";
        print
"<table class='table table-striped'><tr><td>ID</td><td>Residue</td><td>Mass</td><td>Description</td><td>Default</td><td>Edit/Delete</td></tr>";

        while ((my $fixed_mod = $fixed_mods->fetchrow_hashref)) {
            my $checked;
            if ($fixed_mod->{'setting3'} == 0) {
                $checked = '';
            } else {
                $checked = 'checked="checked"';
            }
            print
"<tr><td>$row_id</td><td><input type='text' name='name' size='10' maxlength='20' value='$fixed_mod->{'name'}'/></td><td><input type='text' name='setting1' size='10' maxlength='10' value='$fixed_mod->{'setting1'}'/></td><td><input type='text' name='setting2' size='10' maxlength='1' value='$fixed_mod->{'setting2'}'/></td><td><input type='checkbox' name='setting3'  value='1' $checked /></td><td><input class='btn btn-primary' type='submit' value='Save' /></td></tr>";
        }
        print
"</table><input type='hidden' name='type' value='fixed_mod'/><input type='hidden' name='id' value='$row_id'/><input type='hidden' name='confirmed' size='10' maxlength='10' value='yes'/></form>";
    } elsif ($query->param('confirmed') eq 'yes') {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;
        my $checked;
        if (!defined $query->param('setting3')) {
            $checked = 0;
        } else {
            $checked = 1;
        }
        update_conf($dbh, $query->param('type'), $query->param('name'),
                    $query->param('setting1'),
                    $query->param('setting2'),
                    $checked, 0, 0, $row_id);

        print "<p>Setting edited return to <a href='settings.pl?page="
          . $query->param('type')
          . "s'>previous page?</a></p>";

    }
} elsif ($query->param('type') eq 'dynamic_mod') {
    if (!defined $query->param('confirmed')) {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;

        my $dynamic_mods = get_conf_value($dbh, $row_id);
        print '<form method="POST" enctype="multipart/form-data" action="settings_edit.pl" >';
        print "<h2>Dynamic Modifications</h2>";
        print
          "<table class='table table-striped'><tr><td>ID</td><td>Name</td><td>Mass</td><td>Residue</td><td>Default?</td><td>Edit/Delete</td></tr>";

        while ((my $dynamic_mod = $dynamic_mods->fetchrow_hashref)) {
            my $checked;
            if ($dynamic_mod->{'setting3'} == 0) {
                $checked = '';
            } else {
                $checked = 'checked="checked"';
            }
            print
"<tr><td>$row_id</td><td><input type='text' name='name' size='10' maxlength='20' value='$dynamic_mod->{'name'}'/></td><td><input type='text' name='setting1' size='10' maxlength='10' value='$dynamic_mod->{'setting1'}'/></td><td><input type='text' name='setting2' size='10' maxlength='1' value='$dynamic_mod->{'setting2'}'/></td><td><input type='checkbox' name='setting3'  value='1' $checked /></td><td><input class='btn btn-primary' type='submit' value='Save' /></td></tr>";
        }
        print
"</table><input type='hidden' name='type' value='dynamic_mod'/><input type='hidden' name='id' value='$row_id'/><input type='hidden' name='confirmed' size='10' maxlength='10' value='yes'/></form>";
    } elsif ($query->param('confirmed') eq 'yes') {
        my $row_id = $query->param('id');
        my $dbh    = connect_conf_db;
        my $checked;
        if (!defined $query->param('setting3')) {
            $checked = 0;
        } else {
            $checked = 1;
        }

        update_conf($dbh, $query->param('type'), $query->param('name'),
                    $query->param('setting1'),
                    $query->param('setting2'),
                    $checked, 0, 0, $row_id);

        print "<p>Setting edited return to <a href='settings.pl?page="
          . $query->param('type')
          . "s'>previous page?</a></p>";

    }
}

print_page_bottom_bootstrap;
exit;
