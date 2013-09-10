#!/usr/bin/perl -I/home/tdall/Execs

#use warnings;
#use diagnostics;

#  bisector analysis of lines taken from an ascii file, containing the 
#  output from bisector.pl


#use Math::Interpolate qw(robust_interpolate);
#use PGPLOT;
#use Getopt::Std;
require "utils.pl";
#require "pg_utils.pl";

foreach $file (@ARGV) {

    open IN, "<$file" or die "md723 fw1-12";

    $i = 0;
    @v1 = ();  @v2 = ();  @v3 = ();
    while ($in = <IN>) {
	@tmp = split /\s+/, $in;
	$sample[$i] = $tmp[0];  
	$bisec[$i] = $tmp[1];
	$i++;
    }
#    $normfac = $sample[-1];     # this is 0% of line, top is 100%
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

    #calculate the velocity of last four points
    $sum = sum( @bisec[-1,-2,-3,-4] );
    $b3 = $sum / 4.0;
#    $sum = sum( @bisec[-11, -12, -13, -14, -15, -16] );
#    $b5 = $sum / 6.0;
#    $b4 = $b5 - $b4;

    $b4 = ($v3 - $v2) - ($v2 - $v1);    # real curvature
    $b5 = ($v1 + $v2 + $v3) / 3.0;      # semi-curvature
    $b6 = $v3 - $v1;                    # velocity span

    print "$b3   $b4    $b5   $b6\n";


} # end of "foreach $file (@ARGV)"
