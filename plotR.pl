#!/usr/bin/perl -I/Users/tdall/copyExecs

#use diagnostics;
#use warnings;

use PGPLOT;
use Getopt::Std;
#use DBI;    # see http://search.cpan.org/perldoc?DBI for how-to
###use Astro::FITS::CFITSIO;

require "utils.pl";
require "trader_utils.pl";

getopts('R:pN:r:');      
# -R <Rval> : calc & plot only values reached after R has reached at least Rval (if trade never reach Rval, then just plot normally with a thin line)
# -N <Nbar> : plot only up until a certain lenght Nbar.
# -r <step> : step size in R starting from the level given in -R
# -p : create a PS file

$mode = "(";
if ($opt_R) {
    $mode .= "dev after R=${opt_R} ";
}
if ($opt_N) {
    $mode .= "up to Nbar=${opt_N} ";
}
if ($mode eq "(") {
    $mode .= "std";
}
$mode .= ")";
if ($opt_r) {
    $stepinr = $opt_r;
} else {
    $stepinr = 0.5;
}

$ file = shift;
if ($opt_p) {
    $file =~ /\/*(.*).txt/;
    if ($1) {
        $fn = $1;
    } else {
        $fn = "outplot";
    }
    $device = "$fn.ps/PS";
    $symbol = 23;
} else {
    $device = "/XSERVE";
    $symbol = 17;
}

&read_ascii;

$nume = @lines;   # number of elements
if ($nume <= 2) {
    print "too few elements...\n";
    exit;
}
$yplot_low = 0.0; $yplot_hig = 0.0;
@rmult = ();
foreach $in (@lines) {
    next unless $in =~ /^\d/;
    # tradeNo:Dir:Nbar:R_MPE:R_MAE:RbarHigh:RbarLow
    # 0       1   2    3     4     5        6
    @splt = split /;/, $in;
    if ($splt[6] == -999) {
        $id = $splt[0];
        $tradeR{$id} = $splt[3];
        $tradeNbars{$id} = $splt[2];
        $tradeDir{$id} = $splt[1];
        push @rmult, $splt[3];
    }
    if ($splt[5] > $yplot_hig) {
        $yplot_hig = $splt[5]; #print "Setting yplot_hig = $yplot_hig from $in... ";
    }
    if ($splt[6] < $yplot_low && $splt[6] > -900) {
        $yplot_low = $splt[6]; #print "Setting yplot_low = $yplot_low ... ";
    }
}
$ntrades = keys %tradeR;
$meanr = sum(@rmult)/$ntrades;
$sigr = sigma($meanr, @rmult);

($xplot_low, $xplot_hig) = (0,$ntrades+1);


    $font = 2;
    $linewidth = 2;
    $charheight = 1.6;
    pgbegin(0,$device,1,1); # Open plot device 
    pgscf($font); # Set character font 
    pgslw($linewidth); # Set line width 
    pgsch($charheight); # Set character height 
    pgsci(1);  # default colour
    $yplot_hig = $opt_M if ($opt_M);
    $yplot_low = $opt_m if ($opt_m);
    pgenv($xplot_low, $xplot_hig, $yplot_low, $yplot_hig, 0, 0);
    pglabel("trade No.", "R", $file);
    pgsci(14);
    pgsls(2); pgline(2, [$xplot_low,$xplot_hig], [0.0,0.0]);
    pgline(2, [$xplot_low,$xplot_hig], [-1.0,-1.0]);
    pgsci(11); pgsls(2); pgline(2, [$xplot_low,$xplot_hig], [$opt_R,$opt_R]) if ($opt_R);
    pgsci(1); pgsls(1);
    pgsch(0.8); # Set character height

$hig = 0.0; $low = 0.0; $thick = 1;
@r0 = (); @r1 = (); @r2 = (); @r3 = (); @r4 = (); @r5 = ();
$f0 = 1; $f1 = 1; $f2 = 1; $f3 = 1; $f4 = 1; $f5 = 1;
foreach $in (@lines) {
    next unless $in =~ /^\d/;
    chomp $in; #print "looking at $in ... ";
    # tradeNo:Dir:Nbar:R_MPE:R_MAE:RbarHigh:RbarLow
    # 0       1   2    3     4     5        6
    if ($opt_R) {
        @b = split /;/, $in;
        if (($b[5] > $opt_R || $hig > $opt_R) && ( ($opt_N && $b[2]<=$opt_N) || ! $opt_N) ) {
            if ($hig == 0.0) {
                $low = $b[6];
                $thick = 10;
            }
            if ($b[5] > $hig) {
                $hig = $b[5];
            }
            if ($b[6] < $low && $b[6] > -900) {
                $low = $b[6];
            }
        }
        if ($f0 && $b[5] >= $opt_R) {
            $f0 = 0;
            push @r0, $opt_R;
        }
        if ($f1 && $b[5] >= $opt_R+$stepinr) {
            $f1 = 0;
            push @r1, $opt_R+$stepinr;
        }
        if ($f2 && $b[5] >= $opt_R+$stepinr*2) {
            $f2 = 0;
            push @r2, $opt_R+$stepinr*2;
        }
        if ($in =~ /-999/) {
            # this line ends this trade so time to plot
            @a = split /;/, $lin; 
            if ($hig == 0.0 && ! $opt_N) {
                $hig = $a[3]; $low = $a[4];
            } elsif ($hig == 0.0) {
                $low = $a[4];
            }
            pgsci(3); pgpoint(2,[$b[0],$b[0]],[$hig,$yplot_hig+10.0],1); # upper R value
            pgsci(2); pgpoint(2,[$b[0],$b[0]],[$low,$yplot_hig+10.0],1); # lower R value
            if ($b[3] > 0) {
                $col = 3;
            } else {
                $col = 2;
            }
            pgslw($thick); pgsci(14); pgline(2,[$b[0],$b[0]],[$hig,$low]); # line connecting the two
            pgslw(1); pgsci($col); pgpoint(2,[$b[0],$b[0]],[$b[3],$yplot_hig+10.0],23); # exit R value
            $hig = 0.0; $low = 0.0; $thick = 1; # resetting the values for the next trade
            push @r0, $b[3] if ($opt_R && !$f0);
            push @r1, $b[3] if ($opt_R && !$f1);
            push @r2, $b[3] if ($opt_R && !$f2);
        }
    } elsif ($opt_N) {
        @b = split /;/, $in;
        if ($b[2] <= $opt_N) {    
            if ($b[5] > $hig) {
                $hig = $b[5];
            }
            if ($b[6] < $low && $b[6] > -900) {
                $low = $b[6];
            }
        }
        if ($in =~ /-999/) {
            # this line ends this trade so time to plot
            pgsci(3); pgpoint(2,[$b[0],$b[0]],[$hig,$yplot_hig+10.0],1); # upper R value
            pgsci(2); pgpoint(2,[$b[0],$b[0]],[$low,$yplot_hig+10.0],1); # lower R value
            if ($b[3] > 0) {
                $col = 3;
            } else {
                $col = 2;
            }
            pgslw($thick); pgsci(14); pgline(2,[$b[0],$b[0]],[$hig,$low]); # line connecting the two
            pgslw(1); pgsci($col); pgpoint(2,[$b[0],$b[0]],[$b[3],$yplot_hig+10.0],23); # exit R value
            $f0 = 1; $f1 = 1; $f2 = 1; $f3 = 1; $f4 = 1; $f5 = 1;
            $hig = 0.0; $low = 0.0; $thick = 1; # resetting the values for the next trade
        }
    } else {
        if ($in =~ /-999/) {
            # previous line is what we want
            @a = split /;/, $lin; #print "extracting from $lin ...\n";
            @b = split /;/, $in; # to get the exit R
            pgsci(3); pgpoint(2,[$a[0],$a[0]],[$a[3],$yplot_hig+10.0],1); # upper R value
            pgsci(2); pgpoint(2,[$a[0],$a[0]],[$a[4],$yplot_hig+10.0],1); # lower R value
            if ($b[3] > 0) {
                $col = 3;
            } else {
                $col = 2;
            }
            pgsci($col); pgpoint(2,[$a[0],$a[0]],[$b[3],$yplot_hig+10.0],23); # exit R value
            pgsci(14); pgline(2,[$a[0],$a[0]],[$a[3],$a[4]]); # line connecting the two
        }
    }
    $lin = $in;
}

pgsci(1);
$postxt = 1.0;
$outtxt = sprintf "R = %.2f +/- %.2f, SQ = %.2f, N = $ntrades",$meanr,$sigr,$meanr/$sigr;
pgmtxt('t', 0.5, $postxt, 1.0, "$outtxt $mode");
$postxt -= 0.05;
if ($opt_R) {
    $meanr = sum(@r0)/$ntrades; 
    printf "R(TP=%.2f) = %.2f, SQ = %.2f\n",$opt_R,$meanr,$meanr/sigma($meanr, @r0);
    $meanr = sum(@r1)/$ntrades; 
    printf "R(TP=%.2f) = %.2f, SQ = %.2f\n",$opt_R+$stepinr,$meanr,$meanr/sigma($meanr, @r1);
    $meanr = sum(@r2)/$ntrades; 
    printf "R(TP=%.2f) = %.2f, SQ = %.2f\n",$opt_R+$stepinr*2,$meanr,$meanr/sigma($meanr, @r2);
}

pgsci(1);
#pgmtxt('r', 1.1, 0.0, 0.0, "(xcol $opt_x, ycol $opt_y)") unless ($opt_f);
pgend;


#
# subroutines
#

sub read_ascii {
    open IN, "<$file" or die "aau3800dfn375hww03";
    @lines = <IN>;
    close IN;
}