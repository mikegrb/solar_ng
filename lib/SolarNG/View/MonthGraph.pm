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
  }

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

  my $ctx = $cc->get_context('default');
  $ctx->range_axis->label('kWh');
  $ctx->range_axis->label_font->size(16);
  $ctx->renderer(
    Chart::Clicker::Renderer::StackedBar->new(
      opacity     => .6,
      bar_padding => 2,
      bar_width   => 20
    ) );

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
