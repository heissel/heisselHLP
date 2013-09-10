#!/usr/bin/perl

# renames archive files to their original names.

# requires filenames to be given on command line

unless (@ARGV) {
    die "specify filenames\n";
}

foreach $f (@ARGV) {
    $in = `dfits $f | grep ORIGFILE`;
    $in =~ /\'(.*)\'/;
    print "$f -> $1\n";
    $ok = rename $f, $1;
    unless ($ok) {
	print "$!\n";
    }
}
