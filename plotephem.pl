#!/usr/bin/perl

use warnings;
use diagnostics;

$period = 0.283616;       #  [days]
$phase  = 0.12;           #  phase corresponding to the given HJD
$ephem  = 2453018.69848;  #  [HJD] 
$ephem -= $phase * $period;

$begin_date = 2453425.5;  $corr_date = "23/02/2005";  $first = 1;
$end_date   = 2453438.5;

$i0 = int $begin_date;
print "           0  3  6  9 12 15 18 21 23\n";
print "           0  3  6  9  2  5  8  1 |\n";

# plot every half of the cycle with different symbol '-' or '+'

for ($i = $i0; $i <= $end_date; $i++) {
    print "$i :: ";
    for ($j = 0; $j <= 23; $j++) {
	#calculate the phase at any given time
	$date_inc = $j / 24.0;
	$t = ($i + $date_inc - $ephem) / $period;
	$ph = $t - int $t;
	if ($ph > 0.5) {
	    print "-";
	} else {
	    print "+";
	}
#	print "$ph\n";
	
    }
    if ($first) {
	print "   $corr_date";
	$first = 0;
    }
    print "\n";
}

