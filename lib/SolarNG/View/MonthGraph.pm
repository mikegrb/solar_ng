package SolarNG::View::MonthGraph;

use strict;
use warnings;

use DateTime;
use POSIX 'strftime';
use Chart::Clicker;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Marker;
use Chart::Clicker::Axis::DateTime;
use Chart::Clicker::Renderer::StackedBar;

sub generate {
  my ($package, $dbh, $date) = @_;
  my ($year, $month) = split /-/, $date;

  $date  = DateTime->new( year => $year, month => $month );
  my $title = $date->strftime('%B %Y');

  my $sth = $dbh->prepare(q{
    SELECT strftime('%s',`date`) AS `date`,
      SUM(`solar`)       AS `solar`,
      SUM(`consumption`) AS `consumption`
    FROM `history`
    WHERE `date` LIKE ?
    GROUP BY `date`
    ORDER BY `date` ASC;
  });
  $sth->execute("$year-$month-%");

  my ( $month_solar, $month_consumption ) = ( 0, 0 );
  my @data;

  # this ones a bit of a dogey kluge but it gets the job done
  # we check if dow is a weekend, if it's a sat we throw it's epoch in sat
  # if it's a sun, we append an array of [ sat, sun ] epochs if we have the prior sat,
  # else just [sun]... markers will hold the Chart::Clicker::Data::Marker objs later
  my $weekends = { ranges => [], markers => [] };

  while ( my $row = $sth->fetchrow_hashref ) {
    $row->{$_} /= 1000 for (qw(consumption solar));
    my $net = $row->{consumption} - $row->{solar};
    $month_solar       += $row->{solar};
    $month_consumption += $row->{consumption};
    my ($deficit, $surplus, $solar);
    if ($net > 0) {
      $deficit = $net;
      $surplus = 0;
      $solar = $row->{solar};
    }
    else {
      $deficit = 0;
      $surplus = $net * -1;
      $solar = $row->{solar} + $net;
    }
    push @data, [ $row->{date}, $solar, $row->{consumption}, $net, $deficit, $surplus ];

    # weekend check, see explanation above
    my $dow = DateTime->from_epoch( epoch => $row->{date} )->day_of_week;
    if ( $dow >= 6 ) {
      if ( $dow == 7 ) {
        push @{ $weekends->{ranges} },
          [ grep { defined $_ } ( delete $weekends->{sat}, $row->{date} ) ];
      }
      else {
        $weekends->{sat} = $row->{date};
      }
    }
  }

  # last day of month was a sat?
  push @{ $weekends->{ranges} }, [ $weekends->{sat} ] if defined $weekends->{sat};

  my $month_net = sprintf('%.2f', $month_consumption -  $month_solar );
  my $sub_title = "Solar $month_solar kWh, Consumed $month_consumption kWh, Grid $month_net kWh";

  my $cc = Chart::Clicker->new(width => 900, height => 400, format => 'png');
  $cc->color_allocator->add_to_colors( Graphics::Color::RGB->from_hex_string('#377eb8') );
  $cc->color_allocator->add_to_colors( Graphics::Color::RGB->from_hex_string('#4daf4a') );
  $cc->color_allocator->add_to_colors( Graphics::Color::RGB->from_hex_string('#e41a1c') );

  my %serieses;
  my %name_for = ( solar => 'Consumption from Solar', surplus => 'Excess Solar', deficit => 'Consumption from Grid' );
  $name_for{deficit} .= " $month_net kWh";

  for my $series (qw{ solar deficit surplus } ) {
    $serieses{ $series } = Chart::Clicker::Data::Series->new( name => $name_for{$series} );
  }

  my (@ticks, @tick_labels);
  for my $row (@data) {
    push @ticks, $row->[0];
    push @tick_labels, strftime('%m/%d', gmtime $row->[0]);
    $serieses{solar}->add_pair( $row->[0], $row->[1] );
    $serieses{deficit}->add_pair( $row->[0], $row->[4] );
    $serieses{surplus}->add_pair( $row->[0], $row->[5] );
  }

  my $ds = Chart::Clicker::Data::DataSet->new( series => [ $serieses{solar}, $serieses{surplus}, $serieses{deficit} ] );
  $cc->add_to_datasets( $ds );

  for my $weekend (@{ $weekends->{ranges} }) {
    push @{ $weekends->{markers} },
      Chart::Clicker::Data::Marker->new(
        key => $weekend->[0] - 43200, # 43200 = 12 hrs padding
        ( $weekend->[1] ? ( key2 => $weekend->[1] + 43200 ) : () ),
        inside_color => Graphics::Color::RGB->new( red=>0, green=>0, blue=>0, alpha=>.2 ),
      );
  }

  my $ctx = $cc->get_context('default');
  $ctx->range_axis->label('kWh');
  $ctx->range_axis->label_font->size(16);
  $ctx->renderer(
    Chart::Clicker::Renderer::StackedBar->new(
      opacity     => .6,
      bar_padding => 2,
      bar_width   => 20
    ) );

  $ctx->add_marker($_) for @{ $weekends->{markers} };

  my $daxis = $ctx->domain_axis;
  $daxis->label('Date');
  $daxis->staggered(1);
  $daxis->tick_values( \@ticks );
  $daxis->tick_labels( \@tick_labels );
  $daxis->label_font->size(16);

  $cc->legend->font->size(18);
  $cc->title->text( "Energy for $title" );
  $cc->title->padding->bottom(5);
  $cc->title->font->size(20);

  $cc->draw;
  return $cc->rendered_data();
}

1;
