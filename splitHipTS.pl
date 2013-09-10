#!/usr/bin/perl 

#use Getopt::Std;

#getopts('c:a');

use warnings;

# get a filename on the command line and split according to the filters.

$name = shift @ARGV;

unless ($name) {
    die "ERROR. Provide input file\n";
}

open IN, "<$name" or die "enw37rws";

$suffix = 1;
$newfile = $name . $suffix;
open OUT, ">$newfile";

while ($in = <IN>) {
    next if $in =~ /#/;

    if ($in =~ /^\s+/) {

	close OUT;
	$suffix++;
	$newfile = $name . $suffix;
	open OUT, ">$newfile";

    } else {

	print OUT "$in";

    }

}

close OUT;
close IN;
