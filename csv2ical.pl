#! /usr/bin/env perl

use 5.010;

use warnings;
use strict;

use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;
use Date::Manip;
use LWP::Simple;
use Pod::Usage;
use Text::CSV;

#############
# Constants #
#############
my $SHEETSAPI_HOST = "https://sheets.googleapis.com";
my $EMPTY_RES_SLOT = '';

###############
# Subroutines #
###############
sub process_reservation {
  my ($calendar,
      $owner,
      $date,
      $starttime,
      $endtime,
      $offset) = @_;
  my $startdate = new Date::Manip::Date;
  my $enddate = new Date::Manip::Date;

  $startdate->parse("$date $starttime") and
    die ("Error parsing \"$date $starttime\": " . ($startdate->err()));

  $enddate->parse("$date $endtime") and
    die ("Error parsing \"$date $endtime\": " . ($enddate->err()));

  my $event = Data::ICal::Entry::Event->new();
  $event->add_properties
    (
     summary => "Reservation for $owner"
     , dtstart => Date::ICal->new(ical => $startdate->printf('%Y%m%dT%H%M%S')
				  , offset => $offset)->ical
     , dtend => Date::ICal->new(ical => $enddate->printf('%Y%m%dT%H%M%S')
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

my $csv_raw = get $uri or die "Could not fetch CSV file from '$uri'";
#say $csv_raw;

my $csv = Text::CSV->new();

my @rows = split("\n", $csv_raw);
my %col2time = ();
my $calendar = Data::ICal->new();
for my $i (0 .. $#rows) {
  my $row = $rows[$i] . "\n";

  $csv->parse($row) or die "Could not parse row '$row'";
  my @fields = $csv->fields();
  if (0 == $i) {
    # Header row
    if ("Date" ne $fields[0]) {
      die "Malformed CSV file";
    }

    # Populate col2time
    for my $j (1 .. $#fields) {
      $col2time{$j} = $fields[$j];
    }
  } else {
    # This is a row of reservations
    my $res_owner = undef;
    my $res_starttime = undef;

    my $date = $fields[0];
    for my $j (1 .. $#fields) {
      my $slot_owner = $fields[$j];

      if (defined $res_owner) {
	# I have an active reservation
	if ($res_owner eq $slot_owner) {
	  # The active reservation continues
	  next;
	} else {
	  # I have a completed reservation to process
	  process_reservation($calendar,
			      $res_owner,
			      $date,
			      $res_starttime,
			      $col2time{$j},
			      $offset);

	  my $res_owner = undef;
	  my $res_starttime = undef;
	  my $res_endtime = undef;
	}
      }

      # At this point, I've processed any finished reservation if it existed.

      if ($EMPTY_RES_SLOT ne $slot_owner) {
	# Start a new reservation
	if (defined $res_owner) {
	  die "starting a new reservation with existing active one?!";
	}

	$res_owner = $slot_owner;
	$res_starttime = $col2time{$j};
      }
    }
  }
}

print ($calendar->as_string());

######
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
