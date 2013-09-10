#!/usr/bin/perl
#*******************************************************************************
# E.S.O. - VLT project
#
# "@(#) $Id: stopCESpipe.pl,v 1.26 2005/08/15 21:55:51 vltsccm Exp $"
#
# who       when        what
# --------  ----------  ----------------------------------------------
# tdall     2004-09-28  created
# tdall     2004-11-23  killing of hanging midas processes too
#

# call this script to stop the CES pipeline gracefully
#

$| = 1;   # force flush/print...

# stop the queuer
@pid = `ps -u astro | grep CESqueue`;
foreach $in (@pid) {
    $in =~ s/^\s+//g;
    ($pid, $pipe) = split /\s+/, $in;
    #chomp($pid = `cat /home/astro/CES/pipeWork/.pipePID`);
    `kill -9 $pid`;
}
`rm -f /home/astro/CES/pipeWork/.pipe*`;

# get the tty/pts of the pipeline processes
#
$pipe = `ps h -C inmidas | grep 77`;
$pipe =~ s/^\s+//g;
($d1, $tt, $d2) = split /\s+/, $pipe;

`echo 1 > /data/E3P6OPS/CES/pipeWork/.stopsign`;

# wait for the process to exit, then kill remaining midas-hangings
#
print "Stopping hanging processes. Please wait...";
while (-e "/data/E3P6OPS/CES/pipeWork/.stopsign") {
    sleep 5;
}

@proc = `ps h -t $tt`;

foreach $pipe (@proc) {
    next if $pipe =~ /bash/;
    $pipe =~ s/^\s+//s;
    ($pid, $d2) = split /\s+/, $pipe;
    $err = `kill -9 $pid` if $pipe =~ /midas/;
    if ($err) {
	print "\nProblem encountered with process $pid. Please check manually\n";
    }
}

print "Done\n";

#
# ___oOo___
