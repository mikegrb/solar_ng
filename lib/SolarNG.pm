package SolarNG;
use Mojo::Base 'Mojolicious';

use DateTime;
use SolarNG::Util;
use SolarNG::Controller::Day;

sub startup {
  my $self = shift;
  SolarNG::Util->startup($self);

  my $r = $self->routes;

  $r->get('/graphs/:date')->to('graphs#graphs');
  $r->get('/day/:date')->to('day#date');
  $r->get('/month/:date')->to('month#month');
  $r->get('/year/:date')->to('year#year');

  $r->get('/' => sub {
    my $self = shift;
    $self->redirect_to( '/day/' . latest_date($self) );
  });

  $r->get('/json' => sub {
    my $self = shift;
    $self->render( json => { date => latest_date($self) } );
  });

  $r->get('/latest.json' => sub {
    my $self = shift;
    $self->redirect_to( '/day/' . latest_date($self) . '.json' );
  });
}

sub latest_date {
  my $c = shift;
  return ( $c->dbh->selectrow_array('SELECT MAX(`date`) FROM `history` WHERE `consumption` > 0') );
}

1;
