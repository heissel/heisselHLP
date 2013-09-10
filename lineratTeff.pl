#!/usr/bin/perl
# 	$Id: lineratTeff.pl,v 1.5 2004/11/28 05:07:01 tdall Exp $	

use diagnostics;
use warnings;
use Tk;

# pendings:


#print .074 * 3.56e-2;exit;

my $mw = MainWindow->new;
$mw -> title("Teff (Kovtyukh+2003)");

# read the default starting values (needed...)
#
&read_defaults;


# read the database
# 
open DATA, "</home/tdall/Execs/.data.lineratTeff" or die "datafile missing!";

$i = 1;
while ($in = <DATA>) {
    $in =~ s/^\s+//s;
    $in =~ s/ I/_I/g;
    $in =~ s/D/e/g;
    ($num[$i],$T1[$i],$T2[$i],$lamb1[$i],$elem1[$i],$lamb2[$i],$elem2[$i],$dum,$expr[$i]) = split /\s+/, $in;
    $expr[$i] =~ s/r/\$r/g;
    $expr[$i] =~ s/\^/\*\*/g;
    $i++;
}


#$r = 1.5;
#print (eval "$expr[8]","\n");

# ----------------------------------------------
# define the main layout (frames) of the window
# ----------------------------------------------

# top of the main window with some helpful text
#
$fr_top_text = $mw -> Frame(
			 #   -relief => 'groove',
			    -borderwidth => 16,
			    ) -> grid(
				      -sticky => 'w'
				      );
# frame with wavelength selectors
#
$fr_top_lamb = $mw -> Frame(
			#    -relief => 'groove',
			    -borderwidth => 16,
			    ) -> grid(
				      -sticky => 'w'
				      );
# frame with entryboxes for the linedepths
#
$fr_top_dept = $mw -> Frame(
		#	    -relief => 'groove',
			    -borderwidth => 12,
			    ) -> grid(
				      -sticky => 'w'
				      );
# frame with buttons
#
$fr_top_butt = $mw -> Frame(
	#		    -relief => 'groove',
			    -borderwidth => 16,
			    ) -> grid(
				      -sticky => 'w'
				      );
# bottom frame to contain output from the calculations
#
$fr_bot_outp = $mw -> Frame(
#			    -relief => 'groove',
			    -borderwidth => 16,
			    ) -> grid(
				      -sticky => 'w'
				      );

# -----------------------------------------------
# now define the wigedts that go into the frames
# -----------------------------------------------

$l_help_text = $fr_top_text -> Label(
				     -text => "Calculation of Teff from line ratios.\nChoose lines and enter their depths, then click Calculate\n",
				     -justify => 'center',
				     );
$o_elem1 = $fr_top_lamb -> Optionmenu(
				      -options => [ ["Ti I", "TiI"],
						    ["Si I", "SiI"],
						    ["Fe I", "FeI"],
						    ["V I", "V_I"],
						    ["Ni I", "NiI"],
						    ["S I", "S_I"],
						    ["S II", "SII"],
						    ["Cr I", "CrI"]
						    ],
				      -textvariable => \$txt_elem1,
				      -variable => \$elem1,
				      -command => \&select_elem1,
				      );
$o_elem2 = $fr_top_lamb -> Optionmenu(
				      -options => [ ["Ti I", "TiI"],
						    ["Si I", "SiI"],
						    ["Fe I", "FeI"],
						    ["V I", "V_I"],
						    ["Ni I", "NiI"],
						    ["S I", "S_I"],
						    ["Co I", "CoI"]
						    ],
				      -textvariable => \$txt_elem2,
				      -variable => \$elem2,
				      -command => \&select_elem2,
				      );
$o_lamb1 = $fr_top_lamb -> Optionmenu(
				      -options => [ [100, 100] ],
#				      -variable => \$lamb1,
				      -textvariable => \$lamb1,
				      -command => \&select_wl1,
				      );
$o_lamb2 = $fr_top_lamb -> Optionmenu(
				      -options => [ [100, 100] ],
				      -textvariable => \$lamb2,
				      -command => \&select_wl2,
				      );
$l_dept1 = $fr_top_dept -> Label(
				 -text => "depth of first line:",
				 );
$l_dept2 = $fr_top_dept -> Label(
				 -text => "depth of second line:",
				 );
$e_dept1 = $fr_top_dept -> Entry(
				 -textvariable => \$dept1,
				 );
$e_dept2 = $fr_top_dept -> Entry(
				 -textvariable => \$dept2,
				 );
$b_run = $fr_top_butt -> Button(
				-text => "Calculate",
				-command => \&calculate,
				);
$b_exit = $fr_top_butt -> Button(
				 -text => "Exit",
				 -command => \&my_exit,
				 );
$b_mean = $fr_top_butt -> Button(
				 -text => "Calculate mean",
				 -command => \&get_mean,
				 );
$b_use = $fr_top_butt -> Button(
				 -text => "Use this value",
				 -command => \&use_this_value,
				 );
$b_master = $fr_top_butt -> Button(
				   -text => "Use master.inp",
				   -command => \&use_masterinp,
				   );
$t_outp = $fr_bot_outp -> Text(
			       -height => 14,
			       );
$dummy = $fr_top_text -> Label(
			       -text => "  ",
			       );
$dummy2 = $fr_top_lamb -> Label(
				-text => " ",
				);

# ---------------------------------------------------
# now pack the widgets with grid and draw the window
# ---------------------------------------------------

$dummy -> grid($l_help_text,'-','x',
	       -sticky => 'w',
	       );
$o_elem1 -> grid($o_lamb1,$o_elem2,$o_lamb2,
		 -sticky => 'w',
		 -padx => 8,
		);
$l_dept1 -> grid($e_dept1,$l_dept2,$e_dept2,
		 -sticky => 'w',
		 );
$b_run -> grid($b_use,$b_mean,$b_master,$b_exit,
	       -sticky => 'w',
	       -padx => 3,
	       );
$t_outp -> grid('-','-','-',
		-sticky => 'w',
		);
$t_outp -> insert('end', "Please select two lines from the pulldown\nmenus, selecting from left to right.\n");
$b_use -> configure(-state => 'disabled');
if (-e "master.inp") {
    $b_master -> configure(-state => 'normal');
} else {
    $b_master -> configure(-state => 'disabled');
}


MainLoop;

sub use_masterinp {
    # check if the master.inp file (output from abund_gui) is present, and open it
    #
    if (-e "master.inp") {
        # take each entry and make a search in the master.inp file
	for ($j=1; $j <= $i; $j++) {
	    $success = 0;
	    $grep = get_string( $elem1[$j], $lamb1[$j] );
	    $res1 = `grep $grep master.inp`;
	    $grep = get_string( $elem2[$j], $lamb2[$j] );
	    $res2 = `grep $grep master.inp`;
	    if ($res1 && $res2) {
		# get the variables, then call calculate
		$dept1 = substr $res1, 68,5;
		$dept2 = substr $res2, 68,5;
		$elem1 = $elem1[$j];   $elem2 = $elem2[$j];
		$lamb1 = $lamb1[$j];   $lamb2 = $lamb2[$j];
		$this_entry = $j;
		&calculate;
		&use_this_value;
		print "Match for entry $j\n";
		$success = 1;
	    }
	    
	}
	unless ($success) {
	    print "Sorry, no matches!\n";
	    $t_outp -> insert('end',"\nSorry, no matching pairs in master.inp!\n");
	    $t_outp -> see('end');
	}
    }
}

sub get_string {
    ($el, $la) = @_;

    $el = substr $el, 0, 2;   # WARN :  S II is not taken into account (only one entry)
    $el =~ s/_/ /s;
    $la = substr $la, 0, 6;
    $dum1 = "\"'$el 1', $la\"";
    
    return $dum1;
}




sub select_elem1 {
    $t_outp -> insert('end', "Selected $txt_elem1 for line 1...");
    # isolate all entries with this element as element 1
    @elements = ();
    @is = ();
    for ($i = 1; $i <= 112; $i++) {
	if ($elem1[$i] eq $elem1) {
#	    print "match of $elem1[$i] at pos $num[$i]\n";
	    push @elements, $lamb1[$i];
	    push @is, $i;
	}
    }
    $o_lamb1 -> configure(-options => \@elements);
    $t_outp -> insert('end',"ready for wavelength selection.\n");
    $t_outp -> see('end');
}

sub select_wl1 {
    $t_outp -> insert('end', "Selected $lamb1 for line 1...");
    # isolate all entries with this wl as the first choice using the list from &select_element1
    @tmpis = @is;
    @is = ();
    for ($i = 1; $i <= 112; $i++) {
	if ($lamb1[$i] == $lamb1) {
#	    print "match of $lamb1[$i] at pos $num[$i]\n";
  	    push @is, $i;
	}
    }
    $t_outp -> insert('end',"proceed with line 2.\n");
    $t_outp -> see('end');
}

sub select_elem2 {
    $t_outp -> insert('end', "Selected $txt_elem2 for line 2...");
    # isolate all entries with this element as element 2 from the list made in &select_wl1
    @elements = ();
    foreach $i (@is) {
	if ($elem2[$i] eq $elem2) {
#	    print "match of $elem2[$i] at pos $num[$i]\n";
	    push @elements, $lamb2[$i];
	}
    }
    if (@elements) {
	$o_lamb2 -> configure(-options => \@elements);
	$t_outp -> insert('end',"ready for wavelength selection.\n");
    } else {
	$t_outp -> insert('end',"WARNING: no lines to match!! Try again.\n");
    }
    $t_outp -> see('end');
}

sub select_wl2 {
    $t_outp -> insert('end', "Selected $lamb2 for line 2...");
    # calculate which entry is the one...
    foreach $i (@is) {
	if ($lamb2[$i] == $lamb2 && $lamb1[$i] == $lamb1) {
#	    print "match of $lamb1[$i] at pos $num[$i]\n";
  	    $this_entry = $i;
	    $t_outp -> insert('end',"ready to calculate\n");
	}
    }
    $t_outp -> see('end');
}


sub calculate {
    $t_outp -> insert('end', "Calculating...");
    unless ($dept2) {  # check for division by 0
	$t_outp -> insert('end', "ERROR: depths not defined\n");
	return;
    }
    $r = $dept1 / $dept2;
    $teff = eval "$expr[$this_entry]";
#    print (eval "$expr[$this_entry]", "\n");
    $t_outp -> insert('end', "done:  Teff = $teff\n");
    # check if result is within the wavelength limits....
    if ($teff < $T1[$this_entry] || $teff > $T2[$this_entry]) {
	$t_outp -> insert('end',"WARNING: outside valid temperature range\n");
    }
    $t_outp -> see('end');
    $b_use -> configure(-state => 'normal');   # enable the 'use this value' button
}

sub use_this_value {
    push @teff, $teff;     # save the Teff value
    push @log, "$teff    $lamb1 $elem1   $lamb2 $elem2";   # save a nice status line
    $r = @teff;
    $t_outp -> insert('end',"Took value of $teff. Total of $r values taken.\n");
    $t_outp -> see('end');
    $b_use -> configure(-state => 'disabled');
}

sub my_exit {
    &get_mean;
    print "\n\n";
    foreach $r (@log) {
	@outp = split /\s+/, $r;
	printf "%7.2f    from: %7.2f (%4s)  %7.2f (%4s)\n", $outp[0], $outp[1], $outp[2], $outp[3], $outp[4];
    }
    print "------------------\n";
    print "mean Teff = $mean +/- $sigma   ($num entries)\n";
    print "------------------\n";

    exit;
}


#sub get_from_daospec {
    # first find the 

sub get_mean {
    if (@teff) {
	$num = @teff;
	$mean = sum(@teff);
#	$mean = 0.0;
#	foreach $in (@teff) {
#	    $mean += $in;
#	}
	$mean /= $num;
	$sigma = sigma($mean,@teff);
    }
    $t_outp -> insert('end', "----- mean Teff = $mean +/- $sigma   ($num entries)\n");
    $t_outp -> see('end');
}


sub read_defaults {
    $txt_elem1 = "Ti I";
    $elem1 = "TiI";
    $txt_elem2 = "V I";
    $elem2 = "V_I";
    $lamb1 = 100;
    $lamb2 = 100;
# also some variable inits:
    $mean = 0.0;
    $num = 0;
    @teff = ();
    @log = ();
}


sub sigma (\$\@) {  # finder rms scatter af et givet array, givet en middelvaerdi
    use strict;
    my($sig,$mean,$num);
    $mean = shift;
    $sig = 0.0;
    $num = 0;
    foreach (@_) {
        $sig += $_**2;
        $num += 1;
    }
    $sig = ( $sig / $num - $mean**2 )**.5;
    return $sig;
}

sub sum (\@) {  # summerer et givet array
    use strict;
    my($sum,$e);
    $sum=0;
    foreach $e (@_) {
        $sum += $e;
    }
    return $sum;
}


