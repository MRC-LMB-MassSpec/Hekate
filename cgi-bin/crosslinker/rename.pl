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

my $query    = new CGI;
my $table    = $query->param('table');
my $new_name = $query->param('name');

my $settings_dbh = DBI->connect("dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 });

print_page_top_fancy('Rename');

if (defined $new_name) {
    if ($new_name eq "") { $new_name = "None" }
    my $settings_sql = $settings_dbh->prepare("
					UPDATE settings 
					SET desc=?
					WHERE name=?
					");

    $settings_sql->execute($new_name, $table);
    print "<p>Return to <a href='results.pl'>results</a>?</p>";
} else {

    my $table_list = $settings_dbh->prepare(
                        "SELECT name, desc, finished FROM settings WHERE name=? ORDER BY length(name) DESC, name DESC");
    $table_list->execute($table);

    my $table_name = $table_list->fetchrow_hashref;

    print "<p>Please give new name for $table?</p>";
    print "<p><form style='margin:1em 1em 1em 4em;'>
	<input type='hidden' name='table' value='" . $table . "'/>
	New name: <input type='text' name='name' value='"
      . $table_name->{'desc'} . "' />
       <input type='submit' value='Submit'></form></p>"
}
print_page_bottom_fancy;

exit;

