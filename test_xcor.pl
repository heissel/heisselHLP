#!/usr/bin/perl -I/home/tdall/Execs

#use diagnostics;
#use warnings;
# input VALD line list, wavelength range and resolution, make a HARPS-style
# mask-file and if specified, a fits file.
#use strict;
#use Getopt::Std;
use Astro::FITS::CFITSIO;

require "utils.pl";

($spec, $mask) = @ARGV;

($x, $yspec) = read_fits_spectrum( $spec );
($x, $ymask) = read_fits_spectrum( $mask );

($ccf, $dist) = xcor( $yspec, $ymask, 0.1, 100);


@x = @$dist;
@ccf = @$ccf;

$n = @ccf;
open OUT, ">test.asc";
for ($i = 0; $i < $n; $i++) {
    print OUT "$x[$i]  $ccf[$i]\n";
}
close OUT;
