use strict;

package Crosslinker::Config;
use base 'Exporter';

our @EXPORT = ( 'get_mods', 'get_conf_value', 'connect_conf_db', 'add_conf', 'get_conf', 'delete_conf', 'update_conf' );
######
#
# Config import functions
#
# Contains functions for the loading and saving of setting to and from the configuration database
#
######

sub _retry {
    my ( $retrys, $func ) = @_;
    attempt: {
      my $result;

      # if it works, return the result
      return $result if eval { $result = $func->(); 1 };

      # nah, it failed, if failure reason is not a lock, croak
      die $@ unless $@ =~ /database is locked/;

      # if we have 0 remaining retrys, stop trying.
      last attempt if $retrys < 1;

      sleep 100/$retrys;
      $retrys--;
      redo attempt;
    }

    die "Attempts Exceeded $@";
}

sub get_conf {
   my ( $dbh, $setting ) = @_;

   my $sql = $dbh->prepare("SELECT rowid, * FROM setting WHERE type = ? ORDER BY name ASC");
   _retry 15, sub {$sql->execute($setting)};
   return $sql;

}

sub get_conf_value {
   my ( $dbh, $rowid ) = @_;

   my $sql = $dbh->prepare("SELECT * FROM setting WHERE rowid = ?");
   _retry 15, sub {$sql->execute($rowid)};
   return $sql;

}

sub get_mods {

   my ( $table, $mod_type, $dbh ) = @_;
   if (!defined $dbh) { $dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } )};
   my $sql = $dbh->prepare("SELECT * FROM modifications WHERE run_id = ? AND mod_type = ?");
   _retry 15, sub {$sql->execute( $table, $mod_type )};
   return $sql;

}

sub delete_conf {
   my ( $dbh, $rowid ) = @_;

   my $sql = $dbh->prepare("DELETE FROM setting WHERE rowid = ?");
   _retry 15, sub {$sql->execute($rowid)};
   return $sql;

}

sub connect_conf_db {
   my $dbh = DBI->connect( "dbi:SQLite:dbname=db/config", "", "", { RaiseError => 1, AutoCommit => 1 } );

   _retry 15, sub {$dbh->do(
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
   )};

   return $dbh;
}

sub update_conf {
   my ( $dbh, $type, $name, $setting1, $setting2, $setting3, $setting4, $setting5, $row_id ) = @_;

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
   _retry 15, sub {$sql->execute( $type, $name, $setting1, $setting2, $setting3, $setting4, $setting5, $row_id )};
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
   _retry 15, sub {$sql->execute( $type, $id, $name, $setting1, $setting2, $setting3, $setting4, $setting5 )};
}

1;

