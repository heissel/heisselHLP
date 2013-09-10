#!/usr/bin/perl
# Extract time accounting information from OT xml files
# v2006.06.21 - original version
# v2006.06.22 - working version
# v2008.08.17 - add seconds to output
# v2008.08.18 - add option to show pause events
#------------------------------------------------------------------------

# OT xmls are exported regularly to: 
# /net/draco/export/data/dataproc/home/dataproc/GN-2006A-xml
# but you should probably do your own in the OT: File: Export XML: Bulk

use Getopt::Std;

getopts("d:hpv");

$nargs = $#ARGV + 1;

if ($opt_h) { usage(); }

if ($opt_d) { 
  $tyear  = substr($opt_d, 0, 4);
  $tmonth = substr($opt_d, 5, 2);
  $tday   = substr($opt_d, 8, 2);
} else {
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  $mon += 1;
  $tyear = $year;
  $tmonth = sprintf("%02i",$mon);
  $tday   = sprintf("%02i",$mday);
}
$date = $tyear."/".$tmonth."/".$tday;
if ($opt_v) { print("...Target Date: $tyear - $tmonth - $tday \n"); }

@filelist = `ls -1 *.xml`;
	      
$i = 0;

foreach $xmlfile (@filelist){
  chomp($xmlfile);
  if ($opt_v) { print("FILE: $xmlfile: \n"); }

  open (xml, $xmlfile) || die ("...could not open ",$xmlfile,"\n");

  $paramset = 0; # outside paramset container

  foreach $line (<xml>) {

    $line =~ s/^\s+//;       # strip beginning spaces
    #if ($opt_v) { print ("line:",$line); }

    if      ( $line =~ /<paramset name="event" kind="StartVisit">/ ) {
      ($x, $x, $x, $event) = split('[\"]', $line);
      if ($opt_v) { print("...$event \n"); }
      $paramset = 1;

    } elsif ( $line =~ /<paramset name="event" kind="Slew">/ ) {
      ($x, $x, $x, $event) = split('[\"]', $line);
      if ($opt_v) { print("...$event \n"); }
      $paramset = 1;

    } elsif ( $line =~ /<paramset name="event" kind="EndVisit">/ ) {
      ($x, $x, $x, $event) = split('[\"]', $line);
      if ($opt_v) { print("...$event \n"); }
      $paramset = 1;

    } elsif ( $opt_p && $line =~ /<paramset name="event" kind="PauseObserve">/ ) {
      ($x, $x, $x, $event) = split('[\"]', $line);
      if ($opt_v) { print("...$event \n"); }
      $paramset = 1;

    } elsif ( $line =~ /<paramset name="event" kind="AbortObserve">/ ) {
      ($x, $x, $x, $event) = split('[\"]', $line);
      if ($opt_v) { print("...$event \n"); }
      $paramset = 1;

    }

    if ( $paramset ) {   # inside one of the interesting paramset containers

      if ( $line =~ /<param name="timestamp"/ ) { 
	($x, $x, $x, $timestamp) = split('[\"]', $line);
	if ($opt_v) { print ("\n...timestamp = $timestamp \n"); }
	$timestamp = $timestamp / 1000.;   # looks like they use milliseconds!
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($timestamp);
	$year += 1900;
        $mon += 1;
	if ($opt_v) { print ("...time: ",$year,"-",$mon,"-",$mday," $hour:$min:$sec \n"); }

        #if ($sec > 30) { $min = $min + 1; } # round to the nearest minute
	#if ($opt_v) { print ("...time: ",$year,"-",$mon,"-",$mday," $hour:$min \n"); }

      } elsif ( $line =~ /<param name="obsid"/ ) {
	($x, $x, $x, $obsid) = split('[\"]', $line);
	if ($opt_v) { print ("...obsid = $obsid \n"); }

      } elsif ( $line =~ /<param name="reason"/ ) {
	($x, $x, $x, $reason) = split('[\"]', $line);
	if ($opt_v) { print ("...reason = $reason \n"); }

      } elsif ( $line =~ /<\/paramset>/ ) {
	
	if ($opt_v) { printf ("%4i-%02i-%02i  %02i:%02i:%02i  %-18s %s %s\n",
			      $year,$mon,$mday,$hour,$min,$sec,$obsid,$event,$reason); }

	if ( $tyear==$year && $tmonth==$mon && $tday==$mday ) {
	  if ($opt_v) { print ("...MATCH! \n"); }
          $newline[$i] = sprintf("%02i:%02i:%02i  %-18s  %s %s", $hour,$min,$sec,$obsid,$event,$reason);
	  if ($opt_v) { print ("...newline: $newline[$i] \n"); }
	  $i++;
	}

	$paramset = 0;
        $reason = "";

      }
    }
  }
  close (xml);
}

if ($opt_v) { print ("...found $i events for $date \n"); }

if ($opt_v) { print ("...sorting...\n"); }
#@sortedline = sort {$a <=> $b} @newline;
@sortedline = sort {lc $a cmp lc $b} @newline;


print ("---------- Timeline for $date ----------\n");
$i = 0;
while ($sortedline[$i]) {
  print("$sortedline[$i] \n");
  $i++;
}

print ("\n");

#------------------------------------------------------------------------

sub usage {
  print ("\n");
  print ("SYNOPSIS: \n");
  print ("       timeline.pl [options] \n\n");
  print ("DESCRIPTION \n");
  print ("       Read OT xml files and dump time accounting information.\n");
  print ("OPTIONS \n");
  print ("       -h : print this help message \n");
  print ("       -d DATE : format: 2006-06-22 \n");
  print ("       -p : include pause events \n");
  print ("       -v : Verbose debugging output \n\n");
  print ("AUTHOR \n");
  print ("       Andrew W. Stephens - Gemini Observatory \n\n");
  exit;
}

#------------------------------------------------------------------------
