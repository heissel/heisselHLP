#
#   subroutines used by abund_gui.pl:   graphics routines
#

sub plot_the_spec {
    &init_graph;
    $xplot_low = $central_lamb - $range_lamb / 2.0;
    $xplot_hig = $central_lamb + $range_lamb / 2.0;
    $index1 = int( ($xplot_low - $lowlimit) / $wldelt );
    if ($index1 < 0) {
	$index1 = 0;
    }
    $index2 = int( ($xplot_hig - $lowlimit) / $wldelt );    # print "Total of $num points. index1 = $index1, "; 
    if ($index2 > $num-1) {
	$index2 = $num - 1;
    }
    @x = ();   @y = ();                                 # print "index2 = $index2\n";
    for ($i = $index1; $i <= $index2; $i++) {
	push @x, $wave[$i];  push @y, $flux[$i];
    }
    $numsmall = @y;                                    #  print "$num points in \@y\n";
    ($yplot_low, $yplot_hig) = low_and_high(@y);       #   print "($xplot_low, $xplot_hig, $yplot_low, $yplot_hig)\n";
    $offset = $yplot_hig - $yplot_low;
    $yplot_low -= $offset * 0.02;
    $yplot_hig += $offset * 0.1;
    pgenv($xplot_low, $xplot_hig, $yplot_low, $yplot_hig, 0, 0);
    pgline($numsmall, \@x, \@y);
    &overplot_linepos;
    print "Mark good lines with 'a', delete with 'd', exit with 'x'\n";
    &take_lines_from_graph;
    &end_graph;
}

sub plot_next_section {
    $central_lamb += $range_lamb/1.9;
    &plot_the_spec;
}
sub plot_prev_section {
    $central_lamb -= $range_lamb/1.9;
    &plot_the_spec;
}

sub overplot_linepos {   
    @lines2plot = (); 
    pgsci(2);              # plot first all lines in red....
  LOOPPOS:
    foreach $in ( sort keys %pos ) {
#	print "$in\n";
	if ($in > $xplot_hig) {
	    last LOOPPOS;
	}
	unless ($in < $xplot_low) {
	    push @lines2plot, $in;
	}
    }
    print "---------------from left to right:---------------------\n";
    foreach $in (@lines2plot) {
	$y2 = $yplot_hig - $offset*0.07;  $y1 = $yplot_hig - $offset*0.07 - $offset * $dp{$in};
	pgline(2,[$adjusted{$in},$adjusted{$in}],[$y1,$y2]);
	print "$el{$in}   $in   $dp{$in}";
	if (exists $kanonlist{$in}) {
	    pgsci(9);     # selected, so overplot in green...
	    pgline(2,[$adjusted{$in},$adjusted{$in}],[$y1,$y2]);
	    print " - selected\n";
	    pgsci(2);
	} else {
	    print "\n";
	}
    }
    pgsci(1);
}

sub take_lines_from_graph {
    my ($x, $y, $key);
    $key = "a";  $x = $central_lamb;  $y = $yplot_low + $offset;
    while ($key !~ /[xX]/) {
	pgcurs( $x, $y, $key );
	if ($key =~ /[xX]/) {
	    last;
	} elsif ($key =~ /[aA]/) {
	    &take_nearest_line($x,1);
	} elsif ($key =~ /[dD]/) {
	    &take_nearest_line($x,0);
	}
#	print "Received: ( $x, $y )  key $key\n";
    }
}


sub take_nearest_line {
    my ($x,$takeit);
    ($x, $takeit) = @_;
 #   print "Searching for positions around $x\n";
    $match = 10.0;
    foreach $in (@lines2plot) {
	if ( abs( $adjusted{$in} - $x ) < $match) {
	    $match = abs( $adjusted{$in} - $x );
	    $lamb = $in;
	}
    }
    print "I found $el{$lamb} line at $lamb to be best match - ";
    if ($takeit) {
	pgsci(9);
	if (exists $kanonlist{$lamb}) {
	    print "Already taken!\n";
	} else {
	    $kanonlist{$lamb} = `grep '$lamb' $list_default`;  # $line_list_name`;
	    print "Taken!\n";
	}
    } else {
	pgsci(2);
	if (exists $kanonlist{$lamb}) {
	    delete $kanonlist{$lamb};
	    print "Deleted!\n";
	} else {
	    print "Not found...so not deleted!\n";
	}
    }
    $y2 = $yplot_hig - $offset*0.07;  $y1 = $yplot_hig - $offset*0.07 - $offset * $dp{$lamb};
    pgline(2,[$adjusted{$lamb},$adjusted{$lamb}],[$y1,$y2]);
    pgsci(1);
}



sub init_graph {

    if ($ps =~ /screen/) {
	$device = "/XSERVE";
	$font = 2;
	$linewidth = 4;
	$charheight = 1.6;
    } else {
	$device = "$ps_filename/PS";
	$font = 1;
	$linewidth = 2;
	$charheight = 1.4;
    }
    if ($plot_diag =~ /diagnostics/) {
	$numrows = 2;
    } else {
	$numrows = 3;
    }
    if ($plot_spec == 1) {
	$numrows = 1;
	$numcols = 1;
    } else {
	$numcols = 2;
    }

    pgbegin(0,$device,$numcols,$numrows); # Open plot device 
    pgscf($font); # Set character font 
    pgslw($linewidth); # Set line width 
    pgsch($charheight); # Set character height 
}

sub end_graph {
    pgsci(1);  # default colour
    if ($plot_spec == 1) {
	print "choose lines....\n";
    } else {
	pgmtxt('r', 1.1, 0.0, 0.0, "$model vmic=$vmic");
    }
    pgend;
}


sub plot_results_ew {
    
    ($ion,$x,$y) = @_;

    pgsci(1);  # default colour

    if ($ion == 1) {
	$symbol = 17;
	# Define data limits and plot axes if this is the first time
	pgenv($elow,$ehig,$abn - 3 * $sigma/100.0,$abn + 3 * $sigma/100.0,0,0); 
	pglabel('EW (m\A)',"Abund","$file_prefix : $elem"); # Labels 
	pgsci(5); # Change colour 
	$linesty = 2;  # dashed line
    } else {
	$symbol = 21;
	pgsci(2); # Change colour 
	$linesty = 4;  # dotted line
    }

    $i = @$x;   # number of elements
    pgpoint($i,$x,$y,$symbol);      
    pgsls($linesty);  # dashed(1) or dotted(2) line
    pgline(2,[$elow,$ehig],[$abn,$abn]);
    pgsls(1);  # default full line

}



sub plot_result {
    my ($mean, $sig);
    ($x, $y, $xtit, $ytit, $framtit) = @_;
    pgsci(1);  # default colour
    $symbol = 17;
    $i = @$x;   # number of elements
    # find low and high in x, add a little extra in both ends
    ($xplot_low, $xplot_hig) = low_and_high(@$x);  # dereferences the array pointer
    $mean = ( $xplot_hig - $xplot_low ) * 0.02;
    $xplot_hig += $mean;
    $xplot_low -= $mean;
    # find sigma in y-coord and set limit of plot to 3 sigma above and below
    $mean = sum( @$y ) / $i;
    $sig = sigma( $mean, @$y );
    $yplot_low = $mean - 3 * $sig;
    $yplot_hig = $mean + 3 * $sig;
    pgenv($xplot_low, $xplot_hig, $yplot_low, $yplot_hig, 0, 0);
    pglabel($xtit, $ytit, $framtit);
    pgsci(5);
    $linesty = 2;  # dashed line
    pgpoint($i,$x,$y,$symbol);    # plot the points    
    pgsls($linesty);  # set the dashed line
    pgline(2,[$xplot_low,$xplot_hig],[$abn,$abn]);
    pgsls(1);  # default full line

    print "i = $i\n";
}




sub plot_results_xp {
    
    ($ion,$x,$y) = @_;

    pgsci(1);  # default colour

    if ($ion == 1) {
	$symbol = 17;
	# Define data limits and plot axes if this is the first time
	pgenv($xlow,$xhig,$abn - 3 * $sigma/100.0,$abn + 3 * $sigma/100.0,0,0); 
	pglabel("Exit pot. (eV)","Abund","$file_prefix : $elem"); # Labels 
	pgsci(5); # Change colour 
	$linesty = 2;  # dashed line
    } else {
	$symbol = 21;
	pgsci(2); # Change colour 
 	$linesty = 4;  # dotted line
   }

    $i = @$x;   # number of elements
    pgpoint($i,$x,$y,$symbol);      
    pgsls($linesty);  # dashed(1) or dotted(2) line
    pgline(2,[$xlow,$xhig],[$abn,$abn]);
    pgsls(1);  # default full line

}



sub plot_diagnostics {
    # plots the Fe-diagnostics
    &init_graph;

    FINDFE: foreach $file (@list_of_abn) {
	
	# we need only Fe
	next FINDFE unless ($file =~ /Fe/);

	&init_abund_arrays;  # print "file is $file\n";

	# check that the file has non-zero size and we have both neutral and ionized Fe
	if (-s $file && $neutral && $ionized) {
	    open IN, "<$file" or die "error opening $file...";
	} else {
	    print "n=0\n";
	    next FINDFE;
	}

	# read in the relabn file for procesing
	&read_in_relabn_file;
	$ab1 = sum( @el1 );    $num = @el1;
	$ab1 = sprintf "%5.2f", $ab1 / $num;
	$sig1 = sigma( $ab1, @el1 );
	$sig1 = sprintf "%5.2f", $sig1;
	$ab2 = sum( @el2 );    $num = @el2;
	$ab2 = sprintf "%5.2f", $ab2 / $num;
	$sig2 = sigma( $ab2, @el2 );
	$sig2 = sprintf "%5.2f", $sig2;
	$abn = $ab1;    # for the plot routine

	# fit a straight line to the data
	@fit_ew = linfit(\@ew1, \@el1);
	@fit_xp = linfit(\@expot1, \@el1);
	@fit_wl = linfit(\@wl, \@el1);

	&plot_result(\@ew1, \@el1,  'EW (m\A)', "[Fe/H]",  "[Fe-I/H] = $ab1 +/- $sig1");
	&plot_slope(@fit_ew);

	&plot_result(\@expot1, \@el1,  "Exit.pot. (eV)", "[Fe/H]", "");
	&plot_slope(@fit_xp);

	&plot_result(\@wl, \@el1,  'lambda (\A)', "[Fe/H]", "");
	&plot_slope(@fit_wl);

	$abn = $ab2;    # for the plot routine
	&plot_result(\@ew2, \@el2,  'EW (m\A)', "[Fe/H]", "[Fe-II/H] = $ab2 +/- $sig2");
	
	# make file with abund, wl, EW and X-pot for later plotting
	&makeFefile;   

    }

    &end_graph;

}

sub plot_slope {
    my @fit = @_;
    pgsci(1); pgsch(2.0);
    $dum1 = sprintf "slope = %8.6f", $fit[2];
    pgmtxt('b', -1.2, 0.2, 0.0, "$dum1");
    pgsch($charheight);  pgsls(4);
    pgline(2,[0,10000],[$fit[0]   ,    $fit[2] * 10000.0 + $fit[0]  ]);  
    pgline(2,[0,10000],[$fit[0] + $fit[1]   ,  ($fit[2] - $fit[3]) * 10000.0 + $fit[0] + $fit[1]  ]);  
    pgline(2,[0,10000],[$fit[0] - $fit[1]   ,  ($fit[2] + $fit[3]) * 10000.0 + $fit[0] - $fit[1]  ]);  
    pgsls(1);
}















1;
