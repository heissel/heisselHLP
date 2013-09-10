#!/usr/bin/perl  -I/home/tdall/Execs

#use diagnostics;
#use warnings;

# take a fits spectrum (1D only for now...), range in wavelength and write
# two-column ascii files with that section of the spectrum

use Getopt::Std;
use Astro::FITS::CFITSIO;
#use Math::Trig;
#use Carp;

require "utils.pl";

getopts('u:l:');
unless ($opt_u && $opt_l) {
    die "error: supply -l and -u limits";
}

foreach $fitsfile (@ARGV) {

    $stem = find_stem_of_fits( $fitsfile );
    $ascfile = $stem . ".asc";

    @x = ();  @y = ();

    $x = \@x; $y = \@y;
    ($x, $y) = read_fits_spectrum($fitsfile);
    @x = @$x; @y = @$y;

    open ASC, ">$ascfile" or die "could not open $ascfile";
    
    $num = @x;
    
    for ($i = 0; $i < $num; $i++) {
	next if $x[$i] < $opt_l;
	last if $x[$i] > $opt_u;
	print ASC "$x[$i]   $y[$i]\n";
    }

    close ASC;

}
