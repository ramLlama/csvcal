#! /usr/bin/env perl

use 5.010;

use warnings;
use strict;

use Date::Manip;
use LWP::Simple;
use Pod::Usage;
use Term::ANSIColor;
use Text::CSV;

#############
# Constants #
#############
my $EMPTY_RES_SLOT = '';
my $ASCII_EXCL = <<'END';
  ___         ___
 |\  \       |\  \
 \ \  \      \ \  \
  \ \  \      \ \  \
   \ \__\      \ \__\
    \|__|       \|__|
        ___         ___
       |\__\       |\__\
       \|__|       \|__|
END

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
  my ($alert, $msg) = @_;

  my $num_cols = `tput cols`;

  my $box_width = length($msg) + 2;
  if ($box_width > $num_cols) {
    # Too big, so no box

    if ($alert) {
      print color('white on_red');
      print "$ASCII_EXCL";
      print " $msg \n";
      print color('reset');
    } else {
      print color('white on_blue');
      print " $msg ";
      print color('reset');
      print "\n";
    }
  } else {
    # Make a box!

    my $offset = ($num_cols - $box_width) / 2;
    die "offset is negative?!" if ($offset < 0);

    if ($alert) {
      my $color = 'white on_red';
      say_with_offset($offset, $color, "-" x ($box_width + 2));
      say_with_offset($offset, $color, "|" . (" " x $box_width) . "|");
      say_with_offset($offset, $color, "|" . (" $msg ") . "|");
      say_with_offset($offset, $color, "|" . (" " x $box_width) . "|");
      say_with_offset($offset, $color, "-" x ($box_width + 2));
    } else {
      my $color = 'white on_blue';
      say_with_offset($offset, $color, "-" x ($box_width + 2));
      say_with_offset($offset, $color, "|" . (" " x $box_width) . "|");
      say_with_offset($offset, $color, "|" . (" $msg ") . "|");
      say_with_offset($offset, $color, "|" . (" " x $box_width) . "|");
      say_with_offset($offset, $color, "-" x ($box_width + 2));
    }
  }
}

sub currently_reserved {
  my ($owner,
      $date,
      $starttime,
      $endtime) = @_;
  my $now = new Date::Manip::Date;
  my $startdate = new Date::Manip::Date;
  my $enddate = new Date::Manip::Date;

  $now->parse("now") and
    die ("Error parsing \"now\": " . ($now->err()));

  $startdate->parse("$date $starttime") and
    die ("Error parsing \"$date $starttime\": " . ($startdate->err()));

  $enddate->parse("$date $endtime") and
    die ("Error parsing \"$date $endtime\": " . ($enddate->err()));

  my $startcmp = $startdate->cmp($now);
  my $endcmp = $enddate->cmp($now);
  return (((-1 == $startcmp) || (0 == $startcmp)) && (1 == $endcmp));
}

########
# Main #
########
# Parse Options
if (scalar(@ARGV) != 1) {
  pod2usage(-verbose => 1, -exitval => 1);
  exit 255;
}
my $uri = $ARGV[0];

my $csv_raw = get $uri or die "Could not fetch CSV file from '$uri'";
#say $csv_raw;

my $csv = Text::CSV->new();

my @rows = split("\n", $csv_raw);
my %col2time = ();
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
	  my $res_endtime = $col2time{$j};
	  if (currently_reserved($res_owner,
				 $date,
				 $res_starttime,
				 $res_endtime)) {
	    my $enddate = new Date::Manip::Date;
	    $enddate->parse("$date $res_endtime") and
	      die ("Error parsing \"$date $res_endtime\": " . ($enddate->err()));

	    print_banner(1,
			 "RESERVED by $res_owner until " .
			 ($enddate->printf('%R')));
	    exit 0;
	  }

	  $res_owner = undef;
	  $res_starttime = undef;
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

print_banner(0, "VACANT");

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
