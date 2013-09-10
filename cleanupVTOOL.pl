#!/usr/bin/perl
#*******************************************************************************
# E.S.O. - VLT project
#
# "@(#) $Id: cleanupVTOOL.pl,v 1.26 2005/08/15 21:55:51 vltsccm Exp $"
#
# who       when        what
# --------  ----------  ----------------------------------------------
# tdall     2004-11-23  created
#

# called at the end of checkAll to clean-up any hanging midas proceses
#

$| = 1;   # force flush/print...

# get the tty/pts
#
$proc = `ps h -C checkAll`;
$proc =~ s/^\s+//s;
($d1, $tt, $d2) = split /\s+/, $proc;

# wait for the process to exit, then kill remaining midas-hangings
#
print "Stopping hanging processes. Please wait...";
sleep 3;

@proc = `ps h -t $tt`;

foreach $proc (@proc) {
    next if $proc =~ /bash/;
    next if $proc =~ /cleanupVTOOL/;     # do not commit suicide....
    next if $proc =~ /checkAll/;         # do not commit suicide....
    $proc =~ s/^\s+//s;
    ($pid, $d2) = split /\s+/, $proc; 
    $err = `kill -9 $pid` if $proc =~ /midas/;
    if ($err) {
	print "\nProblem encountered with process $pid. Please check manually\n";
    }
}

print "Done\n";

#
# ___oOo___
