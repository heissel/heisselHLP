#!/usr/bin/perl
#*******************************************************************************
# E.S.O. - VLT project
#
# "@(#) $Id: makeCESlog.pl,v 1.26 2005/08/15 21:55:50 vltsccm Exp $"
#
# who       when        what
# --------  ----------  ----------------------------------------------
# tdall     2004-09-29  created
# tdall     2005-01-12  date-input changed. Minor fixes.
# tdall     2005-03-17  rewrite based on dfits instead of gethead. Added airmass and RO+binning.
#
# should be run on w3p6off
#

#use warnings;
#use diagnostics;

# if no date given check if date-file exists. yes: open, show and ask. no: just ask.
#
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
                                                                           
# open the log-file and print the headlines.
#
open LOG, ">/data/backlog/$date/CES_$date.log" or die "could not open log\n";
print LOG "CES3.6 observing log - $date\n";
print LOG "----------------------------------------------------------------------------------------------------------------------------------------\n";
print LOG "original filename [.fits]  archive name [.fits]          mode  object         RA           DEC         Texp  airm.  wlen    PID\n";
print LOG "----------------------------------------------------------------------------------------------------------------------------------------\n";



# get the names and extract header info
#
@filelist = `ls -1tr /data/raw/$date/CES_hcfa_*_*[Afdbl]*_????.fits`;
LOOP: foreach $name (@filelist) {
    chomp( $name );
    print "\ntesting $name ";

    # first test to see what kind of frame it is
    # and treat it accordingly:
    #
    chomp( $dprtype = `dfits $name | grep "HIERARCH ESO OBS NAME"` );
    next LOOP if $dprtype =~ /Maintenance/;
    chomp( $dprtype = `dfits $name | grep  "HIERARCH ESO DPR TYPE" ` );
    #print "-> $dprtype";
    if ($dprtype =~ /OBJECT/) {
	$hdr = `dfits $name | grep "HIERARCH ESO OBS TARG NAME"`;
	$hdr =~ /=\s+\'(.*)\'/;
	$object = $1;
    } else {
	$dprtype =~ /=\s+\'(.*)\'/;
	$object = $1;
	# check for back template
	#
	if ($name =~ /back/) {
	    $object =~ s/DARK/BACK/s;
	}
    }
    #
    # Extraxt the info common to all files
    #
    &convRAandDEC;
    if ($ra !~ /:/ || $dprtype !~ /OBJECT/) {
	# if something was wrong with the preset or if not an OBJECT, $ra contains garbage...
	&dummyRAandDEC;
    }
    $hdr = `dfits $name | grep "HIERARCH ESO INS1 GRAT1 WLEN"`;
    $hdr =~ /=\s+(\d+\.\d+)\s/;
    $wlen = $1;

    $hdr = `dfits $name | grep "HIERARCH ESO OBS PROG ID"`;
    $hdr =~ /=\s+\'(.*)\'/;
    $pid = $1;

    $hdr = `dfits $name | grep EXPTIME`;
    $hdr =~ /=\s+(\d+\.\d+)\s/;
    $texp = $1;

    $hdr = `dfits $name | grep ORIGFILE`;
    $hdr =~ /(CES.*).fits/;
    $org_file = $1;

    $hdr = `dfits $name | grep ARCFILE`;
    $hdr =~ /(CES.*).fits/;
    $arc_file = $1;

    $hdr = `dfits $name | grep CDELT1`;
    $hdr =~ /=\s+(\d)\./;
    $binx = $1;

    $hdr = `dfits $name | grep CDELT2`;
    $hdr =~ /=\s+(\d)\./;
    $biny = $1;

    $hdr = `dfits $name | grep "HIERARCH ESO DET READ SPEED"`;
    $hdr =~ /=\s+\'(.)/;
    $readmode = $1;

    $mode = $readmode . $binx . "x" . $biny;

    $hdr = `dfits $name | grep "HIERARCH ESO TEL AIRM END"`;
    $hdr =~ /=\s+(\d+\.\d+)\s/;
    $airmass = $1;

    # format the header info and write to the log file.
    # 
    write LOG;
}
close LOG;
print "\nDone\n";
                                                                                
# now print the log...
#
`a2ps -o CES_$date.ps -r -Ma4 -f9.5 --columns=1 --center-title="CES observing log $date" /data/backlog/$date/CES_$date.log `;
`gv CES_$date.ps`;


sub dummyRAandDEC {

	$ra = "--:--:--.---";
	$dec = "---:--:--.---";

    }


sub convRAandDEC {
                       
    $header = `dfits $name | grep "RA (J2000) pointing (deg)"`;
    ($d1,$d2,$d3,$d4, $ra, $d5) = split /\s+/, $header;

    $header = `dfits $name | grep "DEC (J2000) pointing (deg)"`;
    ($d1,$d2,$d3,$d4, $dec, $d5) = split /\s+/, $header;
    unless ($dec =~ /-/) {
	$dec = " " . $dec;
    }
}


format LOG =
@<<<<<<<<<<<<<<<<<<<<<< -> @<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<  @<<<<<<<<<<<<  @<<<<<<<<<  @<<<<<<<<<<  @###  @.### @###.#   @>>>>>>>>>>>>
$org_file, $arc_file, $mode, $object, $ra, $dec, $texp, $airmass, $wlen, $pid
. 





#************************************************************************
#   NAME
# 
#   SYNOPSIS
# 
#   DESCRIPTION
#
#   FILES
#
#   ENVIRONMENT
#
#   RETURN VALUES
#
#   CAUTIONS
#
#   EXAMPLES
#
#   SEE ALSO
#
#   BUGS     
#
#------------------------------------------------------------------------
#

# signal trap (if any)


#
# ___oOo___
