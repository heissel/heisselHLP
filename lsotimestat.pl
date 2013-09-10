#!/usr/bin/perl
use diagnostics;
use warnings;
use Tk;

my $mw = MainWindow->new;
$mw -> title("ESOTIL - ESO Time Log");


@instruments = ( "CES", "HARPS", "TIMMI2", "EFOSC2");
$instrument = "CES";

# top of the main window with some helpful text
#
$fr_top_text = $mw -> Frame(
                            -borderwidth => 16,
                            ) -> grid(
                                      -sticky => 'w'
                                      );
# buttons with observing downtime etc.
$fr_but = $mw -> Frame(
		       -borderwidth => 16,
		       ) -> grid(
				 -sticky => 'w'
				 );
# comment field
$fr_stat = $mw -> Frame(
			-borderwidth => 16,
			) -> grid(
				  -sticky => 'w'
				  );


$l_help_text = $fr_top_text -> Label(
                                     -text => "Tool for time accounting.",
                                     -justify => 'left',
                                     );
$o_tel = $fr_top_text -> Optionmenu(
				    -options => [ ["Choose telescope", "dummy"],
						  ["ESO 360", "3p6"],
						  ["NTT", "ntt"],
						  ["ESO/MPI 220", "2p2"]
                                                  ],
				    -variable => \$telescope,
				    );
$o_ins = $fr_top_text -> Optionmenu(
				    -options => \@instruments,
				    -variable => \$instrument,
				    );
$b_cal = $fr_but -> Button(
			   -text => "Start of calibrations",
			   );
$b_obs = $fr_but -> Button(
			   -text => "Start of observations",
			   -command => \&toggle_obs,
			   );
$b_tech = $fr_but -> Button(
			    -text => "Tech down time",
			    -command => \&toggle_tech,
			    );
$b_vejr = $fr_but -> Button(
			    -text => "Weather down time",
			    -command => \&toggle_vejr,
			    );
$b_idle = $fr_but -> Button(
			    -text => "Idle down time",
			    -command => \&toggle_idle,
			    );

$l_stat = $fr_stat -> Label(
			    -bd => 1, -relief => 'groove',
			    -text => "System and operational status:",
			    );
$l_tel1 = $fr_stat -> Label(
			    -bd => 1, -relief => 'groove',
			    -text => "Telescope: ",
			    );
$l_tel2 = $fr_stat -> Label(
			    -bd => 1, -relief => 'groove',
			    -text => "$telescope",
			    );
$l_ins1 = $fr_stat -> Label(
			    -bd => 1, -relief => 'groove',
			    -text => "Instrument: ",
			    );
$l_ins2 = $fr_stat -> Label(
			    -bd => 1, -relief => 'groove',
			    -text => "$instrument",
			    );
$l_obs = $fr_stat -> Label(
			   -text => "Not observing.",
			    -bd => 1, -relief => 'groove',
			   );
$l_down = $fr_stat -> Label(
			    -bd => 1, -relief => 'groove',
			    -text => "Everything OK.",
			    );


$l_help_text -> grid('-',
		     -sticky => 'w',
		     -padx => 4,
		     -pady => 2,
		     );
$o_tel -> grid($o_ins,
		     -sticky => 'w',
		     -padx => 4,
		     -pady => 2,
		     );
$b_cal -> grid($b_obs, 'x',
		     -sticky => 'w',
		     -padx => 4,
		     -pady => 2,
		     );
$b_tech -> grid($b_vejr, $b_idle,
		     -sticky => 'w',
		     -padx => 4,
		     -pady => 2,
		     );
$l_stat -> grid('-','-','-',
		-sticky => 'nesw',
		-ipadx => 8,
		-ipady => 5,
		);
$l_tel1 -> grid($l_tel2, $l_ins1, $l_ins2,
		-sticky => 'nesw',
		-ipadx => 8,
		-ipady => 2,
		);
$l_obs -> grid('-',$l_down, '-',
		-sticky => 'nesw',
		-ipadx => 8,
		-ipady => 2,
		);

MainLoop;
