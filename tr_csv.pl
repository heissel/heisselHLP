#!/usr/bin/perl

@lines = <>;

$num = 1;
foreach $line (@lines) {
    $line =~ s/\.(\d{3})/$1/sg;
    $line =~ s/,(\d{2})/.$1/sg;
    $line =~ s/,//sg;
    $line =~ s/;/,/sg;
    print "$num,$line";
    $num++;
}