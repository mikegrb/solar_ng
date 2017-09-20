package SolarNG::Controller::Graphs;
use Mojo::Base 'Mojolicious::Controller';

use SolarNG::View::DayGraph;
use SolarNG::View::MonthGraph;
use SolarNG::View::YearGraph;

sub graphs {
  my $c = shift;

  if ( $c->stash('date') =~ m/(\d{4}-\d{2}-\d{2})/ ) {
    $c->render(
      data   => SolarNG::View::DayGraph->generate( $c->dbh, $1 ),
      format => 'png',
    );
  }
  elsif ( $c->stash('date') =~ m/(\d{4}-\d{2})/ ) {
    $c->render(
      data   => SolarNG::View::MonthGraph->generate( $c->dbh, $1 ),
      format => 'png',
    );
  }
  elsif ( $c->stash('date') =~ m/(\d{4})/ ) {
    $c->render(
      data   => SolarNG::View::YearGraph->generate( $c->dbh, $1 ),
      format => 'png',
    );
  }
  else {
    $c->render( text => "Say wha?" );
  }

}

1;
