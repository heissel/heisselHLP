#!/usr/bin/perl
#*******************************************************************************
# E.S.O. - VLT project
#
# "@(#) $Id: CESqueueIms.pl,v 1.26 2005/08/15 21:55:51 vltsccm Exp $"
#
# who       when        what
# --------  ----------  ----------------------------------------------
# tdall     2005-03-21  created
# tdall     2005-04-17  warning if not run on current date
#

# runs in the background and checks for new spectra ariving. 
# controls the behavior of the pipeline
# Updates the queue-files
#
# -b <bin>     <bin> must be 4 or 1
# -d <file>    <file> is the file to use for dark/back corrrection. optional,
#              since the default is the latest one.

use Getopt::Std;
getopts('b:d:');

# binning must be specified with -b
if ($opt_b) {
    if ($opt_b == 1 || $opt_b == 4) {
	`echo $opt_b > .binCES`;
    } else {
	print "ERROR: Binning must be 4 or 1.\n";
	exit;
    }
} else {
    print "ERROR: Please specify the allowed binning with -b option.\n";
    exit;
}

# if a dark/back is given, write it to a file
if ($opt_d) {
    if (-e $opt_d) {
	`echo $opt_d > .darkToUse`;
    } else {
	print "ERROR: Specified file (with -d) do not exist...\n";
	exit;
    }
}

# remove old files and check for parallel processes
if (-e ".pipePID") {
    print "ERROR: Old process might still be running. Please check.\n";
    exit();
}
`rm -f .CES*Ims`;

# get the date
open DATE, "<date.of.today" or die "FATAL:  problem with date.of.today\n";
chomp( $date = <DATE> );
close DATE;

# produce a warning if date.of.today is different from real date
$rdate = `date --iso-8601`;
unless ($date =~ /$rdate/) {
    print "Warning: Scheduler not running on today's date.\n";
}

# stores the process ID and the date this process is working on
#
$pid = `ps h -C CESqueueIms`;
$pid = substr $pid, 0, 5;
`echo $pid > .pipePID`;
`echo $date > .pipeDate`;


# prepare the queue files
`touch .CESrereduceIms`;
`touch .CEStoreduceIms`;
`touch .CESreducedIms`;


# enters the loop
$oldnum = 0;
while ($pid) {
    @files = glob("/data/raw/$date/CES_hcfa_obs*");
    $num = @files;
    if ($num != $oldnum || -s ".CESrereduceIms") {
      CHECKFILES:
	foreach $file (@files) {
	    # check if this file is in any of the queues
	    sleep 20 if (-z ".waitSIG");     # in case pipeline is accessing files...
	    $grep = `grep $file .CES*Ims`;
	    if ($grep) {
		next CHECKFILES;                      # already scheduled or has been reduced
	    } else {
		($dum, $bin) = split /\s+/, `dfits $file | fitsort -d CDELT1`;     # check binning
		next CHECKFILES unless ($bin =~ /$opt_b/);
		sleep 20 if (-z ".waitSIG");
		`echo $file >> .CEStoreduceIms`;      # to be reduced
	    }

	}
    } else {
	sleep 30;
    }
    $oldnum = $num;
}
