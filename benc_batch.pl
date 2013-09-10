#!/usr/bin/perl


open WAV, "<files" or die "cannot open file\n";
open MP3, "<mp3s"  or die "cannot open mp3s\n";

print "Name of Artist:  ";chomp( $art = <STDIN> );

print "\nHere are the copmmands to be execed. Please check:\n";
while (chomp( $wav = <WAV> )) {
    chomp( $tit = <MP3> );
    $out = $art."_-_".$tit.".mp3";
    $comm = "bladeenc $wav $out -del -nogap";
    push @comm, $comm;
    print "$comm\n";
}

print "Press ENTER to continue, ^C to abort.\n"; $art = <STDIN>;

foreach $comm (@comm) {
    print "$comm\n";
    system "$comm";
}

close WAV;
close MP3;
