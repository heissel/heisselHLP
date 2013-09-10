#!/usr/bin/perl  -I/home/tdall/Execs

#use diagnostics;
#use warnings;

# assuming wavelengt unit is AA, we give binsize as absolute value in -b
#                                     OR
# we give the number of points to go into each new bin as -n

use Getopt::Std;
use Astro::FITS::CFITSIO;
# use Erics module.....?!

require "utils.pl";

getopts('b:n:s:');
&handle_options();

$oldfile = shift;

#$wl = \@wl; $y = @y;

#($wl, $y) = read_fits_spectrum($oldfile);
#@wl = @$wl;  @y = @$y;   

    open IN, "<$oldfile" or die "wwweerrddd...$!";

    while ( $in = <IN> ) {
	chomp( $in );
	$in =~ s/^\s+//s;
	@in = split /\s+/, $in;
	if ($in[0] !~ /[a-zA-Z]/ && $in[1] !~ /[a-zA-Z]/) {
	    @x = (@x, $in[0]);
	    @y = (@y, $in[1]);
	}
    }
    
    close IN;


$naxis = @y; 
$cdelt = $x[1] - $x[0];

unless ($bin) {
    $bin = $num2sum * $cdelt;
}
($effb, $x, $y) = do_rebin_spectrum($bin, \@x, \@y, $sigma);
@x = @$x;  @y = @$y;

$num = @y;
print "Went from $naxis to $num points in spectrum\n";
print "Input bin of $bin -> $effb\n";

open OUT, ">rebin.asc";
for ($i = 0; $i < $num; $i++) {
    print OUT "$x[$i]  $y[$i]\n";
}
close OUT;



###############
## subroutines
###############

sub handle_options
{
    if ($opt_b)
    {
	$bin = $opt_b;
    }
    if ($opt_n)
    {
	$num2sum = $opt_n;
    }
    if ($opt_n && $opt_b)
    {
	print "ERROR: only one of -b and -n must be given!\n";
	exit();
    }
    unless ($opt_n || $opt_b) 
    {
	print "ERROR: must specify -b or -n\n";
	exit();
    }
    if ($opt_s)   # sigmaclipping
    {
	$sigma = $opt_s;
    } else {
	$sigma = 0;
    }
}
