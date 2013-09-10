#!/usr/bin/perl
# 	$Id: mkidlfile.pl,v 1.5 2005/08/04 16:55:27 tdall Exp $	

# 20-08-2004:  -w option to produce asc-output for VWA.

# produce two-col output (wavelgth  value) to be used with idl
# from iraf file with header on top of values.  Optional to
# provide a file list-newasc with the names
# 
# cl> wtextim input outasc header+ pixels+
#

# options to the program:
# 
# -w  construct a file for VWA
# -h  print usage/help text
# -f  use default files
# -s  scaling factor to be multiplied to the data
use Getopt::Std;

getopts('whfs:');

# check for help request...
if ($opt_h) {
    print "mkidlfile.pl [-h] [-w] [-s <num>] [-f] <infile> <outfile>\n\n";
    print "-h   prints this help message\n";
    print "-w   makes an ascii file to use with VWA\n";
    print "-s   scales the data with <num>\n";
    print "-f   use default list files for processing multiple files.\n\n";
    print "Takes IRAF produced ascii spectra with header section on top and rewrites\n";
    print "them in two column format (lambda and flux). Original filenames from file\n";
    print "list-asc, new filenames in file list-newasc, or give the original and new\n";
    print "filename on the command line.\n";
    exit;
}

$numfil = @ARGV;
if ($numfil==2) {
    @files = ($ARGV[0]);   @newname = ($ARGV[1]);  $newname = 1;
} elsif ($opt_f) {
    open LIST, "<list-asc" or die "Please provide file list-asc!!\n";
    chomp( @files = <LIST> );
    close LIST;
    
    $newname = 0;
    if (-e "list-newasc") {
	open NEWNAME, "<list-newasc" or die "Provide list list-newasc!!\n";
	chomp( @newname = <NEWNAME> );
	close NEWNAME;
	$newname = 1;
    }
} else {
#unless ($opt_f) {
    print "Try mkidlfile.pl -h for help...\n";
    exit;
}

if ($opt_s) {
    $scale = $opt_s;
} else {
    $scale = 1.0;
}



foreach $file (@files) {
    if ($newname) {
	$newfile = shift @newname;
    } else {
	$newfile = "idl_$file";
    }
    if ($opt_w) {
	print "Type the comment line for $newfile here: ";
	$comm = <STDIN>;
	@values = ();
    }
    open OLD, "<$file";
  HEADER:{ while ($in = <OLD>) {
      # find the CRVAL1  (startin lambda)
      if ($in =~ /NAXIS1/) {
	  ($dum1, $dum2, $num, $dum3) = split /\s+/, $in;
	  print "$num points in ";
      }
      if ($in =~ /CRVAL1/) {
	  ($dum1, $dum2, $lamb1, $dum3) = split /\s+/, $in;
	  print "$file:  lambda1 = $lamb1, ";
      }
      if ($in =~ /CDELT1/) {
	  ($dum1, $dum2, $delta, $dum3) = split /\s+/, $in;
	  print "increment = $delta\n";
	  last HEADER;
      }
  }
       }
    # out of the header, now look for beginning of data
    $pixel = 0;
    $yes = 0;
    open NEW, ">$newfile";
    print NEW "$comm$num\n" if ($opt_w);
    print "Writing spectrum to $newfile\n";

    while ($in = <OLD>) {
	if ($in =~ /^\s*[-\s]\d+/ || $yes) {
	    $value = $in * $scale;
	    $lamb = $lamb1 + $delta * $pixel;
	    $pixel++;
	    $yes = 1;
	    if ($opt_w) {
		print NEW "$lamb\n";
		push @values, $value;   # save them for later
	    } else {
		print NEW "$lamb   $value\n";
	    }
	}
    }
    if ($opt_w) {
	foreach $value (@values) {
	    print NEW "$value\n";
	}
    }

    close NEW;

}
exit();


