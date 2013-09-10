#!/usr/bin/perl

# takes .frq files and produces files ready to plot with eg. IDL, containing
# one row of a quantity like a(h_b)/a(v)  or  phi(b-y)-phi(y) etc.
# needs to have two file names on the command line.
# the .frq files are created by ix.rfreq

use Getopt::Std;
use Math::Trig;

getopts('d:apw:z:') || &bail;          # opt_d is starting point (in degrees) of 360 degree range in phi1-phi2
                                     #        defaults to 0
                                     # opt_a : make amplitude ratio (divide numbers)
                                     # opt_p : make phase difference (subtract numbers)
                                     # opt_w is the file name of result-file, defaults to <file1>-div<file2>.
                                     # opt_z is zeropoint to add to the phase diff.

($file1, $file2) = @ARGV;

bail_out() unless ($file2);    # check that both names are there

if ($opt_w) {
    $out_name = $opt_w;
} else {
    $out_name = "$file1-div-$file2" if $opt_a;
    $out_name = "$file1-min-$file2" if $opt_p;
}
if ($opt_a) {
    $col = 1;
} elsif ($opt_p) {
    $col = 2;
    $zer_pt = 0;
    if ($opt_d) {
	$zero_pt = $opt_d;
    }
    $offset = 0;
    if ($opt_z) {
	$offset = $opt_z;
    }
} else {
    bail_out();    # need either -a or -p
}

open IN1, "<$file1" or die "bla!";
open IN2, "<$file2" or die "bla!!";
open OUT, ">$out_name" or die "bla!!!";

while ($in = <IN1>) {
    $in =~ s/^\s+//s;
    ($in[0], $in[1], $in[2], $err1) = split /\s+/, $in;
    push @in1, $in[$col];
    push @frq, $in[0];
    # need to make err on phases if $opt_p:
    $err1 = atan( $err1/$in[1] ) * (180/pi) if $opt_p;
    push @err1, $err1;
    $in = <IN2>;
    $in =~ s/^\s+//s;
    ($in[0], $in[1], $in[2], $err2) = split /\s+/, $in;
    push @in2, $in[$col];
    # need to make err on phases if $opt_p:
    $err2 = atan( $err2/$in[1] ) * (180/pi) if $opt_p;
    push @err2, $err2;
}
$num = @in2;

close IN1;
close IN2;

for ( $i = 0; $i < $num; $i++ ) {
    if ($opt_a) {
	$res = $in1[$i] / $in2[$i];
	$err = $res * ( $err1[$i]**2 / $in1[$i]**2 + $err2[$i]**2 / $in2[$i]**2 )**0.5;
    } else {
	$res = $in1[$i] - $in2[$i] + $offset;
	if ($res < $zero_pt) {
	    $res += 360;
	}
	if ($res > $zero_pt + 360) {
	    $res -= 360;
	}
	$err = ( $err1[$i]**2 + $err2[$i]**2 )**0.5;
    }
    print "$frq[$i]  $res  $err\n";
    write OUT;
}

close OUT;

format OUT =
@##.####   @##.#####  @##.###
$frq[$i], $res, $err
.

sub bail_out {
    print "\nUsage:  makeplotfile.pl ( -a | -p ) [-d zero_pt] <file1> <file2>\n";
    exit;
}
