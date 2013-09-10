#!/usr/bin/perl -w

use Getopt::Std;
getopts('d:');

# -d is RV in km/s

$file = shift @ARGV;

open IN, "<$file" or die "wr534rwe";
@lines = <IN>;
close IN;

open DATA, ">dop.list" or die "wrfw88883";
open ELEM, ">elm.list" or die "qdmni372332e";

foreach $line (@lines) {
#    next unless $line =~ /O/;
    $elem  = substr $line,  1,  4;
    $wl    = substr $line,  7,  9;
    $depth = substr $line, 69,  5;
    if ($opt_d && $depth =~ /\d/) {
	$wl = $wl + $opt_d * $wl /300000.0;
    }
    unless ($line =~ /Elm/) {
	$out = sprintf "%4.4s  %9.3f  %5.3f\n", $elem, $wl, $depth; 
	print $out;
	$out = sprintf "%9.3f  %5.3f\n", $wl, $depth;
	print DATA $out;
        print ELEM "$elem\n";
    }
}


close ELEM;
close DATA;
