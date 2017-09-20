package SolarNG::Util;

use Exporter 'import';
our @EXPORT_OK = qw(copy_row_values query_data);

use DBI;

sub startup {
  my ( undef, $app ) = @_;

  $app->helper( dbh => sub { DBI->connect('dbi:SQLite:dbname=energy.db') } );

  # view helpers
  $app->helper( year_month => sub { return substr $_[1], 0, 7 } );
  $app->helper( kwh => sub { return sprintf( '%.3f kWh', $_[1] ) } );
}

sub query_data {
  my ( $dbh, $queries, $data, @binds ) = @_;
  for my $query (@$queries) {
    my $sth = $dbh->prepare($query);
    $sth->execute(@binds);
    copy_row_values( $sth->fetchrow_hashref, $data );
  }
}

sub copy_row_values {
  my ( $row, $target ) = @_;
  for my $key ( keys %$row ) {
    $target->{$key} = $row->{$key};
  }
}

1;
