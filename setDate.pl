#!/usr/bin/perl
#*******************************************************************************
# E.S.O. - VLT project
#
# "@(#) $Id: setDate.pl,v 1.26 2005/08/15 21:55:52 vltsccm Exp $"
#
# who       when        what
# --------  ----------  ----------------------------------------------
# tdall     2005-04-17  hacked from pipe0.pl
# tdall     2005-05-30  added ENV check

use warnings;
use diagnostics;
use Getopt::Std;
getopts('q');

$dfile = "date.of.today";

if (@ARGV) {
    $date = shift @ARGV;
} elsif ($opt_q) {
    # check if date-file exists. yes: open, show and ask. no: just ask.
    print "Please enter new date ";
    if (-e $dfile) {
	open IN, "<$dfile" or die "FATAL\n";
	chomp( $date = <IN> );
	close IN;
	print "[$date] ";
    } else {
	$date = "";
    }
    chomp( $ind = <STDIN> );
    if ($ind) {
	$date = $ind;       # take the new value
    } 
} else {
    chomp( $date = `date --iso-8601` );   # defaults to currrent date
}

if ($date) {
    open OUT, ">$dfile" or die "FATAL2\n";
    print OUT "$date";
    close OUT;
} else {
    print "\n\n\nERROR... provide the date!!!!\n\n\n";
    exit;
}

print "Setting date to $date\n";


# now check the environment
unless ( $ENV{'CES_PIPE_HOME'} ) {
    print "WARNING: Your environment has not been set.\n";
    print "         Please set CES_PIPE_HOME before continuing!\n";
# the following does not work. Kept here for reference
    $ENV{'CES_PIPE_HOME'} = "/home/astro/CES/pipeWork/";
    $ENV{'CES_DATA_RAW'} = "/data/raw/";
    $ENV{'CES_DATA_REDUCED'} = "/data/reduced/";
    $ENV{'CES_PIPE_BIN'} = "/vlt/INTROOT/E3P6OPS/bin/";
}


# ______oOo______

# mentioning the variable to stop warning messages.
$ind = $opt_q;









