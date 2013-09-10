#####################
#
#  subroutines
#
#####################

sub read_environment {

    #
    # MASTERMODEL is the dirctory with all available ATLAS models.
    #

    if ($opt_m) {
	$master_model = $opt_m;
    } elsif ($opt_M) {
	chomp( $master_model = `pwd` );
    } else {
	$master_model = $ENV{"MASTERMODEL"};
	unless ($master_model) {
	    print "ERROR: please set the environment variable MASTERMODEL\n";
	    exit;
	}
    }
    $master_model = add_slash($master_model);
    print "MASTERMODEL = $master_model\n";

    #
    # ATLAS9EXE is the dirctory with all ATLAS executables.
    #

    $atlas_exe = $ENV{"ATLAS9EXE"};
    unless ($atlas_exe) {
	print "ERROR: please set the environment variable ATLAS9EXE\n";
	exit;
    }
    $atlas_exe = add_slash($atlas_exe);
    print "ATLAS9EXE = $atlas_exe\n";

    #
    # LINE_LISTS is the dir with all the linelists (sub: molecules, lines)
    #

    $line_lists = $ENV{"LINE_LISTS"};
    unless ($line_lists) {
	print "ERROR: please set the environment variable LINE_LISTS\n";
	exit;
    }
    $line_lists = add_slash($line_lists);
    print "LINE_LISTS = $line_lists\n";

    #
    # MOL_LISTS is the dir with the molecular linelists
    #

    $mol_lists = $ENV{"MOL_LISTS"};
    unless ($mol_lists) {
	print "ERROR: please set the environment variable MOL_LISTS\n";
	exit;
    }
    $mol_lists = add_slash($mol_lists);
    print "MOL_LISTS = $mol_lists\n";

}



sub copy_to_internal_names {

    #
    # the general data files
    #
    `ln -s ${line_lists}lines/he1tables.dat fort.18`;
    `ln -s ${line_lists}lines/molecules.dat fort.2`;
    `ln -s ${line_lists}lines/continua.dat fort.17`;

}




sub modify_model_header {

    # reads the original model ($origmodel) and puts control cards on top,
    # according to rotation on/off, and writes to a temporary model in the current dir.
    #

    open IN, "<${master_model}$origmodel" or die "nn37rhdn2822";
    open OUT, ">tmpmodel.mod" or die "j3j38f73hj33";
    if ($vsini) {
	$out = "SURFACE INTENSI 17 1.,.9,.8,.7,.6,.5,.4,.3,.25,.2,.15,.125,.1,.075,.05,.025,.01";
    } else {
	$out = "SURFACE FLUX";
    }
    print OUT "$out\n";
    print OUT "ITERATIONS 1 PRINT 2 PUNCH 2
CORRECTION OFF
PRESSURE OFF
READ MOLECULES
MOLECULES ON\n";
    while ($in = <IN>) {
	$in =~ s/DECK6  72/DECK6 72/s;   # correcting extra-space error in Heiter grid
	print OUT "$in";
    }
    close OUT;
    close IN;
}




sub synbeg_set_parameters {

    #
    # passing the parameters to synbag to start the synthesis
    #
    $dum = sqrt( $vmic**2 - 1.0 );
    $params = sprintf "AIR        %6.1f    %6.1f    %6.6d.      %4.2f    %d     30    .0001     1    0", $wl_low, $wl_high, $resol, $dum, $nlte;

    `${atlas_exe}synbeg.exe <<EOF >dump
$params
AIRorVAC  WLBEG     WLEND     RESOLU    TURBV  IFNLTE LINOUT CUTOFF        NREAD
EOF`;
    `rm dump`;

}


sub build_linelist {

    #
    # all the molecules need to read....
    #
    foreach $file ( glob "${line_lists}molecules/*.dat" ) {
	`ln -s $file fort.11`;
	`${atlas_exe}rmolecasc.exe > dump`;
	`rm -f fort.11 dump`;
    }

    #
    # sort the atomic lines according to the wavelength range
    #
    foreach $file ( glob "${line_lists}lines/*.100" ) {
	$file =~ /gf(\d+)\.100/;
	next if $1 < $wl_low;
	if ($1 < 800) {
	    last if $1 > $wl_high + 100.0;
	} elsif ($1 == 800) {
	    last if $1 > $wl_high + 200.0;
	} elsif ($1 == 1200) {
	    last if $1 > $wl_high + 400.0;
	}
	`ln -s $file fort.11`;
	`${atlas_exe}rline2.exe > dump`;
#	print "$file\n";
	`rm -f fort.11 dump`;
    }
	    
    #
    # read the molecular lines that need to be sythesized
    #

    #  TiO
    #
    if ($mol_tio) {
	`ln -s ${mol_lists}schwenke.bin fort.11`;
	`ln -s ${mol_lists}etioschwenke.bin fort.48`;
	`${mol_lists}rschwenk.exe > dump`;
	`rm fort.48 fort.11 dump`;
    }

    #  H2O
    #
    if ($mol_h2o) {
	`ln -s ${mol_lists}h2ofast.bin fort.11`; 
	`${mol_lists}rh2ofast.exe > dump`;  print "read H2O DONE\n";
	`rm fort.11 dump`;
    }

}






sub synthe {
    #
    # run SYNTHE main program and the SPECTRV program
    #

    `${atlas_exe}synthe.exe > dump`;  print "synthe DONE\n";
    `rm dump`;
    `ln -s tmpmodel.mod fort.5`;
    $out1 = $outroot . ".flx";

    # xxx Warning: the content of fort.25 is taken directly from the example script of L.S.
    open OUT, ">fort.25" or die "nw73wcccc";
    print OUT "0.0       0.        1.        0.        0.        0.        0.        0.
0.
RHOXJ     R1        R101      PH1       PC1       PSI1      PRDDOP    PRDPOW\n";
    close OUT;

    `${atlas_exe}spectrv.exe > dump`;  print "spectrv DONE\n";
    `rm dump`;
    `mv fort.7 $out1`;
    `cp $out1 backup_nobroad_norot.flx`;   # use this to skip synthe step if just changing broad/rot... TBD
 
    if ($vsini) {
	`ln -s $out1 fort.1`;
	`${atlas_exe}rotate.exe<<EOF >dump
1
$vsini
EOF`;  print "rotate DONE\n";
	`mv ROT1 $out1`;
	`rm fort.1 dump`;
    }

    `rm fort.5`;

}


sub broaden { 
    #
    # do instrumental broadening and write ascii files suitable for plotting
    #
    `ln -s $out1 fort.21`;
    $outbroad = "br_" . $out1;
    `ln -s $outbroad fort.22`;

    #  do the broadening
    $dum = sprintf "GAUSSIAN       %5.2fKM", $broad;    # xxx must be given in km/s
    `${atlas_exe}broaden.exe << EOF >dump
$dum
EOF`;  print "broaden DONE\n";
    `rm fort.2 dump`;

    # make ascii files
    `ln -s $out1 fort.1`;
    $outasc = $outroot . ".asc";
    $outlines = $outroot . ".lines";
    $outascb = $outroot . "_b.asc";
    $outlinesb = $outroot . "_b.lines";
    `ln -s dmp.dmp fort.4`;
    # ... first for the non-broadened spectrum
    `ln -s $outlines fort.3`;
    `ln -s $outasc fort.2`;
    `${atlas_exe}syntoascanga.exe`;  print "nonbroad to ascii DONE\n";
    `rm -f fort.1 fort.2 fort.3`;
    # ... then for the broadened one
    `ln -s $outlinesb fort.3`;
    `ln -s $outascb fort.2`;
    `ln -s $outbroad fort.1`;
    `${atlas_exe}syntoascanga.exe`; print "broadened to ascii DONE\n";
    `rm fort.* dmp.dmp`; 
}


1;
