package SolarNG::View::DayGraph;

use strict;
use warnings;

use Data::Printer;
use Chart::Clicker;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Marker;

sub generate {
  my ($package, $dbh, $date) = @_;

  my $sth = $dbh->prepare(q{
    SELECT SUM(`solar`), SUM(`consumption`)
    FROM history
    WHERE `date` = ?
  });
  $sth->execute( $date );
  my ($gen_total, $used_total) = $sth->fetchrow_array;

  my %labels = (
    net => "Net " . ( $used_total - $gen_total ) / 1000 . " kWh",
    solar       => "Solar " . $gen_total / 1000 . " kWh",
    consumption => "Consumption " . $used_total / 1000 . " kWh",
  );

  my $cc = Chart::Clicker->new(width => 900, height => 400, format => 'png');
  $cc->color_allocator->add_to_colors( Graphics::Color::RGB->from_hex_string('#4daf4a') );
  $cc->color_allocator->add_to_colors( Graphics::Color::RGB->from_hex_string('#e41a1c') );
  $cc->color_allocator->add_to_colors( Graphics::Color::RGB->from_hex_string('#377eb8') );

  my %serieses;
  for my $series (qw{ net solar consumption } ) {
    $serieses{$series} = Chart::Clicker::Data::Series->new( name => $labels{$series} );
  }

  $sth = $dbh->prepare(q{
    SELECT `time`, `solar`, `consumption`, consumption - solar AS `net`
    FROM history
    WHERE `date` = ?
    ORDER BY `time` ASC
  });
  $sth->execute( $date );

  my @ticks;
  my @tick_labels;
  while ( my $row = $sth->fetchrow_hashref ) {
    my ($tick) = ( $row->{time} =~ m/0?(\d+):00:00/ );
    $row->{time} =~ s/:00$//;
    push @ticks,       $tick;
    push @tick_labels, $row->{time};
    $serieses{$_}->add_pair( $tick, $row->{$_} / 1000 ) for (qw(solar consumption net));
  }

  my $ds = Chart::Clicker::Data::DataSet->new( series => [ @serieses{qw(solar consumption net)} ] );
  $cc->add_to_datasets( $ds );

  my $ctx = $cc->get_context('default');
  $ctx->range_axis->label('kWh');
  $ctx->range_axis->fudge_amount( .10 );
  $ctx->range_axis->label_font->size(16);
  $ctx->add_marker( Chart::Clicker::Data::Marker->new( value => 0 ) );

  my $axis = $ctx->domain_axis;
  $axis->label('Time');
  $axis->tick_values( \@ticks );
  $axis->tick_labels( \@tick_labels );
  $axis->staggered( 1 );
  $axis->label_font->size(16);

  $cc->legend->font->size(18);
  $cc->title->text( "Energy Consumption for $date" );
  $cc->title->font->size(20);
  $cc->title->padding->bottom(5);
  $cc->draw;
  return $cc->rendered_data();
}

1;
