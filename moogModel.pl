#!/usr/bin/perl

#use diagnostics;
#use warnings;

# first argument is real model (full path), second is new filename, third metallicity [Fe/H]

chomp( ($inmodel, $outmodel, $metal) = @ARGV );
die "werwr344wwe" unless ($inmodel && $outmodel && $metal);

open IN, "<$inmodel" or die "2r2r4r42r";
open OUT, ">$outmodel" or die "dgm405y4er";

$in = <IN>;
$in =~ /TEFF\s+(\d+).\s+GRAVITY (\d\.\d\d)/;
print OUT "KURUCZ\n          Teff= $1          log g= $2\n";
print OUT "NTAU         72\n";

$ok = 0;
while (chomp($in = <IN>)) {

    next unless ($ok == 1 || $in =~ /^READ/);
    $ok = 1;
    next unless $in =~ /^\s+\d/;
    
    print OUT "$in\n";

}

close IN;

print OUT "    2.000e+05\n";
print OUT "NATOMS     0  $metal\n";
print OUT "NMOL      19
      606.0    106.0    607.0    608.0    107.0    108.0    112.0    707.0
      708.0    808.0     12.1  60808.0  10108.0    101.0      6.1      7.1
        8.1    822.0     22.1\n";


close OUT;

print "\n Your model has been written to $outmodel. It contains 19 species of\n";
print " molecules and/or ionized atomic species. Add/delete by hand if you need to.\n";

