#! /usr/bin/env perl

use 5.010;

use warnings;
use strict;

use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin/../lib");

use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;
use LWP::Simple;
use Pod::Usage;

use CSVCal::Parse;

###############
# Subroutines #
###############
sub process_reservation {
  my ($calendar,
      $offset,
      $reservation) = @_;
  my $event = Data::ICal::Entry::Event->new();
  $event->add_properties
    (
     summary => "Reservation for $reservation->{owner}"
     , dtstart => Date::ICal->new(ical => $reservation->{start}->printf('%Y%m%dT%H%M%S')
				  , offset => $offset)->ical
     , dtend => Date::ICal->new(ical => $reservation->{end}->printf('%Y%m%dT%H%M%S')
				, offset => $offset)->ical
    );
  $calendar->add_entry($event);
}

########
# Main #
########
# Parse Options
if (scalar(@ARGV) != 2) {
  pod2usage(-verbose => 1, -exitval => 1);
  exit 255;
}
my $uri = $ARGV[0];
my $offset = $ARGV[1];

my $csv_raw = get($uri) or die "Could not fetch CSV file from '$uri'";
my $reservations = CSVCal::Parse::parse_csv($csv_raw);

my $calendar = Data::ICal->new();
for my $reservation (@$reservations) {
  process_reservation($calendar, $offset, $reservation);
}

print ($calendar->as_string());

#######
# POD #
#######
=head1 NAME

csv2ical.pl: Convert simple CSV calendars to ICal format.

=head1 SYNOPSIS

csv2ical.pl URL TZOFFSET

=head1 ARGUMENTS

URL The url to the CSV file to convert. See README for format information.

TZOFFSET The Timezone offset of the CSV file (e.g. '-0500' for EST).

=cut
