#!/usr/bin/perl

# checks fits files for parameters

# requires filenames to be given on command line

unless (@ARGV) {
    die "specify filenames\n";
}

foreach $f (@ARGV) {
    $in = `dfits $f | grep "GRAT1 WLEN"`;
    $in =~ /=\s+(\d+.\d+)\s+/;
    $wl = $1;
    $in = `dfits $f | grep ARCFILE`;
    $in =~ /\'(.*)\'/;
    $an = $1;
    $in = `dfits $f | grep OBJECT`;
    $in =~ /\'(.*)\'/;
    $ob = $1;
    print "$f ::: $an  ::: $ob :::  $wl\n";
}
