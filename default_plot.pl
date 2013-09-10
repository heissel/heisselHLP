#!/usr/bin/perl
# 	$Id: default_plot.pl,v 1.2 2004/10/26 01:48:57 tdall Exp $	

use diagnostics;
use warnings;
use PGPLOT;

#  This is a template file to use for the plotting of data using PGPLOT via perl.
# It should not be overwritten, but merely copied to whereever you need it.


# uncomment if making complex GUI type application...
# use Tk;


# to initialize the graph i.e. start a new plot:
# uncomment+edit:
#
pgbegin(0,"/XSERVE",2,3); # Open plot device with 3 rows of 2 columns with plots 
# pgbegin(0,"outfile.ps/PS",1,1); # Open PS-file with one plot

pgscf(2); # Set character font 
pgslw(2); # Set line width 
pgsch(1.4); # Set character height 

pgsci(1);  # this is the default colour to use

# set the plot environment; defines axis limits and such
#
$xlow = 0;
$xhig = 10;
$ylow = -4;
$yhig = 4;
pgenv($xlow, $xhig, $ylow, $yhig ,0,0); 

# set the axis label and name of plot
#
$xlabel = 'wavelength [\A]';
$ylabel = "counts";
$text = "Test";
pglabel($xlabel, $ylabel, $text); # Labels 

#  arrays must be passed as references
#
#    pgpoint plots the individual data points, pgline interconnects them

$i = @x;        # number of points in the array to plot
$symbol = 17;

pgpoint($i, \@x, \@y, $symbol);      

pgsls(4);  # dotted line
pgsls(1);  # default full line
pgline($i, \@x, \@y);


# closes the plots. All done!
pgend;
