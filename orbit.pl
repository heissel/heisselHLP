#!/usr/bin/perl

use diagnostics;
use warnings;
use Math::Trig;
use Getopt::Std;

# inputs the number of points, Period and Eccentricity of an orbit and outputs the eccentric anomaly
# in equal increments of time over one complete orbit

getopts('n:p:e:t:w:k:g:');

if ($opt_n) {
    $num = $opt_n;
} else {
    print "Number of points: ";  $num = <STDIN>;
}
if ($opt_p) {
    $p = $opt_p;
} else {
    print "Period:           ";  $p = <STDIN>;
}
if ($opt_e) {
    $e = $opt_e;
} else {
    print "Eccentricity:     ";  $e = <STDIN>;
}
if ($opt_t) {
    $pat = $opt_t;
} else {
    print "Periastron time:  ";  $pat = <STDIN>;
}
if ($opt_w) {
    $w1 = $opt_w;
} else {
    print "omega:            ";  $w1 = <STDIN>;
}
if ($opt_k) {
    $k1 = $opt_k;
} else {
    print "RV amplitude:     ";  $k1 = <STDIN>;
}
if ($opt_g) {
    $gam = $opt_g;
} else {
    print "System velocity:  ";  $gam = <STDIN>;
}
chomp( $pat, $num, $p, $e, $w1, $k1, $gam );

$deltat = $p / $num;
$count = $num * 2;
$w1 = $w1 / (2 * pi);

$outfile = "data_" . $p . "_" . $e . "_" . $w1 . "_" . $k1 . "_" . $num;
open OUT, ">$outfile" or die "askjer364wer";

$v = 0;  $t = $pat;

for ($i = 0; $i < $count; $i++) {
    $m = 2 * pi * ( $i / $num + $pat / $p );
    $v = $v + 2 * pi / $num + 2 * pi * $pat / $p;
    $diff = 1.0;

    while ($diff > 0.00001) {
	$vold = $v;
	$v = $m + $e * sin($v);
	$diff = abs( $v - $vold );#    print "$i ::: v = $v,  diff = $diff\n";
    }
    $y = $k1 * ($e * cos($w1) + cos( $v + $w1 ) ) + $gam;

    print OUT "$v  $t  $y\n";

    $t = $t + $deltat;

}

close OUT;
