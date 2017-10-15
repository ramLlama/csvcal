#! /usr/bin/env perl

use 5.010;

use warnings;
use strict;
use utf8;

use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin/../lib");

use Date::Manip;
use LWP::Simple;
use Pod::Usage;
use Term::ANSIColor;

use CSVCal::Parse;

use Data::Dumper;

#############
# Constants #
#############
my $RESERVED_COLOR = 'white on_red';
my $VACANT_COLOR = 'white on_blue';
my $SCHEDULE_COLOR = 'white on_black';
my $DATE_FORMAT = '%R';
my $EXTENDED_DATE_FORMAT = '%R %a, %b %d';
my $DATE_FORMAT_LENGTH_DIFF = length(" Mon, Jan 01");

###############
# Subroutines #
###############
sub say_with_offset {
  my ($offset, $color, $msg) = @_;
  print (" " x $offset);
  print color($color);
  print $msg;
  print color('reset');
  print "\n";
}

sub print_banner {
  my ($color, $msg) = @_;

  my @lines = split("\n", $msg);

  my $max_length = 0;
  for my $line (@lines) {
    my $line_length = length($line);
    if ($line_length > $max_length) {
      $max_length = $line_length;
    }
  }

  my $box_width = $max_length + 2;

  my $num_cols = `tput cols`;
  if ($box_width > $num_cols) {
    # Too big, so no box
    for my $line (@lines) {
      my $output = $line;
      my $padding_length = $num_cols - (length($line) % $num_cols);
      if ($num_cols != $padding_length) {
	$output = $output . (" " x ($padding_length));
      }

      say_with_offset(0, $color, $output);
    }
  } else {
    # Make a box!
    my $offset = ($num_cols - $box_width) / 2;
    die "offset is negative?!" if ($offset < 0);

    say_with_offset($offset, $color, "┌" . ("─" x $box_width) . "┐");
    say_with_offset($offset, $color, "│" . (" " x $box_width) . "│");

    for my $line (@lines) {
      my $output = "│ " . $line;
      $output = $output . " "  x ($box_width - (length($line) + 1));
      $output = $output . "│";

      say_with_offset($offset, $color, $output);
    }

    say_with_offset($offset, $color, "│" . (" " x $box_width) . "│");
    say_with_offset($offset, $color, "└" . ("─" x $box_width) . "┘");
  }
}

sub active_reservation {
  my ($reservation) = @_;
  my $now = new Date::Manip::Date;

  $now->parse("now") and
    die ("Error parsing \"now\": " . ($now->err()));

  my $startcmp = $reservation->{start}->cmp($now);
  my $endcmp = $reservation->{end}->cmp($now);
  return ((1 != $startcmp) && (1 == $endcmp));
}

########
# Main #
########
# Use UTF-8 output on stdout.
binmode(STDOUT, ":utf8");

# Parse Options
if (scalar(@ARGV) != 1) {
  pod2usage(-verbose => 1, -exitval => 1);
  exit 255;
}
my $uri = $ARGV[0];

my $csv_raw = get $uri or die "Could not fetch CSV file from '$uri'";
my $reservations = CSVCal::Parse::parse_csv($csv_raw);

#
# Print reserved/vacant banner
#
my $reserved = 0;
for my $reservation (@$reservations) {
  if (active_reservation($reservation)) {
    $reserved = 1;
    print_banner($RESERVED_COLOR,
		 "RESERVED by $reservation->{owner} until " .
		 ($reservation->{end}->printf($EXTENDED_DATE_FORMAT)));

    last;
  }
}

if (!$reserved) {
  print_banner($VACANT_COLOR, "VACANT");
}

#
# Print today's schedule
#
# Get today's reservations
my $today = new Date::Manip::Date;
$today->parse("now") and
  die ("Error parsing \"now\": " . ($today->err()));
my @todays_reservations = ();
my $has_multiday = 0;
for my $reservation (@$reservations) {
  if ($today->printf('%Q') eq $reservation->{start}->printf('%Q')) {
    push(@todays_reservations, $reservation);
    if ($today->printf('%Q') ne $reservation->{end}->printf('%Q')) {
      $has_multiday = 1;
    }
  }
}

# Generate schedule
my $schedule = "Today's Reservations:\n";
for my $reservation (@todays_reservations) {
  $schedule =
    $schedule
    . $reservation->{start}->printf($DATE_FORMAT)
    . " ─ ";

  if ($today->printf('%Q') eq $reservation->{end}->printf('%Q')) {
    $schedule =
      $schedule
      . $reservation->{end}->printf($DATE_FORMAT);

    if ($has_multiday) {
      # Add alignment padding since at least one of the reservations is
      # multi-day
      $schedule =
	$schedule
	. (" " x $DATE_FORMAT_LENGTH_DIFF);
    }
  } else {
    $schedule =
      $schedule
      . $reservation->{end}->printf($EXTENDED_DATE_FORMAT);
  }

  $schedule =
    $schedule
    . " │ "
    . $reservation->{owner}
    . "\n";
}

# Print schedule
print ("\n");
print_banner($SCHEDULE_COLOR, $schedule);

######
# POD #
#######
=head1 NAME

csv2banner.pl: Display a reserved/vacant banner based on a CSV calendar.

=head1 SYNOPSIS

csv2banner.pl URL

=head1 ARGUMENTS

URL The url to the CSV file to convert. See README for format information.

=cut
