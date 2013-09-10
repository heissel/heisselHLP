#!/usr/bin/perl -I/Users/tdall/copyExecs
# 	$Id: plot.pl,v 1.2 2004/12/20 19:59:42 tdall Exp tdall $	


# uncomment these for development
#use diagnostics;
#use warnings;

use PGPLOT;
use Getopt::Std;
use DBI;    # see http://search.cpan.org/perldoc?DBI for how-to
###use Astro::FITS::CFITSIO;

require "utils.pl";
require "trader_utils.pl";

getopts('x:y:spl:u:fc:d:Hb:n:o:w:aFX:Y:m:M:zC:tjA:L:U:E:');      
# -s : symbol plotting
# -p : make a ps file
# -t : trader-plot; plotting a stock rather than from file
# -j : candlesticks plot
# -A : MPE plot
# -E : mark entry signals from a trade* file (give unique ID)
# -U : upper date limit (with -t)
# -L : lower date limit (with -t)
# -u : upper limit in x
# -l : lower limit in x
# -a : make ascii file of plotted region
# -c : central x-value
# -d : delta x-value (range=2xd)
# -f : file is a fits file (a spectrum)
# -H : file is HARPS CCF fits file (plot band 73)
# -o : order to plot (don't give for 1D spectra or HARPS CCF's)
# -w : wavelength zeropt for -o plots
# -n : normalize (crude); give factor
# -F : make fits file of plotted region
# -b : rebin the spectrum to this bin-size [AA]
# -X,-Y: labels for axis
# -M : max y value of plot
# -m : min y value of plot
# -z : draw zero-axes
# -C : column determines point color; red (< 0) or green (> 0)
# If multiple files are given, all must have same structure otherwise results may be strange...

#  plots two columns in a file against each other using PGPLOT

$nfiles = @ARGV;
@files = @ARGV;
die "can't do -p with multiple files\n" if ($opt_p && $nfiles > 1);
unless ( ( ($opt_x && $opt_y) || $opt_f || $opt_H || $opt_o || $opt_t) && $nfiles >= 1) {
    print "plot.pl -x<col> -y<col> <file>\n\n";
}
if ($opt_E) {
    @tfile = glob("/Users/tdall/geniustrader/Backtests/trades*${opt_E}*.txt");
    open IN, "<$tfile[0]" || die "no file $tfile[0]...\n";
    chomp(@tdays = <IN>);
    close IN; 
}
if ($opt_x) {
    $xcol = $opt_x - 1;  $ycol = $opt_y - 1;  
}
if ($opt_w) {
    $wloffset = $opt_w;
} else {
    $wloffset = 0.0;
}
$normfac = 1.0;
if ($opt_n) {
    $normfac = $opt_n;
}
if ($opt_X) {
    $xlab = $opt_X;
} else {
    $xlab = "";
}
if ($opt_Y) {
    $ylab = $opt_Y;
} else {
    $ylab = "";
}
#$file = $ARGV[0];
if ($opt_t) {
    $dbfile = "/Users/tdall/geniustrader/traderThomas";
    if (-e $dbfile) {
        $dbh = DBI->connect("dbi:SQLite:$dbfile", undef, undef, {
            AutoCommit => 1,
            RaiseError => 1,
            sqlite_see_if_its_a_number => 1,
          });
    } else {
        die "no such file: $tmfile\n";
    }
}
if ($opt_p) {
    $files[0] =~ /(.*).txt/;
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

$nn = 0;
foreach $file (@files) {
$nn++;  # counter for the files...
@x = ();  @y = ();

if ($opt_o) {
    $x = \@x; $y = \@y;
    ($x, $y) = read_fits_order($opt_o, $wloffset, $file);
    @x = @$x; @y = @$y;
} elsif ($opt_f) {
    $x = \@x; $y = \@y;
    ($x, $y) = read_fits_spectrum($file);
    @x = @$x; @y = @$y;
} elsif ($opt_H) {
    $x = \@x; $y = \@y;
    ($x, $y) = read_fits_ccf($file);
    @x = @$x; @y = @$y;
} elsif ($opt_t) {
    &read_stockprice;
} else {
    &read_ascii;
}
@ynew = div_array( \@y, $normfac ) if $opt_n;
@y = @ynew if $opt_n;

$nume = @x;   # number of elements
if ($nume <= 2) {
    print "too few elements...\n";
    exit;
}

# find low and high in x and y, add a little extra in both ends
if ($opt_u && $opt_l) {
    &truncate_spectrum();
    @ycut=();
    LOOP: for ($i = 0; $i < $nume; $i++) {
	if ($x[$i] > $xplot_low) {
	    push @ycut, $y[$i];
	}
	last LOOP if $x[$i] > $xplot_hig;
    }
    ($yplot_low, $yplot_hig) = low_and_high(@ycut);  # dereferences the array pointer
} elsif ($opt_c && $opt_d) {
    $xplot_hig = $opt_c + $opt_d;
    $xplot_low = $opt_c - $opt_d;
    &truncate_spectrum();
    @ycut=();
    LOOP2: for ($i = 0; $i < $nume; $i++) {
        if ($x[$i] > $xplot_low) {
            push @ycut, $y[$i];
        }
        last LOOP2 if $x[$i] > $xplot_hig;
    }
    ($yplot_low, $yplot_hig) = low_and_high(@ycut);  # dereferences the array pointer
} elsif ($opt_U && $opt_L) {
    $xplot_hig = 0; $xplot_low = 0;
    for ($i = 1; $i < $nume; $i++) {
        if ($xplot_low == 0 && $date[$i] gt $opt_L) {
            $xplot_low = $i-1; 
        }
        if ($xplot_hig == 0 && $date[$i] ge $opt_U) {
            $xplot_hig = $i; 
        }
    }
#    @xt = ($xplot_low .. $xplot_hig);
    $stockt = "$date[$xplot_low] - $date[$xplot_hig]";
    @ycut=();
    for ($i = $xplot_low; $i <= $xplot_hig; $i++) {
        push @ycut, $y[$i];
    }
    ($yplot_low, $yplot_hig) = low_and_high(@ycut);
    print "plotting from $xplot_low to $xplot_hig\n";
    $mean = atr($file, \%hday, \%dayindex, \%maxp, \%minp, \%closep, 20, $date[$xplot_hig]);
    $yplot_hig += $mean;
    $yplot_low -= $mean;
    $xplot_low -= 0.5; $xplot_hig += 0.5;
} else {
    ($xplot_low, $xplot_hig) = low_and_high(@x);  # dereferences the array pointer
    $mean = ( $xplot_hig - $xplot_low ) * 0.02;
    $xplot_hig += $mean;
    $xplot_low -= $mean;
    ($yplot_low, $yplot_hig) = low_and_high(@y);  # dereferences the array pointer
}
$xplot_hig = $opt_u if ($opt_u);
$xplot_low = $opt_l if ($opt_l);
$mean = ( $yplot_hig - $yplot_low ) * 0.02;
$yplot_hig += $mean;
$yplot_low -= $mean;

if ($opt_b && $opt_b > $x[1]-$x[0]) {
    ($effb, $x, $y) = do_rebin_spectrum($opt_b, \@x, \@y, 3.0);   # xxx 3-sigma cutting in rebinning
    @x = @$x;  @y = @$y;
    $nume = @x; 
    print "Input bin of $opt_b -> $effb\n";
}

if ($nn == 1) {
    # first time through
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
    pglabel("$xlab", "$ylab", $file);
    if ($opt_z) {
        pgsci(14);
        pgline(2, [$xplot_low,$xplot_hig], [0.0,0.0]);
        pgline(2, [0.0,0.0], [$yplot_low,$yplot_hig]);
        pgsci(1);
    }
    if ($opt_A) {
        pgsci(14);
        pgline(2, [1,100], [1,100]);
        pgsls(2);
        for ($i=1; $i<int($xplot_hig); $i+=int( ($xplot_hig-$xplot_low)/6.0) ) {
            pgline(2, [1+$i,100+$i], [1,(100+$i)*$opt_A]);
        }
    }
    $col = 11;
    $postxt = 1.0;
}
pgsch(0.8); # Set character height
if ($opt_t) {
    $file = $stockt;
}
if ($opt_s) {  # symbol plotting
    pgsci($col);
    pgpoint($nume,\@x,\@y,$symbol);    # plot the points
} elsif ($opt_j) {
    pgsci(1);  # default colour
    pgsls(1);
    my $candlew = 0.31; # old: int(300.0 / $nume / 2.0) + 1;
    pgsfs(1); # fill is true
    for ($i = 0; $i < $nume; $i++) {
        # find entry signals on this day
        if ($opt_E) {
            $entrySig = '';
            foreach $tday (@tdays) {
                @tmp = split /\s+/, $tday;
                if ($tmp[4] eq $date[$i]) {
                    $entrySig = $tmp[2];
                    last;
                }
            }
            if ($entrySig) {
                if ($tmp[8] > 10) {
                    pgsci(3);  $symbol = 27;
                } elsif ($tmp[8] > 6) {
                    pgsci(3);  $symbol = 26;
                } elsif ($tmp[8] > 4) {
                    pgsci(3);  $symbol = 25;
                } elsif ($tmp[8] > 2) {
                    pgsci(3);  $symbol = 24;
                } elsif ($tmp[8] > 0) {
                    pgsci(3);  $symbol = 22;
                } else {
                    pgsci(2);  $symbol = 22; 
                }
                if ($tmp[8] > -0.2 && $tmp[8] < 0.3) {
                    pgsci(8);
                }
                pgsls(4); pgslw(1);
                pgline(2,  [$x[$i],$x[$i]], [$yh[$i]+3*$mean,$yl[$i]-3*$mean]);
                pgsls(1);
            }
            if ($entrySig eq 'long') {
                pgpoint(1, [$x[$i]], [$yh[$i]-$mean/2],$symbol);
            } elsif ($entrySig eq 'short') {
                pgpoint(1, [$x[$i]], [$yl[$i]+$mean/2],$symbol);
            }
        }
        # draw the candles
        pgsci(14);                          # color 15 = light gray
        pgslw(2); # Set line width 
        pgline(2, [$x[$i],$x[$i]], [$yl[$i],$yh[$i]]);
        if ($yo[$i] > $y[$i]) {
#            pgsci(2); # red
            pgsci(14); # down day
        } else {
#            pgsci(3); # green
            pgsci(1); # up day
        }
        pgslw(1); # Set line width 
        pgrect($x[$i]-$candlew, $x[$i]+$candlew, $yo[$i], $y[$i]); 
    }
} else {
    pgsci($col);                            # color 15 = light gray
    pgline($nume,\@x,\@y);                   # plot the spectrum    
}
if ($opt_C) {
    $npos = @posy;  $nneg = @negy;  #print "pos: $npos, neg: $nneg\n";
    pgsci(3);
    pgpoint($npos, \@posx, \@posy, $symbol) if $npos;
    pgsci(2);
    pgpoint($nneg, \@negx, \@negy, $symbol) if $nneg;
    pgsci($col);
}    
pgmtxt('t', 0.5, $postxt, 1.0, "$file");
$postxt -= 0.05;
$col++;
$col = 2 if ($col > 14);
}
pgsci(1);
#pgmtxt('r', 1.1, 0.0, 0.0, "(xcol $opt_x, ycol $opt_y)") unless ($opt_f);
pgend;

&write_ascii if ($opt_a);
&write_fits_spectrum( "testout.fits", $x[0], $x[1]-$x[0], \@y ) if ($opt_F);

#
# subroutines
#

sub truncate_spectrum {

    @cutx =(); @cuty = ();
    for ($i = 0; $i <= $nume; $i++) {
	if ($x[$i] > $xplot_low) {
	    push @cutx, $x[$i];
	    push @cuty, $y[$i];
	}
	last if $x[$i] > $xplot_hig;
    }

    $nume = @cutx;
    @x = @cutx;  @y = @cuty;

}


sub write_ascii {
    open OUT, ">plot.asc" or die "bbbb37rt whrg s s...";

    for ($i = 0; $i <= $nume; $i++) {
	if ($x[$i] > $xplot_low) {
	    print OUT "$x[$i]   $y[$i]\n";
	}
	last if $x[$i] > $xplot_hig;
    }

    close OUT;
}

sub read_stockprice {
    # for now only close price...
    @dtmp = @{$dbh->selectcol_arrayref(qq{SELECT date FROM stockprices WHERE symbol='$file' ORDER BY date DESC})};
    @yrev = @{$dbh->selectcol_arrayref(qq{SELECT day_close FROM stockprices WHERE symbol='$file' ORDER BY date DESC})};
    #    @y = @{$dbh->selectcol_arrayref(qq{SELECT day_close FROM stockprices WHERE symbol='$file' ORDER BY date DESC})};
    $numdb = @yrev;
    @y = reverse @yrev;
    @x = (1 .. $numdb);
    $stockt = "$dtmp[-1] - $dtmp[0]";
    @date = reverse @dtmp;
    print "$date[0] to $date[-1] ...";
    if ($opt_j) {
        @closep{@date} = @y;
        @yrev = @{$dbh->selectcol_arrayref(qq{SELECT day_open FROM stockprices WHERE symbol='$file' ORDER BY date DESC})};
        @yo = reverse @yrev;
        @openp{@date} = @yo;
        @yrev = @{$dbh->selectcol_arrayref(qq{SELECT day_high FROM stockprices WHERE symbol='$file' ORDER BY date DESC})};
        @yh = reverse @yrev;
        @maxp{@date} = @yh;
        @yrev = @{$dbh->selectcol_arrayref(qq{SELECT day_low FROM stockprices WHERE symbol='$file' ORDER BY date DESC})};
        @yl = reverse @yrev;
        @minp{@date} = @yl;
        @hday{@x} = @date;
        @dayindex{@date} = @x;
    }
#    print "$y[0] ... $y[-1]\n"; exit;
}


sub read_ascii {
    open IN, "<$file" or die "wwweerrddd...$!";
    if ($opt_C) {
        $ccol = $opt_C - 1;
        @posx = (); @posy = (); $negx = (); $negy = ();
    }
    while ( $in = <IN> ) {
        next if $in =~ /^[#S]/;
        chomp( $in );
        $in =~ s/^\s+//s;
        @in = split /\s+/, $in;
        if ($in[$xcol] !~ /[a-zA-Z]/ && $in[$ycol] !~ /[a-zA-Z]/) {
            @x = (@x, $in[$xcol]);
            @y = (@y, $in[$ycol]);
            if ($opt_C) {
                if ($in[$ccol] > 0.0) {
                    push @posx, $in[$xcol];
                    push @posy, $in[$ycol];
                } elsif ($in[$ccol] < 0.0) {
                    push @negx, $in[$xcol];
                    push @negy, $in[$ycol];
                }
            }
        }
    }
    
    close IN;
}
