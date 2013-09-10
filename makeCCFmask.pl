#!/usr/bin/perl -I/home/tdall/Execs

#use diagnostics;
#use warnings;
# input VALD line list, wavelength range and resolution, make a HARPS-style
# mask-file and if specified, a fits file.
#use strict;
use Getopt::Std;
use Astro::FITS::CFITSIO;

require "utils.pl";

# makeHPSmask.pl [-c <min_depth>] [-s <sat_limit>] [-f delta] <R> <wl1> <wl2> <VALD-list> <mask_name>
#
# -f : make a fits file of the mask, using <delta> as wavelength step.
# -c : minimum depth required for a line to be included
# -s : saturation limit; skip lines deeper than this
# -e : elements to exclude; format as e.g "H Na Ca"

#my ($opt_c, $opt_f);
my $mindepth = 0.0;
my $maxdepth = 1.0;
my ($delta, $r, $wl1, $wl2, $vald, $file, $dum);
my ($w2old, $dpold, $in);
my @in = ();
my ($dw, $w1, $w2, $outline);
my @mas = (); my @line = ();
my ($n, $i, $res);
getopts('c:f:s:e:');

if (@ARGV == 0) {
    &print_help_and_exit;
}
($r, $wl1, $wl2, $vald, $file) = @ARGV;
die "Error, mask name given was: $file\n" unless $file;
if ($opt_c) {
    $mindepth = $opt_c;
} 
if ($opt_s) {
    $maxdepth = $opt_s;
}
if ($opt_f) {
    $delta = $opt_f;
}
if ($opt_e) {
    @elem = split /\s+/, $opt_e;
}
open IN, "<$vald" or die "28ru2rerw";

$dum = <IN>;

$w2old = 0.0;
$dpold = 0.0;
$discarded = 0;
LOOP: while (chomp($in = <IN>)) {
    @in = split /,/, $in;
    next if ($in[1] < $wl1);
    last if ($in[1] > $wl2);
    next unless ($in[9] > $mindepth && $in[9] < $maxdepth);       # skip small and large lines...
    foreach $elem (@elem) {
	$test = "$elem ";
	if ($in[0] =~ $test) {
	    $discarded++;
	    next LOOP;
	}
    }
    $dw = $in[1] / $r;
    $w1 = $in[1] - $dw;
    $w2 = $in[1] + $dw;
    $outline = sprintf "%11.6f     %11.6f     %5.3f\n", $in[1] - $dw, $in[1] + $dw, $in[9]; 
    if ($w1 < $w2old && $in[9] > $dpold) {
	pop @mas;
	pop @line;
	push @mas, $outline;
	push @line, "$in[1]   $in[9]\n";
	$w2old = $w2;  $dpold = $in[9];
    } elsif ($w1 < $w2old && $in[9] < $dpold) {
	# do nothing...
    } else {
	push @mas, $outline;
	push @line, "$in[1]   $in[9]\n";
	$w2old = $w2;  $dpold = $in[9];
    }

}

open OUT, ">${file}.mas" or die "237ye7y3e3e";

$n = @mas;
for ($i = 0; $i < $n; $i++) {
    print OUT "$mas[$i]";
}

print "$n lines written to ${file}.mas\n";
print "$discarded lines of ($opt_e) discarded.\n" if $discarded;
close OUT;

# now make a spectrum
$res = ($wl2 + $wl1) / (2.0 * $r);
printf "Resolution element: %6.3f\n", $res;
printf "Wavelength step:    %6.3f\n", $delta;

# we need at least two pixels per resolution element...
if ($delta * 2.0 < $res) {
    &make_spectrum;
} else {
    print "WARNING: no spectrum made. Undersampled profile.\n";
}


sub make_spectrum {
    # @mas contains the line parameters. $wl1 and $wl2 are lambda limits, $delta is stepsize
    $numpix = int( ($wl2 - $wl1) / $delta + 0.5 ) + 1;
    print "Making $numpix pixel spectrum...";
    @yspec = (); @xspec = ();
    for ($i = 0; $i < $numpix; $i++) {
	push @yspec, 1.0;
	push @xspec, $wl1 + $delta * $i;
    }
    foreach $line (@line) {
	$line =~ s/\s+//s;
	($w1, $dp) = split /\s+/, $line; 
	# find index in @xspec, corresponding to this wavelength
	$lower = int( ($w1 - $wl1 - 3.0*$w1 / $r ) / $delta );
	$upper = int( ($w1 - $wl1 + 3.0*$w1 / $r ) / $delta ) + 1;
	$lower = 0 if ($lower < 0);
	$upper = $numpix - 1 if ($upper > $numpix - 1);
	for ($k = $lower; $k <= $upper; $k++) {
	    $yspec[$k] -= $dp * exp( -1.0 * ($xspec[$k]-$w1)**2 / ($w1/$r/2.0)**2 );
	}
    }
    print "Done!\n";

    write_fits_spectrum( "${file}.fits", $wl1, $delta, \@yspec );
    print "Spectrum written to ${file}.fits\n";

}


sub print_help_and_exit {
    print "makeHPSmask.pl [-c <min_depth>] [-s <sat_limit>] [-f delta] <R> <wl1> <wl2> <VALD-list> <mask_name>\n\n";
    print " -f : make a fits file of the mask, using <delta> as wavelength step.\n";
    print " -c : minimum depth required for a line to be included\n";
    print " -s : saturation limit; skip lines deeper than this\n\n";
    print "
Makes a HARPS-style CCF mask file containing line limits corresponding 
to the resolution element given (<R>). It will consider only lines in 
the interval <wl1> to <wl2> (in Angstroms), which are read from a line 
list in native VALD format. The HARPS-style file will be called 
<mask_name>.mas, while the fits spectrum (if -f is given) will be called
<mask_name>.fits. Lines in the fits file will have FWHM corresponding to
the resolution.\n\n";
    print "";
    exit;
}
