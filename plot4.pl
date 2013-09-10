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

unless ( $file == 2 ) {
    print "plot.pl [-v RV] [-s] [-p] [-f] filename O|A|B|F|G|K|M|y|l\n\n";
}
if ($opt_v) {
    $radvel = $opt_v;
} else {
    $radvel = 0.0;
}

$file = $ARGV[0];
$startype = $ARGV[1];
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
$xmax = $x[-1];
$xmin = $x[0];

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
    if ($numiny) {          # protect against outside spectral coverage
	$mean /= $numiny;
	$sig = sigma( $mean, @ycut ); 
    }
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
    &WilsonBappu if ($startype =~ /[zZ]/ && $key =~ /CaK/);
    &lithium if ($startype =~ /[yYZ]/ && $key =~ /Li/);
}

pgsci(2);
pgmtxt('r', 1.1, 0.0, 0.0, "$file");
pgend;

print "\n";
print "$text{$startype}\n";
print "\n";



#
# subroutines
#

sub lithium {
    # plot other color for the lithium line
    pgsci(7);
    pgline( 2, [6707.8 + ( $radvel * 6707.8 / 300000.0), 6707.8 + ( $radvel * 6707.8 / 300000.0)],
	    [$yplot_hig,$yplot_hig-$sizeline] );
    pgsci(1);
}

sub WilsonBappu {
    # plot lines for Mv estimate
    pgsls(4);
    @offset = (  # in km/s WB width
		125.0, 70.0, 40.0, 22.0
		  # Mv = -5, 0, 5, 10
		  );
    for ($j=0; $j<4; $j++) {
	pgsci(7+$j);
	pgline( 2, 
		[3933.66 + ( ($radvel+$offset[$j]/2.0) * 3933.66 / 300000.0), 3933.66 + ( ($radvel+$offset[$j]/2.0) * 3933.66 / 300000.0)],
		[$yplot_hig,$yplot_low] );
	pgline( 2, 
		[3933.66 + ( ($radvel-$offset[$j]/2.0) * 3933.66 / 300000.0), 3933.66 + ( ($radvel-$offset[$j]/2.0) * 3933.66 / 300000.0)],
		[$yplot_hig,$yplot_low] );
    }
    pgsls(1)
}

sub init_hashes {
#    print "Looking at a $startype star\n";
    if ($startype =~ /O/) {
	%xhig = (
		 He1He2 => 4560,
		 Si4Hdel => 4130,
		 N3He1 => 4395,
		 Si4He1 => 4125
		 );
	%xlow = (
		 He1He2 => 4460,
		 Si4Hdel => 4080,
		 N3He1 => 4370,
		 Si4He1 => 4112
		 );
	%lines = (
		  He1He2 => [4471.479, 4542],
		  Si4Hdel => [4088.85, 4101.74],
		  N3He1 => [4379.11, 4387.929],
		  Si4He1 => [4116.10, 4120.99]
		  );
    } elsif ($startype =~ /B/) {
	%xhig = (
		 He1Mg2Si3 => 4560,
		 He1Heps => 4040,
		 HgamHe1O2 => 4430,
		 He1O2Hdel => 4130,
#		 Si3He1 => 4560
		 );
	%xlow = (
		 He1Mg2Si3 => 4460,
		 He1Heps => 3950,
		 HgamHe1O2 => 4330,
		 He1O2Hdel => 4020,
#		 Si3He1 => 4460
		 );
	%lines = (
		  He1Mg2Si3 => [4471.479, 4481.13, 4481.327, 4552.62],
		  He1Heps => [4026.191, 3970.07],
		  HgamHe1O2 => [4387.929, 4340.47, 4416.974, 4348],
		  He1O2Hdel => [4101.74, 4070, 4076, 4026.2],
#		  Si3He1 => [4471.479, 4552.62]
		  );
    } elsif ($startype =~ /A/) {
	%xhig = (
		 CaHKHeps => 4000,
#		 Ca1Fe1 => 4280,
		 HdelFeTiSi2 => 4185,
		 Hgam => 4390,
		 H8H9 => 3890,
#		 Halpha => 6600
		 );
	%xlow = (
		 CaHKHeps => 3925,
#		 Ca1Fe1 => 4220,
		 HdelFeTiSi2 => 4100,
		 Hgam => 4300,
		 H8H9 => 3830,
#		 Halpha => 6520
		 );
	%lines = (
		  CaHKHeps => [3933.66, 3968.47, 3970.07],
#		  Ca1Fe1 => [4226.728, 4271.759],
		  HdelFeTiSi2 => [4101.74, 4128, 4130, 4172, 4178],
		  Hgam => [4340.47],
		  H8H9 => [3889.05, 3835.39],
#		  Halpha => [6562.797]
		  );
    } elsif ($startype =~ /F/) {
	%xhig = (
		 Gband => 4350,
		 CaBalmer => 4000,
		 ionCa1 => 4235,
		 Sr2Hdel => 4130
		 );
	%xlow = (
		 Gband => 4200,
		 CaBalmer => 3860,
		 ionCa1 => 4165,
		 Sr2Hdel => 4070
		 );
	%lines = (
		  Gband => [],
		  CaBalmer => [3933.66, 3968.47, 3970.07, 4026.2],
		  ionCa1 => [4226.728, 4173.461, 4177.196, 4178.9, 4171.91, 4174.072],
		  Sr2Hdel => [4101.74, 4077.71]
		  );
    } elsif ($startype =~ /G/) {
	%xhig = (
		 Fe1Hdel => 4115,
		 Fe1Hgam => 4355,
		 FeCrFe => 4265,
		 Y2Fe1 => 4390
		 );
	%xlow = (
		 Fe1Hdel => 4040,
		 Fe1Hgam => 4320,
		 FeCrFe => 4245,
		 Y2Fe1 => 4370
		 );
	%lines = (
		  Fe1Hdel => [4101.74, 4045.813],
		  Fe1Hgam => [4340.47, 4325.761],
		  FeCrFe => [4254.332, 4250.786, 4260.474],
		  Y2Fe1 => [4374.935, 4383.545]
		  );
    } elsif ($startype =~ /K/) {
	%xhig = (
		 CaI => 4245,
		 Y2Fe1 => 4390,
		 CaFe => 4395,
		 FeCrFe => 4265
		 );
	%xlow = (
		 CaI => 4215,
		 Y2Fe1 => 4370,
		 CaFe => 4210,
		 FeCrFe => 4245
		 );
	%lines = (
		  CaI => [4226.728],
		  Y2Fe1 => [4374.935, 4383.545],
		  CaFe => [4226.728, 4383.545],
		  FeCrFe => [4254.332, 4250.786, 4260.474]
		  );
    } elsif ($startype =~ /M/) {
	%xhig = (
		 CaH => 3990,
		 CaI => 4245,
		 TiO => 5200,
		 CaOH => 5590
		 );
	%xlow = (
		 CaH => 3950,
		 CaI => 4215,
		 TiO => 4700,
		 CaOH => 5400
		 );
	%lines = (
		  CaH => [3968.47, 3970.07],
		  CaI => [4226.728],
		  TiO => [4861.33],
		  CaOH => []
		  );
    } elsif ($startype =~ /[yY]/) {
	%xhig = (
		 Li => 6714,
		 CaIRT => 8690,
		 Halpha => 6600,
                 CaHK => 4050,
		 );
	%xlow = (
		 Li => 6694,
		 CaIRT => 8630,
		 Halpha => 6520,
                 CaHK => 3860,
		 );
	%lines = (
		  Li => [6707.8, 6712.67, 6696.02, 6703.567, 6705.1, 6710.319],
		  CaIRT => [8662.14],
		  Halpha => [6562.797],
                  CaHK => [3933.66, 3968.47, 3970.07, 4026.2],
		  );
    } elsif ($startype =~ /[lL]/) {
	%xhig = (
		 NaD => 5900,
		 MgTriplet => 5188,
		 O7771 => 7780,
		 Halpha => 6580
		 );
	%xlow = (
		 NaD => 5870,
		 MgTriplet => 5163,
		 O7771 => 7767,
		 Halpha => 6545
		 );
	%lines = (
		  NaD => [5895.924, 5889.951, 5875.6],
		  MgTriplet => [5167.322, 5172.684, 5183.604],
		  O7771 => [7771.94, 7774.17, 7775.39],
		  Halpha => [6562.797]
		  );
    } elsif ($startype =~ /[z]/) {
	%xhig = (
		 NaD => 5898,
		 CaI => 4233,
		 CaK => 3936,
		 Halpha => 6570
		 );
	%xlow = (
		 NaD => 5887,
		 CaI => 4220,
		 CaK => 3932,
		 Halpha => 6556
		 );
	%lines = (
		  NaD => [5895.924, 5889.951, 5875.6],
		  CaI => [4226.728],
		  CaK => [3933.66],
		  Halpha => [6562.797]
		  );
    } elsif ($startype =~ /[Z]/) {
	%xhig = (
		 Li => 6710,
		 NaD => 5898,
		 CaK => 3936,
		 Halpha => 6570
		 );
	%xlow = (
		 Li => 6702,
		 NaD => 5887,
		 CaK => 3932,
		 Halpha => 6556
		 );
	%lines = (
		 Li => [6707.8, 6712.67, 6696.02, 6703.567, 6705.1, 6710.319],
		  NaD => [5895.924, 5889.951, 5875.6],
		  CaK => [3933.66],
		  Halpha => [6562.797]
		  );
    } else {
	print "ERROR: invalid type!\n";
	exit;
    }
    %text = (
	     O => " === O stars ===
Spectral type: characterized by lines of neutral helium (He I) and 
of singly ionized helium (He II). The spectral type can be judged easily 
by the ratio of the strengths of lines of He I to He II; He I tends to 
increase in strength with decreasing temperature while He II decreases in 
strength. The ratio He I 4471 to He II 4542 shows this trend clearly.

Luminosity type: in the O7 supergiant star, the N III 4634-42 feature actually 
goes into emission and the neighboring He II 4686 line decreases in strength 
(in O6 stars, it actually goes into emission in the supergiant). Note that the 
nearby He II 4542 line actually increases slightly in strength as we move 
toward higher luminosities.
   At O9 the hydrogen lines show a more pronounced sensitivity to luminosity 
than at earlier (hotter) types. In addition, the ratio of Si IV 4089 (which 
increases in strength as we pass to higher luminosities) to Hdelta (which 
becomes narrower and weaker in the more luminous stars), the ratio of 
Si IV 4116 to the neighboring He I 4121 line, and the ratio of N III 4379 
to He I 4387 can be used to judge the luminosity class at O9.",
	     B => " === B stars ===
Spectral type: The definition of the break between the O-type stars and 
the B-type stars is the absence of lines of ionized helium (He II) in the 
spectra of B-type stars. The lines of He I pass through a maximum at 
approximately B2, and then decrease in strength towards later (cooler) types. 
A useful ratio to judge the spectral type is the ratio of HeI 4471/MgII 4481.
As we move toward later (cooler) types, the helium lines continue to fade 
until they essentially disappear at a spectral type of about A0.

Luminosity type: While the width and strength of the hydrogen lines is a useful
luminosity criterion at B1, the sensitivity of the O II lines (see O II 4070, 
4348 and 4416), especially in ratio with the hydrogen lines and the He I lines 
(which tend to weaken with increasing luminosity) helps to increase the 
precision of luminosity classification at B1. Note the Si III 4553 line can be 
used to discriminate between dwarf (V) and (III) classes around B1.  At B5 the 
only luminosity-sensitive features in the spectrum are the hydrogen lines. 
The He I lines show little or no sensitivity to luminosity. Fortunately, the 
sensitivity of the hydrogen lines to luminosity is much more pronounced at B5 
than in earlier types.",
	     A => " === A stars ===
Spectral type: At A0, the Ca II K-line becomes a notable feature in the 
spectrum (in the B-type stars, the K-line often is mostly interstellar), and 
increases dramatically in strength as we move toward later spectral types. 
However, it is well to keep in mind that in the peculiar A-type stars and the 
metallic-line A-type stars, the strength of the Ca II K-line is almost always 
too weak for the spectral type. In addition, the general metallic-line 
spectrum, almost invisible in the B-type stars, becomes evident and 
strengthens through the A-type stars. The Mg II 4481 line changes little in 
strength in the A-type stars. As we move toward later (cooler) types along the 
main sequence after A5, the hydrogen lines now begin to weaken, as the hydrogen
lines reach their maximum strength in the early A-type stars.

Luminosity type: Near a spectral type of A0, the primary luminosity criterion 
is the progressive widening and strengthening of the hydrogen lines with 
decreasing luminosity. Notice as well that certain lines of ionized iron 
(especially Fe II 4233), certain blends of Fe II and Ti II (especially 
4172-8 Å) and the Si II doublet (4128 - 30 Å) are enhanced in the supergiants.
Strong lines between H8 and H9 could indicate supergiant around A0.",
	     F => " === F stars ===
Spectral type: The Ca II K-line continues to strengthen, although it becomes 
essentially saturated by the late F-type stars. The general strength of the 
metallic-line spectrum grows dramatically. Around F2, depending upon the 
resolution of the spectrum, the G-band makes its first appearance. 

Luminosity type: By F0, the hydrogen lines have lost most of their sensitivity 
to luminosity. Note, however, that they can still be used to distinguish the 
supergiant classes from lower luminosities. Near F0, the luminosity class is 
estimated from the strength of lines due to ionized iron and titanium. 
Excellent luminosity-sensitive features include the Fe II, Ti II double blend 
at 4172-8, and similar blends at 4395-4400, 4417 and 4444. The strength of 
these blends are usually estimated with respect to other less luminosity 
sensitive features, such as Ca I 4227, Fe I 4271 and Mg II 4481.
   By F5, the hydrogen lines have lost all sensitivity to luminosity, and we 
must now rely solely on lines and blends of ionized species. The luminosity 
sensitive features are essentially the same as at F0, except that at F5 and 
later types, we can use the Sr II 4077 line with some confidence. Also note 
that at F5 (and later types), the Ca II K-line shows a slight positive 
sensitivity to luminosity, in the sense that it becomes slightly broader 
in the more luminous stars.",
	     G => " === G stars ===
Spectral type: There is no one single indicator of the G-K transistion. The 
hydrogen lines continue to fade through the G types, while the strength of 
the general metallic-line spectrum continues to increase. The G-band continues
to increase in strength until the early K-type stars (about K2), and then 
begins to fade. The Ca I 4227 line grows gradually in strength until the early
K stars. The ratios Fe I 4046/Hdelta and Fe I 4325/Hgamma are useful in 
estimating the temperature type, reversing at a spectral type near G8. 
Unfortunately, these ratios are not reliable in metal-weak or metal-strong 
stars. The temperature type may be estimated with precision, even in metal-weak
stars by using the ratio of the Cr I 4254 line with the two neighboring Fe I 
lines at 4250 and 4260. Notice that the Cr I line (which arises from a 
low-lying level) becomes stronger in ratio with the two flanking Fe I lines, 
being clearly stronger than both by K5.

Luminosity type: The primary luminosity discriminant at G0 is the strength of 
the Sr II 4077 line. Of use as well are the blends of Ti II and Fe II which 
were used in the F-type stars to distinguish luminosity types. For instance, 
Ti II, Fe II 4172-8, and Ti II, Fe II 4444 (in ratio with Mg II 4481) continue 
to be useful. At G8 the ratio of Sr II 4077 to nearby iron lines (Fe I 4046, 
4063, 4071) remains sensitive to luminosity. The violet-system CN bands, with 
bandhead at 4216 , visible in the supergiant and giant spectra as a concavity 
in the continuum, show a strong sensitivity to luminosity. Notice as well that 
the Ca II K and H lines show extremely broad damping wings in the supergiant 
class. But the criterion affording the greatest discrimination in the 
luminosity classes is the ratio of the YII 4376 line to Fe I 4383.",
	     K => " === K stars ===
Spectral type: The G-band continues to increase in strength until the early 
K-type stars (about K2), and then begins to fade. The Ca I 4227 line grows 
gradually in strength until the early K stars, and then becomes dramatically 
stronger by mid-K. The temperature type may be estimated with precision, even 
in metal-weak stars by using the ratio of the Cr I 4254 line with the two 
neighboring Fe I lines at 4250 and 4260. Notice that the Cr I line (which 
arises from a low-lying level) becomes stronger in ratio with the two flanking 
Fe I lines, being clearly stronger than both by K5. In the later K-type dwarfs,
the spectral type may be estimated from the ratio of Ca I 4227 to Fe I 4383, 
in the sense that Ca I/Fe I grows toward later types. Notice as well the 
development of the MgH feature at 4780. It begins in the mid-K-type dwarfs 
as a pointed tooth-like absorption feature, which then becomes progressively 
more flat-bottomed as a nearby TiO band grows in strength. 

Luminosity type: As for late G-types, the ratio of Sr II 4077 to nearby iron 
lines (Fe I 4046, 4063, 4071) remains sensitive to luminosity. The violet-
system CN bands, with bandhead at 4216 , visible in the supergiant and giant 
spectra as a concavity in the continuum, show a strong sensitivity to 
luminosity. Notice as well that the Ca II K and H lines show extremely broad 
damping wings in the supergiant class. But the criterion affording the 
greatest discrimination in the luminosity classes is the ratio of the 
YII 4376 line to Fe I 4383.",
	     M => " === M stars ===
Spectral type: By M0, bands due to TiO become visible in the spectrum, and 
these strengthen quite dramatically toward later types; by M4.5 they dominate 
the spectrum. To exclude the possibility of systematic errors in metal-weak 
stars, ratios of TiO band strengths should be employed. Notice as well the 
development of the MgH feature at 4780. It begins in the mid-K-type dwarfs 
as a pointed tooth-like absorption feature, which then becomes progressively 
more flat-bottomed as a nearby TiO band grows in strength. A band of CaOH, 
a tri-atomic molecule, makes its first appearance at about M3, and contributes 
to a strong absorption feature by M4.5.

Luminosity type: The negative luminosity effect in the Ca I 4227 line is the 
most striking luminosity indicator in the M2 stars. At this resolution, the 
morphology of the MgH/TiO blend near 4770 can be used as well to distinguish 
luminosity classes; notice that the MgH band dominates this blend in the dwarf 
star, producing a tooth-shaped feature. The morphology of the spectral region 
between 4900 and 5200 Å seems as well to be sensitive to luminosity.",
	     y => "H-alpha:        absorption or emission?
Ca IR-triplet:  luminosity sensitive. Can be in emission in very active stars.
Ca II H+K:      emission cores are activity indicators.
lithium:        third (yellow) from the right indicates the 6707 Li-blend.",
	     l => "H-alpha:        absorption or emission?
Mg-b feature:   luminosity sensitive
Na D lines:     look for IS absorption
O I lines:      oxygen triplet",
	     z => "H-alpha:        absorption or emission?
Ca I:           luminosity sensitive in M stars
Na D lines:     look for IS absorption
Ca K line:      luminosity sensitive:
                      cyan :  Mv = 10
                      green:  Mv =  5
                      orange: Mv =  0
                      yellow: Mv = -5",

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
