#!/usr/bin/perl

use diagnostics;
use warnings;
use Getopt::Std;

getopts('t:w:h');

# take as argument a filenane and an OBJECT name
#

# extTSfromLOG.pl [-w <x>] -t <targetname> <filename(s)>
#
# -w :  convert errors to weights; w = err^-x
#
# The files must be HARPS log-files (or similar) which have been 
# written using makeHARPSlog.pl
#

@dum = ();

if ($opt_h) {
    print "Usage:\n  extTSfromLOG.pl [-h] [-w <x>] -t <targetname> <filename(s)>\n\n";
    print " -w :  convert errors to weights; w = err^-x\n";
    print " -h : print this help message\n";
    print " -t : name of the target (required)\n\n";
    exit;
}

unless ($opt_t) {
    die "give target name with -t option or try -h for help.\n";
}
$object = $opt_t;

if ($opt_w) {
    $xxx = -$opt_w;
}

unless (@ARGV) {
    die "need a filename~\n";
}

@files = @ARGV;


open TS, ">$object.dat" or die "error1\n";


foreach $file (@files) {

    open IN, "<$file" or die "error2\n";

    while ( $in = <IN> ) {
	if ( $in =~ /$object/ ) {

#	    $in = substr $in, -85;
#	    $in =~ s/^\s+//s;
	    ($d1, $d2, $d3, $d1, $d2, $d3, $rv, $err, $drift, $fwhm, $bjd, @dum) = split /\s+/, $in;
	    if ($opt_w) {
		$err = $err**$xxx;
	    }
	    $err = ( $err*$err + $drift*$drift )**0.5;
	    write TS;
	}
    }

    close IN;

}

close TS;

exit;
$in = $opt_h;

format TS =
@<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<  @<<<<<<<<<<<  @<<<<<<<<<<<<<
$bjd, $rv, $err, $fwhm
.

