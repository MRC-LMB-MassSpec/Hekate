use strict;

package Crosslinker::Config;
use base 'Exporter';


our @EXPORT = ( 'get_mods','get_conf_value', 'connect_conf_db', 'add_conf', 'get_conf', 'delete_conf', 'update_conf' );
######
#
# Config import functions
#
######

sub get_conf {
    my ( $dbh, $setting ) = @_;

    my $sql = $dbh->prepare("SELECT rowid, * FROM setting WHERE type = ?");
    $sql->execute($setting);
    return $sql;

}

sub get_conf_value {
    my ( $dbh, $rowid ) = @_;

    my $sql = $dbh->prepare("SELECT * FROM setting WHERE rowid = ?");
    $sql->execute($rowid);
    return $sql;

}

sub get_mods {

    my ($table,$mod_type  ) = @_;

    my $dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );
     my $sql = $dbh->prepare("SELECT * FROM modifications WHERE run_id = ? AND mod_type = ?");
    $sql->execute($table, $mod_type);
    return $sql;

}

sub delete_conf {
    my ( $dbh, $rowid ) = @_;

    my $sql = $dbh->prepare("DELETE FROM setting WHERE rowid = ?");
    $sql->execute($rowid);
    return $sql;

}

sub connect_conf_db {
    my $dbh = DBI->connect( "dbi:SQLite:dbname=db/config", "", "", { RaiseError => 1, AutoCommit => 1 } );

    $dbh->do(
        "CREATE TABLE IF NOT EXISTS setting (
						      type,
						      id,
						      name,
						      setting1,
						      setting2,
						      setting3,
						      setting4,
						      setting5
						      ) "
    );

    return $dbh;
}

sub update_conf {
    my ( $dbh, $type, $name, $setting1, $setting2, $setting3, $setting4, $setting5, $row_id) = @_;

    my $sql = $dbh->prepare(
        "UPDATE setting SET
						      type     = ?,
						      name     = ?,
						      setting1 = ?,
						      setting2 = ?,
						      setting3 = ?,
						      setting4 = ?,
						      setting5 = ?    
						WHERE rowid    = ?"
    );

    my $id = 0;
    $sql->execute( $type, $name, $setting1, $setting2, $setting3, $setting4, $setting5, $row_id);
}


sub add_conf {
    my ( $dbh, $type, $name, $setting1, $setting2, $setting3, $setting4, $setting5 ) = @_;

    my $sql = $dbh->prepare(
        "INSERT INTO setting 
						(
						      type,
						      id,
						      name,
						      setting1,
						      setting2,
						      setting3,
						      setting4,
						      setting5    
						 ) VALUES (?,?,?,?,?,?,?,?)"
    );

    my $id = 0;
    $sql->execute( $type, $id, $name, $setting1, $setting2, $setting3, $setting4, $setting5 );
}



1;

