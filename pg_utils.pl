#
#  subroutines to use the PGPLOT routines
#


sub pg_take_x_from_graph {

    my ($y, $key, $oldx);
    $key = "a";  $x = $xplot_low;  $y = $yplot_low; $oldx = 0;
    while ($key !~ /[xX]/) {
	pgcurs( $x, $y, $key );
	if ($key =~ /[xX]/) {
	    last;
	} elsif ($key =~ /[aAdD]/) {
	    $oldx = $x
	} 
	print "Position: $x\n";
    }
    $x = $oldx if $oldx;
    print "Took position: $x\n";
}





sub pg_plot_vertical_line {          # arguments:  position,  linestyle,  color

    my ($x, $style, $color) = @_;
    pgsci($color);
    pgsls($style);
    pgline(2, [$x,$x], [$yplot_low,$yplot_hig]);
    if ($linestyle) {
	pgsls($linestyle);
    } else {
	pgsls(1);   # set to full line
    }
}





sub pg_plot_horizontal_line {          # arguments:  position,  linestyle,  color

    my ($y, $style, $color) = @_;
    pgsci($color);
    pgsls($style);
    pgline(2, [$xplot_low,$xplot_hig], [$y,$y]);
    if ($linestyle) {
	pgsls($linestyle);
    } else {
	pgsls(1);   # set to full line
    }
}





sub pg_plot_graph_Xfix {   # Plot where x-limits have already been determined
                           # The $device variable must have been set in the calling program

    my ($xx, $yy, $xtext, $ytext, $head) = @_;    # these are references to x and y arrays
    my @x = @$xx;          # dereference the array to get size
    my $i = @x;
    my $mean;

    die "Device not set! $!" unless $device;

    # find low and high in y, add a little extra in both ends
    #
    ($yplot_low, $yplot_hig) = low_and_high(@y);
    $mean = ( $yplot_hig - $yplot_low ) * 0.02;
    $yplot_hig += $mean;
    $yplot_low -= $mean;

    pgbegin(0,$device,1,1);               # Open plot device 
    pgsci(1);                             # default colour = white
    if ($linestyle && $font && $linewidth && $charheight) {
	pgsls($linestyle);                    # set line style
	pgscf($font);                         # Set character font 
	pgslw($linewidth);                    # Set line width 
	pgsch($charheight);                   # Set character height 
    }
    pgenv($xplot_low, $xplot_hig, $yplot_low, $yplot_hig, 0, 0);
    pglab($xtext, $ytext, $head);
    pgsci(15);                            # color 15 = light gray
    pgline($i,$xx,$yy);                   # plot the spectrum    
}




sub pg_plot_graph {  # Simple plot. Detrmines automatically the x and y limits
                     # The $device variable must have been set in the calling program

    my ($xx, $yy, $xtext, $ytext, $head) = @_;    # these are references to x and y arrays
    my @x = @$xx;            # dereference the array to get size
    my @y = @$yy;
    my $i = @x;
    my $j = @y;
    my $mean;

    die "Mismatching size ($i and $j) ! $!" unless ($i == $j);
    die "Device not set! $!" unless $device;

    # find low and high in x and y, add a little extra in both ends
    #
    ($yplot_low, $yplot_hig) = low_and_high(@y);
    $mean = ( $yplot_hig - $yplot_low ) * 0.02;
    $yplot_hig += $mean;
    $yplot_low -= $mean;
    ($xplot_low, $xplot_hig) = low_and_high(@x);
    $mean = ( $xplot_hig - $xplot_low ) * 0.02;
    $xplot_hig += $mean;
    $xplot_low -= $mean;

    pgbegin(0,$device,1,1);               # Open plot device 
    pgsci(1);                             # default colour = white
    if ($linestyle && $font && $linewidth && $charheight) {
	pgsls($linestyle);                    # set line style
	pgscf($font);                         # Set character font 
	pgslw($linewidth);                    # Set line width 
	pgsch($charheight);                   # Set character height 
    }
    pgenv($xplot_low, $xplot_hig, $yplot_low, $yplot_hig, 0, 0);
    pglab($xtext, $ytext, $head);
    pgsci(15);                            # color 15 = light gray
    pgline($i,$xx,$yy);                   # plot the spectrum    
}



1;
