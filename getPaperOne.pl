#!/usr/bin/perl

#
# fetch source of Paper One from the wiki, save it locally with an adequate timestamp, and
# process to a PDF file.
#

# get the source
`rm Source_of_Paper_One* Paper_One_Ref*`;
`wget --http-user=vsop --http-password=vsop2006 http://vsop.sc.eso.org/wiki/Source_of_Paper_One`;
`wget --http-user=vsop --http-password=vsop2006 http://vsop.sc.eso.org/wiki/Paper_One_Refs`;

# process the bibtex file
open IN, "<Paper_One_Refs" or die "...download must have failed!?\n";
open REF, ">refs.bib" or die "ERROR: could not open refs.bib\n";

while ( $in = <IN> ) {
    next unless $in =~ /<pre>/;      # read next line unless we're at the beginning of tex-codes

    while ($tex = <IN>) {
	last if $tex =~ /<\/pre>/;   # exit loop if we're out of tex-codes
	$tex =~ s/&quot;/\"/g;
	$tex =~ s/&amp;/\&/g;
	print REF $tex;
    }

}

close REF;
close IN;
unlink "Paper_One_Refs";

# process the latex source file
open IN, "<Source_of_Paper_One" or die "...download must have failed!?\n";

while ( $in = <IN> ) {
    &translateDate if $in =~ /f-lastmod/;
    next unless $in =~ /<pre>/;      # read next line unless we're at the beginning of tex-codes

    @tex = ();
    while ($tex = <IN>) {
	last if $tex =~ /<\/pre>/;   # exit loop if we're out of tex-codes
	$tex =~ s/&lt;/</g;
	$tex =~ s/&gt;/>/g;
	$tex =~ s/&amp;/\&/g;
	push @tex, $tex;
    }

}

close IN;
#unlink "Source_of_Paper_One";

# write to time-stamped file
die "wroong filename = $texname ???\n" unless ($texname);
open TEX, ">${texname}.tex" or die "could not open $texname...";
print TEX @tex;
close TEX;

# latex processing...
$rerun = 1;
unlink "${texname}.bbl";
print "Running latex...";
while ($rerun) {
    $out = `latex $texname`;
    if ($out =~ /No file ${texname}.bbl/) {
	`bibtex $texname`;
	$rerun = 1;
	print "...";
    } elsif ($out =~ /Rerun to get citations correct/) {
	$rerun = 1;
	print "...";
    } else {
	$rerun = 0;
	print "Done\n";
    }
}
print "Making PS file...\n";
`dvips -q -o -t a4 $texname`;
print "Making PDF file...\n";
`ps2pdf -dPDFSETTINGS=/prepress ${texname}.ps`;
print "Done!  File ${texname}.pdf is ready for inspection.\n";



sub translateDate {
    %month = (
	      January => 1,
	      February => 2,
	      March => 3,
	      April => 4,
	      May => 5,
	      June => 6,
	      July => 7,
	      August => 8,
	      September => 9,
	      October => 10,
	      November => 11,
	      December => 12
	      );
    print "translating...";
    $in =~ /modified (\d+:\d+), (\d+) (\w+) (\d+)./;
    $texname = sprintf "paper_one%4d-%2.2d-%2.2dT%5s", $4, $month{$3}, $2, $1;
    print "OK\n";
}
