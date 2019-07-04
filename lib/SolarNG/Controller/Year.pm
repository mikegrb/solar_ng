package SolarNG::Controller::Year;

use Mojo::Base 'Mojolicious::Controller';
use DateTime;

use SolarNG::Util 'query_data';

sub year {
  my $c = shift;

  if ( $c->stash('date') =~ m/(\d{4})/ ) {
    $c->stash( 'date', $1 );
  }
  else {
    $c->render( text => "Say wha?" );
    return;
  }

  my ( $year, $month ) = split /-/, $c->stash('date');

  my $date = DateTime->new( year => $year, month => 1, day => 1 );


  my $month_data = $c->dbh->selectall_arrayref(
    q{
      SELECT
        SUM(`solar`) / 1000.0 AS 'gen',
        SUM(`consumption`) / 1000.0 AS 'used',
        `date`
      FROM history WHERE `date` LIKE ?
      GROUP BY substr(`date`, 0, 8)
    },
    { Slice => {} },
    $c->stash('date') . '-%',
  );

  for my $month (@$month_data) {
    my ( $y, $m, $d ) = split /-/, $month->{date};
    $month->{month} = DateTime->new( year => $y, month => $m, day => $d )->month_name;
  }

  $c->stash( month_data => $month_data );

  my @queries = (
    q{
      SELECT SUM(`solar`) / 1000.0 AS 'tot_solar', SUM(`consumption`) / 1000.0 AS 'tot_used'
      FROM history WHERE date LIKE ?
      GROUP BY substr(`date`, 0, 4)
    },
    q{
      SELECT SUM(`solar`) / 1000.0 AS 'gen_best', `date` AS 'gen_best_date'
      FROM history WHERE date LIKE ?
      GROUP BY substr(`date`, 0, 8)
      ORDER BY SUM(`solar`) DESC LIMIT 1
    },
    q{
      SELECT SUM(`solar`) / 1000.0 AS 'gen_worst', `date` AS 'gen_worst_date'
      FROM history WHERE date LIKE ? AND solar > 0
      GROUP BY substr(`date`, 0, 8)
      ORDER BY SUM(`solar`) ASC LIMIT 1
    },
    q{
      SELECT SUM(`consumption`) / 1000.0 AS 'used_best', `date` AS 'used_best_date'
      FROM history WHERE date LIKE ?
      GROUP BY substr(`date`, 0, 8)
      ORDER BY SUM(`consumption`) ASC LIMIT 1
    },
    q{
      SELECT SUM(`consumption`) / 1000.0 AS 'used_worst', `date` AS 'used_worst_date'
      FROM history WHERE date LIKE ? AND solar > 0
      GROUP BY substr(`date`, 0, 8)
      ORDER BY SUM(`consumption`) DESC LIMIT 1
    },
    q{
      SELECT (SUM(`consumption`) - SUM(`solar`)) / 1000.0 AS 'net_best', `date` AS 'net_best_date'
      FROM history WHERE date LIKE ?
      GROUP BY substr(`date`, 0, 8)
      ORDER BY (SUM(`consumption`) - SUM(`solar`)) ASC LIMIT 1
    },
    q{
      SELECT (SUM(`consumption`) - SUM(`solar`)) / 1000.0 AS 'net_worst', `date` AS 'net_worst_date'
      FROM history WHERE date LIKE ?
      GROUP BY substr(`date`, 0, 8)
      ORDER BY (SUM(`consumption`) - SUM(`solar`)) DESC LIMIT 1
    },
  );

  my $data;
  $data->{date_str}  = $date->strftime('%A, %B %e, %Y');
  $data->{month_str} = $date->strftime(' %Y');
  $data->{month}     = $date->strftime('%Y-%m');

  query_data( $c->dbh, \@queries, $data, $c->stash('date') . '-%' );

  $c->stash(%$data);
  $c->respond_to(
    json => { json => $data },
    html => sub { $c->render } );
}

1;
