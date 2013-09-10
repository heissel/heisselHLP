#!/usr/bin/perl -I/home/tdall/Execs

#use warnings;
#use diagnostics;

#  bisector analysis of lines taken from a fits file.
#
# output goes to bisector.log, the parameters are:
# object  BJD  bis  b_b  b_n  RV/wl  v_bot  c_b  semicurv  semispan
#               *    *                 *     *                        <-- these are the 'good' ones...
#
# file can be multidimensional (like HARPS ccf files) or
# can be 1D as normal spectra.   
#
#  [-l <lower>]       lower bound of continuum-zoom
#  [-u <upper>]       upper bound for continuum-zoom
#  [-e <elem>]        descriptor to go into filename; could be element name or anything else
#  [ -N]              no normalization, continuum already at 1.0
#  [ -p]              make a ps file dump of final plot
#  [ -o <ord>]        spectral order  (default is 73 for ccf file and 1 for s1d spectra)
#  [ -r]              reversed spectrum; the line is an 'emission' feature
#  [ -b <num>]        batch processing; if file is a spectrum then -l and -u must be given to define 
#                     continuum (from <lower> to <lower>+<num> and <upper>-<num> to <upper>). If file
#                     is a ccf then only -U and -L must be given.
#  [ -L <low>]        lower x-value of line profile to interpolate. Required if -b
#  [ -U <upp>]        upper x-value of line profile to interpolate. Required if -b
#  [ -S <snr>]        S/N ratio in continuum. If given, errors on individual bisector points will be calculated.
#  [ -a]              Files are simple ascii files with wl and flux pairs. Comment lines contain # and are not read
#
# All ranges (-bulUL) are given in wavelength units.
#
use Math::Interpolate qw(robust_interpolate);
use Astro::FITS::CFITSIO;
use PGPLOT;
use Getopt::Std;
require "utils.pl";
require "pg_utils.pl";

getopts('u:l:e:No:prb:L:U:S:a');

$| = 1;
$command = "bisector.pl ";
$command .= "-a " if ($opt_a);
$command .= "-N " if ($opt_N);
$command .= "-p " if ($opt_p);
$command .= "-r " if ($opt_r);
$command .= "-S $opt_S " if ($opt_S);

if ($opt_b) {
    unless ($opt_L && $opt_U) {
	die "Please give -L and -U with -b\n";
    }
    $command .= "-b $opt_b -L $opt_L -U $opt_U ";
}

&bis_set_defaults();

$elem = "";
if ($opt_e) {
    $elem = $opt_e;
    $command .= "-e $elem ";
}
if ($opt_u && $opt_l) {
    $xplot_hig = $opt_u;
    $xplot_low = $opt_l;
    $command .= "-u $xplot_hig -l $xplot_low ";
} else {
    $xplot_hig = 0;           # means: will find and use full range later
    $xplot_low = 0;
}
if ($opt_o) {
    $order = $opt_o;
    $command .= "-o $order ";
} else {
    $order = 73;            # HARPS ccf files have the combined ccf in order 73
    # if 1D spectrum, this will be set to 1 later on
}

#
#  get filename, open it, and open the logfile
#
$next_file = 0;
open LOG, ">>bisector.log" or die "im37qjk883e";
print LOG "# $command @ARGV\n#\n";
foreach $file (@ARGV) {
    $next_file++;
    @x = ();   @y = ();
    if ($opt_a) {
	&read_ascii_spectrum_b;
    } else {
	&read_fits_spectrum_b;
    }
    chomp( $date = `date` );
    print LOG "# $date\n";

#
# if x-limits were given at run-time, then use those values, otherwise calculate now
# if more than one file, we may have to re-define limits or re-set to original values
#
    if ($opt_l && $opt_u) {
	$xplot_hig = $opt_u;
	$xplot_low = $opt_l;
    } elsif ($xplot_hig == 0 || $next_file > 1) {          
	($xplot_low, $xplot_hig) = low_and_high(@x);
	$mean = ( $xplot_hig - $xplot_low ) * 0.02;
	$xplot_hig += $mean;
	$xplot_low -= $mean;
    }


#  if y contains large numbers, then do a simple normalization
    unless ($opt_N) {
	@y = div_array( \@y, $y[4] );
    }



# if not batch mode then proceed...
    unless ($opt_b) {
#
# if not a ccf, then have a look to dertemine the line to look at
#
	unless ($ccf) {
	    &bis_redefine_arrays if ($opt_u && $opt_l);    # experimental......
	    &pg_plot_graph_Xfix(\@x,\@y, "", "", "$stem -- $object");
	    #
	    # get the exact limits of the plot
	    #
	    print "Please click on the left and right edges of the region to be investigated\n";
	    print "Now, first mark the left edge and exit.\n";
	    &pg_take_x_from_graph;
	    $xplot_low = $x;
	    print "Now, mark the right edge and exit.\n";
	    &pg_take_x_from_graph;
	    $xplot_hig = $x;
	    pgend();                  # end of the first plot
	    #
	    #  truncates @x and @y to contain only the interesting region
	    #  then replot to show it
	    #
	    &bis_redefine_arrays;
	}
	$num = @x;  

#
#  plot (again) the line and its surroundings
#
	&pg_plot_graph_Xfix(\@x, \@y, "", "", "$stem -- $object");

#
#  if not a ccf, thn it is the second plot. Check that it was truncated OK.
# 
	unless ($ccf) {
	    print "\nAre you satisfied with this cut [Y/n]? ";   $svar = <STDIN>;
	    if ($svar =~/[nN]/) {
		print "Please restart and try again then!\n";
		exit;
	    }
	}

#
#  normalize continuum: first mark the regions to be used for the continuum
#
	unless ($opt_N) {
	    print "Please mark a region of pure continuum:  Continuum will be the region\n";
	    print "from left edge of plot till the first click with the mouse, and from the\n";
	    print "position of the second mouse click till the right edge of plot.\n";
	    print "First mark right edge of the left continuum region, then exit\n";
	    &pg_take_x_from_graph;
	    &pg_plot_vertical_line($x, 1, 8);    # orange color
	    $i1 = int( ($x - $x[0])/$wl_inc );
	    print "Now mark left edge of the right continuum region and exit\n";
	    &pg_take_x_from_graph;
	    &pg_plot_vertical_line($x, 1, 8);    # orange color
	    $i2 = int( ($x - $x[0])/$wl_inc);  
	}
	pgend();
	
    } else {       # if batch mode, just normalize and redefine the array with input values
	if ($ccf) {
	    ($xplot_low, $xplot_hig) = low_and_high(@x);
	} else {
	    &bis_redefine_arrays;
	}
	$num = @x;
	$i1 = int( ($opt_b)/$wl_inc );
	$i2 = $num - $i1 - 1;
    }
    
    #
    #  calculate continuum and normalize
    #
    unless ($opt_N) {
	$cont = 0;  $nincont = 0;
	for ($i = 0; $i <= $i1; $i++) {
	    $cont += $y[$i];
	    $nincont++;
	}
	for ($i = $i2; $i <= $num-1; $i++) {
	    $cont += $y[$i];
	    $nincont++;
	}
	$cont /= $nincont;
	@y = div_array( \@y, $cont);
    }

#
# find the center of the line and split into left and right parts
#
    &pg_plot_graph_Xfix(\@x,\@y, "", "", "$stem -- $object");
    &pg_plot_horizontal_line( 1.0, 5, 8 ); # position, linestyle, color
    &pg_plot_vertical_line($x[$i2], 1, 8);    # orange color
    &pg_plot_vertical_line($x[$i1], 1, 8);    # orange color
    ($dum1, $y_top_of_line, $i_cent, $dum2) = low_and_high_index(@y);  #   print "TOP Y = $y_top_of_line\n";
    $i_cent = $dum2 if ($opt_r);                   # emission feature, so index of center is for highest point
    &pg_plot_vertical_line($x[$i_cent], 1, 10);    # bluish-green color
    print "Center is at pixel $i_cent, wl = $x[$i_cent]\n";
#
# find the useful range of the line interactively or automatically
#
    if ($opt_b) {
	$i_xlow = int( ($opt_L - $x[0])/$wl_inc );
	&pg_plot_vertical_line($x[$i_xlow], 1, 9);    # grenish-yellow color
	$i_xhig = int( ($opt_U - $x[0])/$wl_inc );
	&pg_plot_vertical_line($x[$i_xhig], 1, 9);    # grenish-yellow color
    } else {
	print "Now mark the left and right edges of the useful profile.\n";
	print "Mark left edge\n";
	&pg_take_x_from_graph;
	$i_xlow = int( ($x - $x[0])/$wl_inc );
	&pg_plot_vertical_line($x[$i_xlow], 1, 9);    # grenish-yellow color
	print "Mark right edge\n";
	&pg_take_x_from_graph;
	$i_xhig = int( ($x - $x[0])/$wl_inc );
	&pg_plot_vertical_line($x[$i_xhig], 1, 9);    # grenish-yellow color
    }
    pgend();
    if ($opt_r) {
	for ($i = $i_xlow; $i <= $i_xhig; $i++) {
	    $y[$i] = -1.0*$y[$i] + 2.0;
	}
    }
    $y_top_of_line = $y[$i_xlow];
    $y_top_of_line = $y[$i_xhig] if ( $y[$i_xhig] > $y[$i_xlow] );

#
# now construct the two sides of the line
#
    $rv = $x[$i_cent] unless ($ccf);     # use center of line if it is a spectrum
    @x_left = (); @y_left = (); @x_right = (); @y_right = ();
    for ($i = $i_xlow; $i <= $i_cent; $i++) {
	unshift @x_left, $x[$i]-$rv;                # rv if ccf, else set to cnter of line (see above)
	unshift @y_left, $y[$i];
    }
    for ($i = $i_cent; $i <= $i_xhig; $i++) {
	push @x_right, $x[$i]-$rv;                  # rv if ccf, else set to cnter of line (see above)
	push @y_right, $y[$i];
    }
    $pts_left = @x_left;
    $pts_right = @x_right;
    ($xplot_low, $xplot_hig) = ($x[$i1]-$x[$i_cent], $x[$i2]-$x[$i_cent]);
    unless ($opt_b) {
	&pg_plot_graph_Xfix( \@x_left, \@y_left, "", "", "$object -- $stem -- $elem$x[$i_cent]");
	pgline($pts_right, \@x_right, \@y_right);
    }
#
# Construct the interpolation of the two sides of the profile and find the bisector
#
    @sample = (); @left_int_x = (); @right_int_x = (); @bisec = (); @delt = ();
    ($ref_sample, $ref_bisec, $ref_delt) = construct_bisec(\@x_left, \@y_left, \@x_right, \@y_right);     # correspond to points on left profile
    @sample = @$ref_sample;   @bisec = @$ref_bisec;  @delt = @$ref_delt;
    @x_right = reverse(@x_right);  @y_right = reverse(@y_right);
    ($ref_sample, $ref_bisec, $ref_delt) = construct_bisec(\@x_right, \@y_right, \@x_left, \@y_left);     # correspond to points on right profile
    push @sample, @$ref_sample;   push @bisec, @$ref_bisec;  push @delt, @$ref_delt;
    &sort_bisector();
    pop @sample; pop @bisec; pop @delt;    # bottom point is not real...
    pop @sample; pop @bisec; pop @delt;    # bottom point is not real in both sides of the line...
    $numpts = @bisec;  
    
#
#  check if the plot is ok, otherwise discard the top point
#
    unless ($opt_b) {
	pgend();
	print "Is plot OK? Look for diverging edges [Y/n] ";  $dum1 = <STDIN>;
	if ($dum1 =~ /[nN]/) {
	    print "OK, discarding top point...\n";
	    shift @sample; shift @bisec; shift @left_int_x; shift @right_int_x;   $numpts--;
	}
    }

#
#  now plot the bisector and check if it is OK
#
    $dum1 = "n";
    $step = ( 1.0 - $y[$i_cent] ); # / $opt_n;
    while ($dum1 =~ /n/) {
	($xplot_low, $xplot_hig) = low_and_high(@bisec);
	@extra = low_and_high(@delt);
	$mean = ( $xplot_hig - $xplot_low );
	$xplot_hig += ($mean + $extra[1]);
	$xplot_low -= ($mean + $extra[1]);
	&pg_plot_graph_Xfix(\@bisec, \@sample, "", "", "$object -- $stem -- $elem$x[$i_cent]");
	pgtext(0.1,0.1,"$elem $x[$i_cent]");
	pgsci(4);
	pgpoint($numpts, \@bisec, \@sample, 17);
	&pg_plot_horizontal_line( 1.0, 5, 8 ); # position, linestyle, color
	&pg_plot_horizontal_line( $y[$i_cent], 5, 8 ); # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.10*$step, 4, 9 ); # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.40*$step, 4, 9 ); # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.55*$step, 4, 10 ); # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.90*$step, 4, 10 ); # position, linestyle, color
	pgsci(4);     print "numpts (2)= $numpts\n";
	for ($i = 0; $i < $numpts; $i++) {
	    pgline(2, [$bisec[$i]-$delt[$i],$bisec[$i]+$delt[$i]], [$sample[$i],$sample[$i]]);
	}
	pgend(); 
	if ($opt_b) {
	    $dum1 = " ";
	} else {
	    print "Is plot OK? Look for diverging edges [Y/n] ";  $dum1 = <STDIN>;
	    if ($dum1 =~ /[nN]/) {
		print "OK, discarding top point...\n";
		shift @sample;    shift @bisec;    shift @delt;  $numpts--;
	    }
	}
    }

#
#  calculate the BIS.  Top is 10-40%, Bottom is 55-90%
#
    $i_top = 0;  $i_bot = 0;   @lf_x = ();  @lf_y = ();      print "numpts(3) = $numpts\n";
    $step = ( 1.0 - $y[$i_cent] ); # here $step is the full extent of the line....
    for ($i = 0; $i < $numpts; $i++) {
	if ($sample[$i] < 0.9*$step+$y[$i_cent] && $sample[$i] > 0.6*$step+$y[$i_cent]) {
	    $top += $bisec[$i];
	    $i_top++;
	}
	if ($sample[$i] < 0.45*$step+$y[$i_cent] && $sample[$i] > 0.1*$step+$y[$i_cent]) {
	    $bot += $bisec[$i];
	    $i_bot++;
	}
	if ($sample[$i] < 0.75*$step+$y[$i_cent] &&  $sample[$i] > 0.2*$step+$y[$i_cent]) {
	    push @lf_x, $sample[$i];
	    push @lf_y, $bisec[$i];
	}
    }
    $top /= $i_top;   $bot /= $i_bot;
    $bis = $top - $bot;  print "BIS = $bis  ($i_top points in top, $i_bot in bottom)\n";
#
#   calculate the 'true' slope in the interval 25% - 80%
#
    ($a, $siga, $b, $sigb) = linfit( \@lf_x, \@lf_y );
    $bnorm = $b / ($lf_x[0] - $lf_x[-1]);
    print "slope = $b,  norm.slope = $bnorm\n";

#
#  calculate the three intervals and construct vbot and curvature
#
    @v1 = ();  @v2 = ();  @v3 = ();
    for ($j = 0; $j <= $i; $j++) {
	$fac = ($sample[$j] - $sample[-1]) / (1.0 - $sample[-1]);
	if ($fac < 0.8 && $fac > 0.7) {
	    push @v1, $bisec[$j];
	} elsif ($fac < 0.6 && $fac > 0.45) {
	    push @v2, $bisec[$j];
	} elsif ($fac < 0.25) {
	    push @v3, $bisec[$j];
	}
    }
    $num = @v1;
    $v1 = sum(@v1) / $num;
    $num = @v2;
    $v2 = sum(@v2) / $num;
    $num = @v3;
    $v3 = sum(@v3) / $num;


    $sum = sum( @bisec[-1,-2,-3,-4] );
    $b3 = $sum / 4.0;                   # vbot; velocity of last four points
    $b4 = ($v3 - $v2) - ($v2 - $v1);    # real curvature
    $b5 = ($v1 + $v2 + $v3) / 3.0;      # semi-curvature
    $b6 = $v3 - $v1;                    # velocity span


#
#  write the bisector to output file (name defined on reading input file)
#  also write to logfile
#
    if ($ccf) {
	if ($opt_e) {
	    $outfile = "${stem}_${elem}.bis";
	} else {
	    $outfile = "${stem}.bis";
	}
    } else {
	$outfile = sprintf "%7.2f",$x[$i_cent];
	$outfile = "${stem}_${elem}${outfile}.bis";
    }
    open OUT, ">$outfile" or die "nd27rhd";
    for ($i = 0; $i < $numpts; $i++) {
	print OUT "$sample[$i]  $bisec[$i]   $delt[$i]\n";
    }
    close OUT;
    print LOG "# object    BJD                  BIS            slope             norm.slope           RV   vbot     curv  sem.cur   span\n";
    print LOG "$object  $bjd   $bis   $b   $bnorm  $rv  $b3  $b4  $b5  $b6\n";
    chomp( $date = `date` );
    print LOG "# Finished $stem [$order] on $date\n\n";
    
#
# dump a PS file of the plot
#
    if ($opt_p) { 
	if ($ccf) {
	    $device = "${stem}_${elem}bis.ps/PS";
	} else {
	    $device = sprintf "%7.2f", $x[$i_cent];
	    $device = "${stem}_$elem${device}.ps/PS";
	}
	&pg_plot_graph_Xfix(\@bisec, \@sample, "$stem", "", "$object -- $rv");
	pgline(2, [$a + $b * $lf_x[0] +0.05, $a + $b * $lf_x[-1] +0.05 ], [$lf_x[0], $lf_x[-1]]);
	pgsci(4);
	pgpoint($numpts, \@bisec, \@sample, 17);
	&pg_plot_horizontal_line( 1.0, 5, 8 );   # position, linestyle, color
	&pg_plot_horizontal_line( $y[$i_cent], 5, 8 );   # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.10*$step, 4, 9 );   # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.40*$step, 4, 9 );   # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.55*$step, 4, 10 );   # position, linestyle, color
	&pg_plot_horizontal_line( 1.0-0.90*$step, 4, 10 );   # position, linestyle, color
	pgend();
    }

}  # closes the main loop; foreach $file (@ARGV)

close LOG;

exit;

########
########  END OF PROGRAM
########


# pod documentation to follow
#

=pod

=head1 NAME

bisector.pl - derive bisector of spectral lines


=head1 USAGE

bisector.pl [-a] [-N] [-p] [-r] [-e F<elem>] [-o F<order>] [-S F<snr>] [-l F<lower> -u F<upper>] [-b F<range> -L F<low> -U F<upp>] F<file(s)>


=head1 DESCRIPTION

Calculates the bisector for F<file(s)>, which can be either spectral lines, or cross-correlation functions (ccf's). These types are
referred to as I<s1d> (spectrum, one-dimensional) and I<ccf>. For the latter type, currently only HARPS ccf files are recognized.

The task will find the midpoint of the line for a number of intensity positions inside the line. Both the red and blue
wing is interpolated in turn: For each wing, the midpoints are calculated between each point in the wing and corresponding 
interpolated points at the same depth in the other wing. In interactive mode (default), the user will mark positions on the
plot with a left click (to mark position) followed by a right click (to accept the last marked position). 
Interactive mode can be overruled by the B<-b> option.

The bisector is written to a file, and a number of parameters are calculated. Please see section B<FILES> below, and 
the paper Dall et al. 2006, A&A, 454, 341 for details.

Options are as follows:

=over

=item B<-a>

Input F<files> are ascii format rather than fits. 

=item B<-N>

No normalization applied. The spectrum is plotted assuming continuum value of 1.

=item B<-p>

Make a PS file dump of the final bisector plot. See I<FILES> below.

=item B<-r>

Reversed profiles. The line is an emission feature.

=item B<-e> F<elem>

Optional descriptor to go into output file names.

=item B<-o> F<order>

Spectral order to be investigated. Defaults to 1 in case of I<s1d> spectra, and to 73 (the HARPS default) for
I<ccf> files.

=item B<-S> F<snr>

Signal-to-noise ratio in the continuum. If F<snr> is given, the errors on individual bisector points will be calculated,
plotted, and written to the output .bis file.

=item B<-l> F<lower>, B<-u> F<upper>

Lower and upper bound of the section around which to display and calculate the continuum. If omitted,
the full range of the order will be used.

=item B<-L> F<low>, B<-U> F<upp>

Lower (blue side) and upper (red side) positions in the profile between which to calculate bisector points. 
Intended for batch mode only - see B<-b> option.

=item B<-b> F<range>

Batch mode. Task runs without any manual intervention. Requires B<-L> and B<-U> as well. 
Runs slightly different, depending on whether F<file> is
a I<s1d> or I<ccf>:

=over

=item I<s1d>

Also F<lower> and F<upper> must be given via the B<-l> and B<-u> options. Continuum in this case is defined
as two regions, usually on either side of the line profile. One from F<lower> to F<lower>+F<range>, the other 
from F<upper>-F<range> to F<upper>.

=item I<ccf> 

In this case the F<lower> and F<upper> parameters are normally the endpoints of the order, and they can be omitted
unless one wants to zoom in on the line, e.g. in case of multi-peaked ccf's. 
The range is used like for I<s1d> spectra.

=back

=back

=head1 FILES

Some output files follow a naming convention that looks like F<file_[F<elem>][1234.56|ccf]>. The meaning of the components
are as follows:

If F<file> is a I<s1d> spectrum, then the approximate central 
wavelength is part of the output file name (instead of 1234.56), if F<file> is a I<ccf> file, then the string "ccf" will
be part of the output file name. The F<elem> string will be part of the output file name if given via the B<-e> option.

=over

=item F<bisector.log>

Contains descriptive comments about every file examined, prepended by a hash (#). For each file,
all the calculated bisector quantities are printed. For explanations of the individual
quantities, please see Dall et al. 2006, A&A, 454, 341. Output is in the following format:

object  BJD  bis  b_b  b_n  RV/wl  v_bot  c_b  semicurv  semispan

The following is a short description of each column. Measures deemed "good" are marked with a plus (+).

=over

=item I<object>: 

Target description taken from the fits header keyword HIERARCH ESO OBS TARG NAME. 

=item I<BJD>: 

Barycentric Julian Day

=item I<bis>: 

Bisector Inverse Slope (+)

=item I<b_b>: 

Bisector slope (+)

=item I<b_n>: 

Normalized (by the line depth) bisector slope

=item I<RV/wl>: 

Radial velocity from the header keywords (if HARPS ccf file) or approximate central wavelength.

=item I<v_bot>: 

Radial velocity average of bottom four point of bisector (+)

=item I<c_b>: 

Curvature (+)

=item I<semicurv>: 

Semi-curvature

=item I<semispan>: 

"Top" minus "bottom", resembling the velocity span.

=back


=item F<file_[F<elem>][1234.56|ccf].bis>

Two-column output file containing the calculated bisector.
First column is depth in line with continuum being equal to 1, second column is wavelength
or RV position at that depth. The bisector has had the RV subtracted in case of I<ccf> files, 
in which case the RV must be present in the fits image header. In case of I<s1d> spectra, 
the bisector have had the approximate central wavelength of the line subtracted. If the B<-S> option
was given, the 1-sigma error on each bisector point is calculated and included as a third column.

=item F<file_[F<elem>][1234.56|ccf].ps>

PS dump of the final bisector plot. Controlled by the B<-p> option. 

=back

=head1 REQUIREMENTS

The following Perl modules are required:

=over

=item Astro::FITS::CFITSIO

=item Math::Interpolate

=item PGPLOT

=back



=head1 BUGS & PENDING IMROVEMENTS

No bugs known.  

=over

=item 

Would be nice to have general recognition of ccf files, instead of just HARPS.

=item 

Allow for non-ESO header keywords (e.g. OBJECT alongside HIERARCH ESO OBS TARG NAME)

=back

=cut

#
# END of pod documentation


sub read_fits_spectrum_b {
    $stem = find_stem_of_fits($file);
    $fptr = Astro::FITS::CFITSIO::open_file($file,Astro::FITS::CFITSIO::READONLY(),$status);
    check_status($status) or die;

#
# check if it is a spectrum or an image with more dimensions (e.g. individual orders, HARPS ccf, etc)
# Then read the image dimensions, abd other information.
#
    $fptr -> read_key_str('NAXIS', $dim, undef, $status);
    $fptr -> read_key_str('HIERARCH ESO OBS TARG NAME', $object, undef, $status);
    print LOG "# Image $file has $dim dimensions\n";
#
# read the dimensions of the individual axis
#
    $fptr->read_key_str('NAXIS1',$naxis1,undef,$status);
    print LOG "# Spectrum has $naxis1 pixels\n";
    if ($dim > 1) {
	$fptr -> read_key_str('NAXIS2', $naxis2, undef, $status);
    } else {
	$naxis2 = 0;
    }    
#
# check if it is a HARPS ccf file...
#
    if ( $file =~ /ccf/ ) {     # it is a ccf file
	$ccf = 1;               # a flag...
	$fptr -> read_key_str('HIERARCH ESO DRS CCF RV', $rv, undef, $status);
	$fptr -> read_key_str('HIERARCH ESO DRS BJD', $bjd, undef, $status);
	print LOG "# Object $object has RV = $rv on BJD = $bjd\n";
    } else {
	die "Specify -u and -l for a 1D spectrum\n" unless ($opt_l && $opt_u);
	$ccf = 0;
	$order = 1;
	if ($file =~ /CES/) {
	    $fptr -> read_key_str('MJD-OBS', $bjd, undef, $status);
	    print LOG "# Object $object on MJD = $bjd\n";
	} elsif ($file =~ /HARPS/) {
	    $fptr -> read_key_str('HIERARCH ESO DRS BJD', $bjd, undef, $status);
	    print LOG "# Object $object on BJD = $bjd\n";
	} else {
	    $fptr -> read_key_str('DATE-OBS', $bjd, undef, $status);
	    print LOG "# Object $object on DATE-OBS = $bjd\n";
	}
    }

#
# prepare the wavelength/velocity scale
#
    $fptr -> read_key_str('CRVAL1', $wl_start, undef, $status);
    $fptr -> read_key_str('CDELT1', $wl_inc, undef, $status);
    for ($i = 0; $i < $naxis1; $i++) {
	push @x, $wl_start + $i * $wl_inc;
    }
# 
# read the fits data
#
    my ($array, $nullarray, $anynull);
    if ($dim > 1) {
	print "Reading ${naxis2}x${naxis1} image...";
	$fptr -> read_subset(Astro::FITS::CFITSIO::TDOUBLE(), [1,$order], [$naxis1,$order], [1,1], $nullarray, $array, $anynull ,$status);
    } else {
	print "Reading $naxis1 pixel image...";
	$fptr -> read_subset(Astro::FITS::CFITSIO::TDOUBLE(), 1, $naxis1, [1], $nullarray, $array, $anynull ,$status);
    }
    @y = @$array or die;
    print "done\n";

    $fptr -> close_file($status);
    check_status($status) or die;

}    



sub read_ascii_spectrum_b {
    open ASC, "<$file" or die "dm2n37kqwq3e82322";
    while (chomp( $in = <ASC> )) {
	next if $in =~ /\#/;
	$in =~ s/^\s+//s;
	($wl, $flux) = split /\s+/, $in;
	push @x, $wl;
	push @y, $flux;
    }
    close ASC;
    $ccf = 0;
    $order = 1;
    $stem = $file;
    $object = $file;
    $naxis1 = @x;
    $wl_inc = $x[1] - $x[0];
    $wl_start = $x[0];
    print LOG "# Image $file is an ascii-file with no headers\n";
    print LOG "# Spectrum has $naxis1 pixels\n";
}



sub sort_bisector {
    # sample values should be in descending order
    my $num = @sample;    print "sample has $num elements";
    my @tmps = @sample; 
    my @indices = ();
    for ($i = 0; $i < $num; $i++) {
	@res = low_and_high_index(@tmps);
	push @indices, $res[-1];
	$tmps[$res[-1]] = -1;
    }
    @sample = @sample[@indices];   $num = @sample;  print " - now $num elements\n";
    @bisec = @bisec[@indices];
    @delt = @delt[@indices];
}
    

	

sub construct_bisec {
    my @sample = ();   my @bisec = ();  my @delt = ();  my $ok; my @tmp = ();
    my ($rX, $rY, $rToIntX, $rToIntY) = @_;
    my @x = @$rX;   my @y = @$rY;   my @intX = @$rToIntX;   my @intY = @$rToIntY;
    my $num = @x;   my $othernum = @intX;
    ($miny, $maxy, $iminy, $imaxy) = low_and_high_index(@intY); 
    for ($i = 0; $i < $num; $i++) {        # walk through the profile
	@xx = (); @yy = (); @yyy = ();
	$ok = 0;
        CHECK:for ($j = 1; $j < $othernum; $j++) {
	    if (  ($intY[$j] > $y[$i] && $intY[$j-1] < $y[$i])  || ($y[$i] > $maxy) || ($y[$i] < $miny) )   {
		$j = $imaxy if ($y[$i] > $maxy);
		$j = $iminy if ($y[$i] < $miny);
		$ok = 1;
		last CHECK;
	    }
	}
	if ($ok) {
	    if ($j < 3) {
		$j = 3;
	    } elsif ($j > $othernum-3) {
		$j = $othernum-3;
	    }
	    for ($k = $j-3; $k <= $j+2; $k++) {
		push @xx, $intX[$k];
		push @yy, $intY[$k];
		push @yyy, $intY[$k] * $opt_S**2;
	    }
	    $new1 = robust_interpolate( $y[$i], \@yy, \@xx );
	    push @sample, $y[$i];
	    push @bisec, ($new1 + $x[$i])/2.0;
	    if ($opt_S) {      # if S/N specified, then calculate the noise on each bisector point
		@tmp = linfit( \@yyy, \@xx );
		#print "$tmp[0], slope =  $tmp[2] \n";
		push @delt,  abs($tmp[2]) * $opt_S / (2.0**0.5);
	    }
	    pgpoint(1, [($new1+$x[$i])/2.0], [$y[$i]], 3) unless ($opt_b);
	}  
    }
    return (\@sample, \@bisec, \@delt);
}



sub bis_redefine_arrays {
    $i1 = int( ($xplot_low - $wl_start)/$wl_inc );     # $num=@x; print "foer = $num, ";
    $i2 = int( ($xplot_hig - $wl_start)/$wl_inc );
    print "Start ($wl_start), Inc ($wl_inc) -> Index $i1 - $i2\n";
    @tmpx = ();   @tmpy = ();  $j = 0;
    for ($i = $i1; $i < $i2; $i++) {
	$tmpx[$j] = $x[$i];
	$tmpy[$j] = $y[$i];
	$j++;
    }
    @x = @tmpx;   print "X: $x[0] - $x[$j-1]\n";
    @y = @tmpy;   print "Y: $y[0] - $y[$j-1]\n";
    $wl_start = $xplot_low;
}



sub bis_set_defaults {

    $status = 0;
    $device = "/XSERVE";             # default device
    $font = 2;
    $linewidth = 4;
    $charheight = 1.6;
    $symbol = 17;
    $linestyle = 1;

}







# TMP  # TMP # TMP  # TMP
###   ###   ###   ####  ####
#&pg_plot_graph(\@left_int_x, \@sample, "", "", "interpolation check");
#pgsci(4);
#pgpoint($numpts, \@left_int_x, \@sample, 21);
#pgsci(7);
#pgline($pts_left, \@x_left, \@y_left);
#pgend();
#sleep 3;
#&pg_plot_graph(\@right_int_x, \@sample, "", "", "interpolation check");
#pgsci(4);
#pgpoint($numpts, \@right_int_x, \@sample, 21);
#pgsci(7);
#pgline($pts_right, \@x_right, \@y_right);
#pgend();
#sleep 3;
###   ###   ###   ####  ####
# TMP  # TMP # TMP  # TMP


