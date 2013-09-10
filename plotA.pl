#!/usr/bin/perl -I/home/tdall/Execs
# 	$Id: plot.pl,v 1.2 2004/12/20 19:59:42 tdall Exp tdall $	


# uncomment these for development
#use diagnostics;
#use warnings;

use PGPLOT;
use Getopt::Std;
use Astro::FITS::CFITSIO;

require "utils.pl";

getopts('spfnv:');      
# -s : symbol plotting
# -p : make a ps file
# -f : file is a fits file (a spectrum)
# -n : normalize (crude) ----------------- DEFUNCT!!!!
# -v radvel : apply RV correction to line positions

#  plots two columns in a file against each other using PGPLOT

$file = @ARGV;

unless ( $file == 1 ) {
    print "plot.pl [-s] [-p] [-f] <file>\n\n";
}
if ($opt_v) {
    $radvel = $opt_v;
} else {
    $radvel = 0.0;
}

$file = $ARGV[0];
&init_hashes;

if ($opt_p) {
    $device = "outplot.ps/PS";
} else {
    $device = "/XSERVE";
}

@x = ();  @y = ();

if ($opt_f) {
    $x = \@x; $y = \@y;
    ($x, $y) = read_fits_spectrum($file);
    @x = @$x; @y = @$y;
} else {
    &read_ascii;
}

# now the plotting

$nume = @x;   # number of elements
if ($nume <= 2) {
    print "too few elements...\n";
    exit;
}

$font = 2;
$linewidth = 2;
$charheight = 1.6;
pgbegin(0,$device,2,2); # Open plot device with 2x2 plots 
pgscf($font); # Set character font 
pgslw($linewidth); # Set line width 
pgsch($charheight); # Set character height 

$symbol = 17;

# find low and high in x and y, add a little extra in both ends
foreach $key (keys %xhig) {
    $xplot_hig = $xhig{$key};  
    $xplot_low = $xlow{$key};
    @ycut=();
    LOOP: for ($i = 0; $i < $nume; $i++) {
	if ($x[$i] > $xplot_low) {
	    push @ycut, $y[$i];
	}
	last LOOP if $x[$i] > $xplot_hig;
    }
    ($yplot_low, $yplot_hig) = low_and_high(@ycut);  # dereferences the array pointer
    # check for cosmics...
    $mean = sum( @ycut );   $numiny = @ycut;
    $mean /= $numiny;
    $sig = sigma( $mean, @ycut ); 
    if ($yplot_hig > $mean + $sig) {
	$yplot_hig = $mean + $sig * 2.0;
    }
    $mean = ( $yplot_hig - $yplot_low ) * 0.02;
    $yplot_hig += $mean;
    $yplot_low -= $mean;
    pgsci(1);  # default colour
    pgenv($xplot_low, $xplot_hig, $yplot_low, $yplot_hig, 0, 0);
    pglabel("", "", $key);
    if ($opt_s) {  # symbol plotting
	pgsci(5);
	pgpoint($nume,\@x,\@y,$symbol);    # plot the points    
    } else {
	pgsci(15);                            # color 15 = light gray
	pgline($nume,\@x,\@y);                   # plot the spectrum    
    }
    $sizeline = $yplot_hig/6.0;
    pgsci(9);
    for ($j=0; $j < 9; $j++) {
	last unless $lines{$key}[$j];
	pgline( 2,  [$lines{$key}[$j]+($radvel*$lines{$key}[$j]/300000.0) ,$lines{$key}[$j]+($radvel*$lines{$key}[$j]/300000.0)],
		[$yplot_hig,$yplot_hig-$sizeline]);
	
    }

}
#pgmtxt('r', 1.1, 0.0, 0.0, "(xcol $opt_x, ycol $opt_y)") unless ($opt_f);
pgend;




#
# subroutines
#

sub init_hashes {
    %xhig = (
	     CaHK => 4050,
	     NaD => 5910,
	     Halpha => 6600,
	     BaFeCa => 6200
	     );
    %xlow = (
	     CaHK => 3860,
	     NaD => 5870,
	     Halpha => 6520,
	     BaFeCa => 6115
	     );
    %lines = (
	      CaHK => [3933.66, 3968.47, 3970.07, 4026.2],
	      NaD => [5895.924, 5889.951, 5875.6],
	      Halpha => [6562.797],
	      BaFeCa => []
	      );
    %names = (
	      CaHK => ["K", "H", "Heps", "HeI"],
	      NaD => [],
	      Halpha => [],
	      BaFeCa => []
	      );



}


sub read_ascii {
    open IN, "<$file" or die "wwweerrddd...$!";

    while ( $in = <IN> ) {
	chomp( $in );
	$in =~ s/^\s+//s;
	@in = split /\s+/, $in;
	if ($in[$xcol] !~ /[a-zA-Z]/ && $in[$ycol] !~ /[a-zA-Z]/) {
	    @x = (@x, $in[$xcol]);
	    @y = (@y, $in[$ycol]);
	}
    }
    
    close IN;
}
