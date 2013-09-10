#!/usr/bin/perl -w

@files = <*.mt>;

foreach $file (@files) {
    $file =~ /(.*).mt/;
    $newname = $1 . ".fits";
    rename $file, $newname;
}
