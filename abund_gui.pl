#!/usr/bin/perl  -I/home/tdall/Execs
# 	$Id: abund_gui.pl,v 1.12 2005/02/03 13:55:10 tdall Exp tdall $	

# uncomment these for development
#use diagnostics;
#use warnings;

use Tk;
use PGPLOT;
use Getopt::Std;
use Astro::FITS::CFITSIO;


require "utils.pl";
require "ab_plot_utils.pl";

    # -e : take the working directory from the environment, otherwise from the pwd
getopts('he');

if ($opt_h) {
    &help;
    &my_exit;
    print "$opt_h";   # dummy to suppress diagnostic error
}


# GUI to select the .inp files and the model, the range of v_micro.
# launching of Width_new and subsequent analysis of the results.
#
# Pendings:
#           - refine the listing of models to iterate from 
#           - option to include EWs measured by splot
#           - refine the choice of odf files to use in model-making
#           - a way to choose a predefined linelist for the analysis instead of laboratory.dat  (initiated - buggy!)
#           - shadowing of buttons while not supposed to be used
#           - in linelist/plot::: option to plot only certain elements/ionizations

# ... see help on defaults at the end of the file
#
&set_defaults;



my $mw = MainWindow->new;
$mw -> title("Abundance analysis");

# ----------------------------------------------
# define the main layout (frames) of the window
# ----------------------------------------------

# the top (main) frames
$fr_top1 = $mw -> Frame(
		       -relief => 'groove',
		       -borderwidth => 1,
		       ) -> pack(
				 -pady => 3,
				 -fill => 'both'
#				 -sticky => 'we'
				 );
$fr_top2 = $mw -> Frame(
		       -relief => 'groove',
		       -borderwidth => 1,
		       ) -> pack(
				 -pady => 3,
				 -fill => 'both'
#				 -sticky => 'w'
				 );
$fr_elem = $mw -> Frame(
		       -relief => 'groove',
		       -borderwidth => 1,
		       ) -> pack(
				 -pady => 3,
				 -fill => 'both',
				 );
# the entries delimiting EW and Xpot
$fr_lim = $mw -> Frame(
		       -relief => 'groove',
		       -borderwidth => 1,
		       ) -> pack(
				 -pady => 3,
				 -fill => 'both'
#				 -sticky => 'we'
				 );
# text area
$fr_txt = $mw -> Frame(
		       -relief => 'groove',
		       -borderwidth => 0,
		       ) -> pack(
				 -pady => 6,
				 -fill => 'both',
#				 -sticky => 'w'
				 );


# -------------------------------------------------------------------
# define the elements of the ATLAS model selection calculation window
# -------------------------------------------------------------------

$top_specplot = $mw -> Toplevel();
$top_specplot -> title("Line selection");
$l_specplot_central = $top_specplot -> Label(
					     -text => "Central wavelength: ",
					     );
$l_specplot_range = $top_specplot -> Label(
					   -text => "Range in wavelength: ",
					   );
$e_specplot_central = $top_specplot -> Entry(
					     -textvariable => \$central_lamb,
					     );
$e_specplot_range = $top_specplot -> Entry(
					     -textvariable => \$range_lamb,
					     );

$b_specplot_exit = $top_specplot -> Button(
					   -text => "Exit",
					   -command => \&exit_kanon_linelist,
					   );

$b_specplot_plot = $top_specplot -> Button(
					   -text => "re-plot",
					   -command => \&plot_the_spec,
					   );
$b_specplot_prev = $top_specplot -> Button(
					   -text => "<<",
					   -command => \&plot_prev_section,
					   );
$b_specplot_next = $top_specplot -> Button(
					   -text => ">>",
					   -command => \&plot_next_section,
					   );
$b_specplot_exit -> grid('x',
			 -pady => 2,
			 );
$l_specplot_central -> grid($e_specplot_central,
			    -pady => 2,
			    );
$l_specplot_range -> grid($e_specplot_range,
			  -pady => 2,
			  );
$b_specplot_plot -> grid('-',
			 -pady => 2,
			 );
$b_specplot_prev -> grid($b_specplot_next,
			 -pady => 2,
			 );

$top_initmod = $mw -> Toplevel();
$top_initmod -> title("ATLAS9 model calculation");
$l_initmod = $top_initmod -> Label(
				   -text => "Please select the model to iterate from:",
				   ) -> pack(
					     -pady => 4,
					     );
$o_initmod = $top_initmod -> Optionmenu(
					-options => \@list_models,
					-variable => \$sel_initmod,
					-textvariable => \$txt_initmod,
					) -> pack;
$o_odfros = $top_initmod -> Optionmenu(
				       -options => \@list_odf_ros,
				       -variable => \$odf_ros,
				       -textvariable => \$txt_odf_ros,
				       ) -> pack;
$o_odfbig = $top_initmod -> Optionmenu(
				       -options => \@list_odf_big,
				       -variable => \$odf_big,
				       -textvariable => \$txt_odf_big,
				       ) -> pack;
$fr_init = $top_initmod -> Frame() -> pack(
					   -pady => 4,
					   );
$b_initmod = $fr_init -> Button(
				-text => "Go!",
				-command => \&calculate_new_model,
				);
$b_init_cancel = $fr_init -> Button(
				    -text => "Cancel",
				    -command => \&forget_model,
				    );

$b_init_cancel -> grid($b_initmod,
		       -pady => 5,
		       );


$top_dao = $mw -> Toplevel();
$top_dao -> title("DAOSPEC parameters");
$l_dao = $top_dao -> Label(
			   -text => "Set the parameters for DAOSPEC:",
			   ) -> pack(
				     -pady => 4,
				     );
$fr1_dao = $top_dao -> Frame(
		       -relief => 'groove',
		       -borderwidth => 0,
		       ) -> pack(
				 -pady => 6,
				 -fill => 'both',
				 );
$fr2_dao = $top_dao -> Frame(
		       -relief => 'groove',
		       -borderwidth => 0,
		       ) -> pack(
				 -pady => 6,
				 -fill => 'both',
				 );
$fr3_dao = $top_dao -> Frame(
		       -relief => 'groove',
		       -borderwidth => 0,
		       ) -> pack(
				 -pady => 6,
				 -fill => 'both',
				 );

$l_spec = $fr3_dao -> Label(
			    -text => "Spectrum to reduce: ",
			    );
$o_spec = $fr3_dao -> Optionmenu(
				 -options => \@fits_spectra,
				 -variable => \$dao_spectrum,
#				 -textvariable => \$txt_spectrum,
				 );
$c_dao_kanon = $fr3_dao -> Checkbutton(
				       -text => "Use canonical linelists",
				       -offvalue => 0,
				       -onvalue => 1,
				       -variable => \$kanon,
				       );
$c_dao_master = $fr3_dao -> Checkbutton(
				       -text => "Remake master.inp",
				       -offvalue => 0,
				       -onvalue => 1,
				       -variable => \$remake_master,
				       );
$b_dao_cancel = $fr3_dao -> Button(
				   -text => "Cancel",
				   -command => \&forget_daospec,
				   );
$b_dao_run = $fr3_dao -> Button(
				-text => "Run DAOSPEC",
				-command => \&run_daospec,
				);
$b_dao_inp = $fr3_dao -> Button(
				-text => "re-create inp files",
				-command => \&prepare_inp_files,
				);

$l_lines = $fr2_dao -> Label(
			     -text => "Restrict the linelist:",
			     );
$l_mindepth = $fr2_dao -> Label(
				-text => "Min line depth = ",
				);
$e_mindepth = $fr2_dao -> Entry(
				-textvariable => \$depth_min,
				);
$l_maxdepth = $fr2_dao -> Label(
				-text => "Max line depth = ",
				);
$e_maxdepth = $fr2_dao -> Entry(
				-textvariable => \$depth_max,
				);
$l_maxXpot = $fr2_dao -> Label(
			       -text => "Max Xpot = ",
			       );
$e_maxXpot = $fr2_dao -> Entry(
			       -textvariable => \$xpot_max,
			       );
$l_lamberr = $fr2_dao -> Label(
			       -text => "Allowed lambda error = ",
			       );
$e_lamberr = $fr2_dao -> Entry(
			       -textvariable => \$delta_lamb,
			       );

$l_dao_fw = $fr1_dao -> Label(
			    -text => "FWHM (px, estimated) = ",
			    );
$e_dao_fw = $fr1_dao -> Entry(
			    -textvariable => \$dao_fw,
			    );
$l_dao_or = $fr1_dao -> Label(
			    -text => "Order for continuum fit = ",
			    );
$e_dao_or = $fr1_dao -> Entry(
			    -textvariable => \$dao_or,
			    );
$l_dao_sh = $fr1_dao -> Label(
			    -text => "Short wavelength limit = ",
			    );
$e_dao_sh = $fr1_dao -> Entry(
			    -textvariable => \$dao_sh,
			    );
$l_dao_lo = $fr1_dao -> Label(
			    -text => "Long wavelength limit = ",
			    );
$e_dao_lo = $fr1_dao -> Entry(
			    -textvariable => \$dao_lo,
			    );
$l_dao_ba = $fr1_dao -> Label(
			    -text => "Bad data value = ",
			    );
$e_dao_ba = $fr1_dao -> Entry(
			    -textvariable => \$dao_ba,
			    );
$l_dao_re = $fr1_dao -> Label(
			    -text => "Residual core flux (\%) = ",
			    );
$e_dao_re = $fr1_dao -> Entry(
			    -textvariable => \$dao_re,
			    );
$l_dao_mi = $fr1_dao -> Label(
			    -text => "Minimum RV = ",
			    );
$e_dao_mi = $fr1_dao -> Entry(
			    -textvariable => \$dao_mi,
			    );
$l_dao_ma = $fr1_dao -> Label(
			    -text => "Maximum RV = ",
			    );
$e_dao_ma = $fr1_dao -> Entry(
			    -textvariable => \$dao_ma,
			    );
$l_dao_sm = $fr1_dao -> Label(
			    -text => "Smallest EW = ",
			    );
$e_dao_sm = $fr1_dao -> Entry(
			    -textvariable => \$dao_sm,
			    );
$l_dao_cr = $fr1_dao -> Label(
			    -text => "Create output spectra = ",
			    );
$e_dao_cr = $fr1_dao -> Entry(
			    -textvariable => \$dao_cr,
			    );
$l_dao_sc = $fr1_dao -> Label(
			    -text => "Scale FWHM with lambda = ",
			    );
$e_dao_sc = $fr1_dao -> Entry(
			    -textvariable => \$dao_sc,
			    );
$l_dao_fi = $fr1_dao -> Label(
			    -text => "Fix FWHM = ",
			    );
$e_dao_fi = $fr1_dao -> Entry(
			    -textvariable => \$dao_fi,
			    );

$l_dao_fw -> grid($e_dao_fw, $l_dao_or, $e_dao_or,
		-sticky => 'w', -pady => 2,
		);
$l_dao_sh -> grid($e_dao_sh, $l_dao_lo, $e_dao_lo,
		-sticky => 'w', -pady => 2,
		);
$l_dao_ba -> grid($e_dao_ba, $l_dao_re, $e_dao_re,
		-sticky => 'w', -pady => 2,
		);
$l_dao_mi -> grid($e_dao_mi, $l_dao_ma, $e_dao_ma,
		-sticky => 'w', -pady => 2,
		);
$l_dao_sm -> grid($e_dao_sm, $l_dao_cr, $e_dao_cr,
		-sticky => 'w', -pady => 2,
		);
$l_dao_sc -> grid($e_dao_sc, $l_dao_fi, $e_dao_fi,
		-sticky => 'w', -pady => 2,
		);

$l_lines -> grid('-','-','-',
		 -sticky => 'w', -pady => 4,
		 );
$l_mindepth -> grid($e_mindepth, $l_maxdepth, $e_maxdepth,
		    -sticky => 'w', -pady => 4,
		    );
$l_maxXpot -> grid($e_maxXpot, $l_lamberr, $e_lamberr,
		   -sticky => 'w', -pady => 4,
		   );

$l_spec -> grid($o_spec,
		-sticky => 'w', -pady => 4,
		);
$c_dao_kanon -> grid($c_dao_master,
		     -sticky => 'w', -pady => 4,
		     );
$b_dao_cancel -> grid($b_dao_run, $b_dao_inp,
		-sticky => 'w', -pady => 4,
		);

# -----------------------------------------------------------------
# now define the wigedts that go into the frames of the main window
# -----------------------------------------------------------------

$l_elemfr = $fr_elem -> Label(
			      -text => "What do you want to plot:",
			      -font => '10x16bold',
			      );
$o_diag = $fr_elem -> Optionmenu(
				 -options => [ "Fe diagnostics", "Relative abundances of:", "Absolute abundances of:" ],
				 -variable => \$plot_diag,
				 -command => \&check_what_to_plot,
				 );
$o_el1 = $fr_elem -> Optionmenu(
				-options => [ "Fe", "Ti", "Ni", "Cr", "Co", "V", "Si" ],
				-variable => \$plot_e1,
				);
$o_el2 = $fr_elem -> Optionmenu(
				-options => [ "Fe", "Ti", "Ni", "Cr", "Co", "V", "Si" ],
				-variable => \$plot_e2,
				);
$o_el3 = $fr_elem -> Optionmenu(
				-options => [ "Fe", "Ti", "Ni", "Cr", "Co", "V", "Si" ],
				-variable => \$plot_e3,
				);
$l_sigma = $fr_elem -> Label(
			     -text => " sigma clipping = ",
			     );
$e_sigma = $fr_elem -> Entry(
			     -textvariable => \$sig_lim,
			     );

$l_limits = $fr_lim -> Label(
		   -text => 'Apply limits from atomic parameters: ',
		   -font => '10x16bold',
		   );
$l_elow = $fr_lim -> Label(
			   -text => "EW(low) =",
			   );
$e_elow = $fr_lim -> Entry(
			   -textvariable => \$elow,
			   );

$l_ehig = $fr_lim -> Label(
			   -text => "EW(high) =",
			   );
$e_ehig = $fr_lim -> Entry(
			   -textvariable => \$ehig,
			   );
$l_xlow = $fr_lim -> Label(
			   -text => "Xpot(low) =",
			   );
$e_xlow = $fr_lim -> Entry(
			   -textvariable => \$xlow,
			   );

$l_xhig = $fr_lim -> Label(
			   -text => "Xpot(high) =",
			   );
$e_xhig = $fr_lim -> Entry(
			   -textvariable => \$xhig,
			   );
$l_fe1h = $fr_lim -> Label(
			   -text => "FeI(high) =",
			   );
$e_fe1h = $fr_lim -> Entry(
			   -textvariable => \$fe1hig,
			   );
$l_fe1l = $fr_lim -> Label(
			   -text => "FeI(low) =",
			   );
$e_fe1l = $fr_lim -> Entry(
			   -textvariable => \$fe1low,
			   );
$l_fe2h = $fr_lim -> Label(
			   -text => "FeII(high) =",
			   );
$e_fe2h = $fr_lim -> Entry(
			   -textvariable => \$fe2hig,
			   );
$l_fe2l = $fr_lim -> Label(
			   -text => "FeII(low) =",
			   );
$e_fe2l = $fr_lim -> Entry(
			   -textvariable => \$fe2low,
			   );
$l_lamh = $fr_lim -> Label(
			   -text => "lambda max =",
			   );
$e_lamh = $fr_lim -> Entry(
			   -textvariable => \$lamhig,
			   );
$l_laml = $fr_lim -> Label(
			   -text => "lambda min =",
			   );
$e_laml = $fr_lim -> Entry(
			   -textvariable => \$lamlow,
			   );


$t_stat = $fr_txt -> Text(      # status text with model info.
			  -height => 3,
			  );


$l_ref = $fr_top1 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "Set reference:",
			  );
$o_ref = $fr_top1 -> Optionmenu(   # the choice of reference model
#	       -relief => 'groove',
#	       -borderwidth => 1,
				  -options => \@stars_ref,
				  -textvariable => \$txt_refmodel,
				  -variable => \$reffile_prefix,
				  -command => \&set_models,
				  );

$l_cmp = $fr_top1 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "Calculate for:",
			  );
$o_cmp = $fr_top1 -> Optionmenu(   # the choice of star to analyze
#	       -relief => 'groove',
#	       -borderwidth => 1,
				  -options => \@stars,
				  -textvariable => \$txt_cmpmodel,
				  -variable => \$file_prefix,
				  -command => \&set_models,
				  );

$l_mic = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "      and vmicro:",
			  );
$e_mic = $fr_top2 -> Entry(
			   -textvariable => \$vmic,
			   );
#$o_mic = $fr_lim -> Optionmenu(   # the choice of v_mic from the abn/inp files
#	       -relief => 'groove',
#	       -borderwidth => 1,
#				  -options => [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.4, 2.6, 2.8, 3.0],
#				  -textvariable => \$txt_vmic,
#				  -variable => \$vmic,
#				  -command => \&update_inp_files,
#				  );
$l_newmod = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "or make a new model... ",
			  );
$l_teff = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "Teff = ",
			  );
$l_logg = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "logg = ",
			  );
$e_teff = $fr_top2 -> Entry(
			    -textvariable => \$newTeff,
			    );
$e_logg = $fr_top2 -> Entry(
			    -textvariable => \$newlogg,
			    );
$e_mh = $fr_top2 -> Entry(
			    -textvariable => \$newmh,
			    );
$l_mh = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "[M/H] = ",
			  );
$b_newmod = $fr_top2 -> Button(
			       -text => "Make new model",
			       -command => \&show_the_models,
			       );

$l_mod = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "Choose a model: ",
			  );
$o_mod = $fr_top2 -> Optionmenu(   # the choice of .mod file for this star
				   -options => \@model,
				   -textvariable => \$txt_mod,
				   -variable => \$model,
				   -command => \&copy_model,
				  );
$l_ps = $fr_top1 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			  -text => "Output graphs on: ",
			  );
$o_ps = $fr_top1 -> Optionmenu(
			       -options => ["PS file","screen"],
			       -textvariable => \$txt_ps,
			       -variable => \$ps,
			       -command => \&set_ps_filename,
			       );

$l_toptext = $fr_top1 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			       -font => '10x16bold',
			       -text => 'Setup: Select from the menus:',
			       );
$l_modeltext = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			       -font => '10x16bold',
			       -text => 'Model settings: ',
			       );
$l_dum0 = $fr_top1 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			   -text => '          ',
			   );
$l_dum1 = $fr_top1 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			   -text => '          ',
			   );
$l_dum11 = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			   -text => '          ',
			   );
$l_dum10 = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			   -text => '          ',
			   );
$l_dum12 = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			   -text => '          ',
			   );
$l_dum13 = $fr_top2 -> Label(
#	       -relief => 'groove',
#	       -borderwidth => 1,
			   -text => '          ',
			   );
$b_exit = $fr_top1 -> Button(
			    -text => "Exit",
			    -command => \&my_exit,
			    );
$b_dao = $fr_top1 -> Button(
			    -text => "Get EWs",
			    -command => \&prepare_daospec,
			    );
$b_linelist = $fr_top1 -> Button(
				 -text => "Linelist",
				 -command => \&make_kanon_linelist,
				 );


$b_run = $fr_top2 -> Button(  # runs Width_new using the currently selected model
			   -text => "Get new abund.",
			   -command => \&run_width_new,
			   );

$b_abn = $fr_lim -> Button(        # combines the abundances based on the chosen selection criteria for EW and Xpot
			   -text => "Apply limits",
			   -command => \&do_the_rest,
			   );
$b_inp = $fr_lim -> Button(        # takes the current set of lines defined by the limits and make them into the new .inp files
			   -text => "Take current set of lines",
			   -command => \&take_linelist,
			   );


# ---------------------------------------------------
# now pack the widgets with grid and draw the window
# ---------------------------------------------------

$l_toptext -> grid('-', $l_dum0, $l_ref, $o_ref,
	       -sticky => 'w',
	       -pady => 4,
	       );
$l_dum1 -> grid('x', 'x', $l_cmp, $o_cmp,
	       -sticky => 'w',
	       -pady => 4,
	       );
$b_exit -> grid($b_dao, $b_linelist, $l_ps, $o_ps,
	       -sticky => 'w',
	       -pady => 4,
	       );


$l_modeltext -> grid('-', '-','-',
		     -sticky => 'w',
		     -pady => 4,
		     );
$l_mod -> grid($o_mod, $l_mic, $e_mic,    #$b_run,
	       -sticky => 'w',
	       -pady => 6,
	       );
$l_dum13 -> grid('x','x',$b_run,
		 -sticky => 'ne',
		 -pady => 6,
		 );
$l_newmod -> grid($l_teff, $e_teff, 'x',
		  -sticky => 'e',
		  -pady => 4,
		  );
$l_dum10 -> grid($l_logg, $e_logg, 'x',
		 -sticky => 'e',
		 -pady => 4,
		 );
$l_dum11 -> grid($l_mh, $e_mh, 'x',
		 -sticky => 'e',
		 -pady => 4,
		 );
$l_dum12 -> grid('-', 'x', $b_newmod,
		 -sticky => 'w',
		 -pady => 4,
		 );

$l_elemfr -> grid('-','-','-','-','-',
	       -sticky => 'w',
	       -pady => 4,
	       );
$o_diag -> grid($o_el1, $o_el2, $o_el3, $l_sigma, $e_sigma,
	       -sticky => 'w',
	       -pady => 4,
	       );

$l_limits -> grid('-','-','-',
	       -sticky => 'w',
	       -pady => 4,
	       );
$l_elow -> grid($e_elow, $l_ehig, $e_ehig,
	       -sticky => 'w',
	       -pady => 4,
	       );
$l_xlow -> grid($e_xlow, $l_xhig, $e_xhig,
		-sticky => 'w',
		-pady => 4,
		);
$l_fe1l -> grid($e_fe1l, $l_fe1h, $e_fe1h,
		-sticky => 'w',
		-pady => 4,
		);
$l_fe2l -> grid($e_fe2l, $l_fe2h, $e_fe2h,
		-sticky => 'w',
		-pady => 4,
		);
$l_laml -> grid($e_laml, $l_lamh, $e_lamh,
		-sticky => 'w',
		-pady => 4,
		);

#$l_mic -> grid($o_mic, '-','x',
#	       -sticky => 'w',
#	       -pady => 4,
#	       );
$b_abn -> grid('-',$b_inp,'-',
	       -sticky => 'w',
	       -pady => 4,
	       );


$t_stat -> grid('-','-','-',
		-sticky => 'w',
		);

&set_models;
&check_what_to_plot;

$b_inp -> configure(-state => 'disabled');
$mw -> raise();
$top_dao -> lower();
$top_initmod -> lower();
$top_specplot -> lower();

MainLoop;



######   END of window definitions        #################################
######  now follows the subroutines       #################################


sub read_asc_spec {
    open SPEC, "<$test";
    @flux = ();   @wave = ();
  OUTER:
    while ( $in = <SPEC> ) {
	chomp( $in );
	$in =~ s/^\s+//s;
	if ( $in =~ /CRVAL1/ ) {
	    ($d1, $d2, $wl1, $d3) = split /\s+/, $in;
	    $lowlimit = $wl1;
	}
	if ( $in =~ /CDELT1/ ) {
	    ($d1, $d2, $wldelt, $d3) = split /\s+/, $in;
	}
	if ( $in =~ /^\d+/ ) {
	    push @flux, $in;   push @wave, $wl1;
	    while ( $in = <SPEC> ) {
		chomp( $in );
		$in =~ s/^\s+//s;
		$wl1 += $wldelt;
		push @flux, $in;   push @wave, $wl1;
	    }
	    last OUTER;
	}
    }
    $higlimit = $wl1;
    $num = @flux;
    close SPEC;
}


sub read_fits_spec {
    @flux = ();   @wave = ();
    my ($status, $naxis1);
    my $fptr = Astro::FITS::CFITSIO::open_file($test,Astro::FITS::CFITSIO::READONLY(),$status);
    check_status($status) or die;
    $fptr -> read_key_str('NAXIS', $dim, undef, $status);
    die "Wrong dimemensions fits file!\n" if ($dim != 1);
    $fptr->read_key_str('NAXIS1',$naxis1,undef,$status);
    # prepare the wavelength/velocity scale
    $fptr -> read_key_str('CRVAL1', $wl1, undef, $status);
    $fptr -> read_key_str('CDELT1', $wldelt, undef, $status);
    for ($i = 0; $i < $naxis1; $i++) {
	push @wave, $wl1 + $i * $wldelt;
    }
    $fptr -> read_subset(Astro::FITS::CFITSIO::TDOUBLE(), 1, $naxis1, [1], $nullarray, $array, $anynull ,$status);
    @flux = @$array or die;
    $lowlimit = $wl1;
    $higlimit = $wave[-1];
    $num = @flux;
    $fptr -> close_file($status);
    check_status($status) or die;
}


sub make_kanon_linelist {
    $top_specplot -> raise();
    chdir( $cmp_prefix );   print "now in $cmp_prefix\n";
    &get_radvel_corr;
    # read the spectrum (asci-file or fits-file -- must be created first)
    $test = 'asc.' . $file_prefix;  print "Looking for $test\n";
    if (-e $test) {
	&read_asc_spec;
    } else {
	# no ascii, so there must be a fits spectrum
	$test = $file_prefix . ".fits";
	unless (-e $test) {
	    print "FATAL: no spectrum!\n";
	    return;
	}
	&read_fits_spec;
    }
    $line_list_name = $test;
    $plot_spec = 1;
    &read_all_lines;
    &plot_the_spec;

}

sub exit_kanon_linelist {
    $plot_spec = 0;
    $top_specplot -> lower();
    if (-e "vald.kanonlist") {
	rename "vald.kanonlist", "vald.kanonlist.old";
    }
    open KAN, ">vald.kanonlist" || die "wjjjjd...";
    print KAN "$d1"; 
    foreach $in (sort keys %kanonlist) {
	print KAN "$kanonlist{$in}";
    }
    close KAN;
}

sub read_all_lines {
    if (-e "vald.kanonlist.FULL.lst") {
	open LINES, "<vald.kanonlist.FULL.lst" or die "no kanon...";    # contains all possible lines... this file is REQUIRED!!
    } else {
	open LINES, "<$list_default" or die "no default kanon...";
    }
    $d1 = <LINES>;
    $pos = 0;
    open SPLOT, ">input_for_splot_ALL" or die "splotyyyyy...";     # corrected wavelengths for splot
    while ( $in = <LINES> ) {
	$el = substr $in, 1, 4;
	$wl = substr $in, 7, 9;
	$dp = substr $in, 69, 5;   #  print "---$dp---\n"; exit;
	$el{$wl} = $el;
	$pos{$wl} = $pos;
	$dp{$wl} = $dp;
	$adjusted{$wl} = $wl + ($radvel * $wl / 300000.0);                            #### CHECK THIS
	print SPLOT "$adjusted{$wl}\n";
    }
    close LINES;
    close SPLOT;
    %kanonlist = ();
    if (-e "vald.kanonlist") {
	open LINES, "<vald.kanonlist" or die "kkkkqkqqqqo";
	$d1 = <LINES>;
	while ( $in = <LINES> ) {
	    $wl = substr $in, 7, 9;
	    $kanonlist{$wl} = $in;
	}
	close LINES;
    }
    
}

sub check_what_to_plot {

    # shade the element pull-downs if they are not to be used.
    if ($o_el1) {

	if ($plot_diag =~ /diagnostics/) {
	    $o_el1 -> configure(-state => 'disabled');
	    $o_el2 -> configure(-state => 'disabled');
	    $o_el3 -> configure(-state => 'disabled');
	} else  {   
	    $o_el1 -> configure(-state => 'normal');
	    $o_el2 -> configure(-state => 'normal');
	    $o_el3 -> configure(-state => 'normal');
	}
    
	if ($plot_diag =~ /Absolute/ ) {
	    $absolute = 1;
	} else {
	    $absolute = 0;
	}
    }
}





sub forget_daospec {

    $top_dao -> lower();

}


sub forget_model {

    $top_initmod -> lower();

}


sub prepare_daospec {

    $top_dao -> raise();
    chdir $workdir . $file_prefix;

    &update_fits_spectra;

}

sub update_fits_spectra {

    # list of possible spectra
    chomp( @fits_spectra = `ls -1 HD*.fits` );
    $o_spec -> configure(
			 -options => \@fits_spectra,
			 );
}


sub take_linelist {
    # read all the current Fe*.inp files, and write the lines that has not been cut away to new inp files.
    @list = ();
    foreach $f ( glob("HD*Fe*.inp") ) {
	open FE, "<$f" or die "sskkk 90";    print "$f:\n";
	while ($in = <FE>) {
	    if ($in =~ /Fe /) {
		$lamb = substr $in, 7, 8;
		$lamb =~ s/\s+//s;       #  $test = grep /$lamb/, (@wl,@wl2);    print "$lamb :: $test\n";
		if ( grep /$lamb/, (@wl,@wl2) ) {
		    push @list, $in;      
		}
	    }
	}
	close FE;
	rename $f, "$f.old";
    }
    # now we have all the lines
    `rm -f *Fe*.inp`;
    $match = @list;   print "total $match lines\n";
    $element = "Fe";
    $num = 0;
    
    &open_proper_file;
    foreach $in (@list) {
	&get_the_lun;
	print $lun "$in";
	$written{$lun}++;
	if ( $written{$lun} >= 150 ) {
	    &close_inp_file;
	    delete $written{$lun};
	}
    }
    foreach $lun (keys %written) {
	&close_inp_file;
    }

}

sub open_proper_file {
  MAX150:
    if ($match > 150) {
	$name = $file_prefix . "_$element" . "_$num" . ".inp";
	$lun = $element . $num;
		print "$lun -> $name\n";
	$match -= 150;
	$num++;
	$num_in_this = 150;
	&open_inp_file;
	goto MAX150;
    }
    chomp( $num_in_this = $match );
    if ($num > 0) {
	$name = $file_prefix . "_$element" . "_$num" . ".inp";
	$lun = $element . $num;
		print "$lun -> $name\n";
	&open_inp_file;
    } else {
	$name = $file_prefix . "_$element.inp";
	$lun = $element;
		print "$lun -> $name\n";
	&open_inp_file;
    }
}

sub get_the_lun {
    $alt0 = $element . "0";
    $alt1 = $element . "1";
    $alt2 = $element . "2";
    $alt3 = $element . "3";
    $alt4 = $element . "4";
    $alt5 = $element . "5";
    $alt6 = $element . "6";
    if ( exists $written{$element} ) {
	$lun = $element;
    } elsif ( exists $written{$alt0} ) {
	$lun = $alt0;
    } elsif ( exists $written{$alt1} ) {
	$lun = $alt1;
    } elsif ( exists $written{$alt2} ) {
	$lun = $alt2;
    } elsif ( exists $written{$alt3} ) {
	$lun = $alt3;
    } elsif ( exists $written{$alt4} ) {
	$lun = $alt4;
    } elsif ( exists $written{$alt5} ) {
	$lun = $alt5;
    } elsif ( exists $written{$alt6} ) {
	$lun = $alt6;
    } else {
	print "something wrong.... stop\n";
	print "element: $element, line = $in\n";
	exit;
    }
}


sub run_daospec {

    # all options are set (or should be) so prepare the daospec.opt file
    # and the batch file for running daospec.

    # make the laboratory.dat file
    # look for anything called "*.lst" and assume the newest one is what we want
    # and assume it is in VALD format (get stellar query), then make the line list.
    #
    $c_dao_master -> select();     # make sure we remake the master.inp as well
    `ls -1rt *.lst | tail -1 > tmp.tmp`;
    chomp( $test = `cat tmp.tmp` );
    unless ($test) {
	$test = $list_default;     # in case we didd not create a specific one, we use the default
    }
    print `pwd`;
    print "Basing linelist on file $test\n";
    unless (-e $test) {
	print "ERROR: cannot find .lst file. Found name = $test\n";
	exit;
    }
#    `rm -f tmp.tmp`;
    open IN, "<$test" or die "erorr pening vald list";
    open OUT, ">laboratory.dat" or die "no open lab-file";
    $dum1 = <IN>;  # header line....

    while ( $in = <IN> ) {
	last if ($in =~ /References/);
	$depth = substr $in, 69, 5;
	next if ($depth > $depth_max || $depth < $depth_min);
	$in = substr $in, 0, 69;
	$lamb = substr $in, 7, 10;
	$lamb =~ s/\s+//s;
	$xpot = substr $in, 18, 8;
	next if $xpot > $xpot_max;
	$test = sprintf "%8.8s$in", $lamb;
	print OUT "$test\n";
    }
    close IN;
    close OUT;

    # make the opt file 
    open OUT, ">daospec.opt" or die "no daospec opt file";
    print OUT "ve=2\nwa=0\nle=$dao_sh\nri=$dao_lo\n";    # always these for non-graphical
    print OUT "fw=$dao_fw\nor=$dao_or\nsh=$dao_sh\nlo=$dao_lo\n";
    print OUT "ba=$dao_ba\nre=$dao_re\nmi=$dao_mi\nma=$dao_ma\n";
    print OUT "sm=$dao_sm\ncr=$dao_cr\nsc=$dao_sc\nfi=$dao_fi\n";
    close OUT;

    # make the batch file
    open OUT, ">run.daospec" or die "cannot open runfile";
    print OUT "#!/bin/csh\n#\n";
    $test = $atlas_exe . "daospec";
    print OUT "$test << EOF >! logfile\n";
    print OUT "\n$dao_spectrum\n\nEOF\n";
    close OUT;
    `chmod u+x run.daospec`;
    `./run.daospec`;
    $test = `cat logfile`;
    print "RESULTS:\n--------------------\n$test\n";

    # done - so now prepare the .inp files
    &prepare_inp_files;
 
}


sub prepare_inp_files {

    # the $dao_spectrum without the .fits extension + 'daospec' is the output file
    # must compare line by line with laboratory.dat to identify, grab the EW and write 
    # a new line to a master file.  Then split in element .inp files.

    $test = $dao_spectrum;
    $test =~ s/.fits//s;
    $test = $test . ".daospec";
    $radvel = `head -1 $test | awk '{print \$4}'`; print "radvel = $radvel\n";

    # first delete all the old .inp files if present
    `rm -f HD*.inp`;

    # check if master.inp should be re-created
    if ($remake_master) {
	`rm -f input_for_splot txtstring_splot`;
	
	open OUT, ">master.inp" or die "error 42";

	# loop through the master.inp file and write to the output
	#
	if (-e "vald.kanonlist") {
	    open LAB, "<vald.kanonlist" or die "error 33";
	    $lamb_from = 8;  $out_from = 0;
	} else {
	    print "WARNING:  You did not not go through the line selection process!\n";
	    open LAB, "<laboratory.dat" or die "error 32";
	    $lamb_from = 0;  $out_from = 8;
	}
      LABENTRY:while ( $in = <LAB>  ) {
	  $trysplot = 1;    # flag - assume we don't find it, so we should try splot.log afterwards
	  $found = 0;
	  chomp( $in );
	  $lamb = substr $in, $lamb_from, 8;
	  $outstring = substr $in, $out_from, 69;
	  open DAO, "<$test" or die "errror 43";
	  # two lines of header in daospec output:
	  $dum1 = <DAO>;
	  $dum1 = <DAO>;
	DAO_LOOP:while ( $dao_in = <DAO>  ) {
	    chomp( $dao_in );
	    $lamb_dao = substr $dao_in, 10, 8;
	    last DAO_LOOP if ( $lamb_dao > $lamb+$delta_lamb );
	    if ( $lamb_dao < $lamb+$delta_lamb && $lamb_dao > $lamb-$delta_lamb ) {
		# we have a match... or we think we have.... depends on value of $delta_lamb
		($dum1, $dum2, $ew, $dum3) = split /\s+/, $dao_in;
		chop( $outstring );
		$dum1 = sprintf "$outstring%5.5s, 'written by abund_gui (DAO)'\n", $ew;
		print OUT "$dum1";                                 #  print "found in DAO\n";
		$found = 1;
		$trysplot = 0;       # don't look in splot.log for this line
		last DAO_LOOP;       # found a match for this line, now go on
	    }
	} 
	  close DAO;
	  next LABENTRY unless $trysplot;
	  #  maybe nothing in daospec file, look for a splot.log
	  if (-e "splot.log" && -s "splot.log" && $trysplot == 1) {
	      open SPLOT, "<splot.log" or die "error 93";                                 # print "looking in splot for $lamb\n";
	    IRAF:
	      while ( $in = <SPLOT> ) {
		  chomp( $in );
		  next IRAF unless ($in =~ /\d/ && $in !~ /[.*]/);
		  $in =~ s/^\s+//s;
		  ($lamb_iraf, $dum1, $dum2, $ew, $dum3) = split /\s+/, $in;
		  $ew = sprintf "%5.1f", $ew * 1000.0;                                      #  print "checking against $lamb_iraf (RVcorrected = ";
		  $lamb_iraf = $lamb_iraf * ($radvel / -300000.0) + $lamb_iraf;           # print "$lamb_iraf)\n";      # doppler correct lambda
		  if ( $lamb_iraf < $lamb+$delta_lamb && $lamb_iraf > $lamb-$delta_lamb ) {
		      # we think we have a match...
		      chop( $outstring );
		      $dum1 = sprintf "$outstring%5.5s, 'written by abund_gui (splot)'\n", $ew;            #  print "found $lamb at $lamb_iraf: $outstring\n";
		      print OUT "$dum1";
		      $found = 1;
		      last IRAF;
		  }
	      }
	      close SPLOT;
	  }
	  # print the RV corrected line positions if the line was not found, so we may use splot 'd' with this file
	  if ($found == 0) {
	      $lamb_iraf = $lamb * ($radvel / 300000.0) + $lamb;
	      `echo $lamb_iraf >> input_for_splot`;
	      `echo $outstring >> txtstring_splot`;
	  }
      }
	close LAB;

	close OUT;
    }

    # now we have the master.inp with everything. We want individual files for each element,
    # so loop through all elements and check if they are present. Open and write...
    foreach $element (@elements) {
	$match = `grep -c '$element ' master.inp`;
	if ($match > 0) {
	    $element =~ s/\s+//s;
	    $num = 0;
	    # check if there is a canonical list for this element
	    # if yes, find number of lines actually present
	    $test = "linelist.$element.kanon";
	    if ($kanon == 1 && -e $test) {
		open KANON, $test;
		$match = 0;
		while ( $in = <KANON> ) {
		    chomp( $in );
		    $test = `grep -c '$in' master.inp`;                #      print "$in -> $test";
		    $match += $test;
		}
	    }
	    &open_proper_file;
	}
    }
#    print keys %written;
    open MASTER, "<master.inp" or die "yrk!";
 READTHEMASTER:
    while ( $in = <MASTER> ) {
	# read in a line, check which file it should go to
	$element = substr $in, 1, 2;
	$element =~ s/\s+//s;

	&get_the_lun;
	print $lun "$in";
	$written{$lun}++;
	if ( $written{$lun} >= 150 ) {
	    &close_inp_file;
	    delete $written{$lun};
	}

    }
    close MASTER;
    foreach $lun (keys %written) {
	&close_inp_file;
    }
    $top_dao -> lower();


}

sub close_inp_file {
    $dum1 = "'" . $file_prefix . ".mod',\n1 2.0\n0.0\n";
    print $lun "$dum1";
    close $lun;
}


sub open_inp_file {

    $written{$lun} = 0;
    open $lun, ">$name" or die "bldrk!";
    print $lun "100. 40000. $num_in_this\n";
    print $lun " Width_new $name\n";
    print $lun "Elm Ion  WL(A)    Excit(eV) Vmic log(gf) Rad.   Stark  Waals factor   EQW  Reference\n";
    
}


sub update_inp_files {

    # change the second last line in all the inp files to read soemthing like "1 1.4" 
    # or whatever vmic is supposed to be.

    if ( chdir $cmp_prefix ) {
	print "Updating .inp files in $cmp_prefix\n";
	@runlist = `ls -1 *.inp`;
	foreach $in (@runlist) {
	    chomp( $in );
	    $test = $in . ".old";
	    `cp $in $test`;
	    open IN, "<$test" or die "error opening inp file $!";
	    open OUT, ">$in" or die "errorr modifying inp file";
	    while ($line = <IN>) {
		if ($line =~ /^\d\s/) {
		    $line = "1 $vmic\n";
		}
		print OUT $line;
	    }
	    close OUT;
	    close IN;
	}
    } else {
	print "error..........";
	exit;
    }

    &update_text;
    &set_ps_filename;
}


sub do_the_rest {

    # make list of .abn files to merge and analyse
    @list_of_abn = glob( $cmp_prefix . $file_prefix . "*.abn");
    $current_prefix = $cmp_prefix;
    $cur_file_prefix = $file_prefix;
    &merge_abn_files;

    if ($plot_diag =~ /diagnostics/) {
	@list_of_abn = glob( $cmp_prefix . "abn_" . $file_prefix . "*Fe*" . $vmic);
    } else {
	@list_of_abn = glob( $cmp_prefix . "abn_" . $file_prefix . "*" . $vmic);
    }

    &compare_two_stars unless $plot_diag =~ /Absolute/;  # don't compare if we are not doing the relative...

    @list_of_abn = glob( $cmp_prefix . "relabn_" . $reffile_prefix . $file_prefix . "*" . $vmic);
    # get the relative abundance, plot them for three elements and make a nice output table.
    # OR... work only on Fe and plot diagnostics to evaluate the used model
    #
    if ($plot_diag =~ /Relative/) {
	&get_relative_abund;
    } elsif ($plot_diag =~ /diagnostics/) {
	&plot_diagnostics;
    } elsif ($plot_diag =~ /Absolute/) {
	@list_of_abn = glob( $cmp_prefix . "abn_" . $file_prefix . "*" . $vmic);
	&get_absolute_abund;
    } else {
	print "WARNING: something wrong"; exit;
    }

    $b_inp -> configure(-state => 'normal');
}



sub run_width_new {

    # update the inp files and delete old abn files just to be sure...
    &update_inp_files;
    `rm -f HD*.abn`;

    $test = $cmp_prefix;
    if ( chdir $test ) {
	print "Now running in $test\n";
	if ($plot_diag =~ /diagnostics/) {
	    @runlist = `ls -1 HD*_Fe*.inp`;
	} else {
	    @runlist = `ls -1 HD*.inp`;
	}
	foreach $in (@runlist) {
	    chomp( $in );
	    print "$in ...";
	    $test = $atlas_exe . "Width_new $in";
	    $error = `$test`;
	    unless ($error) {
		print "Done!\n";
	    }
	}
    }
    
    &do_the_rest;
    
}


sub init_abund_arrays {

    $neutral = 0;
    $ionized = 0;
    @ew1 = ();  @ew2 = ();  @expot1 = ();  @expot2 = (); @wl =(); @lande =(); @ew_wl =();
    $file =~ /.*\_([a-zA-Z]{1,2})\_\d.\d/;
    $elem = $1;
    print "$elem: ";

    # test if there are lines of the neutral species
    $test = $elem . "1";
    if (`grep $test $file`) {
	$neutral = 1;
	@el1 = ();       # the abundances of the neutral species
    }
    
    # test if there are ionized species too...  NOTE!!!!! only finds singly ionized species!!!!!!!!!!!!!!!!
    $test = $elem . "2";
    if (`grep $test $file`) {
	$ionized = 1;
	@el2 = ();       # the abundances of the singly ionized species
    }
    
}

sub makeFefile {
    # makes a file with the Fe lines i + ii in separate files.
    # including wl, EW and Xpot for later plotting
    # first line is 'a siga b sigb' for abund = a + b*EW    (only Fe1 file)
    # second line the same for abund = a + b*Xpot
    $j = @el1;
    open FELIST, ">linelist.Fe.kanon.suggest" or die "asejrfu 7";
    open FE1, ">diagnosticsFe1" or die "hssss 8";
    print FE1 "@fit_ew\n";
    print FE1 "@fit_xp\n";
    for ($i = 0; $i < $j; $i++) {
	print FE1 "$wl[$i]  $el1[$i]  $ew1[$i]  $expot1[$i]\n";
	print FELIST "$wl[$i]\n";
    }
    close FE1;
    $j = @el2;
    open FE2, ">diagnosticsFe2" or die "hssss 9";
    for ($i = 0; $i < $j; $i++) {
	print FE2 "$wl2[$i]  $el2[$i]  $ew2[$i]  $expot2[$i]\n";
	print FELIST "$wl2[$i]\n";
    }
    close FE2;
    close FELIST;
}


sub read_in_relabn_file {
    my ($mean, $num, $sig);
    while ( $in = <IN> ) {
	@star = split /\s+/, $in;
	if ( $star[0] =~ /1/ ) {    # neutral species
	    push @wl, $star[1];
	    push @lande, $star[4];    # Lande factor
	    push @el1, $star[9];       # abundance for this line
	    push @ew1, $star[5];       # EW of the star (not the reference)
	    push @ew_wl, $star[5]/$star[1];
	    push @expot1, $star[2];    # excitation potential for the line
	} else {                    # ionized species...
	    push @wl2, $star[1];
	    push @el2, $star[9];
	    push @ew2, $star[5];       # EW of the star (not the reference)
	    push @expot2, $star[2];    # excitation potential for the line
	}
    }
    close IN;

    # now apply sigma clipping to the abundances.
    $lim_hig = $fe1hig; $lim_low = $fe1low;
    ($a,$b,$c,$d) = clip( \@el1, \@wl, \@ew1, \@expot1 );
    @el1 = @$a;  @wl = @$b;  @ew1 = @$c;  @expot1 = @$d;
    $lim_hig = $fe2hig; $lim_low = $fe2low;
    ($a,$b,$c,$d) = clip( \@el2, \@wl2, \@ew2, \@expot2 );
    @el2 = @$a;  @wl2 = @$b;  @ew2 = @$c;  @expot2 = @$d;

}

sub clip {
    # apply sigma clipping OR clipping from limits.  If sigma > 0 then NO limit-clipping will be done
    my (@el, @w, @xp, @ew);
    my ($a, $b, $c, $d);
    ($a,$b,$c,$d) = @_;
    @el = @$a;  @w = @$b;  @ew = @$c;  @xp = @$d;
    
    $num = @el;
    if ($num >= 7) {                      # NOTE::: hard coded limit
	$mean = sum( @el ) / $num;    print "Mean = $mean  ";
	if ( $sig_lim > 0 ) {
	    if ( $neutral ) {
		$sig = sigma( $mean, @el );   print "sigma = $sig\n";
		for ($i = 0; $i < $num; $i++) {
		    if ( $el[$i] > ($mean + $sig_lim * $sig) || $el[$i] < ($mean - $sig_lim * $sig) ) {  
			$ew[$i] = "A";  $el[$i] = "A";  $w[$i] = "A"; $xp[$i] = "A";
		    }
		}
	    }
	} else {
	    for ($i = 0; $i < $num; $i++) {
		if ( $el[$i] > $lim_hig || $el[$i] < $lim_low) {
		    $ew[$i] = "A";  $el[$i] = "A";  $w[$i] = "A"; $xp[$i] = "A";
		}
	    }
	}
	@ew = prune( @ew );   @el = prune( @el );
	@w = prune( @w );     @xp = prune( @xp );
    }
    return ( \@el, \@w, \@ew, \@xp );
}

sub read_in_absabn_file {
    my ($mean, $num, $sig);
    while ( $in = <IN> ) {
	@star = split /\s+/, $in;
	if ( $star[0] =~ /1/ ) {    # neutral species
	    push @el1, $star[6];       # abundance for this line
	    push @ew1, $star[5];       # EW of the star (not the reference)
	    push @expot1, $star[2];    # excitation potential for the line
	} else {                    # ionized species...
	    push @el2, $star[6];
	    push @ew2, $star[5];       # EW of the star (not the reference)
	    push @expot2, $star[2];    # excitation potential for the line
	}
    }
    close IN;
    # now apply sigma clipping to the abundances.
    if ( $sig_lim > 0 ) {
	$num = @el1;
	if ($num >= 7) {                                                     # NOTE::: hard coded limit!!!!!!!!!
	    $mean = sum( @el1 ) / $num;    #print "Mean = $mean  ";
	    $sig = sigma( $mean, @el1 );   #print "sigma = $sig\n";
	    for ($i = 0; $i < $num; $i++) {
		if ( $el1[$i] > ($mean + $sig_lim * $sig) || $el1[$i] < ($mean - $sig_lim * $sig) ) {  
		    $ew1[$i] = "A";  $el1[$i] = "A";  $expot1[$i] = "A";
		}
	    }
	    @ew1 = prune( @ew1 );   @el1 = prune( @el1 );   @expot1 = prune( @expot1 );
	}
	$num = @el2;
	if ($num >= 7) {                                                     # NOTE::: hard coded limit!!!!!!!!!
	    $mean = sum( @el2 ) / $num;   # print "Mean = $mean  ";
	    $sig = sigma( $mean, @el2 );  # print "sigma = $sig\n";
	    for ($i = 0; $i < $num; $i++) {
		if ( $el2[$i] > ($mean + $sig_lim * $sig) || $el2[$i] < ($mean - $sig_lim * $sig) ) {  
		    $ew2[$i] = "A";  $el2[$i] = "A";  $expot2[$i] = "A";
		}
	    }
	    @ew2 = prune( @ew2 );   @el2 = prune( @el2 );   @expot2 = prune( @expot2 );
	}
    }
}



sub prune {

    my @arr;  my $arr;
    @arr = ();
    foreach $arr (@_) {
	unless ($arr =~ /A/) {
	    @arr = (@arr, $arr);
	}
    }

    return @arr;
}


sub get_absolute_abund {

    print "Calculating absolute abundances for $file_prefix:\n";
    $test = $file_prefix . "absabn_" . $file_prefix . "table.asc";
    open TABLE, ">$test" or die "error opening table";
    print TABLE "Absolute abundances for $file_prefix\n";
    print TABLE "-------------------------------------------------------\n";

    # prepare the plotting device
 &init_graph;

    READABS:foreach $file (@list_of_abn) {

	&init_abund_arrays;

	if (-s $file) {
	    open IN, "<$file" or die "error opening $file...";  # print "File = $file\n";
	} else {
	    print "n=0\n";
	    next READABS;
	}

	&read_in_absabn_file;

	&make_plot_and_table_entry;
    }

    close TABLE;
    &end_graph;
}


sub get_relative_abund {
    
    print "Calculating relative abundances for $file_prefix - $reffile_prefix:\n";
    $test = $cmp_prefix . "relabn_" . $reffile_prefix . $file_prefix . "table.asc";
    open TABLE, ">$test" or die "error opening table";
    print TABLE "Relative abundances for $file_prefix - $reffile_prefix:\n";
    print TABLE "-------------------------------------------------------\n";

    # prepare the plotting device
    &init_graph;

    # from the relabn* files, construct the abundances of all elements and ionic species
    READREL: foreach $file (@list_of_abn) {

	&init_abund_arrays;

	# check that the file has non-zero size
	if (-s $file) {
	    open IN, "<$file" or die "error opening $file...";
	} else {
	    print "n=0\n";
	    next READREL;
	}

	# read in the file for processing
	&read_in_relabn_file;

	&make_plot_and_table_entry;

    } #end READ

    close TABLE;
    &end_graph;

}


sub make_plot_and_table_entry {
    # neutral species (most often = everything)
    $abn = sum( @el1 );
    $num = @el1;
    if ($neutral && $num > 0) {     # might be only ionized species...
	$abn = sprintf "%5.2f", $abn / $num;
	if ($num >= 7) {                                # NOTE:: hard coded limit!!!
	    $sigma = sigma( $abn, @el1 );
	} else {
	    $sigma = "0.0000";
	}
	$test = sprintf "%5.2f", $sigma;
	$sigma = substr( $test, -2 );
	print "$abn($sigma) n=$num";
	print " [$elem" . "1],  ";
	$ab1 = sprintf "%5.2f(%2d) %3d", $abn,$sigma,$num;
	if ($elem =~ /$plot_e1/ || $elem =~ /$plot_e2/ || $elem =~ /$plot_e3/) {
	    &plot_results_ew(1,\@ew1, \@el1);
	    $save1 = $abn;   # save it for the exit.plot
	}
    } else {
	$ab1 = "99.99(00)   0";
    }
    
    # if there were ionized species, some additional info
    $num = @el2;
    if ($ionized && $num > 0) {
	$abn = sum( @el2 );
	$abn = sprintf "%5.2f", $abn / $num;
	if ($num >= 7) {                               # NOTE:: hard coded limit!!!
	    $sigma = sigma( $abn, @el2 );
	} else {
	    $sigma = "0.0000";
	}
	$test = sprintf "%5.2f", $sigma;
	$sigma = substr( $test, -2 );
	print "$abn($sigma) n=$num [$elem" . "2], ";
	$ab2 = sprintf "%5.2f(%2d) %3d", $abn,$sigma,$num;
	if ($elem =~ /$plot_e1/ || $elem =~ /$plot_e2/ || $elem =~ /$plot_e3/) {
	    &plot_results_ew(2,\@ew2, \@el2);
	    $save2 = $abn;
	}
    } else {
	$ab2 = "99.99(00)   0";
    }
    
    # ...plus when using all lines together
    @el = (@el1, @el2);
    $num = @el;
    if ($ionized && $neutral && $num > 0) {
	$abn = sum( @el );
	$abn = sprintf "%5.2f", $abn / $num;
	if ($num >= 7) {                               # NOTE:: hard coded limit!!!
	    $sigma = sigma( $abn, @el );
	} else {
	    $sigma = "0.0000";
	}
	$test = sprintf "%5.2f", $sigma;
	$sigma = substr( $test, -2 );
	print "$abn($sigma) combined";
	$ab3 = sprintf "%5.2f(%2d) %3d", $abn,$sigma,$num;
	if ($elem =~ /$plot_e1/ || $elem =~ /$plot_e2/ || $elem =~ /$plot_e3/) {
	    $abn = $save1;
	    &plot_results_xp(1,\@expot1, \@el1);
	    $abn = $save2;
	    &plot_results_xp(2,\@expot2, \@el2);
	}
    } else {
	$ab3 = "99.99(00)   0";
    }
    write TABLE;
    print "\n";
}



sub compare_two_stars {
    
    #take the first file of the star in question, see if the ref star has similar file
    foreach $file (@list_of_abn) {

	$ref_flag = 0;   # has a similar file?
	$file =~ /.*\_([a-zA-Z]{1,2})\_\d.\d/;
	$elem = $1;
	print "Working on $elem...";

	# see if we can make relative abundances...
	$test = $ref_prefix . "abn_" . $reffile_prefix . "_" . $elem . "_" . $vmic_ref;
	if (-e $test) {
	    open REF, "<$test" or die "error open $test";
	    $ref_flag = 1;
	    @all_ref = <REF>;
	    close REF;

	    open STAR, "<$file" or die "cannot open $file";

	    $test = $cmp_prefix . "relabn_" . $reffile_prefix . $file_prefix . "_" . $elem . "_" . $vmic;
	    open RELABN, ">$test" or die "no open $test";

	    # compare line by line
	    LINE: while ( $in = <STAR> ) {

		chomp( $in );
		@star = split /\s+/, $in;
		foreach $line (@all_ref) {

		    @ref = split /\s+/, $line;
		    if ( $star[1] =~ $ref[1] ) {

			# same line in the two stars, now check for ex.pot, wl and EW limits
			if ( $star[2] > $xlow  &&  $star[2] < $xhig  &&  $star[5] > $elow  &&  $star[5] < $ehig && $star[1] > $lamlow && $star[1] < $lamhig ) {
			    if ( $ref[2] > $xlow  &&  $ref[2] < $xhig  &&  $ref[5] > $elow  &&  $ref[5] < $ehig && $ref[1] > $lamlow && $ref[1] < $lamhig ) {
				$relabn = sprintf "%5.2f", $star[6] - $ref[6];
				print RELABN "$in  $ref[5] $ref[6] $relabn\n";
			    }
			}
			next LINE;
		    }


		}
	    }
	    close STAR;
	    close RELABN;
	    print "OK!";
	}
	print "\n";
    }

    # update refencences vmic if it has been changed here
    if ($file_prefix =~ /$reffile_prefix/) {
	$vmic_ref = $vmic;
    }

}


sub merge_abn_files {

    # check the .inp file for the number of v-micro calculations
    $test = $cmp_prefix . $file_prefix . "*.inp";
    @file = `ls -1 $test`;
    @tmp = `tail -2 $file[0]`;
    ($dum1, @vmic) = split /\s+/, $tmp[0];
    foreach $file (@list_of_abn) {
	chomp( $file );
	$file =~ /HD\d+\_(.+)\.abn/;
	$elem = $1;
       
	# if there is a _ in the element, then there are >1 .abn files for this element
	if (  $elem =~ /(.+)\_(\d)/  ) {
	    $elem = $1;
	    $already_open = $2;
	} else {
	    $already_open = 0;
	}
	foreach $loc_vmic (@vmic) {
	    $newfile = $current_prefix . "abn_" . $cur_file_prefix . "_" . $elem . "_" . $loc_vmic;
	    unless ($already_open) {
		# print "$file -> $newfile\n";
		open $loc_vmic, ">$newfile" or die "cannot open $newfile";
	    } else {
		open $loc_vmic, ">>$newfile" or die "cannot re-open $newfile";
	    }
	}

	# open the current file and extract the info
	open IN, "<$file" or die "error opening $file";
	READ: while ($in = <IN>) {
	    next READ if $in !~ /\d/;
	    next READ if $in =~ /CGM/;
	    if ( $in =~ /velocity=\s+(\d+.\d+)/) {   # extract the vmicro
		$loc_vmic = $1;
	    }
	    next READ if $in =~ /abundance/;
	    if ( $in =~ /-/ ) {
		$in =~ s/-/ -/g;
		$in = $elem . $ion . $in;
		print $loc_vmic "$in";
		next READ;
	    }
	    if ( $in =~ /$elem\s+(\d)/ ) {  # get the ionization
		$ion = $1;
		next READ;
	    }
	} #end READ
	close IN;

	# now close the new files properly
	foreach $loc_vmic (@vmic) {
	    $newfile = $current_prefix . "abn_" . $cur_file_prefix . "_" . $elem . "_" . $loc_vmic;
	    close $loc_vmic or die "cannot close $newfile";
	}

    }

}

sub set_prefixes {
    $ref_prefix = $workdir . $reffile_prefix . "/";
    $cmp_prefix = $workdir . $file_prefix . "/";
}

sub set_models {
    &set_prefixes;
    chdir $cmp_prefix;
    chomp( @model = `ls -1 *.*.mod` );
 #   print @model;
    chdir $pwd;
    $model = $model[0];  # default value
    $txt_mod = $model;
    $o_mod -> configure( -options => \@model,
			 -textvariable => \$txt_mod);
    &update_fits_spectra;

}

sub update_text {

    # prints two lines with reference model and current star to perfor calc on.

    # first clear the text area
#    $t_stat -> delete(0, 'end');

    # find the info 
    $test = $ref_prefix . $reffile_prefix . ".mod";
    if (-e $test) {
	open TMP, "<$test" or die "cannot open $test";
	$in = <TMP>;
	close TMP;
	($dum1, $teff, $dum2, $logg, $dum3) = split /\s+/, $in;
	$reftxt = "Reference = $reffile_prefix, Teff = $teff, logg = $logg, vmicro = $vmic_ref\n";
    } else {
	$reftxt = "No reference model!\n";
    }
    $t_stat -> insert('end', $reftxt);
    $test = $cmp_prefix . $file_prefix . ".mod";
    if (-e $test) {
	open TMP, "<$test" or die "cannot open $test";
	$in = <TMP>;
	close TMP;
	($dum1, $teff, $dum2, $logg, $dum3) = split /\s+/, $in;
	$reftxt = "Unknown   = $file_prefix, Teff = $teff, logg = $logg, vmicro = $vmic\n";
    } else {
	$reftxt = "No model!\n";
    }
    $t_stat -> insert('end', $reftxt);
    $t_stat -> see('end')

}


sub copy_models_from_masterdir {

    # select models from a list and copy them to the working directory,
    # corrects the extra-space error.  
    #
    #!!!!!!!!  NOTE  !!!!!!   must be coded ::: requires a new button 'copy models' or something...
    #

	$testname = sprintf "T0%4dG%3d_2%1s%2s*", $newTeff, $newlogg*100, $m_or_p, abs($newmh * 10);
	print "Testing if $testname matches...\n";
	@name = glob( $testname );
	if ( @name ) {
	    print "... it does!  $name[0]\n";
	}
}


sub calculate_new_model {

    # calculates a new model with the given parameters - after some error checking
    # places the model in the master-model-directory and copies it to the local star-dir with name HDxxxxxx.5370g458p20.mod

    # check that all values are sensible and start...
    #
    if ( $newTeff > 2000 && $newTeff < 30000 && $newlogg > 0.2 && $ $newlogg < 8.0 && $newmh > -2.0 && $newmh < 1.0 ) {
	$dum1 = substr $newmh, 0, 1;
	if ($dum1 =~ /-/) {
	    $m_or_p = "m";
	} else {
	    $m_or_p = "p";
	}
	print "Calculating model with Teff = $newTeff, logg = $newlogg, [M/H] = $newmh\n";
	# clean up old files. Then link the required files
	#
	`rm -f for00* fort.?`;
	`rm -f PFIRON.DAT`;

	$test = $new_odf_dir . "PFIRON.DAT";
	`ln -s $test PFIRON.DAT`;         #  not required in the new atlas version

	$test = $new_odf_dir . "molecules.dat";
#     the old version:	`ln -s $test for002.dat`;
	`ln -s $test fort.2`;

	# check if the model from the grid has the extra-space error, and correct if it has
	$test = `grep "DECK6  72" $sel_initmod`;
	if ($test) {
	    # read in the model... correct and output  (in old version of atlas, model file was for003.dat)
	    open IN, "<$sel_initmod" or die "cannot open $sel_initmod";
	    open OUT, ">fort.3" or die "error fort.3";
	    while ($in = <IN>) {
		$in =~ s/DECK6  72/DECK6 72/s;
		print OUT $in;
	    }
	    close OUT;  close IN;
	} else {
	    `ln -s $sel_initmod fort.3`;
	}

#	$dum1 = substr $sel_initmod, -6, 2;
#	$test = $new_odf_dir . "kap" . $m_or_p . $dum1 . ".ros";
#   this is the old version:	`ln -s $odf_ros for001.dat`;
	`ln -s $odf_ros fort.1`;

#	$test = $new_odf_dir . $m_or_p . $dum1 . "big1.bdf";
#     the old version:	`ln -s $odf_big for009.dat`; 
	`ln -s $odf_big fort.9`; 

	# ready to run the ATLAS9 program
	#
	open RUNFILE, ">run_tmp.csh" or die "error opening runfile";
	print RUNFILE "#!/bin/csh -f\n\n";
	$test = $atlas_exe . "atlas9mem_newodf.exe <<EOF > junk.dat";
	print RUNFILE "$test\n";
	print RUNFILE "READ KAPPA\n";
	print RUNFILE "READ PUNCH\n";
	print RUNFILE "MOLECULES ON\n";
	print RUNFILE "READ MOLECULES\n";
	print RUNFILE "FREQUENCIES 337 1 337 BIG\n";
	print RUNFILE "VTURB 2.0E+5\n";
	print RUNFILE "CONVECTION OVER 1.25 0\n";
	print RUNFILE "TITLE abund_gui for $file_prefix\n";
	$scale = 10**$newmh;
	$test = sprintf "ABUNDANCE SCALE   %7.5f ABUNDANCE CHANGE 1 0.92070 2 0.07836", $scale;
	print RUNFILE "$test\n";
#         print RUNFILE "ABUNDANCE SCALE   1.00000 ABUNDANCE CHANGE 1 0.92070 2 0.07836\n";
	print RUNFILE " ABUNDANCE CHANGE  3 -10.88  4 -10.89  5  -9.44  6  -3.48  7  -3.99  8  -3.11\n";
	print RUNFILE " ABUNDANCE CHANGE  9  -7.48 10  -3.95 11  -5.71 12  -4.46 13  -5.57 14  -4.49\n";
	print RUNFILE " ABUNDANCE CHANGE 15  -6.59 16  -4.83 17  -6.54 18  -5.48 19  -6.82 20  -5.68\n";
	print RUNFILE " ABUNDANCE CHANGE 21  -8.94 22  -7.05 23  -8.04 24  -6.37 25  -6.65 26  -4.53\n";
	print RUNFILE " ABUNDANCE CHANGE 27  -7.12 28  -5.79 29  -7.83 30  -7.44 31  -9.16 32  -8.63\n";
	print RUNFILE " ABUNDANCE CHANGE 33  -9.67 34  -8.69 35  -9.41 36  -8.81 37  -9.44 38  -9.14\n";
	print RUNFILE " ABUNDANCE CHANGE 39  -9.80 40  -9.54 41 -10.62 42 -10.12 43 -20.00 44 -10.20\n";
	print RUNFILE " ABUNDANCE CHANGE 45 -10.92 46 -10.35 47 -11.10 48 -10.18 49 -10.58 50 -10.04\n";
	print RUNFILE " ABUNDANCE CHANGE 51 -11.04 52  -9.80 53 -10.53 54  -9.81 55 -10.92 56  -9.91\n";
	print RUNFILE " ABUNDANCE CHANGE 57 -10.82 58 -10.49 59 -11.33 60 -10.54 61 -20.00 62 -11.04\n";
	print RUNFILE " ABUNDANCE CHANGE 63 -11.53 64 -10.92 65 -11.94 66 -10.94 67 -11.78 68 -11.11\n";
	print RUNFILE " ABUNDANCE CHANGE 69 -12.04 70 -10.96 71 -11.28 72 -11.16 73 -11.91 74 -10.93\n";
	print RUNFILE " ABUNDANCE CHANGE 75 -11.77 76 -10.59 77 -10.69 78 -10.24 79 -11.03 80 -10.95\n";
	print RUNFILE " ABUNDANCE CHANGE 81 -11.14 82 -10.19 83 -11.33 84 -20.00 85 -20.00 86 -20.00\n";
	print RUNFILE " ABUNDANCE CHANGE 87 -20.00 88 -20.00 89 -20.00 90 -11.92 91 -20.00 92 -12.51\n";
	print RUNFILE " ABUNDANCE CHANGE 93 -20.00 94 -20.00 95 -20.00 96 -20.00 97 -20.00 98 -20.00\n";
	print RUNFILE " ABUNDANCE CHANGE 99 -20.00\n";
	$test = sprintf "SCALE 72 -6.875 0.125 %4d. %4.2f", $newTeff, $newlogg; 
	print RUNFILE "$test\n";
	print RUNFILE "ITERATIONS 10  PRINT 0 0 0 0 0 0 0 0 0 0\n";
	print RUNFILE "PUNCH 0 0 0 0 0 0 0 0 0 1\n";
	print RUNFILE "BEGIN                    ITERATION  10 COMPLETED\n";
	print RUNFILE "$test\n";
	print RUNFILE "ITERATIONS 10  PRINT 0 0 0 0 0 0 0 0 0 0\n";
	print RUNFILE "PUNCH 0 0 0 0 0 0 0 0 0 1\n";
	print RUNFILE "BEGIN                    ITERATION  10 COMPLETED\n";
	print RUNFILE "$test\n";
	print RUNFILE "ITERATIONS 10  PRINT 0 0 0 0 0 0 0 0 0 1\n";
	print RUNFILE "PUNCH 0 0 0 0 0 0 0 0 0 1\n";
	print RUNFILE "BEGIN                    ITERATION  10 COMPLETED\n";
	print RUNFILE "END\n";
	print RUNFILE "EOF\n";
	close RUNFILE;
	`chmod u+x run_tmp.csh`;
	`./run_tmp.csh`;   #exit;  #### stop inserted

	# rename the new model
	$_ = abs( $newmh * 100 );
	$dum1 = tr/0-9//;    # count the digits
	if ($dum1 == 1) {
	    $dum1 = "00" . $_;
	} elsif ($dum1 == 2) {
	    $dum1 = "0" . $_;
	} else {
	    $dum1 = $_;
#	    $dum1 = "00";
	}
	$test = sprintf "T0%4dG%3d_2%1s%3s.mod", $newTeff, $newlogg*100, $m_or_p, $dum1;
	print "$test\n\n";
	$mod_name = $master_model . $test;
	print "$mod_name\n";
	`cp fort.7 $mod_name`;
	$mod_name = $file_prefix . "." . $newTeff . "g" . $newlogg*100 . $m_or_p . $dum1 . ".mod";
	print "$mod_name\n";
	`mv fort.7 $mod_name`;

	# check the convergence:
	`tail -72 junk.dat > junktmp.1`;
	@err1 = `awk '{print \$12}' junktmp.1`;
	`tail -72 junk.dat > junktmp.1`;
	@err2 = `awk '{print \$13}' junktmp.1`;
	$er1 = sum( @err1 ) / 72.0;  $er2 = sum( @err2 ) / 72.0;
	$sg1 = sigma( $er1, @err1 );  $sg2 = sigma( $er2, @err2 );
	print "\nCONVERGENCE CHECK:  $er1 +/- $sg1    and    $er2 +/- $sg2\n";
	print "Above values should be < 0.1 and < 1.0 respectively.  If not, then consider\n";
	print "running it again, this time with the model itself as reference...\n";

	# clean up after the calculations
	`rm -f fort.*`;
	`rm -f PFIRON.DAT run_tmp.csh`;
	`rm -f junk*`;

	# make the new model visible
	&set_models;

	$top_initmod -> lower();
    }


}


sub show_the_models {
    # brings forth the window where the reference model for ATLAS9 is chosen
    &update_model_selection;
    $top_initmod -> deiconify();
    $top_initmod -> raise();
}

sub update_model_selection {

    # update the array to be displayed in the menu that displays
    # the models to be used as reference for the new model calculation
    @list_models = ();
    $test = substr $newTeff, 0, 1;
    $dum3 = substr $newTeff, 1, 1;
    $dum3++ unless ( $dum3 / 2 == int( $dum3 / 2 ) );
    if ($dum3 > 9) {
	$test++;  $dum3 = 0;
    }
    $dum1 = $newlogg * 100;
    $dum2 = substr $dum1, 0, 1;
    $dum4 = substr $dum1, 1, 1;
    $dum4++ unless ( $dum4 / 2 == int( $dum4 / 2 ) );
    if ($dum4 > 9) {
	$dum2++;  $dum4 = 0;
    }
    $dum1 = "p";
    $dum1 = "m" if $newmh < 0.0;
    $test = $master_model . "T0" . $test . $dum3 . "*G" . $dum2 . $dum4 . "*_2" . $dum1 . "*.mod"; 
    $dum3 = $master_model . "T0" . $newTeff;
    $dum2 = $newlogg * 100;
    $dum2 = $dum3 . "*G" . $dum2 . "*.mod";
    $dum3 = $dum3 . "*" . $dum1 . "???.mod";
    print "$test\n$dum2\n";
    chomp( @list_models = `ls -1 $test $dum2 $dum3` );
#    $txt_initmod = $list_models[0];
    $o_initmod -> configure( -options => \@list_models,
			     );

}



sub copy_model {

    #takes the currently selected model and makes a local copy

    $test = $cmp_prefix . $model;
    $newmodel = $cmp_prefix . $file_prefix . ".mod";
    $error = `cp $test $newmodel`;
    if ($error) {
	print "WARNING: error in copy $test -> $newmodel\n";
    }
    &update_inp_files;
    &set_ps_filename;
#    &update_text;   # included in the call to update_inp_files...

}

sub set_defaults {

    # set the current directory. It does not matter from where th eprogram is called, it's 
    # just to avoid getting lost...
    $pwd = `pwd`;
    print "Running in $pwd\n\n";

    # WIDTH9WORK is the dirctory with the model directories where the calculations are done.
    if ($opt_e) {
	$workdir = $ENV{"WIDTH9WORK"};
    } else {
	chomp( $workdir = `pwd` );
    }
    unless ($workdir) {
	print "ERROR: please set the environment variable WIDTH9WORK\n";
	exit;
    }
    $workdir = add_slash($workdir);
    print "WIDTH9WORK = $workdir\n";

    # NEWODFDIR is the dirctory with the new opacity tables for ATLAS models.
    $new_odf_dir = $ENV{"NEWODFDIR"};
    unless ($new_odf_dir) {
	print "ERROR: please set the environment variable NEWODFDIR\n";
	exit;
    }
    $new_odf_dir = add_slash($new_odf_dir);
    print "NEWODFDIR = $new_odf_dir\n";

    # MASTERMODEL is the dirctory with all available ATLAS models.
    $master_model = $ENV{"MASTERMODEL"};
    unless ($master_model) {
	print "ERROR: please set the environment variable MASTERMODEL\n";
	exit;
    }
    $master_model = add_slash($master_model);
    print "MASTERMODEL = $master_model\n";

    # ATLAS9EXE is the dirctory with all ATLAS executables.
    $atlas_exe = $ENV{"ATLAS9EXE"};
    unless ($atlas_exe) {
	print "ERROR: please set the environment variable ATLAS9EXE\n";
	exit;
    }
    $atlas_exe = add_slash($atlas_exe);
    print "ATLAS9EXE = $atlas_exe\n";

    # LISTDEFAULT is the default linelist (file).
    $list_default = $ENV{"LISTDEFAULT"};
    unless ($list_default) {
	print "ERROR: please set the environment variable LISTDEFAULT\n";
	exit;
    }
    print "LISTDEFAULT = $list_default\n";

    print "\nThe above are your environment variables. Please check that they are OK.\n\n";

    chdir $workdir;
    chomp( @stars = `ls -1d HD*` );
    
    @stars_ref = ("no ref", @stars);
    chdir $pwd;
    $file_prefix = $stars[0] ; # default model
    $txt_cmpmodel = $file_prefix;
    $reffile_prefix = "no ref";  # default ref.model
    $txt_refmodel = "no ref";   # default ref. model

#    $txt_vmic = "1.2";   # for use with the option-menu widget - obsolete
    $vmic = 1.2;
    $vmic_ref = 1.2;

    $ps = "screen";
    $txt_ps = $ps;

    # dummy valus for new model calculations
    $newTeff = 5550;
    $newlogg = 4.42;
    $newmh = -0.10;

    # limits on Fe abundances
    $fe1low = -12;  $fe1hig = 12;
    $fe2low = -12;  $fe2hig = 12;
    # limits on the exit.potential (eV)
    $xlow = 0.0;
    $xhig = 8.0;
    #limits on the EW (mAA)
    $elow = 8.0;
    $ehig = 100.0;
    # limits on the wavelengths
    $lamlow = 5000;
    $lamhig = 6800;
    &set_prefixes;

    # default elements to plot:
    $plot_e1 = "Fe";
    $plot_e2 = "Ti";
    $plot_e3 = "Ni";

    $sig_lim = 0.0;

    # default atlas model selection:
    $dum1 = $master_model . "T056*G44*_2m10*.mod";
    chomp( @list_models = `ls -1 $dum1` );
    $txt_initmod = $list_models[0];
    $sel_initmod = $list_models[0];

    # the opacity (odf) files to select from
    $dum1 = $new_odf_dir . "kap*.ros";
    chomp( @list_odf_ros = `ls -1 $dum1` );
    $txt_odf_ros = $list_odf_ros[0];
    $odf_ros = $txt_odf_ros;
    $dum1 = $new_odf_dir . "*big1.bdf";
    chomp( @list_odf_big = `ls -1 $dum1` );
    $txt_odf_big = $list_odf_big[0];
    $odf_big = $txt_odf_big;

    # default daospec parameters:
    $dao_fw = 10.0;
    $dao_or = 15;
    $dao_sh = 5000;
    $dao_lo = 6800;
    $dao_ba = 0;
    $dao_re = 12;
    $dao_mi = -1.0;
    $dao_ma = 1.0;
    $dao_sm = 10.0;
    $dao_cr = 1;
    $dao_sc = 0;
    $dao_fi = 0;
    # ... and line selection / linelist
    $depth_max = 0.85;
    $depth_min = 0.01;
    $xpot_max = 10;
    $delta_lamb = 0.02;
    $kanon = 0;
    $remake_master = 0;
    $central_lamb = 6160;
    $range_lamb = 10.0;

    # elements array:
    @elements = ('H ', 'Li', 'Be', 'B ', 'C ', 'N ', 'O ', 'F', 'Ne', 'Na', 'Mg', 'Al', 'Si', 'S ', 'K ', 'Ca', 'Sc', 'Ti', 'V ', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn', 'Y ', 'Zr', 'Nb', 'Mo', 'Cs', 'Ba', 'La', 'Ce', 'Nd', 'Eu', 'W ', 'Hg', 'Pr');

}


sub my_exit {
    `rm tmp.tmp`;
    exit;
}


sub help {
    # provides help text and tutorial for the program.
    chomp( $installdir = `which abund_gui.pl` );
    $installdir =~ s/abund_gui.pl//;
    $test = $installdir . "README.abund";
    $ok = `cat $test`;
    unless ($ok) {
	print "Unable to find README file...\n\n";
    }
}


sub set_ps_filename {
    # prepares for a new PS-filename no matter if we make one or not
    $ps_filename = $model;
    $ps_filename =~ /.*\.(.*)\.mod/;
    $ps_filename = $1 . "v$vmic.ps";
}




sub get_radvel_corr {
    chomp( $test = `ls -1 HD*.daospec` );        #   print "$test\n"; exit;
    if (-e $test) {
	$radvel = `head -1 $test | awk '{print \$4}'`;
    } else {
	print "WARNING! Please determine RV first. Will set RV = 0!!!\n";
	$radvel = 0.0;
    }
}

format TABLE =
@<  @<<<<<<<<<<<<  @<<<<<<<<<<<<  @<<<<<<<<<<<<
$elem, $ab1, $ab2, $ab3
.

#
# END OF PROGRAM
#


#
#  abund_gui main documentation
#


=pod

=head1 NAME

abund_gui - Interactive stellar model fitting and abundance analysis

=head1 USAGE

abund_gui.pl

=head1 DESCRIPTION

Given 1D spectra, will calculate EWs of spectral lines, allow interactive or pre-defined selection of lines
for abundance analysis, and perform the analysis interactively, calculating new model atmospheres as required.

=head2 Preparations

In order to work properly, a strict data structure must be created. In the working directory, create
directories F<HDxxxxxx> for each star to be analysed (the x'es are digits, and there must be exactly 6 digits).
In each directory, place the 1D spectrum as a fits file named F<HDxxxxxx.fits>.

=head2 Calculating EWs

Upon start, choose a star in the B<Calculate> menu. Now click the B<Get EWs> button and adjust the DAOSPEC parameters as
required. Please consult the DAOSPEC documentation for details. Pay special attention to the radial velocity limits; you should
have obtained already a good estimate of the RV.  When done filling in, click B<Run DAOSPEC>, and wait for it to finish.
Check the screen output for a reasonable value of the RV.

=head3 Some_hints...

=over

=item RV estimate

The Ca I 6162.17 line is good for a quick estimate of the RV.

=item Linelists

The default linelist (see FILES and ENVIRONMENT sections below) contains a lot of lines, and may slow down
the RV calculation considerably. If you know that you anyway will be using a particular subset of lines to
calculate abundances, you can place a linelist named F<vald.kanonlist> in that star directory, and DAOSPEC will
consider only those lines.

=back

=head2 Selecting lines

If you have a good linelist already, you may want to skip this step completely by simply placing an existing
linelist called F<vald.kanonlist> in the star directory.  This list will then be used in subsequent steps.

If you need to select lines, or to check the lines already selected
in your linelist, click the B<Linelist> button.  This will show a section of the spectrum with lines marked from the master
default list (either F<$LISTDEFAULT> or newest file ending in F<.lst> in the current star directory). 
A green color means the line has been selected (is contained in F<vald.kanonlist> file), while red lines
are not selected.  You can select lines by left clicking, deselect lines by middle-click, and exit the plot with right click.
After exit, a small pop-up window will allow you to enter another central wavelength for the plot, or simply to shift the
spectrum by clicking the B<E<lt>E<lt>> and B<E<gt>E<gt>> buttons.  Once finished selecting lines, click B<Exit> to return to
the main window, and to update F<vald.kanonlist> with the new (de)selections. 

=head2 Determining atmospheric parameters

Select a model from the pull-down menu, or calculate a new model.

=head3 Calculating_new_models

Enter the desired model parameters, and click B<Make new model>.  A window will pop up, where you can select the 
model to iterate from, and the opacity files to use. Please refer to the ATLAS documentation for explanations of the 
naming scheme.  Click B<Go!> and wait for it to complete. Check the screen output for the model convergence check. The new
model will now appear in the model pull-down menu.

=head3 Comparison_with_solar_abundances

In order to compare with solar abundances, the Sun should be the first star to be analysed. Set B<Calculate for:> to HD000000
(which is a good name for the Sun), choose the model, select B<Absolute abundances of:> from the B<What do you want to plot:> field, 
and click B<Get new abund.>  The plot may not seem convincing, but never mind.  Now select another star and you are ready to
calculate relative abundances ([X/H] values).

=head3 Fe_ionisation_equilibrium

Put the B<Set reference:> to the Sun (HD000000 is a good name for the Sun), B<Calculate for:> to the star you want to 
analyse, select a model, and make sure you have selected B<Fe diagnostics> from the B<What do you want to plot> pull-down menu.
Enter a value for microturbulence in the B<and vmicro:> field, and click B<Get new abund.>  After a short while, you will see
a plot with four panels showing in the first three panels the calculated abundances using FeI lines as a function of EW, excitation
potential and wavelength. In the last panel is shown the calculated abundance using FeII lines as a function of EW. When the 
correct model has been used, all the slopes are zero, and the abundance from FeI and FeII lines agree.

Suggestions for iterative matching: TBD.

=head2 Calculating abundances

When the correct model has been found, change B<Fe diagnostics> to B<Relative abundances of:>, and click B<Get new abund.>
You can select three elements to be plotted, but abundances will be calculated for all lines contained in F<vald.kanonlist>, 
and which have also been calculated for the solar spectrum.  The resulting abundances are written to 
F<relabn_HDxxxxxxHDyyyyyytable.asc> (see FILES section below).

=head1 FILES

=over

=item F<vald.kanonlist>

Linelist in native VALD format. If present, will be used instead of the default list (see ENVIRONMENT section below) for the
DAOSPEC calculations.  Will also be used for Fe ion balance diagnostics and abundance calculations.

=item F<$LISTDEFAULT>

Master linelist in native VALD format. Is used in DAOSPEC calculations unless F<vald.kanonlist> is present, and is
used as default in the line selection process.  Typically contains all possible lines for a range of spectral types, but this
is not a requirement.

=item F<relabn_HDxxxxxxHDyyyyyytable.asc>

Resulting abundances file. HDxxxxxx is the name of the comparison star (usually the Sun), and HDyyyyyy is the name of the
'unknown' star. For each element is listed from left to right; element, [X/H] with rms error using neutral lines, number of 
neutral lines used, [X/H] with rms error using singly ionized lines, number of singly ionized lines used, combined [X/H] 
with rms error using all lines of the element, total number of lines.

=back

=head1 REQUIREMENTS

=head2 Environment variables

In order to work, the following environment variables must be defined:

=over

=item WIDTH9WORK

The working directory if launched with -e option. Defaults to the present working directory.

=item NEWODFDIR

The location (directory) of the opacity files used by ATLAS

=item MASTERMODEL

The location (directory) of the Kurucz models. New generated models will be put here as well.

=item ATLAS9EXE

The location (directory) of the ATLAS and DAOSPEC executables

=item LISTDEFAULT

Filename of default linelist for DAOSPEC (in native VALD format)

=back

=head2 Perl modules

The following Perl packages are required:

=over

=item Astro::FITS::CFITSIO

=item PGPLOT

=item Tk

=back

=head2 Other software

DAOSPEC must be installed (see L<http://cadcwww.dao.nrc.ca/stetson/daospec/>), and
you must have the cfitsio libraries installed (comes with scisoft).  Linelists should be in VALD format
(see L<http://ams.astro.univie.ac.at/vald/>).

Currently, the Width_new version from H. Bruntt's VWA software is used instead of the regular WIDTH programs
from the ATLAS distribution.  This will be changed to the ATLAS version in future versions.

=head1 BUGS

None known.

=cut
#
# end of main documentation
#

#=head1 RETURN VALUES

#=head1 SEE ALSO



