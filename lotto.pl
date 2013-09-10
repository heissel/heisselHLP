#!/usr/bin/perl -w

# tjek lottotallene. De spillede raekker ligger som permanent struktur
# da de altid er de samme.  Programmet beder om de 7 rigtige hvis de ikke
# er givet med -s

use Getopt::Std;
getopts('s:');
$| = 1;  # forces a flush after every print

@spil = ( "1 7 10 14 17 18 30",
	  "4 7 8 14 15 17 21",
	  "6 15 17 27 30 32 36",
	  "8 12 16 17 20 24 34",
	  "4 14 17 21 24 27 36",
	  "1 10 19 24 25 35 36",
	  "7 10 14 21 24 27 34",
	  "6 11 14 24 27 34 36",
	  "5 9 14 15 17 25 32",
	  "2 3 7 15 19 24 27"
	  );

if ($opt_s) {
    @ugens_tal = split /\s+/, $opt_s;
} else {
    print "Ugens 7 rigtige? ";
    chomp( $s = <STDIN> );
    @ugens_tal = split /\s+/, $s;
}

die "Der er ikke 7 tal!" if (@ugens_tal != 7);

$rknum = 0;
foreach $f (@spil) {                       # indlaes foerste spillede raekke
    @raekke = split /\s+/, $f;
    $rknum++;
    $rigtige = 0;
    for ( $i = 0; $i <= 6; $i++ ) {        # loop gennem alle spillede tal i raekken
	DESYV: for ( $j = 0; $j <= 6; $j++) {      # tjek hvert tal mod hvert af de 7 rigtige
	    if ($raekke[$i] == $ugens_tal[$j]) {
		$rigtige++;
		last DESYV;
	    }
	}
    }
    print "Raekke nummer $rknum :: $rigtige rigtige";
    if ($rigtige == 4) {
	print " !!\n";
    } elsif ($rigtige == 5) {
	print " !!!!!\n";
    } elsif ($rigtige >= 6) {
	print " YAAAAAAHHHH!!!!\n";
    } else {
	print "\n";
    }
}
