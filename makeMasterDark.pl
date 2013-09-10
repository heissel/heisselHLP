#!/usr/bin/perl
#*******************************************************************************
# E.S.O. - VLT project
#
# "@(#) $Id: makeMasterDark.pl,v 1.26 2005/08/15 21:55:51 vltsccm Exp $"
#
# who       when        what
# --------  ----------  ----------------------------------------------
# tdall     2005-03-19  created
# tdall     2005-04-16  checking if directory exists
#

# makeMasterDark.pl [-p path] [-h] [<date>]
#
# scans a date directory for a set of darks and biases taken with the 
# DBC template, combines the darks and biases and makes master darks and
# backs in the corresponding /data/reduced directory.
#
# Default raw data path is /data/raw, but can be changed with -p
#
# Requires that mkiraf has been issued in the directory where called from.
# login.cl must list noao, imred, ccdred as loaded from start.
#
# -----------
use Getopt::Std;
getopts('p:h');
$| = 1;

# if help requested, give it and exit
if ($opt_h) {
    &show_help;  exit();
}

# set the path
if ($opt_p) {
    $path = $opt_p . "/";
} else {
    $path = "/data/raw/";
}

# if no date given check if date-file exists. yes: open, show and ask. no: just ask.
#
&get_date;

@list = glob("$path$date/CES_hcfa_cal_darks*");
push @list, glob("$path$date/CES_hcfa_cal_back*");

&get_next_day;

push @list, glob("$path$date2/CES_hcfa_cal_darks*");
push @list, glob("$path$date2/CES_hcfa_cal_back*");

`rm -f stat.out tmp.out *.fits`;

foreach $file (@list) {
    $obname = `dfits $file | grep "HIERARCH ESO OBS NAME"`;
    if ($obname =~ /DBC/) {
	`ln -s $file .`;
    }
}


$num = `ls -1 CES_hcfa_cal_* | wc -l`;

# check that no old files are messing it up
unless ($num == 21) {
    print "ERROR:  Not the right number of files.\n";
    exit();
}

`ls -1 CES_hcfa_cal_darks* | head -5 > list-tmp-bias1`;
`ls -1 CES_hcfa_cal_darks* | head -8 | tail -3 > list-tmp-dark`;
`ls -1 CES_hcfa_cal_darks* | head -13 | tail -5 >> list-tmp-bias1`;
`ls -1 CES_hcfa_cal_darks* | tail -5 >> list-tmp-bias1`;
`ls -1 CES_hcfa_cal_back* > list-tmp-back`;

# first remove cosmics, then combine and make master darks
@darks = `cat list-tmp-dark list-tmp-back`;
foreach $file (@darks) {
    chomp($file);
    &remove_cosmics;
    `rm -f $file *.bdf .pl`;
    `mv c-tmp.fits $file`;
}
`xgterm -e /vlt/INTROOT/E3P6OPS/include/LiSca/dark.sh`;

`cat stat.out`;

# check if the date-dir exists
unless (-d "/data/reduced/$date") {
    `mkdir /data/reduced/$date`;
}

`mv Dark.fits /data/reduced/$date/.`;
$link = "/data/reduced/CES/CES_" . $date . "_Dark.fits";
`ln -s /data/reduced/$date/Dark.fits $link`;
`mv Back.fits /data/reduced/$date/.`;
$link = "/data/reduced/CES/CES_" . $date . "_Back.fits";
`ln -s /data/reduced/$date/Back.fits $link`;


# delete all the junk...
`rm -f *.fits stat.out stats.*`;
`rm -f list-tmp* logfile`;


# get the statistics of all the frames in /data/reduced/CES
`xgterm -e /vlt/INTROOT/E3P6OPS/include/LiSca/darkstat.sh`;
@list = glob("/data/reduced/CES/CES*.fits");
open IN, "<stat.out" or die "aakj6662s";
@stat = <IN>;
close IN;
shift @stat;

$orghandle = select;
$back = "BACK";  $dark = "DARK";
open $back, ">stats.back" or die "993eha";
open $dark, ">stats.dark" or die "nd237c";
foreach $file (@list) {
    $stat = shift @stat;
    if ($file =~ /Back/) {
	select $back;
    } else {
	select $dark;
    }
    print "$file $stat";
}
select $orghandle;
print "\nDone!\n";


#
# _____________ subroutines _________________


sub get_date {
    $date = $ARGV[0];
    unless ($date) {
	$dfile = "/home/astro/CES/pipeWork/date.of.today";
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
	
	# should have the date by now, if not then fail and exit
	# 
	if ($date) {
	    open OUT, ">$dfile" or die "FATAL2\n";
	    print OUT "$date";
	    close OUT;
	} else {
	    print "\n\n\nERROR... provide the date!!!!\n\n\n";
	    exit;
	}
    }
    
}


sub get_next_day {
    ($yyyy, $mm, $dd) = split "-", $date;

    if ($dd > 27) {
	print "enter next day (yyyy-mm-dd): "; chomp( $date2 = <STDIN> );
    } else {
    
	$dd++;
	
	$date2 = sprintf "%4d-%2d-%2d", $yyyy, $mm, $dd;
	$date2 =~ s/\s/0/g;
    }
}



sub show_help {
    print "Usage: \n";
    print "makeMasterDark.pl [-p path] [-h] [YYYY-MM-DD]\n\n";
    print "  -p         Path. Defaults to /data/raw\n";
    print "  -h         This help.\n";
    print " YYYY-MM-DD  The date. Will be prompted for if omitted\n";
}


sub remove_cosmics {
    # operate on $file
    open OUT, ">imagename.txt" or die "could not open";
    print OUT "$file\n";
    close OUT;
    `./do.rem_cosm`; 
    # corrected image is now d1.fits
    unlink "imagename.txt"; 
    `xgterm -e /vlt/INTROOT/E3P6OPS/include/LiSca/cosmic.sh`;
   # corrected image is now c-tmp.fits
}

#
# ___oOo___



