package CSVCal::Parse;

use 5.010;

use warnings;
use strict;

use Exporter;

our @ISA= qw(Exporter);

# these CAN be exported.
our @EXPORT_OK = qw(parse_csv);

# these are exported by default.
our @EXPORT = qw();

use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin/../lib");

use Date::Manip;
use Text::CSV;

#############
# Constants #
#############
my $_EMPTY_RES_SLOT = '';

########################
# Internal Subroutines #
########################
sub _process_reservation {
  my ($owner,
      $startdate,
      $starttime,
      $enddate,
      $endtime) = @_;
  my $start = new Date::Manip::Date;
  my $end = new Date::Manip::Date;

  $start->parse("$startdate $starttime") and
    die ("Error parsing \"$startdate $starttime\": " . ($start->err()));

  $end->parse("$enddate $endtime") and
    die ("Error parsing \"$enddate $endtime\": " . ($end->err()));

  my %reservation =
    (
     owner => $owner
     , start => $start
     , end => $end
    );

  return \%reservation;
}

##########################
# Exportable Subroutines #
##########################
sub parse_csv {
  my ($csv_raw) = @_;

  my $csv = Text::CSV->new();

  my @rows = split("\n", $csv_raw);
  if ($#rows < 1) {
    die "Empty set of rows";
  }

  #
  # Parse header row
  #
  # need newline for parse to work correctly
  my $row = $rows[0] . "\n";

  # get fields of row
  $csv->parse($row) or die "Could not parse row '$row'";
  my @fields = $csv->fields();

  if ("Date" ne $fields[0]) {
    die "Malformed CSV file";
  }

  # Make col2time, a hash from column index to time
  my %col2time = ();
  for my $j (1 .. $#fields) {
    $col2time{$j} = $fields[$j];
  }

  #
  # Parse reservations
  #
  # Array of reservations
  my @reservations = ();
  # current reservation details
  my $res_owner = undef;
  my $res_startdate = undef;
  my $res_starttime = undef;
  for my $i (1 .. $#rows) {
    # need newline for parse to work correctly
    my $row = $rows[$i] . "\n";

    # get fields of row
    $csv->parse($row) or die "Could not parse row '$row'";
    my @fields = $csv->fields();

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
	  push (@reservations,
		_process_reservation($res_owner,
				     $res_startdate,
				     $res_starttime,
				     $date,
				     $col2time{$j}));

	  $res_owner = undef;
	  $res_startdate = undef;
	  $res_starttime = undef;
	}
      }

      # At this point, I've processed any finished reservation if it existed.

      if ($_EMPTY_RES_SLOT ne $slot_owner) {
	# Start a new reservation
	if (defined $res_owner) {
	  die "starting a new reservation with existing active one?!";
	}

	$res_owner = $slot_owner;
	$res_startdate = $date;
	$res_starttime = $col2time{$j};
      }
    }
  }

  if (defined $res_owner) {
    # If I have an active reservation here, close it at the end of the day.
    my $enddate = new Date::Manip::Date;

    $enddate->parse("$res_startdate") and
      die ("Error parsing \"$res_startdate\": " . ($enddate->err()));
    $enddate->next(undef, 0, [0, 0]) and
      die ("Error going to next midnight: " . ($enddate->err()));

    push(@reservations,
	 _process_reservation($res_owner,
			      $res_startdate,
			      $res_starttime,
			      $enddate->printf('%a, %b %d'),
			      "00:00"));
  }

  return \@reservations;
}

1;
