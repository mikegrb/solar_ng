package SolarNG::Controller::Day;

use Mojo::Base 'Mojolicious::Controller';
use DateTime;

use SolarNG::Util 'query_data';

sub date {
  my $c = shift;

  my $json;
  if ( $c->stash('date') =~ m/(\d{4}-\d{2}-\d{2})/ ) {
    $c->stash( 'date', $1 );
    $json = $2;
  }
  else {
    $c->render( text => "Say wha?" );
    return;
  }

  my ($year, $month, $day) = split /-/, $c->stash('date');
  my $date      = DateTime->new( year => $year, month => $month, day => $day );


  my $hour_data = $c->dbh->selectall_arrayref(
    q{
      SELECT
        `solar` / 1000.0 AS 'gen',
        `consumption` / 1000.0 AS 'used',
        `time`
      FROM history WHERE `date` = ?
      ORDER BY time ASC
    },
    { Slice => {} },
    $c->stash('date'),
  );
  my $data = {
    date             => $c->stash('date'),
    hour_data       => $hour_data,
    gen_best        => 0,
    gen_worst       => 0,
    used_best       => 0,
    used_worst      => 0,
    gen_best_time   => '00:00',
    gen_worst_time  => '00:00',
    used_best_time  => '00:00',
    used_worst_time => '00:00',
  };

  my @queries = (
    q{
      SELECT SUM(`solar`) / 1000.0 AS 'tot_solar', SUM(`consumption`) / 1000.0 AS 'tot_used'
      FROM history WHERE date = ?
    },
    q{
      SELECT `solar` / 1000.0 AS 'gen_best', substr(`time`, 0, 6) AS 'gen_best_time'
      FROM history WHERE date = ?
      ORDER BY `solar` DESC LIMIT 1
    },
    q{
      SELECT `solar` / 1000.0 AS 'gen_worst', substr(`time`, 0, 6) AS 'gen_worst_time'
      FROM history WHERE date = ? AND solar > 0
      ORDER BY `solar` ASC LIMIT 1
    },
    q{
      SELECT `consumption` / 1000.0 AS 'used_best', substr(`time`, 0, 6) AS 'used_best_time'
      FROM history WHERE date = ?
      ORDER BY `consumption` ASC LIMIT 1
    },
    q{
      SELECT `consumption` / 1000.0 AS 'used_worst', substr(`time`, 0, 6) AS 'used_worst_time'
      FROM history WHERE date = ? AND solar > 0
      ORDER BY `consumption` DESC LIMIT 1
    },
    q{
      SELECT (`consumption` - `solar`) / 1000.0 AS 'net_best', substr(`time`, 0, 6) AS 'net_best_time'
      FROM history WHERE date = ?
      ORDER BY (`consumption` - `solar`) ASC LIMIT 1
    },
    q{
      SELECT (`consumption` - `solar`) / 1000.0 AS 'net_worst', substr(`time`, 0, 6) AS 'net_worst_time'
      FROM history WHERE date = ?
      ORDER BY (`consumption` - `solar`) DESC LIMIT 1
    },
  );

  $data->{date_str}  = $date->strftime('%A, %B %e, %Y');
  $data->{month_str} = $date->strftime('%B %Y');
  $data->{month}     = $date->strftime('%Y-%m');

  query_data( $c->dbh, \@queries, $data, $c->stash('date') );

  $c->stash(%$data);

  $c->respond_to(
    json => { json => $data },
    html => { sub { $c->render } } );
}

1;
