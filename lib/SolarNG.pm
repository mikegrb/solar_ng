package SolarNG;
use Mojo::Base 'Mojolicious';

use DateTime;
use SolarNG::Util;

sub startup {
  my $self = shift;
  SolarNG::Util->startup($self);

  my $r = $self->routes;

  $r->get('/graphs/:date')->to('graphs#graphs');
  $r->get('/day/:date')->to('day#day');
  $r->get('/month/:date')->to('month#month');
  $r->get('/year/:date')->to('year#year');

  $r->get('/' => sub {
    shift->redirect_to( '/day/' . DateTime->now->ymd );
  });
}

1;
