#!/usr/bin/perl -I/home/tdall/Execs

# uncomment these for development
#use diagnostics;
#use warnings;
use PGPLOT;                     # NOTE: requires the perl PGPLOT interface to work
use Astro::FITS::CFITSIO;
use Getopt::Std;
require "utils.pl";
###require "pg_utils.pl";    # not required. Only for future developmentx

getopts('f:shy:xd:l:u:L:U:bv:');


if ($opt_h) {
    print "caIIcalib.pl [-s|-S] [-h] [-y <ymax>] [-x] [-v RV] [-d <delLambda>] [-f <param-file>]\n";
    print "             [-b] [-l <lamb>] [-u <lamb>] [-L <lamb>] [-U <lamb>] [<spec1> ...]\n\n";
    print "-h : Shows this help message.\n";
    print "-s : Work on specified spectra <spec1>..., the names of which must also be\n";
    print "     given on the command line. Is -s is omitted, calculations will be based\n";
    print "     on the <param-file> or the parameters will be prompted for.\n";
    print "     This is the DEFAULT.\n";
    print "-S : Do not look for spectra, only calculate using the values in <param-file>.\n";
    print "-f : Use the <param-file>. If omitted, the parameters will be prompted for.\n";
    print "-d : Wavelength range to plot +/- around the center of the Ca lines.\n";
    print "     Defaults to 4 AA.\n";
    print "-v : Radial velocity. Calculation intervals will be corrected.\n";
    print "-x : Print example of <param-file>\n";
    print "-y : y-max of plot\n";
    print "-b : batch mode. Specify the lower and upper bounds with -l -u for the K line,\n";
    print "     and -L -U for the H line\n\n";
    print "caIIcalib.pl will calculate the logR_HK activity index, based on interactive\n";
    print "measurements in spectra that are displayed by the program.  Alternatively, the\n";
    print "calculations can be based on numbers taken from the <param-file>.  In any case\n";
    print "<param-file> should be present, providing values for Teff, V-R and the values\n";
    print "of F^RE_H and F^RE_K (see Linsky et al. 1979, ApJS 41,47).\n";
    print "Run with -x for an example of the <param-file> syntax.\n";
    exit;
}
if ($opt_x) {
    print "Example of the <param-file>. The first seven lines must contain only one entry.\n";
    print "Remaining lines are for comments:\n--------------------------------------------\n";
    print "5240\n";
    print "21.168\n";
    print "23.37888\n";
    print "1338.25\n";
    print "0.67\n";
    print "75000\n";
    print "75000\n";
    print "                                   # all remaining lines are ignored\n";
    print "Teff = 5240                        # First line above is effective temperature.\n";
    print "f_H = 21.168                       #    Lines 2-4 only used if -S is given,\n";
    print "f_K = 23.37888                     #    else they are measured interactively\n";
    print "f_50 = 1338.25                     #    and the listed values ignored\n";
    print "V - R = 0.67                       # Fifth line is the V - R value.\n";
    print "F-RE_H = 75000                     # Correction term for H line\n";
    print "F-RE_K = 75000                     # Correction term for K line\n";
    exit;
}

if ($opt_v) {
    $radvel = $opt_v;
} else {
    $radvel = 0.0;
}
if ($opt_d) {
    $delta = $opt_d;
} else {
    $delta = 4.0;
}
if ($opt_y) {
    $ymax = $opt_y;
}
if ($opt_b) {   # batch mode
    if ($opt_l && $opt_u && $opt_L && $opt_U) {
	
    } else {
	die "must spcify -l, -u, -L, -u\n";
    }
}
$sigmaSB = 5.6705e-5;      # erg cm^-2 s^-1 K^-4

if ($opt_f) {
    open IN, "<$opt_f" or die "dsdfsdfsww";
    chomp( $teff = <IN> );
    chomp( $fh = <IN> );
    chomp( $fk = <IN> );
    chomp( $f50 = <IN> );
    chomp( $vmr = <IN> );
    chomp( $fREh = <IN> );
    chomp( $fREk = <IN> );
    close IN;
} else {
    print "Teff = "; chomp( $teff = <STDIN> );
    print "f_H = "; chomp( $fh = <STDIN> );
    print "f_K = "; chomp( $fk = <STDIN> );
    print "f_50 = "; chomp( $f50 = <STDIN> );
    print "V - R = "; chomp( $vmr = <STDIN> );
    print "F-RE_H = "; chomp( $fREh = <STDIN> );
    print "F-RE_K = "; chomp( $fREk = <STDIN> );
}

# open the logfile
open LOG, ">>caIIcalc.log" or die "cannot open logfile";

# if spectra, then plot and take values. f50, fk, fh will be replaced.
unless ($opt_S) {
    foreach $spec (@ARGV) {
	if ($spec =~ /fits$/) {
	    ($r_x, $r_y) = read_fits_spectrum($spec);
	    @x = @$r_x;   @y = @$r_y;
	    chomp( $jd = `dfits $spec | fitsort -d "HIERARCH ESO DRS BJD"` );
	    chomp( $jd = `dfits $spec | fitsort -d "DATE"` ) unless ($jd);
	    @tmparr = split /\s+/, $jd;    $jd = $tmparr[1];
	    chomp( $targ = `dfits $spec | fitsort -d "HIERARCH ESO OBS TARG NAME"` );
	    @tmparr = split /\s+/, $targ;    $targ = $tmparr[1];
	} else {
	    &read_ascii_file;
	}
	
	$numsmall = @y;
	$stem = find_stem_of_fits($spec);

	chomp( $date = `date` );
	print LOG "# Starting calculation on $stem at $date\n";
	# calculate radial velocity offset
	$rvoffK = $radvel * 3933.65 / 299790.0;   # xxx insert correct c
	$rvoffH = $radvel * 3968.47 / 299790.0;   # xxx insert correct c

	if ($opt_b) {   # batch mode...
	    $fk = sum_up( $opt_l, $opt_u );
	    $fh = sum_up( $opt_L, $opt_U );
	} else {
	    $xplot_low = 3933.65-$delta;  $xplot_hig = 3933.65+$delta;        # plot the K line
	    &plot_and_get_pos;
	    $fk = sum_up( $left, $rigt); # print "fK: from $left to $rigt gives $fk\n";
	    $delt1 = 3933.65 - ($left + $rigt) / 2.0;  #  print "delt1 = $delt1\n";
	    $xplot_low = 3968.47-$delta;  $xplot_hig = 3968.47+$delta;        # plot the H line
	    &plot_and_get_pos;
	    $fh = sum_up( $left, $rigt);  # print "fH: from $left to $rigt gives $fh\n";
	    $delt2 = 3968.47 - ($left + $rigt) / 2.0;   # print "delt2 = $delt2\n";
	}
	$delt = ($delt1 + $delt2) / 2.0;
	$f50 = sum_up( 3925.0 - $delt, 3975.0 - $delt );   #  print "f50: $f50\n";  # get f50

	print "$spec:  ";
	&calculateRHK;
	chomp( $date = `date` );
	print LOG "# Finished on $date\n\n";

    } # end of 'for each spectrum'

} # end of 'if spectra'
else {
    &calculateRHK;
}

close LOG;

exit if ($opt_s || $opt_x || $opt_h);   # to suppress warnings

#### END OF MAIN PROGRAM


# pod documentation follows
#

=pod

=head1 NAME

caIIcalib.pl - Calculate the emission measure R_HK in the calcium H and K lines.

=head1 USAGE

caIIcalib.pl [-s|-S] [-h] [-y ymax] [-x] [-d delLambda] [-v radvel] [-f F<param-file>] [-b] [-l lamb] [-u lamb] [-L lamb] [-U lamb] [F<spec1> ...]\n\n";

=head1 DESCRIPTION

caIIcalib.pl will calculate the logR_HK activity index, based on interactive
measurements in spectra that are displayed by the program.  Alternatively, the
calculations can be based on numbers taken from the F<param-file>.  In any case
F<param-file> should be present, providing values for Teff, V-R and the values
of F^RE_H and F^RE_K for the given star (see Linsky et al. 1979, ApJS 41,47).
Run with B<-x> for an example of the F<param-file> syntax.

=over

=item B<-h>  

Displays a brief help message.

=item B<-s>  

Work on specified spectra <spec1>..., the names of which must also be
given on the command line. If -s is omitted, calculations will be based
on the <param-file> or the parameters will be prompted for.
This is the DEFAULT.

=item B<-S>  

Do not look for spectra, only calculate using the values in <param-file>.

=item B<-f>  

Use the <param-file>. If omitted, the parameters will be prompted for.

=item B<-d>  

Wavelength range to plot +/- around the center of the Ca lines. Defaults to 4 AA.

=item B<-v>

Radial velocity of the star. The summation intervals and the plots will be corrected to zero velocity.
B<Not yet implemented!>

=item B<-x>  

Print example of F<param-file>.

=item B<-y>  

y-max of plot. Can be useful if emission core is very strong, and the 1V and 1R points are hard to find. 

=item B<-b>  

Batch mode. Specify the lower and upper bounds with -l -u for the K line, and -L -U for the H line.
B<?????? - defunct, do not use.>

=back

=head1 FILES

The typical way of running caIIcalib is to use the parameter file specified with the B<-f> option. If
you're using caIIcalib for the first time, you can generate a parameter file by using the B<-x> option and
redirecting (>) the output to a new parameter file. In this case, don't forget to remove the first three descriptive lines
of the output.

=head1 REQUIREMENTS

The following perl modules are required:

=over

=item Astro::FITS::CFITSIO

=item PGPLOT

=back

=head1 BUGS & PENDING IMROVEMENTS

No bugs known.  

=over

=item 

Should have a RV corretion feature to center the f50 interval properly.

=item

Replace dfits/fitsort calls with CFITSIO module calls.

=back

=cut

#
# END of pod documentation



#### BEGIN SUBROUTINES


sub read_ascii_file {
    open SPEC, "<$spec" or die "aaldufhnmm,,";
    @x = ();   @y = ();   $x = 0;
    while ( chomp( $in = <SPEC> ) ) {
	($x, $y) = split /\s+/, $in;
	if ($x > 3900) {         # only take up to 4000 AA
	    push @x, $x;  push @y, $y;
	}
	last if $x > 4000;
    }
    close SPEC;
}


sub calculateRHK {

    if ($vmr < 1.3) {
	$f = 10**(8.264 - 3.076 * $vmr);
    } else {
	$f = 10**(5.5 - 0.944 * $vmr);
    }
    
    $fk1 = 50 * $fk * ($f / $f50);
    $fh1 = 50 * $fh * ($f / $f50);
    
    $fk1 = $fk1 - $fREk;
    $fh1 = $fh1 - $fREh;

    $div = $sigmaSB * $teff**4;

    $rhk = ($fk1 + $fh1) / $div;

    $rhk = 0.4342944819 * log($rhk);    # converts base e log to base 10 log.

    print "log R_HK = $rhk\n"; 
    print LOG "$targ   $jd  $rhk\n";
}



sub mark_position {
    my ($x, $y, $key);
    $key = "a";  $x = $xplot_low;  $y = $yplot_low;
    while ($key !~ /[xX]/) {
	pgcurs( $x, $y, $key );
	if ($key =~ /[xX]/) {
	    last;
	} 
	print "Position = $x\n";
	$pos = $x;
    }
}


sub plot_and_get_pos {
    &init_graph;
    ($yplot_low, $yplot_hig) = low_and_high(@y); 
    $yplot_hig = $ymax if ($opt_y);
    pgenv($xplot_low, $xplot_hig, $yplot_low, $yplot_hig, 0, 0);
    pgline($numsmall, \@x, \@y);
    print "Mark the LEFT side of the profile (1V). Right-click when satisfied\n";
    &mark_position;
    $left = $pos;
    print "Mark the RIGHT side of the profile (1R). Right-click when satisfied\n";
    &mark_position;
    $rigt = $pos;
    &end_graph;
}

sub init_graph {
    $device = "/XSERVE";
    $font = 2;
    $linewidth = 4;
    $charheight = 1.6;
    $numrows = 1;
    $numcols = 1;

    pgbegin(0,$device,$numcols,$numrows); # Open plot device 
    pgscf($font); # Set character font 
    pgslw($linewidth); # Set line width 
    pgsch($charheight); # Set character height 
}

sub end_graph {
    pgend;
}

sub low_and_high{
    my ($hig,$low);
    @somearr = @_;
    $hig = $somearr[0];
    $low = $hig;
    foreach $test (@somearr) {
	if ($test > $hig) {
	    $hig = $test;
	}
	if ($test < $low) {
	    $low = $test;
	}
    }
    return ($low,$hig);
}

sub sum_up {
    my ($x1,$x2,$sum,$num,@tmp);
    ($x1,$x2) = @_;
    # find index values of the two x values
    $num = @x;   @tmp = ();  $i1 = 0;
    for ($i=0; $i < $num; $i++) {
	if ($x[$i] >= $x1) {
	    $i1 = $i;
	}
	if ($i1) {
	    push @tmp, $y[$i];
	}
	if ($x[$i] >= $x2) {
	    last;
	}
    }
    $sum = sum( @tmp ); #  print "summming up to $sum between $x1 and $x2, array had $num points\n";
    return $sum;
}

sub sum {  # summerer et givet array
    use strict;
    my($sum,$e);
    $sum=0;
    foreach $e (@_) {
        $sum += $e;
    }
    return $sum;
}

