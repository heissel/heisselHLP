#!/usr/bin/perl

#use diagnostics;
#use warnings;
use Getopt::Std;

# moogLinelist.pl [-c <min_depth>] <wl1> <wl2> <VALD-list> <new MOOG list> <comment>

getopts('c:');
if ($opt_c) {
    $mindepth = $opt_c;
} else {
    $mindepth = 0.0;
}

($wl1, $wl2, $vald, $file, @comment) = @ARGV;
&define_elements;

open IN, "<$vald" or die "28ru2rerw";
open OUT, ">$file" or die "237ye7y3e3e";

$dum = <IN>;
print OUT "@comment\n";

while (chomp($in = <IN>)) {
    @in = split /,/, $in;
    next if ($in[1] < $wl1);
    last if ($in[1] > $wl2);
    next unless ($in[9] > $mindepth);       # skip small lines...
    $in[0] =~ /\'(\w+)\s+(\d+)\'/;
    $ion = $2 - 1;
    $el = $el{$1};
    print OUT "$in[1]    ${el}.$ion   $in[2]   $in[4]   0.  0.  0.\n";
}

close OUT;




sub define_elements {
    %el = (
	   Fe => 26,
	   H => 1,
	   He => 2,
	   Li => 3,
	   Be => 4,
	   B => 5,
	   C => 6,
	   N => 7,
	   O => 8,
	   F => 9,
	   Ne => 10,
	   Na => 11,
	   Mg => 12,
	   Al => 13,
	   Si => 14,
	   P => 15,
	   S => 16,
	   Cl => 17,
	   Ar => 18,
	   K => 19,
	   Ca => 20,
	   Sc => 21,
	   Ti => 22,
	   V => 23,
	   Cr => 24,
	   Mn => 25,
	   Co => 27,
	   Ni => 28,
	   Cu => 29,
	   Zn => 30,
	   Ga => 31,
	   Ge => 32,
	   As => 33,
	   Se => 34,
	   Br => 35,
	   Kr => 36,
	   Rb => 37,
	   Sr => 38,
	   Y => 39,
	   Zr => 40,
	   Nb => 41,
	   Mo => 42,
	   Tc => 43,
	   Ru => 44,
	   Rh => 45,
	   Pd => 46,
	   Ag => 47,
	   Cd => 48,
	   In => 49,
	   Sn => 50,
	   Sb => 51,
	   Te => 52,
	   I => 53,
	   Xe => 54,
	   Cs => 55,
	   Ba => 56,
	   La => 57,
	   Ce => 58,
	   Pr => 59,
	   Nd => 60,
	   Pm => 61,
	   Sm => 62,
	   Eu => 63,
	   Gd => 64,
	   Tb => 65,
	   Dy => 66,
	   Ho => 67,
	   Er => 68,
	   Tm => 69,
	   Yb => 70,
	   Lu => 71,
	   Hf => 72,
	   Ta => 73,
	   W => 74,
	   Re => 75,
	   Os => 76,
	   Ir => 77,
	   Pt => 78,
	   Au => 79,
	   Hg => 80,
	   Tl => 81,
	   Pb => 82,
	   Bi => 83,
	   Po => 84,
	   At => 85,
	   Rn => 86,
	   Fr => 87,
	   Ra => 88,
	   Ac => 89,
	   Th => 90,
	   Pa => 91,
	   U => 92,
	   );


}
