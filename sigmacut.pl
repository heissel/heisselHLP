#!/usr/bin/perl

# sigmacut -s value -n value -c colnum -u|-l file

use Getopt::Std;

getopts('s:c:n:ul');

if ($opt_s) {
    $cut = $opt_s;
} else {
    $cut = 1.0;
    print "WARNING cut level set = 1.0!!\n";
}

if ($opt_c) {
    $col = $opt_c - 1;
} else {
    $col = 1;
    print "WARNING dafaults to column 1!!\n";
}

if ($opt_n) {
    $new_value = $opt_n;
} else {
    $new_value = 1.0;
    print "WARNING substitute value defaults to 1.0~~\n";
}

die unless ($opt_u || $opt_l);

foreach $file (@ARGV) {
    open IN, "<$file" or die "err1";
    open OUT, ">new_$file" or die "err2";
    while (chomp($in = <IN>)) {
	$in =~ s/^\s+//s;
	@row = split /\s+/, $in;
	$num_cols = @row;
	if ($opt_u) {
	    if ($row[$col] > $cut) {
		print "$row[$col] --> $new_value\n";
		$row[$col] = $new_value;
	    }
	} elsif ($opt_l) {
	    if ($row[$col] < $cut) {
		print "$row[$col] --> $new_value\n";
		$row[$col] = $new_value;
	    }
	}
	$in = join "  ", @row;
	print OUT "$in\n";
    }
    close OUT;
    close IN;
}
