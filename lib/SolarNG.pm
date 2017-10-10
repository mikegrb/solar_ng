package SolarNG;
use Mojo::Base 'Mojolicious';

use DateTime;
use SolarNG::Util;

sub startup {
  my $self = shift;
  SolarNG::Util->startup($self);

  my $r = $self->routes;

  $r->get('/graphs/:date')->to('graphs#graphs');
  $r->get('/day/:date')->to('day#date');
  $r->get('/month/:date')->to('month#month');
  $r->get('/year/:date')->to('year#year');

  $r->get('/' => sub {
    shift->redirect_to( '/day/' . ( $self->dbh->selectrow_array('SELECT MAX(`date`) FROM `history`') ) )
  });

  $r->get('/json' => sub {
      shift->render( json => { date => $self->dbh->selectrow_array('SELECT MAX(`date`) FROM `history`') } )
  });
}

1;
