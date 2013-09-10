#!/usr/bin/perl -w

# converts first column of a file from HH:MM:SS to seconds

$file = shift;

open IN, "<$file" or die "438tu3f34t3 344rw";

while (  $in = <IN>  ) {
    next if $in =~ /\#/;
    ($time, @therest) = split /\s+/, $in;
    ($hh, $mm, $ss) = split /:/, $time;
    $newtime = $ss + $mm * 60 + $hh * 60 * 60;
    $newtime = $newtime / 86400.;    # converting to days
    print "$newtime\n";
}

close IN;
