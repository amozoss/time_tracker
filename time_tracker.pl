#!/usr/bin/perl


# This file is part of time_tracker.
# 
# time_tracker is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
# 
# time_tracker is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with time_tracker.  See gpl3.txt. If not, see <http://www.gnu.org/licenses/>.
#

######################################################
#
# time_tracker
#        time_tracker eases the pain of using several charge numbers
#        per day and switching between them. Enter the Charge number
#        and an optional description and time_tracker takes care of the
#        rest.
#
#   Author: Dan Willoughby
#
#   Usage: time_tracker -h to display the help screen
#
#######################################################
 
use strict;
use warnings;
use Data::Dumper;
use JSON::XS;
use POSIX qw/strftime/;
use Getopt::Std;
use Time::Piece;
use Time::Seconds;

 
# Global variables (not sure how to use format and write without globals)
my $reportHours;
my $reportChargeCode;
my $reportDescription;
my $reportListIndex;
my $filename = "/home/dwilloughby/home/training/time/time_card";
 
 
my $timeCard;# Stores each days data
my $time; # stores times of each day
my $chargeCode;
my $description;
my $chargeCodeList; # List of recently used charge codes
 
####################
# Program options
####################
my %opts;
getopts('bcdehrsuvw', \%opts);
 
print usage() and exit(0) if $opts{'h'};
my $change = $opts{'c'};
my $delete = $opts{'d'};
my $edit = $opts{'e'};
my $report = $opts{'r'};
my $stop = $opts{'s'};
my $update = $opts{'u'};
my $verbose = $opts{'v'};
my $weeklyReport = $opts{'w'};

# Report formatting
$~ = 'REPORT';
$^ = 'REPORT_TOP';
 
#################
# Program
#################
 
$timeCard = read_from_file();
$time = load_time_at_date(get_current_date());
$chargeCodeList = get_charge_code_list();
 
print Dumper $timeCard and exit if $opts{'b'};
 
if ($report) {
  no warnings 'uninitialized';
  if ($ARGV[0] =~ /^\d{8}$/) {
    $time = load_time_at_date($ARGV[0]);
    print "Report for $ARGV[0]\n";
    generate_report();
  }
  else {
    generate_report();
  }
  exit();
}
elsif ($weeklyReport) {
  no warnings 'uninitialized';
    if ($ARGV[0] =~ /^\d{8}$/) {
      my $format = '%Y%m%d';
      my $currentDate = $ARGV[0];
      my $count = 0; # count to 7 days
          print "$count ";
        do {
          print "\n$currentDate\n";
          $time = load_time_at_date($currentDate);
          generate_report();
          $currentDate = Time::Piece->strptime($currentDate, $format);
          $currentDate = $currentDate - ONE_DAY;
          $currentDate = $currentDate->ymd('');
 
          $count++;
        } while ($count < 7);
 
     $time = load_time_at_date($ARGV[0]);
     print "Report for $ARGV[0]\n";
     generate_report();
   }
   else {
     generate_report();
   }
   exit();
}
elsif ($edit) {
  $chargeCode = $ARGV[0];
  my $amount = $ARGV[1];
  get_charge_code_from_list($chargeCode);
  edit_entry($chargeCode, $amount);
  write_to_file ($timeCard);
  generate_report();
  exit();
}
elsif ($change) {
  my $oldChargeCode = $ARGV[0];
  my $newChargeCode = $ARGV[1];
  $oldChargeCode = get_charge_code_from_list($oldChargeCode);
  $newChargeCode = get_charge_code_from_list($newChargeCode);
  change_entry($oldChargeCode, $newChargeCode);
  write_to_file ($timeCard);
  generate_report();
  # if the deleted charge code was the last entry,don't exit and prompt the user to enter another charge code
  if ($oldChargeCode ne $$time{"LAST"}) {
    exit();
  }
}
elsif ($delete) {
  $chargeCode = $ARGV[0];
  get_charge_code_from_list($chargeCode);
  delete_entry($chargeCode);
  write_to_file ($timeCard);
  # if the deleted charge code was the last entry,don't exit and prompt the user to enter another charge code
  if ($chargeCode ne $$time{"LAST"}) {
    exit();
  }
}
elsif ($stop) {
  update_last_entry($time);
  write_to_file ($timeCard);
  exit();
}
elsif ($update) {
  $chargeCode = $$time{"LAST"};
  update_last_entry($time);
  write_to_file($timeCard);
  print "\n*******Time is stopped********\n" if !defined $chargeCode;
  generate_report();
 
  exit;
}
 
$~ = 'CHARGE_CODE';
$^ = 'CHARGE_CODE_TOP';
 
my $i = 0;
foreach my $element (@$chargeCodeList) {
  $reportChargeCode = $element;
  $reportListIndex = $i;
  $i++;
  write;
}
print "\n";
# Change back to report writer
$~ = 'REPORT';
$^ = 'REPORT_TOP';
$- = 0; # force another header
 
print "Enter charge code or QR: ";
$chargeCode = <STDIN>;
chomp $chargeCode;
$chargeCode = uc $chargeCode;
add_charge_code_to_list($chargeCode);
get_charge_code_from_list($chargeCode);
 
print "Enter work description: ";
$description = <STDIN>;
chomp $description;
 
my %record = ();
%record = ( 'text' => $description, 'start' => time(), 'end' => time() );
 
update_last_entry($time);
 
# Push the record into the chargeCode array
push @{$$time{$chargeCode}}, \%record;
print "\nNow charging: $chargeCode";
 
# Save the last for modification later
write_to_file ($timeCard);
 
generate_report();
 
###############
# Sub routines
################
sub get_charge_code_list {
  my @chargeCodeList = ();
  if (defined $$timeCard{"codes"} ) {
    print "Charge Code list defined\n" if $verbose;
    $chargeCodeList = $$timeCard{"codes"};
    return $chargeCodeList;
  }
  else {
    print "Charge Code list not defined\n" if $verbose;
    $$timeCard{"codes"} = \@chargeCodeList;
    return \@chargeCodeList;
  }
}
 
# assumes get_charge_code_list has been called previously and $chargeCodeList contains the array
sub add_charge_code_to_list {
  if ($_[0] =~ m/^\d{1,2}$/) {
    print "Reading in ChargeCode\n" if $verbose;
  }
  else {
    my $cc = $_[0];
 
#determine if code is in the array
    my $exists = 0;
    foreach (@$chargeCodeList) {
      if ($cc eq $_) {
        $exists = 1;
      }
    }
    if (!$exists) {# charge code doesn't exist in list
      push $chargeCodeList, $cc;
    }
  }
}
 
# assumes get_charge_code_list has been called previously and $chargeCodeList contains the array
sub get_charge_code_from_list {
  my $count = 0 + @$chargeCodeList;
 
  if ($_[0] =~ m/^\d{1,2}$/) { # Check if array contains a charge code otherwise die
 
    if ($_[0] < $count) {
      $chargeCode = @$chargeCodeList[$_[0]];
    }
    else {
      die "Charge Code list does not contain an element at $_[0]\n";
    }
  }
  return $chargeCode;
}
 
sub get_current_date {
  return strftime "%Y%m%d", localtime;
}
 
sub load_time_at_date {
  my %time = ();
  my $date = $_[0]; # load first parameter
 
  if (defined $$timeCard{$date} ) {
    print "$date is defined\n" if $verbose;
    $time = $$timeCard{$date};
    return $time;
  }
  else {
    print "$date is not defined. Creating a new one.\n" if $verbose;
    $$timeCard{$date} = \%time;
    return \%time;
  }
 
}
 
sub edit_entry {
  my $editChargeCode = $_[0];
  my $amount = $_[1];
  my %editRecord = ();
  my $editTime = time() + ($amount*3600);
  %editRecord = ( 'text' => $description, 'start' => time(), 'end' => $editTime);
# Push the record into the beginning of chargeCode array
  unshift @{$$time{$editChargeCode}}, \%editRecord;
  print "\nEditing $editChargeCode for $amount\n";
}
 
sub change_entry {
  my $deleteEntry = $_[0];
  my $changeEntry = $_[1];
  my $deletedEntry = delete $$time{$deleteEntry};
# Push the record into the chargeCode array
  foreach (@{$deletedEntry}) {
    push @{$$time{$changeEntry}}, $_;
  }
  print "Changing $deleteEntry to $changeEntry\n";
}
 
sub delete_entry {
  my $deleteEntry = $_[0];
  my $deletedEntry = delete $$time{$deleteEntry};
  print "Deleting $deleteEntry\n";
}
 
sub generate_report {
  print "\n";
  my $totalHours;
 
  foreach my $key_top ( keys %$time )
  {
    my $hours;
    my $array = $$time{$key_top};
    $reportDescription = "";
 
    if (ref($array) eq 'ARRAY' ) {
      for my $index (@$array)
      {
        my $partial = ($$index{"end"} - $$index{"start"})/3600;
        $hours += $partial;
        print "Partial hour: $partial\n" if $verbose;
        no warnings 'uninitialized';
        if ($$index{"text"} ne '') {
          $reportDescription .= $$index{"text"} . "/";
        }
 
      }
   
      $totalHours += $hours;
      $reportHours = $hours;
      $reportChargeCode = $key_top;
      write ;
 
    }
  }
  my $timeNeeded = (10 - $totalHours)*3600;
  my $finishTime = time + $timeNeeded;
 
  $finishTime = scalar strftime("%H:%M:%S", localtime ($finishTime));
 
  print "\nTotal: $totalHours | Go Home: $finishTime\n";
 
}
 
sub update_last_entry {
  my $time = shift;
  my $last_entry = $$time{"LAST"};
  print "Last entry: $last_entry\n" if defined $last_entry;
 
  # update end time of last entry
  if (defined $last_entry) {
    my $arr = $$time{$last_entry};
    my $editHash = $$arr[-1];
    $$editHash{"end"} = time();
  }
  $$time{"LAST"} = $chargeCode;
}
 
sub read_from_file {
  if (-e $filename) {
    #open my $fh, "<", $filename or die "can't open time card";
    #my %data = ();
    #{
      #local $/; # slurp mode
      #$data = eval <$fh>;
      #die "can't recreate time card data from $filename: $@" if $@;
    #}
    #close $fh;
    #return $data;
   
    my $json;
    {
      local $/; #Enable 'slurp' mode
      open my $fh, "<", $filename;
      $json = <$fh>;
      close $fh;
    }
    return decode_json($json);
 
  }
  else {
    my %timeCard = ();
    return \%timeCard;
  }
}
 
sub write_to_file {
  my $data  = shift;
  open my $fh, ">", $filename;
  print $fh JSON::XS->new->pretty(1)->encode($data);#Data::Dumper->Dump([$data],['*DATA']);
  close $fh;
}
 
 
sub usage {
                return '
    Description:
 
        time_tracker eases the pain of using several charge numbers per day
        and switching between them. Enter the Charge number and an optional
        description and time_tracker takes care of the rest.
 
    Usage: time_tracker [-bcdehrsuv]
 
    options (only use one at a time except -v):
 
 
        -b        Displays all data that has been stored. Useful for debugging.
 
        -c <old cn> <new cn>
                  Changes the time charged to <old cn> to <new cn>. <old cn> is
                  replaced by <new cn>. Where <old cn> is the old charge number
                  and <new cn> is the new charge number. Works with QR numbers.
 
        -d <cn>   Deletes the charge number entry for the current day. Where <cn>
                  is the charge number. Works with QR numbers.
 
 
        -e <cn> <amount>
                  Edits the charge numbers total tracked time, where <cn> is the
                  charge number. When <amount> is positive it will add to the total
                  tracked time, and subtract when negative. Works with QR numbers.
 
 
                  EX. "time_tracker -e 1702 -1.2" subtracts 1.2 from 1702 total time.
 
        -h        Displays help menu.
 
        -r <date> Generates and displays a report for the specified <date>. If
                  no <date> is specified the current date will be used.
                  <date> is entered YYYYmmdd (EX. 20130705 for July 5, 2013).
 
        -s        Stops time being tracked. Useful for lunch breaks or the end
                      of the day.
             
        -u        Generates and displays an updated report for the current time
                      of the current day.
 
        -v        Displays verbose output.
        
        -w <date> Generates and displays daily reports from the specified <date> to
                  the previous 6 days.
                  If no <date> is specified the current date will be used.
                  <date> is entered YYYYmmdd (EX. 20130705 for July 5, 2013).

 
        ';
}
 
format CHARGE_CODE_TOP =
QR Charge Code
== ==============
.
 
format CHARGE_CODE =
@> @<<<<<<<<<<<<<
$reportListIndex, $reportChargeCode
.
 
format REPORT_TOP =
Charge Code   Hours    Description
============= ======== ===============================================
.
 
format REPORT =
@<<<<<<<<<<<< @<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$reportChargeCode, $reportHours, $reportDescription
.
