#!/usr/bin/perl

#
#  htmltab2latex <html-file> <latex-file>
#
# reads a html-file for the start of a table, converts the entries into latex format
# and writes it to the latex-file.
#
#
#
#
#
use warnings;
use diagnostics;
#use Getopt::Std;
#getopts('s:');
$| = 1;  # forces a flush after every print

die "Must be two file names!\n" if (@ARGV != 2);
($htmlfile, $latexfile) = @ARGV;

open HTML, "<$htmlfile" or die "no $htmlfile\n";
open TEX, ">$latexfile" or die "no $latexfile\n";

$intable = 0;
while (chomp($in = <HTML>) ) {
    # search for the beginning of the table
    if ($in =~ /<table/) {
	$intable = 1;
	next;
    }
    if ($intable) {   # only do this block if we are in a table
	if ($in =~ /<tr/ || $in =~ m|</table|) {
	    $in =~ s/<tr>/    /;
	    print TEX "\\\\\n";
	} else {
	    print TEX "& ";
	}
	while ($in =~ s/>(.+)<//o) {
	    $new = $1;
	    $new =~ s/^<.*>//o;
	    $new =~ s/<.*>/ & /g;
	    print TEX "$new  ";
	}
    }
    if ($in =~ m|</table|) {
	$intable = 0;
	print TEX "\n";
	next;
    }
    last if $in =~ m|</html|;
}

close HTML;
close TEX;



$latexfile="tmp";
