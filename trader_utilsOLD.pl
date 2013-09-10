use Carp;
$|=1;

# &parseScanOutput($sysfile, $sysprefix, $date, $tickfile, $portfile, $outfile, $outscan, $outpath, $makeplot);
# GT - not used
sub parseScanOutput {
	# &parseScanOutput($sysfile, $sysprefix, $date, $tickfile, $portfile, $outfile, $outscan, $outpath, $makeplot);
	#
	# Now analyze the scan.pl output and extract (1) entry signals and (2) exit signals for open positions
	# $makeplot = 1 if plots are to be made
	#
	use strict;
	my ($sysfile, $sysprefix, $date, $tickfile, $portfile, $outfile, $outscan, $outpath, $makeplot) = @_;
	my @tick;
	my @port;
	my @tick4action = (); my %exitsignal = (); my %entrysignal = ();
	my ($in, $sign, $sys0, $arrow, $ex0, $stop0, $mm0, $tf0, $graph_std, $whichway, $tick, $port);
	
	open TICK, "<$tickfile" or die "mmzds05345783";
	@tick = <TICK>;
	close TICK;
	
	open PORTF, "<$portfile" or die "4cjwp51";
	@port = <PORTF>;
	close PORTF;
	
	open IN, "<$outfile" or die "38fn4899";
	while ($in = <IN>) {
		if ($in =~ /^Signal/) {
			# check which stocks are on this signal
			$in =~ /NAME (.*)$/;
			$sign = $1;
			while ($in = <IN>) {
				# now we read the lines of stocks that generated signals
				last if $in !~ /\w/;   # empty line between blocks
				$in =~ /^\s+([.\w]*)\s+.*$/; $tick = $1;
				if ($sign =~ /exit/) {
					$exitsignal{$tick} .= $sign . ". ";
				} else {
					$entrysignal{$tick} .= $sign . ". ";
				}
			}
		}
	}
	open OUTSCAN, ">$outscan";
	# check the exit signals - only relevant for stocks we actually own...		
	# generate plots of each of the relevant signals we've found
	if ($makeplot) {
		($sys0, $arrow, $ex0, $stop0, $mm0, $tf0) = getSystemAndArrow($sysfile);
		$graph_std = initMyVar();
	}
	print OUTSCAN "Exit signals detected on $date using $sysprefix:\n";
	foreach $port (@port) {
		chomp($port);
		if ($exitsignal{$port} =~ /\w/) {
			$whichway = "exit";
			&makeGraph($outpath, $port, $sysprefix, $whichway, $date, $arrow, $graph_std) if $makeplot;
			print OUTSCAN "Signals for $port: $exitsignal{$port}\n";
		}
	}
	print OUTSCAN "Entry signals detected:\n";
	foreach $tick (@tick) {
		chomp($tick);
		if ($entrysignal{$tick} =~ /\w/) {
			$whichway = "entry";
			&makeGraph($outpath, $tick, $sysprefix, $whichway, $date, $arrow, $graph_std) if $makeplot;
			print OUTSCAN "Signals for $tick: $entrysignal{$tick}\n";
		}
	}
	close OUTSCAN;
}
# makeGraph($path, $tick, $sysname, $whichway, $date, $arrow, $graph_std)
# GT - not used
sub makeGraph {
		use strict;
	# makeGraph($path, $tick, $sysname, $whichway, $date, $arrow, $graph_std)
		my $outg;
		my $path = shift;
		my $tick = shift;
		my $sysname = shift;
		my $whichway = shift;
		my $date = shift;
		my $arrow = shift;
		my $graph_std = shift;
		my $gfile = "$path" . "${tick}_${sysname}_${whichway}_$date.gconf";
		my $png = "$path" . "${tick}_${sysname}_${whichway}_$date.png";
		my $graph = "graphic.pl --file $gfile --out '$png' $tick";
		open GCONF, ">$gfile";
		print GCONF "# file for graphics.pl made by scan_daily.pl\n#\n";
		print GCONF "# $graph\n";
		print GCONF "--nb-item=100
--end=$date
--timeframe=day
--title=$tick: $sysname $whichway signal
--type=candle
#--logarithmic
--volume
--volume-height=80
--add=BuySellArrows($arrow)
$graph_std";
		close GCONF;
		$outg = system $graph;
}
# &makeScanFile($sysfile, $sysprefix, $scanfile)
# GT - not used
sub makeScanFile {
	# &makeScanFile($sysfile, $sysprefix, $scanfile)
	#
	# makes a .scan file to be used with scan.pl, based on a standard .gtsys file.
	#
	use strict;
	my $sysfile = shift;
	my $sysprefix = shift;
	my $scanfile = shift;
	my $system = "";
	my $exit = "";
	my ($in, $in2, $descrip);
	
	open SYS, "<$sysfile" or die "bb40074";
	while ($in = <SYS>) {
	    last if ($in =~ /^\# END/);
		if ($in =~ /^(entry signal long)/) {
			$descrip = $1;
			$system .= "# $sysprefix $descrip:\n";
			while ($in2 = <SYS>) {
				$in2 = <SYS> if $in2 =~ /^G/;   # don't take the 'Generic' statement at the beginning of the line
				last unless $in2 =~ /\S/;
				next if $in2 =~ /^\#/;
				if ($in2 =~ /Generic:And/ || $in2 =~ /G:And/) {  
					$in2 =~ s/^\s+\{//g;    # only remove the { for the first line
				} else {
					$in2 =~ s/^\s+\{/\t\{/g;    # line it up with a single tab
				}
				if ($in2 =~ /^\s+\}/) {
					$in2 = "\tNAME $sysprefix $descrip\n\n";
				}
				$system .= $in2;
			}
		} elsif ($in =~ /^(entry signal short)/) {
			$descrip = $1;
			$system .= "# $sysprefix $descrip:\n";
			while ($in2 = <SYS>) {
				$in2 = <SYS> if $in2 =~ /^G/;   # don't take the 'Generic' statement at the beginning of the line
				last unless $in2 =~ /\S/;  # blank line is end of the block
				next if $in2 =~ /^\#/;
				if ($in2 =~ /Generic:And/ || $in2 =~ /G:And/) {  
					$in2 =~ s/^\s+\{//g;    # only remove the { for the first line
				} else {
					$in2 =~ s/^\s+\{/\t\{/g;    # line it up with a single tab
				}
				if ($in2 =~ /^\s+\}/) {
					$in2 = "\tNAME $sysprefix $descrip\n\n";
				}
				$system .= $in2;
			}
		} elsif ($in =~ /^(exit signal long)/) {
			$descrip = $1;
			$exit .= "# $sysprefix $descrip:\n";
			while ($in2 = <SYS>) {
				last unless $in2 =~ /\S/;
				next if ($in2 =~ /^\#/ || $in2 =~ /^\w/ || $in2 =~ /:Or/ || $in2 =~ /^\s+\}/);
				$in2 =~ s/^\s+\{//g;    # remove the { and }
				$in2 =~ s/\}\s+\\/ \\/g;
				$exit .= $in2;
				$exit .= "\tNAME $sysprefix $descrip\n\n";
			}
		} elsif ($in =~ /^(exit signal short)/) {
			$descrip = $1;
			$exit .= "# $sysprefix $descrip:\n";
			while ($in2 = <SYS>) {
				last unless $in2 =~ /\S/;
				next if ($in2 =~ /^\#/ || $in2 =~ /^\w/ || $in2 =~ /:Or/ || $in2 =~ /^\s+\}/);
				$in2 =~ s/^\s+\{//g;    # remove the { and }
				$in2 =~ s/\}\s+\\/ \\/g;
				$exit .= $in2;
				$exit .= "\tNAME $sysprefix $descrip\n\n";
			}
		}
	}
	close SYS;
	
	open SCAN, ">$scanfile";
	print SCAN "# scan file (tmp) for system $sysprefix\n#\n";
	print SCAN "$system$exit";
	#print "$system$exit";
	close SCAN;
	
}
sub getSystemAndArrow {
	use strict;
	# ($system, $arrowIn1, $exit, $stop, $mm, $tf) = getSystemAndArrow($file)
	#
	# parses the .gtsys file and returns the values for use by backtesting and graphics.
	# 
	my ($in, $system, $arrowIn1, $in2, $arrowIn2, $exit, $stop, $mm, $tf);
	my $file = shift;
	open SYS, "<$file" or die "bb40074";
	while ($in = <SYS>) {
		if ($in =~ /^entry signal long/) {
			$system = "";
			$arrowIn1 = "Systems::";
			while ($in2 = <SYS>) {
				last unless $in2 =~ /[a-z0-9{}]/;
				next if $in2 =~ /^\#/;
				$system .= $in2;
				$arrowIn1 .= $in2;
			}
		} elsif ($in =~ /^entry signal short/) {
			chomp($system); chomp($arrowIn1);
			$system .= " \\\n";
			$arrowIn1 .= " \\\n";
			while ($in2 = <SYS>) {
				last unless $in2 =~ /[a-z0-9{}]/;
				next if $in2 =~ /^\#/;
				$system .= $in2 unless $in2 =~ /^\w/;  # don't take the Generic statement at the beginning of the line
				$arrowIn1 .= $in2 unless $in2 =~ /^\w/;	 # don't take the Generic statement at the beginning of the line
			}
			chomp($arrowIn1);
		} elsif ($in =~ /^exit signal long/) {
			$exit = "";
			$arrowIn2 = "Systems::";
			while ($in2 = <SYS>) {
				last unless $in2 =~ /[a-z0-9{}]/;
				next if $in2 =~ /^\#/;
				$exit .= $in2;
				$arrowIn2 .= $in2;
			}
		} elsif ($in =~ /^exit signal short/) {
			chomp($exit); chomp($arrowIn2);
			$exit .= " \\\n";
			$arrowIn2 .= " \\\n";
			while ($in2 = <SYS>) {
				last unless $in2 =~ /[a-z0-9{}]/;
				next if $in2 =~ /^\#/;
				$exit .= $in2 unless $in2 =~ /^\w/;	 # don't take the Generic statement at the beginning of the line
				$arrowIn2 .= $in2 unless $in2 =~ /^\w/;	 # don't take the Generic statement at the beginning of the line
			}
		} elsif ($in =~ /^stop loss/) {
			$stop = <SYS>;
		} elsif ($in =~ /^money management/) {
			$mm = <SYS>;
		} elsif ($in =~ /^trade filter/) {
			$tf = <SYS>;
		}
	}
	
	close SYS;
	
	chomp($system); chomp($exit); chomp($stop); chomp($mm);
	
	return ($system, $arrowIn1, $exit, $stop, $mm, $tf);
	
}
sub initMyVar {
	# $graph = initMyVar();
	use strict;
	my $graph_std = "--add=Curve(Indicators::EMA 95, [50,70,90])
--add=Curve(Indicators::SMA 10, [0,255,0])
--add=Curve(Indicators::SMA 26, [128,128,0])
--add=Curve(Indicators::SMA 5, [0,0,255])
# volume chart
--add=Switch-Zone(1)
--add=Curve(Indicators::SMA 20 {Indicators::Prices VOLUME}, dark blue)
--add=Text(\"20day vol sma\", 2, 100, left, center, small, blue, arial)
#
# RSI(9)
#
--add=New-Zone(6)
--add=New-Zone(75)
--add=MountainBand(Indicators::Generic::If \\
	{S:Generic:Above {I:RSI 9} 70} \\
	{I:RSI 9} 70,Indicators::Generic::Eval 70,[0,255,0,90]) 
--add=MountainBand(Indicators::Generic::If \\
	{S:Generic:Below {I:RSI 9} 30} \\
	{I:RSI 9} 30,Indicators::Generic::Eval 30,[255,0,0,90]) 
--add=Curve(Indicators::RSI 9)
--add=Curve(Indicators::Generic::Eval 70)
--add=Curve(Indicators::Generic::Eval 30)
--add=Text(\"RSI(9)\", 50, 50, center, center, giant, [80,160,240,70], times) 
#
# RSI(14)
#
--add=New-Zone(6)
--add=New-Zone(75)
--add=MountainBand(Indicators::Generic::If \\
	{S:Generic:Above {I:RSI} 70} \\
	{I:RSI} 70,Indicators::Generic::Eval 70,[0,255,0,90]) 
--add=MountainBand(Indicators::Generic::If \\
	{S:Generic:Below {I:RSI} 30} \\
	{I:RSI} 30,Indicators::Generic::Eval 30,[255,0,0,90]) 
--add=Curve(Indicators::RSI)
--add=Curve(Indicators::Generic::Eval 60)
--add=Curve(Indicators::Generic::Eval 40)
--add=Text(\"RSI(14)\", 50, 50, center, center, giant, [80,160,240,70], times) 
#
# Stochastic
#
--add=New-Zone(6)
--add=New-Zone(75)
--add=Curve(Indicators::STO/3, [0,0,255])
--add=Curve(Indicators::STO/4, [0,255,0])
--add=Curve(Indicators::Generic::Eval 80)
--add=Curve(Indicators::Generic::Eval 20)
--add=Text(Stochastic, 50, 50, center, center, giant, [80,160,240,70], times)
#
# MACD
#
--add=New-Zone(6)
--add=New-Zone(75)
--add=Histogram(Indicators::MACD/3,lightblue)
--add=Curve(Indicators::MACD,[0,0,255])
--add=Curve(Indicators::MACD/2,[255,0,0])
--add=Text(MACD, 50, 50, center, center, giant, [80,160,240,70], times)
#
# CMO
#
--add=New-Zone(6)
--add=New-Zone(75)
--add=Curve(Indicators::CMO,[0,0,0])
--add=Text(CMO, 50, 50, center, center, giant, [80,160,240,70], times)
--add=Curve(Indicators::Generic::Eval 50)
--add=Curve(Indicators::Generic::Eval -50)
";

return $graph_std;
}
##### above not used, kept just in case #####

sub myInitGraph {    
    $font = 2;
    $linewidth = 2;
    $charheight = 1.2;
    pgbeg(0,$device,1,1) || warn "pgbeg on $device says: $!\n"; # Open plot device 
    pgscf($font); # Set character font 
    pgslw($linewidth); # Set line width 
    pgsch($charheight); # Set character height 
    pgsci(1);  # default colour
}

# ($gain, $price) = exitTrade($tick, $db, $whichway, $cash, $margin, $inprice, $psize, $date, $stop);
sub exitTrade {
	# ($gain, $price) = exitTrade($tick, $db, $whichway, $cash, $margin, $inprice, $psize, $date, $stop);
	# $stop is optional; if given it will be used as exit price
	use strict;
	my ($tick, $db, $whichway, $cash, $margin, $inprice, $psize, $date, $stop) = @_;
	my ($price, $gain);

	if ($stop) {
		$price = $stop;
	} else {
		$price = `sqlite3 "$db" "SELECT day_close \\
										   FROM stockprices \\
										   WHERE symbol = '$tick' \\
										   AND date = '$date' \\
										   ORDER BY date \\
										   DESC"`;
		chomp($price);  #print "-- $tick -- $date -- $db -- ";
	}
	if ($whichway eq "long") {
		$gain = ($price - $inprice) * $psize;
	} elsif ($whichway eq "short") {
		$gain = ($inprice - $price) * $psize;
	} else {	
		print "ERROR: must call with either 'long' or 'short'\n";
		exit();
	}
	#print "\n-- gain = $gain, IN = $inprice, OUT = $price; $psize stk.\n";
	return ($gain, $price);
}

# $finamount = getFinAmount($worn, $finamount, $amount);
sub getFinAmount {
# $finamount = getFinAmount($worn, $finamount, $amount);
	use strict;
	my ($worn, $finamount, $amount) = @_;
	if ($finamount) {
		if ($worn =~ /[Ww]/) {  # we want the widest stop from the methods we gave
			if ($amount > $finamount) {
			    printf "FIN($worn):: changing %.2f -> %.2f ::FIN ", $finamount, $amount;
				$finamount = $amount;
			}
		} elsif ($worn =~ /[Nn]/) {
			if ($amount < $finamount) {
			    printf "FIN($worn):: changing %.2f -> %.2f ::FIN ", $finamount, $amount;
				$finamount = $amount;
			}
		} else {
			die "don't know what to do with $worn... (must match N or W)\n";
		}
	} else {
		$finamount = $amount;
	}
	return $finamount;
}

# $newstop = getStop($sysStop, $dbfile, $today, $stop, $istop, $tick, $whichway, $inprice, $priceNow, $target, $daysInTrade, $WorN)
sub getStop {
	# $newstop = getStop($sysStop, $dbfile, $today, $stop, $istop, $tick, $whichway, $inprice, $priceNow, $target, $daysInTrade, $WorN)
	#
	# arguments:    stop-system name, database file, current date, current stop, initial stop, ...
	#               ticker, long/short, entry price, current price, target price, number of days in trade
	#				wide-or-narrow priority
	#               -- if no target price is defined, just set to 0 and it will not be used
	use strict;
	my ($sysStop, $dbfile, $day, $stop, $istop, $tick, $whichway, $inprice, $priceNow, $target, $daysInTrade, $worn) = @_;
	my ($mystop, $factor, $newstop, $amount, $d, $y,$in, $max, $min, $mean, $narr, $peri, $dum, $dev, $r, $val, $ispercent);
	my ($atr, $finamount, $thisday, $atr0, $exclude);
	my @y; my @atr; my @dum; my @data; my @pdays; my @rval; my @rsi;
    my ($po, $ph, $pl, $pc, $yo, $yh, $yl, $yc, $yyh, $yyl, $yyc, $yyo, $tr); 
	# calc current gains etc.
	my $curR = ($priceNow - $inprice)/($inprice - $istop);
	my $yesterday = `sqlite3 "$dbfile" "SELECT date \\
						   FROM stockprices \\
						   WHERE symbol = '$tick' AND date<'$day'\\
						   ORDER BY date \\
						   DESC LIMIT 1"`; 

	#print "\nSTOP:: stop = $stop (istop = $istop) for $whichway position. \n";
    # Time waiting stop: only evaluate a new stop after a number of days. Use in connection with other stops.
    # If stop is to be kept constant, give a value of 999 or other large number.
    # example: "Wait 3"
    #
    if ($sysStop =~ /Wait\s+(\d+)/) { #print "wait";
        if ($1 >= $daysInTrade) {
            return $stop;  # no change, so exit here already!
        }
    }
    # stop at an SMA plus a certain percentage of that price
    # a trailing 'x' means to exclude the current day, i.e., use the previous day instead.
    # example:  "SMA 10 1", "SMA 5 0.1"
    
	# Percentage of H/L used as stop from close price or from high/low of the day.
	# For setting agressive now-stop, i.e. 'sell-now-orders', use percentage = 0 and append 'c'.
    # a trailing 'x' means to exclude the current day, i.e., use the previous day instead.
	# example: "Percent 15", "Percent 0c" (stop at the close). "Percent 0" (stop at the high/low of the day)
	#
	if ($sysStop =~ /Percent\s+(\d+.?\d*)([xc]*)/) {  #print "perc";
	    $factor = $1 / 100.0;  $d = $2;
        if ($d eq "x") {
        	$thisday = $yesterday
        } else {
        	$thisday = $day;
        }
        if ($d eq "c") {
            $dum = "day_close";
        } elsif ($whichway eq "long") {
            $dum = "day_low";
        } else {
            $dum = "day_high";
        }
        $val = `sqlite3 "$dbfile" "SELECT $dum \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' AND date<='$thisday'\\
									   ORDER BY date \\
									   DESC LIMIT 1"`; #print @data, "\n";
        chomp($val);
	    $amount = $val * $factor; #print "Price = $val, so stop size = $amount\n";
        if ($whichway eq "long") {
            $amount += ($priceNow - $val);
        } else {
            $amount += ($val - $priceNow);
        }
        $finamount = getFinAmount($worn, $finamount, $amount);
    }    
    # VolatilityBreakout stop, based on <fac> % of TR of yesterday from the entry/current price. No close-price dependency.
    # example: "TrueRange 40" -----
    #
    if ($sysStop =~ /TrueRange\s+(\d+)/) {
        $factor = $1/100.0;
        chomp( @data = `sqlite3 "$dbfile" "SELECT day_high, day_low, day_close, day_open \\
								   FROM stockprices \\
								   WHERE symbol = '$tick' \\
								   AND date <= '$day' \\
								   ORDER BY date \\
								   DESC LIMIT 3"` );  
        ($ph, $pl, $pc, $po) = split /\|/, $data[0];  # todays prices
        ($yh, $yl, $yc, $yo) = split /\|/, $data[1];  # yesterdays prices
        ($yyh, $yyl, $yyc, $yyo) = split /\|/, $data[2];  # day before yesterdays prices
        $tr = max( ($yh-$yl, $yh-$yyc, $yyc-$yl) );
        if ($worn =~ /i/) {
            # intraday setting of the stop, i.e. wrt the day before
            $tr = max( ($ph-$pl, $ph-$yc, $yc-$pl) ); print "(iday) ";
        }
        $amount = $factor * $tr;    #printf "$factor x $tr = %.3f -> ", $amount;
        $finamount = getFinAmount($worn, $finamount, $amount);     #printf "%.3f -> ", $finamount;
    }
    # Volatility stop based on ATR(<period>), stop to be placed a <multiple> of the ATR away
    # a trailing 'x' means to exclude the current day, i.e., use the <period> previous days instead.
    # example: "Vola 10 2.8", "Vola 14 3.0x"
    #
    if ($sysStop =~ /Vola\s+(\d+)\s+(\d+.?\d*)(x*)/) { #print "vola";
        $peri = $1;
        $factor = $2;
        if ($3) {
        	$thisday = $yesterday
        } else {
        	$thisday = $day;
        }
        $atr = atr($tick, $dbfile, $peri, $thisday);
        $amount = $atr * $factor;
        $finamount = getFinAmount($worn, $finamount, $amount);
    }
    # Dev stop; ATR plus <factor> times 110% stddev of ATR(<period>) for last 30 days
    # a trailing 'x' means to exclude the current day, i.e., use the <period> previous days instead.
    # example: "Dev 1 10", "Dev 2 12x"
    if ($sysStop =~ /Dev\s+(\d+)\s+(\d+)(x*)/) { #print "dev";
        $factor = $1;
        $peri = $2;
        if ($3) {
        	$thisday = $yesterday
        } else {
        	$thisday = $day;
        }
        $atr0 = atr($tick, $dbfile, $peri, $thisday);
        @atr = ();  #getIndicator($tick, "ATR$peri", 0, $day);
		push @atr, $atr0;
        chomp( @data = `sqlite3 "$dbfile" "SELECT date \\
							   FROM stockprices \\
							   WHERE symbol = '$tick' \\
							   AND date < '$thisday' \\
							   ORDER BY date \\
							   DESC LIMIT 29"` ); 
        foreach $thisday (@data) {
        	$atr = atr($tick, $dbfile, $peri, $thisday);
        	push @atr, $atr;
        }
        $mean = sum(@atr)/30.0;
        $dev = sigma($mean, @atr);
        $amount = $atr0 + $dev * $factor * 1.10;
        $finamount = getFinAmount($worn, $finamount, $amount);
    }
    # Stop at absolute <distance>/percentage from local min/max of last <n> days (including today)
    # a trailing 'x' means to exclude the current day, i.e., use the <n> previous days instead.
    # example: "Local 6 0.2", "Local 5 1p", "Local 4 0.5px"
    if ($sysStop =~ /Local\s+(\d+)\s+(\d+.?\d*)(p*)(x*)/) { #print "local";
        $peri = $1;
        $factor = $2;
        $ispercent = $3;
        $exclude = $4;
        if ($whichway eq "long") {
            $dum = "day_low";
        } else {
            $dum = "day_high";
        }
        if ($exclude) {
			@data = `sqlite3 "$dbfile" "SELECT $dum \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' AND date<'$day'\\
									   ORDER BY date \\
									   DESC LIMIT $peri"`; #print @data, "\n";
        } else {
			@data = `sqlite3 "$dbfile" "SELECT $dum \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' AND date<='$day'\\
									   ORDER BY date \\
									   DESC LIMIT $peri"`; #print @data, "\n";
		}
		#print "$peri days of $dum from $day: ", @data;
        chomp(@data);
		@y = ();
		foreach $y (@data) {
		    push @y, $y; # print "pushed $y\n";
		}
		($min, $max) = low_and_high(@y);  #print "\n$min -- $max, factor = $factor\n";
		if ($ispercent) {
		    $factor = $priceNow*$factor/100.0;
		}
		if ($whichway eq "long") {
		    $amount = $priceNow - ($min - $factor); #print "long, so $amount: ($priceNow - ($min - $factor) ";
		} else {
		    $amount = ($max + $factor) - $priceNow; #print "short, so $amount:  ($max + $factor) - $priceNow "; #exit;
		}
        $finamount = getFinAmount($worn, $finamount, $amount); # print "becoming $finamount\n";
    }
    # Stop at absolute distance/percentage from yd high/low if today made a new low/high
    # a trailing 'x' means to exclude the current day, i.e., use the two previous days instead.
    # example:  'HiLo 0.10', 'HiLo 0.2p', 'HiLo 0.5px'
    if ($sysStop =~ /HiLo\s+(\d+.?\d*)(p*)(x*)/) { #print "hilo";
        if ($daysInTrade == 0) {
            warn "Warning: HiLo will not work with initial stop (for now) - use 'Local' instead\n";
        }
        $factor = $1;
        $ispercent = $2;
        $exclude = $3;
        if ($exclude) {
			chomp (@data = `sqlite3 "$dbfile" "SELECT day_low, day_high \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' AND date<'$day'\\
									   ORDER BY date \\
									   DESC LIMIT 2"`); #print @data, "\n";
        } else {
			chomp (@data = `sqlite3 "$dbfile" "SELECT day_low, day_high \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' AND date<='$day'\\
									   ORDER BY date \\
									   DESC LIMIT 2"`); #print @data, "\n";
		}
        ($pl, $ph) = split /\|/, $data[0];  # todays prices
        ($yl, $yh) = split /\|/, $data[1];  # yesterdays prices
        #printf " td l,h=%.2f,%.2f yd l,h=%.2f,%.2f ", $pl,$ph,$yl,$yh;
        if ($ispercent) {
            $factor = ($factor/100.0) * ($pl + $ph)/2.0;
        }
        if ($whichway eq "long" && $ph > $yh) {
            $amount = $priceNow - ($yl - $factor); #printf "yd low=%.2f, setting stop at %.2f ", $yl,$yl-$factor;
        } elsif ($whichway eq "short" && $pl < $yl) {
            $amount = ($yh + $factor) - $priceNow; #printf "yd hig=%.2f, setting stop at %.2f ", $yh, $yh+$factor;
        } else {
            $amount = abs( $priceNow - $stop );
        }
        $finamount = getFinAmount($worn, $finamount, $amount);
    }    

	# Done with the stops as such. Below follows the modifications to the current stop
	$amount = $finamount;      #printf "%.3f (and p = %.2f)...",$amount,$priceNow;

    # Modify stop: according to the current value of the R-multiple $curR
    # Rmult factor|abs|rstop <r1> <val1> <r2> <val2> ....  Must be at end of string! Must have r1 < r2 < ...
    #   factor: multiply stop by this; abs: subtract value from stop; rstop: stop at price corresponding to this R so securing that much R
    # example: "Rmult factor 1.0 0.8 1.5 0.6", 'Rmult rstop 1.2 1.0 1.5 1.3 2 1.8 3 2.5'
    if ($sysStop =~ /Rmult (\w+)\s+(.*)/) { #print "rmul";
        $factor = $1; $dum = $2; 
        @rval = reverse split /\s+/, $dum;
        while ($val = shift @rval) {
            $r = shift @rval;
            if ($curR > $r) {
                if ($factor =~ /factor/) {
                    $amount *= $val; #print "multiplied stop by $val...\n"; exit;
                } elsif ($factor =~ /abs/) {
                    $amount -= $val;
                } elsif ($factor =~ /rstop/) {
                    # calc stop that corresponds to $curR
                    $y = $inprice + $val*($inprice-$istop);
                    if ($whichway eq "long") {
                        $dum = $priceNow - $y;   
                        printf "...R=%.2f so %.2f -> %.2f (via $val) giving R=%.2f\n", $curR, $amount, $dum, (($priceNow-$dum)-$inprice)/($inprice-$istop);
                    } else {
                        $dum = $y - $priceNow;   
                        printf "...R=%.2f so %.2f -> %.2f (via $val) giving R=%.2f\n", $curR, $amount, $dum, (($priceNow+$dum)-$inprice)/($inprice-$istop);
                    }
                    $amount = $dum if ($dum < $amount); 
                } else {
                    die "must give factor, rstop or abs, not $factor...\n";
                }
                last;
            }
        }
    }
    # Modify stop: RSI overbought/sold levels trigger a tightening by a fraction (multiplies factor)
    #       Must come after a 'normal' stop-setting rule
    # examples: 'RSI9 0.7', 'RSI14 0.85'
    if ($sysStop =~ /RSI(\d+)\s+(\d+.?\d*)/) {  #print "srsw3g";
        $peri = $1;
        $factor = $2;
        @rsi = getIndicator($tick, "RSI$peri", 0, $day);
        if ( ($rsi[0] > 70.0 && $whichway eq "long") || ($rsi[0] < 30.0 && $whichway eq "short") ) {
            $amount *= $factor; print " RSI-adjusting stop ";
        }
    }
    # Modify stop:  Multiply by time based factor. After N days the stop will be at 0, meaning at the close of the day.
    # example: "MultLim 4 0.5"  (days, power-to-the...)
    if ($sysStop =~ /MultLim\s+(\d+)\s+(\d+.?\d*)/) {
        $peri = $1;
        $factor = $2;
        if ($daysInTrade <= $peri) {
            $amount *= ($peri - $daysInTrade)**$factor/$peri**$factor;
        } else {
            $amount = 0.0;
        }
    }
    # Aggressive stop - TimeLim; time limit; if not above <factor> R after <peri> days, then set the stop at the current close
    # example: "TimLim 3 1.5"
    if ($sysStop =~ /TimLim\s+(\d+)\s+(\d+.?\d*)/) { #print "vola";
        $peri = $1;
        $factor = $2;
        if ($peri >= $daysInTrade && $curR < $factor) {
            $amount = 0.0;
        }
    }
    # Modify stop:  If it moves against me, tighten the stop. It it moves to profit, give it room to run
    # (or is this a soiund idea at all... initial stop should be ok, plus some tightening ones once it moves for me...)

    # Calculate and evaluate the stop
    #    
    if ($whichway eq "long") {
        $mystop = $priceNow - $amount;
    } elsif ($whichway eq "short") {
        $mystop = $priceNow + $amount;
    } else {
        die "ERROR; no such thing as $whichway...\n";
    }
    #printf "STOP:: modified stop = %.2f, still not accepted\n", $mystop;
    # Modify stop: If soft target price is defined, modify with a linear/parabolic/cubic trailing stop adjustment, i.e.
    # diminish stop by amount between o/c of the day and the regular stop times a factor between 0 and 1.
    if ($target > 0.0 && $daysInTrade > 0) {
        chomp ($dum = `sqlite3 "$dbfile" "SELECT day_open, day_close \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' AND date='$day'\\
									   ORDER BY date \\
									   DESC LIMIT 1"`); 
        @y = split /\|/, $dum;  # todays prices
        ($min, $max) = low_and_high(@y);
        chomp ($dum = `sqlite3 "$dbfile" "SELECT day_low, day_high \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' AND date='$day'\\
									   ORDER BY date \\
									   DESC LIMIT 1"`); 
        ($pl, $ph) = split /\|/, $dum;  # todays prices
        if ($whichway eq "short") {
            $d = $mystop - $max;  printf "changing stop %.2f -> ", $mystop;
            $factor = ($pl - $inprice)**2/($target - $inprice)**2;  # parabolic
#            $factor = abs($pl - $inprice)**3/abs($target - $inprice)**3;  # cubic
#            $factor = abs($pl - $inprice)/abs($target - $inprice);  # linear
            $factor = 0.999 if ($pl < $target);
            $mystop = $mystop - $d * $factor; printf "%.2f (factor=%.3f) ", $mystop, $factor;
        } elsif ($whichway eq "long") {
            $d = $min - $mystop;  printf "changing stop %.2f -> ", $mystop;
            $factor = ($ph - $inprice)**2/($target - $inprice)**2;  # parabolic
#            $factor = abs($ph - $inprice)**3/abs($target - $inprice)**3;  # cubic
#            $factor = abs($ph - $inprice)/abs($target - $inprice);  # linear
            $factor = 0.999 if ($ph > $target);
            $mystop = $mystop + $d * $factor; printf "%.2f (factor=%.3f) ", $mystop, $factor;
        }
    }
    # Apply the calculated stop
    #
    if ( ($whichway eq "long" && $mystop > $stop) || ($whichway eq "short" && $mystop < $stop) ) {
        $newstop = $mystop;  #print "STOP:: $whichway: long and modstop > stop OR short and modstop < stop\n";
    } else {
        $newstop = $stop;
    }
    $newstop = $mystop if ($daysInTrade == 0  && $stop == 0); # the very first pass through 
    #printf "STOP:: setting new stop = %.2f\n", $newstop;
    return $newstop;
}

# $stop = intradayStop();
sub intradayStop {

}


# ($lentry, $lstop, $sentry, $sstop) = getIntraDayEntry($tick, $dbfile, $system, $sysInitStop, $day)
sub getIntraDayEntry {
    # ($lentry, $lstop, $sentry, $sstop) = getIntraDayEntry($tick, $dbfile, $system, $sysInitStop, $day)
    use strict;
    my ($tick, $dbfile, $system, $sysInitStop, $day) = @_;
    my ($tr, $ok, @my, $peri1, $peri2, $frac, $p, $atr1, $atr2, $ptxt, $a, $siga, $b, $sigb);
    my ($lentry, $lstop, $sentry, $sstop);
    if ($system =~ /^VolB(\w{1})(\d+)/) {
        # calc the TR of current day. If price on next day goes beyond yc|po +/- fac % of TR, then enter at that price.
        # two stop-buy orders are to be entered at the close|open of the day
        my $when = $1;
        my $fac = $2/100.0;
        $tr = atr($tick, $dbfile, 1, $day);
        $ok = 1;
        if ($system =~ /VolB[CO]\d+A(\d+)R(\d+)l(\d+)/) {
            $peri1 = $1; $peri2 = $2; $frac = $3/100.0;
            $ok = 1;
            $atr1 = atr($tick, $dbfile, $peri1, $day);
            $atr2 = atr($tick, $dbfile, $peri2, $day);
            # testing influence of current slope...
            ($a, $siga, $b, $sigb) = getSlope($tick, $dbfile, $peri1, $day);
            if ($atr1/$atr2 < $frac) {
                $ok = 1;
                printf "ATR-ratio = %.2f ... slope = %.3f +/- %.3f ", $atr1/$atr2, $b, $sigb;
            }
        } elsif ($system =~ /VolB[CO]\d+A(\d+)/) {
            $peri1 = $1;
            $tr = atr($tick, $dbfile, $peri1, $day);
            $ok = 1;
        }
        if ($when eq "O") {
            # base on opening tomorrow...just let me know delta
            $lentry = $fac*$tr;
            $sentry = -$fac*$tr;
        } elsif ($when eq "C") {
            chomp( $p = `sqlite3 "$dbfile" "SELECT day_close \\
								   FROM stockprices \\
								   WHERE symbol = '$tick' \\
								   AND date = '$day' \\
								   ORDER BY date \\
								   DESC LIMIT 1"` );
            $lentry = $p + $fac*$tr;
            $sentry = $p - $fac*$tr;
            $lstop = getStop($sysInitStop, $dbfile, $day, 0, 0, $tick, "long", $lentry, $lentry, 0, 0, "ni");
            $sstop = getStop($sysInitStop, $dbfile, $day, 0, 0, $tick, "short", $sentry, $sentry, 0, 0, "ni");
        } else {
            die "Error; must give C or O, not \"$when\"\n";
        }
        
    }
    return ($lentry, $lstop, $sentry, $sstop);
}

# $setupOK = getSetupCondition($tick, $system, $dbfile, $day, $yesterday, $setupOld);
sub getSetupCondition {
    # $setupOK = getSetupCondition($tick, $system, $dbfile, $day, $yesterday, $setupOld);
    #
    # $setupOK is either "long", "short", "longshort", or "".
    use strict;
    my ($tick, $system, $dbfile, $day, $yd, $olds) = @_;
    my ($perFast, $perSlow, $slow1, $slow2, $fast1, $fast2, $cross);
    my $setupOK = "longshort";  # default is that all is well...
    
    # SMA crossover
    # returns +1 if fast cross above slow, -1 if fast cross below slow (== slow "cross above" fast), 0 if no crossing
    if ($system =~ /cross(\d+)x(\d+)/) {
        $perFast = $1; $perSlow = $2;
        $slow1 = sma($tick, $dbfile, $perSlow, $yd);
        $slow2 = sma($tick, $dbfile, $perSlow, $day);
        $fast1 = sma($tick, $dbfile, $perFast, $yd);
        $fast2 = sma($tick, $dbfile, $perFast, $day);
        $cross = crossover($fast1, $fast2, $slow1, $slow2);
        if ($cross == 0) {
            $setupOK = $olds;   # no change...
        } elsif ($cross == 1) {
            $setupOK = "long";
        } else {
            $setupOK = "short";
        }
        if ($setupOK eq "longshort") {
            $setupOK = "";  # cannot have OK for both directions at the same time
        }
	}
    
    return $setupOK;
}

sub crossover {
    #    $cross = crossover($fast1, $fast2, $slow1, $slow2);
    #
    # returns +1 if fast (first entries) cross above slow, -1 if fast cross below slow (== slow "cross above" fast), 0 if no crossing
    use strict;
    my ($fast1, $fast2, $slow1, $slow2) = @_;
    my $cross;
    if ( ($slow1-$fast1)*($slow2-$fast2) >= 0.0) {
        $cross = 0;   
    } elsif ($fast2 > $slow2) {
        $cross = 1;
    } else {
        $cross = -1;
    }
    return $cross;
}


# ($entrySig, $exitSig, $txt, $txt, $exitp) = getSignal($tick, $system, $dbfile, $day, $opentrade, $daysIn, $inprice, $istop, $priceNow, $setupOK);    
sub getSignal {
	# ($entrySig, $exitSig, $txt, $ptxt, $exitp) = getSignal($tick, $system, $dbfile, $day, $opentrade, $daysIn, $inprice, $istop, $priceNow, $setupOK);    
	#
	# $entrySig and $exitSig is either "long", "short", or "". Return value is "none" if strategy is not defined
	# $txt is a string 
	# containing useful output either for plots or for file dumping. $exitp is the exit price unless it's the close in which case it's 0.
	# $opentrade is "long" or "short", corresponding to the current open trade
	#
	# incomplete systems moved to subroutine sysInDev  in order to unclutter this
	# 
    use strict;
    my ($tick, $system, $dbfile, $day, $opentrade, $daysIn, $inprice, $istop, $priceNow, $setupOK) = @_;
    my ($entrySig, $exitSig) = ("", "");
    my ($bpi, $bpisig, $macd) = marketStance($day);
    my ($rsi, $dum, $doji, @atr, @adx, @sto, @rsi9, @stos, $ok, $ud, $in, @in, $candle, $a, $siga, $b, $sigb, $rlim);
    my (@xx, @yy, @my, @mx, @lf, $dir, @p, @py, @pyy, $min, $max, $i, $ok2, $altdir, $p, $tr, $peri1, $peri2, $frac);
    my ($ydate, $atr, $au, $ad);
    my $txt = ""; my $ptxt = ""; my $exitp = 0;
	my $curR;
    srand();

    # "systems" for testing; always long or short
    if ($system eq "long" || $system eq "short") {
        $entrySig = $system;
        $exitSig = "";
    }
    # system = LUXOR SMA crossover with delayed entry
    #
    if ($system =~ /cross(\d+)x(\d+)/) {
        $peri1 = $1; $peri2 = $2;
        $dum = `sqlite3 "$dbfile" "SELECT day_open, day_high, day_low, day_close \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' \\
                           AND date = '$day' \\
                           ORDER BY date \\
                           DESC LIMIT 1"`;
        @p = split /\|/, $dum;
        # entry if close is above (below) the stop-buy and it did not gap away
        # ... condition removed: and if it was a white (black) candle && $p[3]>$p[0] hhv. && $p[3]<$p[0] 
        # ... that was faulty! - but could be considered if taken for the day before.
        if ($priceNow < $p[1] && $priceNow > $p[2]) {
            $entrySig = "long" if $setupOK eq "long";
            $entrySig = "short" if $setupOK eq "short";
        }
        # exit signal on the close (for now) is when the SMA cross in the opposite direction
        $ydate = `sqlite3 "$dbfile" "SELECT date \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' \\
                           AND date < '$day' \\
                           ORDER BY date \\
                           DESC LIMIT 1"`;
        $ok2 = getSetupCondition($tick, $system, $dbfile, $day, $ydate, "");
        if ($ok2 eq "long") {
            $exitSig = "short";
        } elsif ($ok2 eq "short") {
            $exitSig = "long";
        }
    }
    
    # system == Random entry
    #
    if ($system =~ /^Random/) {
        if (rand > 0.8) {
            if (rand >= 0.5 ) {
                $entrySig = "long";
            } else {
                $entrySig = "short";
            }
        } else {
            $entrySig = "";
        }
        $exitSig = "";
    }
    # system == Random entry, once out we enter immediately the opposite trade
    # 
    if ($system =~ /^RandCon/) {
        if ($opentrade eq "long") {
            $entrySig = "short";
        } elsif ($opentrade eq "short") {
            $entrySig = "long";
        } elsif (rand >= 0.5 ) {
            $entrySig = "long";
        } else {
            $entrySig = "short";
        }
        $exitSig = "";
    }
    # system == Random entry, only in MACD direction
    #
    if ($system =~ /^RandMACD/) {
        if (rand > 0.8) {
            if ($macd > 0) {
                $entrySig = "long";
            } elsif ($macd < 0) {
                $entrySig = "short";
            }
        } else {
            $entrySig = "";
        }
        $exitSig = "";
    }
    # system == VolB; volatility breakout
    #   examples: "VolBO60", "VolBC105", "VolBO40A14", "VolBC90A5R50l60"
    #               based on opening price
    #                           based on yesterday close
    #                                       use ATR14 instead of TR
    #                                                   use ATR5, only when <ATR5>/<ATR50> < 0.60
    if ($system =~ /^VolB(\w{1})(\d+)/) {
        # calc the TR of yesterday. If price today goes beyond yc|po +/- fac % of TR, then enter at that price.
        # in real life, two stop-buy orders would be entered at the close|open of the day, each with a stop-loss at the other price
        my $when = $1;
        my $fac = $2/100.0;
        $ok = 1;
        chomp( @my = `sqlite3 "$dbfile" "SELECT day_high, day_low, day_close, day_open \\
								   FROM stockprices \\
								   WHERE symbol = '$tick' \\
								   AND date <= '$day' \\
								   ORDER BY date \\
								   DESC LIMIT 3"` );
        my ($ph, $pl, $pc, $po) = split /\|/, $my[0];  # todays prices
        my ($yh, $yl, $yc, $yo) = split /\|/, $my[1];  # yesterdays prices
        my ($yyh, $yyl, $yyc, $yyo) = split /\|/, $my[2];  # day before yesterdays prices
        chomp( $ydate = `sqlite3 "$dbfile" "SELECT date \\
								   FROM stockprices \\
								   WHERE symbol = '$tick' \\
								   AND date < '$day' \\
								   ORDER BY date \\
								   DESC LIMIT 1"` );  # yesterday, for the ATR calculations
        if ($system =~ /VolB[CO]\d+A(\d+)R(\d+)l(\d+)/) {
            $peri1 = $1; $peri2 = $2; $frac = $3/100.0;
            $ok = 0;
            $tr = atr($tick, $dbfile, $peri1, $ydate);
            $atr = atr($tick, $dbfile, $peri2, $ydate);
            # testing influence of current slope...
            ($a, $siga, $b, $sigb) = getSlope($tick, $dbfile, $peri1, $day);
            if ($tr/$atr < $frac) {
                $ok = 1;
                printf "ATR-ratio = %.2f ... slope = %.3f +/- %.3f ", $tr/$atr, $b, $sigb;
                $ptxt = sprintf "ATR-ratio = %.2f, slope = %.3f +/- %.3f", $tr/$atr, $b, $sigb;
            }
        } elsif ($system =~ /VolB[CO]\d+A(\d+)/) {
            $peri1 = $1;
            $tr = atr($tick, $dbfile, $peri1, $ydate); #print "ATR${peri1} = $tr "; exit;
        } else {
            $tr = max( ($yh-$yl, $yh-$yyc, $yyc-$yl) );
        }
        if ($when eq "O") {
            $p = $po;
        } elsif ($when eq "C") {
            $p = $yc;
        } else {
            die "Error; must give C or O, not \"$when\"\n";
        }
        if ($ok) {
            if ( $ph > $p+$fac*$tr && $pl < $p-$fac*$tr ) { # both limits hit on the same day!
                # assuming one position 'survives'. Conservative could assume both will get stopped out for a net -2R loss.
                if ($pc > $po) {  # upday; assume we entered short early and got stopped out, then entered a long
                    $entrySig = "long";
                    $txt = sprintf "%.4f_%.4f_%.4f_short%.4f", $p+$fac*$tr,$tr,$fac,$p-$fac*$tr;
                } else {
                    $entrySig = "short";
                    $txt = sprintf "%.4f_%.4f_%.4f_long%.4f", $p-$fac*$tr,$tr,$fac,$p+$fac*$tr;
                }
                print " Both limits hit! ";
            } elsif ( $ph > $p+$fac*$tr && $pl < $p+$fac*$tr) { # requires crossing the limit, i.e. not entering if it gaps away
                $entrySig = "long";
                $txt = $p+$fac*$tr . "_" . $tr . "_" . $fac;
            } elsif ( $pl < $p-$fac*$tr && $ph > $p-$fac*$tr) { # requires crossing the limit, i.e. not entering if it gaps away
                $entrySig = "short";
                $txt = $p-$fac*$tr . "_" .$tr . "_" . $fac;
            } else {
                $entrySig = "";
                $txt = "";
            }
        } else {
            $entrySig = "";
            $txt = "";
        }
        # addition: Aroon numbers
        if ($system =~ /Vol.*a/ && $entrySig) {
            $au = aroonUp($tick, $dbfile, 25, $day);
            $ad = aroonDown($tick, $dbfile, 25, $day);
            if (  ($ad > 50 + $au && $entrySig eq "short")  ||  ($ad < -50 + $au && $entrySig eq "long") ) {
                $entrySig = "";
                print "Rejecting trade! ";
            }
        }
        # Exit signals for VolB[CO]: if day ends in dircection opposite the trade, then exit at the close
    }
    # system == Candle; Reversal candles
    #
    # TODO: if yesterday was a star and today is confirming, then entry...
    if ($system =~ /^Candle/) {
        # find the direction of the market over the past 3-4 days, using CLOSE prices
        # TODO: proper time interval. plus... should we rather use high/low?
        my $trendper = 4;  # previous $trendper days used
        ($a, $siga, $b, $sigb) = getSlope($tick, $dbfile, $trendper, $day);
        if ($b != 0.0) {
            $dir = $b/abs($b); 
        } else {
            $dir = 0.0; # no signal, probably something wrong or a very sideways market, in any case no signal!
            carp "returned no direction - slope = $b, first&last value in y = $yy[0],$yy[-1]\n";
        }
        # testing if uncertainty on slope is higher than slope itself, then maybe we should make both signals...
        if ( abs($sigb) > abs($b) ) {
            $altdir = -1*$dir;
        } else {
            $altdir = $dir;
        }
        #printf " slope +/- rms = %.3f +/- %.3f\n", $b, $sigb;
        # identify the candle of today, comparing the daily range with ATR(20), except for the doji's, return range/ATR for monitoring
        # bullish hammer, spikes, stars, doji
        #
        @in = `sqlite3 "$dbfile" "SELECT day_open, day_high, day_low, day_close \\
								   FROM stockprices \\
								   WHERE symbol = '$tick' \\
								   AND date <= '$day' \\
								   ORDER BY date \\
								   DESC LIMIT 3"`;
	    chomp(@in);
	    @p = split /\|/, $in[0];  # close price in p[3]
	    @py = split /\|/, $in[1];  # yesterdays prices
	    @pyy = split /\|/, $in[2];  # day before yesterdays prices
	    @my = (@p, @py, @pyy);
        ($min,$max) = low_and_high(@my);  # local, 3-day, min or max
        ($candle,$txt) = candleType(\@p, \@py, $dir); # @p contains prices in the order OHLC
        unless ($candle || $dir == $altdir) {
            ($candle,$txt) = candleType(\@p, \@py, $altdir); # if direction is uncertain and the first one did not return anything...
            $dir = $altdir;  # no candle for the other direction, but maybe for this...
            $altdir = 0;
        }
#        $atr = atr($tick, $dbfile, 14, $day);
#        @rsi9 = getIndicator($tick, "RSI9", 3, $day);
        my ($adx, $adxs, $tr14, $pdm14, $mdm14) = adx($tick, $dbfile, 14, $day);
        $ok = 1;
        if ($candle =~ /Doji/) {
            $doji = "D-";
            # testing ... letting the doji be a signal in its own right... The else-clause at the end of
            # the next if block will negate it.
            if ($dir > 0) {
                $entrySig = "short";     # must be changed if I include Harami
            } elsif ($dir < 0) {
                $entrySig = "long";     #  - do -
            }
        } else {
        	$doji = "";
        }
        if ($candle =~ /ningStar/) { # Morning and Evening Star
            # must have made a new high or low (last 3 days) ... or better?: three sucessive highs, my1 < my2 < m3 ??
            # should have wrat > 0.3
            $txt = "S:" . $txt; # . sprintf "b=%.2f, atr=%.2f, b/atr=%.2f, oc/hl=%.2f", $b, $atr[0], $b/$atr[0], abs($p[0]-$p[3])/($p[1]-$p[2]);
            $ok2 = 0;
            $ok2 = 1;  ### need more testing ### if ( abs($p[0]-$p[3])/($p[1]-$p[2]) < 0.15 );
            if ($dir > 0) {
                $entrySig = "short" if ($p[1] == $max && $candle eq "EveningStar" && $ok2);
                $txt = "E" . $txt; 
            } elsif ($dir < 0) {
                $entrySig = "long" if ($p[2] == $min && $candle eq "MorningStar" && $ok2); 
                $txt = "M" . $txt;      #printf "p2=%.2f, min=%.2f\n", $p[2], $min; exit;
            }
        } elsif ($candle =~ /BullishEngulfing/) {
            $txt = "BE:" . $txt; # . sprintf " b=%.2f, b/atr=%.2f, r9=%.1f", $b, $b/$atr[0], $rsi9[0];
            $entrySig = "long" if ($dir < 0 && ($p[2] == $min || $py[2] == $min) );
        } elsif ($candle =~ /BearishEngulfing/) {
            $txt = "BE:" . $txt; # . sprintf " b=%.2f, b/atr=%.2f, r9=%.1f", $b, $b/$atr[0], $rsi9[0];
            $entrySig = "short" if ($dir > 0 && ($p[1] == $max || $py[1] == $max) );
        } elsif ($candle =~ /BullishHammer/) {   # should maybe have some limit on range/atr; hammer needs a large range
            $txt = "BH:" . $txt; # . sprintf " atr=%.2f, b=%.2f, b/atr=%.2f, r9=%.1f", $atr[0], $b, $b/$atr[0], $rsi9[0];
            $entrySig = "long" if ($p[2] == $min && $dir < 0);     # hammer must have made lowest low of the last 3 days
        } elsif ($candle =~ /ShootingStar/) {
            $txt = "SS:" . $txt; # . sprintf " b=%.2f, b/atr=%.2f, r9=%.1f", $b, $b/$atr[0], $rsi9[0];
            $entrySig = "short" if ($p[1] == $max && $dir > 0);
        } elsif ($candle =~ /PiercingPattern/) {
            $txt = "PP:" . $txt; # . sprintf " oo/atr=%.2f, b/atr=%.2f, r9=%.1f", ($py[0]-$p[0])/$atr[0], $b/$atr[0], $rsi9[0];
            $entrySig = "long" if ($dir < 0 && ($p[2] == $min || $py[2] == $min)); # && ($py[0]-$p[0]) > 0.5*$atr );
        } elsif ($candle =~ /DarkCloudCover/) {
            $txt = "DCC:" . $txt; # . sprintf " oo/atr=%.2f, b/atr=%.2f, r9=%.1f", ($p[0]-$py[0])/$atr[0], $b/$atr[0], $rsi9[0];
            $entrySig = "short" if ($dir > 0 && ($p[1] == $max || $py[1] == $max)); # && ($p[0]-$py[0]) > 0.5*$atr );
        } else {
            $entrySig = "";
        }
        $txt = $doji . $txt . sprintf "ADX=%.2f, sl=%.2f", $adx, $adxs;
        # now check if ADX is well-behaved according to this signal... FOR NOW: only allow signals in sideways markets
        if ($entrySig) {
            printf "$entrySig signal. ADX = %.2f, slope = %.2f\n", $adx, $adxs;
            #$entrySig = "";
        }
    }
    
    # Hard<R>; hard target - exit at the given <R>
    #
    if ($system =~ /Hard(\d+.?\d*)/ && $opentrade) {
        $rlim = $1;
        $curR = ($priceNow - $inprice)/($inprice - $istop);
        if ($curR > $rlim) {
            $exitSig = $opentrade;
            $exitp = $rlim * ($inprice - $istop) + $inprice;
        }
    }
    
    # Ex<T>If<R>; get out at the close on day N if R < some number
    #
    if ($system =~ /Ex(\d+)If(\d+.?\d*)/ && $opentrade) {
        $peri1 = $1;  $rlim = $2;
        $curR = ($priceNow - $inprice)/($inprice - $istop);
        if ($daysIn >= $peri1 && $curR < $rlim) {
            $exitSig = $opentrade;
        }
    }

    # system =~ ExitN;  to get out N days after. Only meant to test reliability in order 
    #                   to stay in the trade the minimum time and so have max number of trades
    if ($system =~ /Exit(\d+)/) {
        if ($daysIn >= $1 && $opentrade) {
            $exitSig = $opentrade;
        } else {
            $exitSig = ""; # note: will cancel other exit signals!
        }
    }
    
    # Modify: check to see if we're only taking long or short trades
    #
    if ($system =~ /Long/ && $entrySig eq "short") {
        $entrySig = "";
    } elsif ($system =~ /Short/ && $entrySig eq "long") {
        $entrySig = "";
    }
    # we won't be in a long and short trade at the same time, so if we get one signal,
    # then we must exit in the other direction... or simply ignore; stay in until stopped out!
    #
#    if ($entrySig eq "long") {
#        $exitSig = "short";
#    } elsif ($entrySig eq "short") {
#        $exitSig = "long";
#    }
    
    return ($entrySig, $exitSig, $txt, $ptxt, $exitp);
}

# ($a, $siga, $b, $sigb) = getSlope($tick, $dbfile, $period, $today);
sub getSlope {
    use strict;
    my ($tick, $dbfile, $trendper, $day) = @_;
    my $dum = $trendper + 1;
    my (@my, @mx, @p);
    my ($i, $a, $siga, $b, $sigb, @xx, @yy);
    chomp( @my = reverse `sqlite3 "$dbfile" "SELECT day_high, day_low, day_close \\
                               FROM stockprices \\
                               WHERE symbol = '$tick' \\
                               AND date <= '$day' \\
                               ORDER BY date \\
                               DESC LIMIT $dum"` );   # value?? was 5 - is 3 better, i.e. last 2 days before this?
    pop @my; # to remove the current day in determining the direction; eliminates some non-star situations
    @mx = (1 .. $trendper); @xx = (); @yy = (); 
    for ($i=0; $i < $trendper; $i++) {
        @p = split /\|/, $my[$i]; #print "$my[$i]\n";
        push @xx, ($mx[$i]-0.1, $mx[$i]-0.1, $mx[$i]+0.1, $mx[$i]+0.2);
        push @yy, ($p[0], $p[1], $p[2], $p[2]);   # extra weight to the close price - Dow would be glad...
    } 
    #print @xx, "\n", @yy, "\n";
    ($a, $siga, $b, $sigb) = linfit(\@xx, \@yy);  # $b is the slope
    return ($a, $siga, $b, $sigb);
}

sub sysandStopInDev {
    # system == DownN; N down days, then an inside upday
    #           how to define "down"? -- N black candles? N downthrust days? N lower closes?
    #           how to define "inside upday"? -- Harami? also PP and Engulfings?
    #
    
    # system == ADXtrendN; A trend setup, ADX rises > N in 2 days (std. N=4)
    #                       Need a way to decide which way to enter, long/short
    
    # system == MAcrossN;   a trend setup, price crossing a N day MA.
    #                       Use with a trailing stop = another MA
    
    # comments from Candle-system:
        #@atr = getIndicator($tick, "ATR20", 0, $day);
        # @adx = getIndicator($tick, "ADX", 9, $day); 
        # Now check the type of candle and respond accordingly...
        # ---- DEFUNCT for now... need another and better ADX
#         if ( ($adx[0]>40.0 && $adx[2]>1.5) || ($adx[0]<20.0 && $adx[2]<0.0) ) {
#             $ok = 1;
#             #$ok = 0;  # 9-day slope < 0 + ADX < 20   OR   9-day slope > 1.5 + ADX > 40: no-go...
#         } else {
#             $ok = 1;
#         }
        # TODO: check for larger trend as linear fit to larger backlog (usually best in direction of larger trend), or use $macd...
        # TODO: plot, later check for, resistance/support levels
        # TODO: if a proper candle is found, then check the RSI(9); must be individualized per individual pattern
        # TODO: check if volume > some SMA is a good indicator
        # TODO: exit check must look at next days (2-3?); if signal is invalidated/not confirmed, then exit
#        @vol = `sqlite3 "$dbfile" "SELECT volume \\
#								   FROM stockprices \\
#								   WHERE symbol = '$tick' \\
#								   AND date <= '$day' \\
#								   ORDER BY date \\
#								   DESC LIMIT 20"`;
#		$avol = sum(@vol)/20.0; $vol = $vol[0];      
        # exit signals for the candles - for now a simple ob/s signal
        # TODO - needs testing, compare with a no-exit-sig run
#         if ($opentrade eq "long" && $rsi9[0] > 80.0 && $rsi9[1] < 0.0) {
#             #$exitSig = "long";
#             $txt = sprintf "rsi9 = %.2f, slope = %.2f", $rsi9[0], $rsi9[1];
#         } elsif ($opentrade eq "short" && $rsi9[0] < 20.0 && $rsi9[1] > 0.0) {
#             #$exitSig = "short";
#             $txt = sprintf "rsi9 = %.2f, slope = %.2f", $rsi9[0], $rsi9[1];
#         } else {
#             $exitSig = "";
#         }

##### for now we DO NOT test for 2-day performance...
#         if ($daysIn == 2) { # entry day is pyy, current day is p
#             # check if it's behaving as it should; so far optimized only for Star
#             if ($opentrade eq "long") {
#                 # if: last two days made lower lows          OR last two days were down days   OR entry-high is still the highest   OR last 2 close < entry close  
#                 if ( ($p[2] < $pyy[2] && $py[2] < $pyy[2])   || ($p[3]<$p[0] && $py[3]<$py[0]) || ($pyy[1]>$py[1] && $pyy[1]>$p[1]) || ($py[3]<$pyy[3] && $p[3]<$pyy[3]) ) {
#                     print "Warning! - $opentrade position not performing. Abandon? [y/N] ";  $dum = <STDIN>;
#                     if ($dum =~ /[yY]/) {
#                         $exitSig = "long";
#                     }
#                 }
#             } elsif ($opentrade eq "short") {
#                 # if: last two days made higher highs        OR last two days were up days   OR the entry-low is still the lowest   OR last 2 close > entry close
#                 if ( ($p[1] > $pyy[1] && $py[1] > $pyy[1])   || ($p[3]>$p[0] && $py[3]>$py[0]) || ($pyy[2]<$py[2] && $pyy[2]<$p[2]) || ($py[3]>$pyy[3] && $p[3]>$pyy[3]) ) {
#                     print "Warning! - $opentrade position not performing. Abandon? [y/N] ";  $dum = <STDIN>;
#                     if ($dum =~ /[yY]/) {
#                         $exitSig = "short";
#                     }
#                 }
#             }
#         }

# consider using for first run througha new equity. Subsequently, comment it out 
#         if ( ($dir == 0 || $altdir == 0) && $entrySig && ! $opentrade) {
#             print "Warning! - manual check of $candle required. OK to go $entrySig here? [y/N] "; $dum = <STDIN>;
#             unless ($dum =~ /[yY]/) {
#                 $entrySig = "";
#             }
#         } 

    # system == RSI9; RSI(9) reversals from ob/s areas (direction is in $rsi9[1])
    #
    if ($system =~ /^RSI9/) {
        # combine with; general direction over last N days? color of current candle? of previous day?
        #               higher/lower low/high than yesterday?
        #       Test with ADX:
        #               ADX up and > 15 means trend, the steeper the ADX the stronger the trend
        #               ADX up in general: oscillators like RSI does not work
        #               ADX down: weakening trend or no trend, oscillators will work
        #       Test acceleration: rsi1 > rsi2 > 0; meaning a rising RSI and an accelerated rise
        @rsi9 = getIndicator($tick, "RSI9", 3, $day);
        #@adx = getIndicator($tick, "ADX", 3, $day);
        $txt = sprintf "rsi9 = %.2f, slope = %.2f, r9-1 = %.2f", $rsi9[0], $rsi9[1], $rsi9[0]-$rsi9[1];   # printf "rsi9 = %.2f, slope = %.2f\n", $rsi9[0], $rsi9[1];
        if ($rsi9[0]-$rsi9[1] > 70.0 && $rsi9[1] < 0.0) {    #### for testing! we take all for 60/40 levels and add Exit0
            $entrySig = "short";
        } elsif ($rsi9[0]-$rsi9[1] < 30.0 && $rsi9[1] > 0.0) {
            $entrySig = "long";
        } else {
            $entrySig = "";
        }
    }
    # system == SlowSTO; Slow stochastic(14,3,3) and RSI(9)
    #
    if ($system =~ /^SlowSTO/) {
        @rsi9 = getIndicator($tick, "RSI9", 3, $day); #print @rsi9, "\n"; exit;
        @sto = getIndicator($tick, "STO", 3, $day);
        @stos = getIndicator($tick, "STOs", 3, $day);
        #  if   STO is above signal ... was below yesterday                ... is rising  ... signal line rising too ... was oversold yesterday
#        if ( ($sto[0] > $stos[0]) && ($sto[0]-$sto[1] < $stos[0]-$stos[1]) && $sto[1] > 0.0 && $stos[1] > 0.0 && ($sto[0]-$sto[1]) < 20.0 ) {
        if ( ($sto[0] > $stos[0]) && ($sto[0]-$sto[1] < $stos[0]-$stos[1]) && $sto[1] > 0.0 && $sto[0] > 20.0 && ($sto[0]-$sto[1]) < 20.0 ) {
            $entrySig = "long";
            $txt = sprintf "L: sto = %.2f -> %.2f, signal = %.2f -> %.2f. rsi9 = %.2f. MACD:$macd", $sto[0]-$sto[1], $sto[0], $stos[0]-$stos[1], $stos[0], $rsi9[0];
        } elsif ( ($sto[0] < $stos[0]) && ($sto[0]-$sto[1] > $stos[0]-$stos[1]) && $sto[1] < 0.0 && $stos[1] < 0.0 && ($sto[0] - $sto[1]) > 80.0 ) {
            $entrySig = "short";
            $txt = sprintf "S: sto = %.2f -> %.2f, signal = %.2f -> %.2f. rsi9 = %.2f. MACD:$macd", $sto[0]-$sto[1], $sto[0], $stos[0]-$stos[1], $stos[0], $rsi9[0];
        } else {
            $entrySig = "";
        }
        $exitSig = "";
    }


	# stops in development...
	#

    # Time-narrowing stop: decrease the stop span with a fraction determined by the number of days in the trade,
    # with 
    
    # Moving Average trailing stop
    # example:  "SMA 20"
    #
    if ($sysStop =~ /SMA\s+(\d+)/) { #print "sma";
        $peri = $1;
        @atr = getIndicator($tick, "SMA$peri", 0, $day);
        $amount = abs ($atr[0] - $priceNow);
        $finamount = getFinAmount($worn, $finamount, $amount);
    }
	
}

# ($posSize, $posPrice) = enterTrade($whichway, $price, $stop, $risk)
sub enterTrade {
	# ($posSize, $posPrice) = enterTrade($whichway, $price, $stop, $risk)
	#
	use strict;
	my ($whichway, $price, $stop, $risk) = @_;
	my ($psize, $pprice);  print "price = $price, stop = $stop\n";
	
	if ($whichway eq "long") {
		$psize = int ($risk / ($price - $stop));
	} elsif ($whichway eq "short") {
		$psize = int ($risk / ($stop - $price));
	} else {
		print "ERROR: must call with either 'long' or 'short'\n";
		exit();
	}
	$pprice = $psize * $price;
	
	return ($psize, $pprice);

}

# ($d, $y) = extractIndicatorValues(@dum)
sub extractIndicatorValues {
    # ($d, $y) = extractIndicatorValues(@dum)
    #   @dum contains output from display_indicator.pl
    #   arr-refs $d = day, $y = indicator value
    use strict;
    my @dum = @_;
    my $in;
    my @y = (); my @d = ();
    chomp(@dum);
    shift @dum;
    foreach $in (@dum) {
        $in =~ /.* \[(\d{4}-\d{2}-\d{2})\] = (-*\d+.\d+)/;
        push @d, $1;
        push @y, $2;
    }
    #print @d,"\n"; print @y,"\n";
    return (\@d, \@y);
}

# @price = getPriceAfterDays($tick, $dbfile, $day, \@days)
sub getPriceAfterDays {
	# @price = getPriceAfterDays($tick, $dbfile, $day, \@days)
	# returns an array with the close price for @days after $day.
	use strict;
	my ($tick, $dbfile, $day, $arr) = @_;
	my @days = @$arr; 
	my @rangePrice = ();  my @price = ();  my @p = ();
	my ($i, $in, $count, $num);
	my @all = `sqlite3 "$dbfile" "SELECT date, day_close \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' \\
									   ORDER BY date \\
									   DESC"`;
	chomp(@all); 
	$count = 0;
	foreach $in (reverse @all) {
		@p = split /\|/, $in;
		next if ($p[0] lt $day);
		$count++; 
		push @rangePrice, $p[1];
		last if ($count > $days[-1]);
	}
	$num = @days; 
	for ($i = 0; $i < $num; $i++) {
		$price[$i] = $rangePrice[$days[$i]];
	}
	
	return @price;
}

# @price = getOHLCAfterDays($ohlc, $tick, $dbfile, $day, \@days)
sub getOHLCAfterDays {
	# @price = getOHLCAfterDays($ohlc, $tick, $dbfile, $day, \@days)
	# returns an array with the close price for @days after $day.
	use strict;
	my ($ohlc, $tick, $dbfile, $day, $arr) = @_;
	my @days = @$arr; 
	my @rangePrice = ();  my @price = ();  my @p = ();
	my ($i, $in, $count, $num);
	my $whatp = "day_$ohlc";
	my @all = `sqlite3 "$dbfile" "SELECT date, $whatp \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' \\
									   ORDER BY date \\
									   DESC"`;
	chomp(@all); 
	$count = 0;
	foreach $in (reverse @all) {
		@p = split /\|/, $in;
		next if ($p[0] lt $day);
		$count++; 
		push @rangePrice, $p[1];
		last if ($count > $days[-1]);
	}
	$num = @days; 
	for ($i = 0; $i < $num; $i++) {
		$price[$i] = $rangePrice[$days[$i]];
	}
	
	return @price;
}

#	($mae, $mpe) = getMAE($tick, $dbfile, $inprice, $istop, $daysintrade, $day);
sub getMAE {
    my ($tick, $dbfile, $inprice, $istop, $daysintrade, $day) = @_;
    my ($d1, $rmax, $rmin, $mae, $mpe);
    my @tdays = (0 .. $daysintrade);  print "Trade on $day, from day 0 to $daysintrade .::. ";
	my @prH = getOHLCAfterDays("high", $tick, $dbfile, $day, \@tdays);
	my @prL = getOHLCAfterDays("low", $tick, $dbfile, $day, \@tdays);
	($d1,$rmax) = low_and_high(@prH);
	($rmin,$d1) = low_and_high(@prL);
	if ($inprice > $istop) {  # long
        $mpe = ($rmax - $inprice)/($inprice - $istop);
        $mae = ($rmin - $inprice)/($inprice - $istop);
    } elsif ($inprice < $istop) { # short
        $mpe = ($rmin - $inprice)/($inprice - $istop);
        $mae = ($rmax - $inprice)/($inprice - $istop);
    } else {
        die "error in direction: inprice = $inprice, stop = $istop\n";
    }
    return ($mae, $mpe);
}

# ($bpi, $bpisig, $macdH) = marketStance($day);
sub marketStance {
    use strict;
    my $day = shift; 
    my ($bpi, $bpisig, $macdH);
    
    #chomp(@day = `sqlite3 "$dbfile" "SELECT date FROM stockprices WHERE symbol = 'BMW.DE' ORDER BY date DESC"`);
    #foreach $day (reverse @day) {

    # S&P500 MACD weekly - Histogram (signal line crossing)
    #
    if ($day gt "2012-08-03") {
        $macdH = 1;
    } elsif ($day gt "2012-05-06") {
        $macdH = -1;
    } elsif ($day gt "2011-10-14") {
        $macdH = 1;
    } elsif ($day gt "2011-03-09") {
        $macdH = -1;
    } elsif ($day gt "2010-08-30") {
        $macdH = 1;
    } elsif ($day gt "2010-05-05") {
        $macdH = -1;
    } elsif ($day gt "2010-03-15") {
        $macdH = 1;
    } elsif ($day gt "2010-01-15") {
        $macdH = -1;
    } elsif ($day gt "2009-03-08") {
        $macdH = 1;
    } elsif ($day gt "2009-03-01") {
        $macdH = -1;
    } elsif ($day gt "2008-12-28") {
        $macdH = 1;
    } elsif ($day gt "2008-06-08") {
        $macdH = -1;
    } else {
        $macdH = 0;
    }

    # NYSE BPI - P&F column
    #
    if ($day gt "2012-07-03") {
        $bpi = "X";
    } elsif ($day gt "2012-04-10") {
        $bpi = "O";
    } elsif ($day gt "2011-12-06") {
        $bpi = "X";
    } elsif ($day gt "2011-11-18") {
        $bpi = "O";
    } elsif ($day gt "2011-10-08") {
        $bpi = "X";
    } elsif ($day gt "2011-09-10") {
        $bpi = "O";
    } elsif ($day gt "2011-08-27") {
        $bpi = "X";
    } elsif ($day gt "2011-07-30") {
        $bpi = "O";
    } elsif ($day gt "2011-07-02") {
        $bpi = "X";
    } elsif ($day gt "2011-05-12") {
        $bpi = "O";
    } elsif ($day gt "2011-04-01") {
        $bpi = "X";
    } elsif ($day gt "2011-03-10") {
        $bpi = "O";
    } elsif ($day gt "2010-09-14") {
        $bpi = "X";
    } elsif ($day gt "2010-08-28") {
        $bpi = "O";
    } elsif ($day gt "2010-07-23") {
        $bpi = "X";
    } elsif ($day gt "2010-06-30") {
        $bpi = "O";
    } elsif ($day gt "2010-06-15") {
        $bpi = "X";
    } elsif ($day gt "2010-05-05") {
        $bpi = "O";
    } elsif ($day gt "2010-03-02") {
        $bpi = "X";
    } elsif ($day gt "2010-01-27") {
        $bpi = "O";
    } elsif ($day gt "2010-01-05") {
        $bpi = "X";
    } elsif ($day gt "2009-10-02") {
        $bpi = "O";
    } elsif ($day gt "2009-07-17") {
        $bpi = "X";
    } elsif ($day gt "2009-06-17") {
        $bpi = "O";
    } elsif ($day gt "2009-03-12") {
        $bpi = "X";
    } elsif ($day gt "2009-02-14") {
        $bpi = "O";
    } elsif ($day gt "2009-01-28") {
        $bpi = "X";
    } elsif ($day gt "2009-01-13") {
        $bpi = "O";
    } elsif ($day gt "2008-11-25") {
        $bpi = "X";
    } elsif ($day gt "2008-11-11") {
        $bpi = "O";
    } elsif ($day gt "2008-10-29") {
        $bpi = "X";
    } elsif ($day gt "2008-10-23") {
        $bpi = "O";
    } elsif ($day gt "2008-10-11") {
        $bpi = "X";
    } elsif ($day gt "2008-09-26") {
        $bpi = "O";
    } elsif ($day gt "2008-09-19") {
        $bpi = "X";
    } elsif ($day gt "2008-09-05") {
        $bpi = "O";
    } elsif ($day gt "2008-07-22") {
        $bpi = "X";
    } elsif ($day gt "2008-06-10") {
        $bpi = "O";
    } elsif ($day gt "2008-03-21") {
        $bpi = "X";
    } elsif ($day gt "2008-03-06") {
        $bpi = "O";
    } elsif ($day gt "2008-01-24") {
        $bpi = "X";
    } elsif ($day gt "2007-12-18") {
        $bpi = "O";
    } elsif ($day gt "2007-11-30") {
        $bpi = "X";
    } else {
        $bpi = "-";
    } 

    # NYSE BPI - P&F signal
    #
    if ($day gt "2011-10-19") {
        $bpisig = "B";
    } elsif ($day gt "2011-05-19") {
        $bpisig = "S";
    } elsif ($day gt "2010-07-27") {
        $bpisig = "b";
    } elsif ($day gt "2010-05-20") {
        $bpisig = "S";
    } elsif ($day gt "2010-04-08") {
        $bpisig = "b";
    } elsif ($day gt "2010-02-04") {
        $bpisig = "S";
    } elsif ($day gt "2009-04-03") {
        $bpisig = "B";
    } elsif ($day gt "2009-02-14") {
        $bpisig = "s";
    } elsif ($day gt "2008-12-06") {
        $bpisig = "B";
    } elsif ($day gt "2008-11-21") {
        $bpisig = "s";
    } elsif ($day gt "2008-10-30") {
        $bpisig = "B";
    } elsif ($day gt "2008-09-27") {
        $bpisig = "s";
    } elsif ($day gt "2008-04-02") {
        $bpisig = "B";
    } else {
        $bpisig = "-";
    }

    #print "$day  $bpi  $bpisig  $macdH\n";
    return ($bpi, $bpisig, $macdH);

}


# ($column, $p10val, $p10slope) = p10week($day);
sub p10week {
    use strict;
    my ($day) = @_;
    my ($in, @tmp, $col, $val, $slope); #print "looking for $day: ";
    if (-e "/Users/tdall/geniustrader/all4percentWk.p10wk") {
        open WK, "/Users/tdall/geniustrader/all4percentWk.p10wk" || die "n3483zxxxo003m";
        while ($in = <WK>) {
            chomp($in);
            @tmp = split /\s+/, $in; #print ".. $tmp[0] ..";
            next unless $tmp[0] eq $day;
            $col = $tmp[3];
            $slope = $tmp[2];
            $val = $tmp[1];
            last;
        }
        close WK;
    }
    return ($col, $val, $slope);
}


# ($candle, $text) = candleType($pd, $py, $dir); # @pd/y contains prices in the order OHLC
sub candleType {
    #         ($candle, $text) = candleType($pd, $py, $dir); # @$pd and @$py contains prices in the order OHLC
    #                                               # for today and yesterday respectively
    # $dir defines trend direction; > 0 uptrend, < 0 downtrend.
    # defines and returns the type of candle pattern among the following:
    # BullishHammer; Star; Doji; DojiStar; GravestoneDoji; BullishEngulfing; BearishEngulfing
    use strict;
    my ($pd, $py, $dir) = @_;
    my ($uw, $lw, $cdir, $body, $maxb, $minb, $maxby, $minby, $wrat);
    my $txt = "";
    my ($po, $ph, $pl, $pc) = @$pd;  my ($yo, $yh, $yl, $yc) = @$py;
    my $candle = "";
    # define body, direction, upper and lower wicks
    if ($po < $pc) {    # white candle today
        $uw = $ph - $pc;
        $lw = $po - $pl;
        $cdir = 1;  # candle direction
        $body = $pc - $po;
        $maxb = $pc; $minb = $po; 
    } else {   # black candle today
        $uw = $ph - $po;
        $lw = $pc - $pl;
        $cdir = -1;
        $body = $po - $pc;
        $maxb = $po; $minb = $pc; 
    }
    if ($yc > $yo) {
        $maxby = $yc; $minby = $yo;  # white candle yesterday
    } else {
        $maxby = $yo; $minby = $yc;  # black candle yesterday
    }
    # wick ratio, 0 < wrat < 1, is smaller divided by larger
    if ($uw == 0 || $lw == 0) {
        $wrat = 0;
    } elsif ($uw > $lw) {
        $wrat = $lw/$uw;
    } else {
        $wrat = $uw/$lw;
    }
    #printf "wrat = %.2f, dir=$dir, body;lw;uw = %.2f, %.2f, %.2f, ybody=%.2f, minby=%.2f, maxb=%.2f \n", $wrat, $body, $lw, $uw, $yo-$yc, $minby, $maxb;
    # star:
    if ( $body < $uw && $body < $lw && 2 * $body < abs($yo-$yc) && ($wrat > 0.30) ) {  #  
        $txt .= sprintf "r0=%.2f, wick=%.2f,%.2f, wrat=%.2f, r1=%.2f ",$body, $uw, $lw, $wrat, abs($yo-$yc);
        if ( $dir < 0 && $minby > $maxb && $yc < $yo) {
#        if ( $minby > $maxb && $yc < $yo) {
            $candle = "MorningStar";
        } elsif ( $dir > 0 && $minb > $maxby && $yc > $yo) {  # could enter wick-to-body size for yesterday
#        } elsif ( $minb > $maxby && $yc > $yo) {  # could enter wick-to-body size for yesterday
            $candle = "EveningStar";
        }
    }
    # bullish engulfing:
    if ( $cdir > 0 && ($yo - $yc > 0) && $pc > $yo && $po < $yc && $dir < 0) {
#    if ( $cdir > 0 && ($yo - $yc > 0) && $pc > $yo && $po < $yc ) {
        $txt .= sprintf "r0/r1=%.2f",($pc-$po)/($yo-$yc);
        $candle = "BullishEngulfing";
    }
    # bearish engulfing:
    elsif ( $cdir < 0 && ($yo - $yc < 0) && $pc < $yo && $po > $yc && $dir > 0) {
#    elsif ( $cdir < 0 && ($yo - $yc < 0) && $pc < $yo && $po > $yc ) {
        $txt .= sprintf "r0/r1=%.2f",($pc-$po)/($yc-$yo);  # negative by def.
        $candle = "BearishEngulfing";
    }
    # dark cloud cover
    elsif ( $cdir < 0 && ($yo - $yc < 0) && ($yc-$pc)*100.0/($yc-$yo) > 50.0 && $po > $yc && $dir > 0) {
#    elsif ( $cdir < 0 && ($yo - $yc < 0) && ($yc-$pc)*100.0/($yc-$yo) > 50.0 && $po > $yc ) {
        $txt .= sprintf "overlap=%.1f",($yc-$pc)*100.0/($yc-$yo); # must be > 50%
        $candle = "DarkCloudCover";
    }
    # piercing pattern
    elsif ( $cdir > 0 && ($yo - $yc > 0) && ($pc-$yc)*100.0/($yo-$yc) > 70.0 && $po < $yc && $dir < 0) {
#    elsif ( $cdir > 0 && ($yo - $yc > 0) && ($pc-$yc)*100.0/($yo-$yc) > 70.0 && $po < $yc ) {
        $txt .= sprintf "overlap=%.1f",($pc-$yc)*100.0/($yo-$yc); # must be > 70%
        $candle = "PiercingPattern";
    }
    # bullish hammer
    elsif ( $dir < 0 && $lw > 2.0*$body && $uw < $body ) {
#    elsif ( $lw > 2.0*$body && $uw < $body ) {
        $txt .= sprintf "r=%.2f", $ph-$pl;
        $candle = "BullishHammer";
    }
    # bearish shooting star
    elsif ( $dir > 0 && $uw > 2.0*$body && $lw < 0.3*$body && ($yo - $yc < 0) && $minb > $maxby && 2 * $body < abs($yo-$yc) ) {
#    elsif ( $uw > 2.0*$body && $lw < 0.3*$body && ($yo - $yc < 0) && $minb > $maxby && 2 * $body < abs($yo-$yc) ) {
        $txt .= sprintf "w/b=%.2f", $uw/$body;
        $candle = "ShootingStar";
    }
    
    # and last: doji -- adding on the candle name
    if ( $body/$po < 0.001 ) {
        $txt .= sprintf "o-c/o=%.2f", $body*100.0/$po;    
        $candle .= "Doji";
    }
    #print "$candle\n"; exit;
    return ($candle, $txt);
    
}

# $atr = atr($tick, $dbfile, $peri, $date)
# Wilder ATR smoothed - not working properly, do not use
sub atrW {
    # Wilders averaged ATR
    # $atr = atr($tick, $dbfile, $peri, $date)
    use strict;
    my ($tick, $dbfile, $peri, $date) = @_;    
    my ($i, $dip, $atr1, $atr);
    my $qperi = $peri + 1;
    
    my @datel = reverse `sqlite3 "$dbfile" "SELECT date \\
                       FROM stockprices \\
                       WHERE symbol = '$tick' AND date<='$date'\\
                       ORDER BY date \\
                       DESC LIMIT 150"`; 
    chomp @datel;
    my $day = shift @datel;  # take the seed value
    my $atr0 = atr($tick, $dbfile, $peri, $day);
    my $numd = @datel;
    for ($i=0; $i < $numd; $i++) {
        #print "$datel[$i] .. ";
        $atr1 = atr($tick, $dbfile, 1, $datel[$i]);  # values for today only 
        $atr = $atr0 - $atr0/$peri + $atr1/$peri;
        $atr0 = $atr;  
    }
    return $atr;
}

# $obvs = OBVs($tick, $dbfile, $peri, $date)
# OBV linear slope over the given period
sub OBVs {
    use strict;
    my ($tick, $dbfile, $peri, $day) = @_;    
    my @x = (1 .. $peri);
    my @obv = doOBV($tick, $dbfile, $peri, $day);
    my ($a, $siga, $b, $sigb) = linfit( \@x, \@obv );
    return $b;
}

# returns an array with the OBV during the period
sub doOBV {
    use strict;
    my ($tick, $dbfile, $peri, $day) = @_;    
    my $qperi = $peri + 1;  
    my ($i, $obv, $a, $siga, $b, $sigb);
    my @pc = reverse `sqlite3 "$dbfile" "SELECT day_close \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$day'\\
                           ORDER BY date \\
                           DESC LIMIT $qperi"`;  
                           # most recent price is at the beginning, index 0, hence we reverse to get it oldest-first
    my @vol = reverse `sqlite3 "$dbfile" "SELECT volume \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$day'\\
                           ORDER BY date \\
                           DESC LIMIT $peri"`; 
    chomp @pc; chomp @vol;
    unshift @vol, 0;
    my @obv = (); $obv = 0;
    for ($i=1; $i<=$peri; $i++) {
        if ($pc[$i] - $pc[$i-1] > 0.0) {
            $obv += $vol[$i]/1000000;
        } elsif ( $pc[$i] - $pc[$i-1] < 0.0) {
            $obv -= $vol[$i]/1000000;
        } # else no change to $obv
        push @obv, $obv;
    }
    return @obv;
}

# $rawatr = atrRaw($tick, $dbfile, $peri, $date)
#sub atrRaw {
sub atr {
    # $atr = atrRaw($tick, $dbfile, $peri, $date)
    use strict;
    my ($tick, $dbfile, $peri, $end) = @_;    
    my ($m, $i);
    my $qperi = $peri + 1;
    my @ph = `sqlite3 "$dbfile" "SELECT day_high \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $qperi"`; #print @data, "\n";
    my @pl = `sqlite3 "$dbfile" "SELECT day_low \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $qperi"`; #print @data, "\n";
    my @pc = `sqlite3 "$dbfile" "SELECT day_close \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $qperi"`; #print @data, "\n";
    chomp @ph; chomp @pl; chomp @pc;
    my $atr = 0.0;
    for ($i = 0; $i < $peri; $i++) {   # $peri  or $peri-1 ????
        $m = max( ($ph[$i]-$pl[$i], $ph[$i]-$pc[$i+1], $pc[$i+1]-$pl[$i]) );
        $atr += $m;
    }
    $atr /= $peri;
    return $atr;
}

sub atrp {
    # $atrp = atrRaw($tick, $dbfile, $peri, $date)
    #   ATR% as defined by Tharp
    use strict;
    my ($tick, $dbfile, $peri, $day) = @_;    
    my ($a, $p, $atrp);
    $a = atr($tick, $dbfile, $peri, $day);
    $p = `sqlite3 "$dbfile" "SELECT day_close \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$day'\\
                           ORDER BY date \\
                           DESC LIMIT 1"`;
    $atrp = $a/$p;
    return $atrp;
}

sub atrpn {
    # normalized ATR% (mean = 0, in units of 1-sigma)
    # very inefficient, calling the big calc every time...
    # TODO: get this out into a database...
    use strict;
    my ($tick, $dbfile, $peri, $day) = @_;    
    my ($a, @a, @days, $d, $mean, $sig, $na);
    
    my @days = `sqlite3 "$dbfile" "SELECT date \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$day'\\
                           ORDER BY date \\
                           DESC"`;
    foreach $d (@days) {
        $a = atrp($tick, $dbfile, $peri, $d);
        push @a, $a;
    }
    $na = @a;
    $mean = sum(@a) / $na;
    @a = add_array(\@a, -1.0*$mean);
    $sig = sigma(0.0, @a);
    $a = $a[0]/$sig;
    return $a;
}

sub aroonUp {
    use strict;
    my ($tick, $dbfile, $per, $day) = @_;
    my ($id, $max, $i, $ar);
    my @ph = `sqlite3 "$dbfile" "SELECT day_high \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$day'\\
                           ORDER BY date \\
                           DESC LIMIT $per"`;
    $id = 0;  $max = $ph[0];
    for ($i = 0; $i < $per; $i++) {
        if ($ph[$i] > $max) {
            $id = $i;
            $max = $ph[$i];
        }
    }
    $ar = ($per - $id)*100.0/$per;
    return $ar;
}
sub aroonDown {
    use strict;
    my ($tick, $dbfile, $per, $day) = @_;
    my ($id, $min, $i, $ar);
    my @pl = `sqlite3 "$dbfile" "SELECT day_low \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$day'\\
                           ORDER BY date \\
                           DESC LIMIT $per"`;
    $id = 0;  $min = $pl[0];
    for ($i = 0; $i < $per; $i++) {
        if ($pl[$i] < $min) {
            $id = $i;
            $min = $pl[$i];
        }
    }
    $ar = ($per - $id)*100.0/$per;
    return $ar;
}

sub sma {
    use strict;
    my ($tick, $dbfile, $per, $day) = @_;
    my @pc = `sqlite3 "$dbfile" "SELECT day_close \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$day'\\
                           ORDER BY date \\
                           DESC LIMIT $per"`;
    my $ma = sum( @pc )/$per;
    return $ma;
}

sub atrRatio {
    use strict;
    my ($tick, $dbfile, $per, $day) = @_;
    my @p = split /\D+/, $per;
    my $atr1 = atr($tick, $dbfile, $p[0], $day);
    my $atr2 = atr($tick, $dbfile, $p[1], $day);
    my $atrR = $atr1/$atr2;
    return $atrR;
}

# ($adx, $slope, $tr14, $pdm14, $mdm14) = adx($tick, $dbfile, $period, $day)
sub adx {
    # ($adx, $slope, $tr14, $pdm14, $mdm14) = adx($tick, $dbfile, $period, $day)
    # this is the original Wilders way of the ADX
    use strict;
    my ($tick, $dbfile, $peri, $end) = @_;
#     if (1) {
#         open DA, "<data4adx.txt";
#         $da = <DA>;
#         $i = 0;
#         while ($da = <DA>) {
#             chomp $da;
#             ($ph[$i], $pl[$i], $pc[$i]) = split /\s+/, $da;
#             $i++;
#         }
#         $numd = @ph;
#     } else {
#             
    my ($i,$tr,$pdm,$mdm,$tr14,$pdm14,$mdm14,$pdi,$mdi,$didif,$disum,$dx,$adx, $slope,$prv);

    my $pback = 10*($peri+1);
    my @datel = reverse `sqlite3 "$dbfile" "SELECT date \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $pback"`; 
    chomp @datel;
    my @ph = reverse `sqlite3 "$dbfile" "SELECT day_high \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $pback"`;
    my @pl = reverse `sqlite3 "$dbfile" "SELECT day_low \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $pback"`;
    my @pc = reverse `sqlite3 "$dbfile" "SELECT day_close \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $pback"`;
    chomp @ph; chomp @pl; chomp @pc;
    my $numd = @datel;
#    }
    my @dx = ();
    my @tr = ();  my @mdm = ();  my @pdm = ();   #  TR, -DM, +DM
    for ($i = 1; $i <= $peri; $i++) {
        # first 14 periods to establish baseline
        $tr = max( ($ph[$i]-$pl[$i], abs($ph[$i]-$pc[$i-1]), abs($pc[$i-1]-$pl[$i])) );
        push @tr, $tr;
        if ($ph[$i]-$ph[$i-1] > $pl[$i-1]-$pl[$i]  &&  $ph[$i]-$ph[$i-1] > 0.0) {
            $pdm = $ph[$i]-$ph[$i-1];
            $mdm = 0.0;
        } elsif ($pl[$i-1]-$pl[$i] > $ph[$i]-$ph[$i-1]  &&  $pl[$i-1]-$pl[$i] > 0.0) {
            $mdm = $pl[$i-1]-$pl[$i];
            $pdm = 0.0;
        } else {
            $pdm = 0.0;  $mdm = 0.0;
        }
        push @pdm, $pdm;
        push @mdm, $mdm;
        #printf "$i:\t%.2f %.2f %.2f  %.2f %.2f %.2f\n", $ph[$i], $pl[$i], $pc[$i], $tr, $pdm, $mdm;
    }
    # create the seeds...
    $tr14 = sum( @tr ); $pdm14 = sum( @pdm ); $mdm14 = sum( @mdm );
    $pdi = 100.0 * $pdm14 / $tr14;    $mdi = 100.0 * $mdm14 / $tr14;
    $didif = abs( $pdi - $mdi );  $disum = $pdi + $mdi;
    $dx = 100.0 * $didif / $disum;
    push @dx, $dx;
    #printf "$i:\t%.2f %.2f %.2f  %.2f %.2f %.2f  %.2f %.2f %.2f %.2f %.2f  %.2f\n", $ph[$i], $pl[$i], $pc[$i], $tr, $pdm, $mdm, $tr14, $pdm14, $mdm14, $pdi, $mdi, $dx;
    for ($i = $peri+1; $i <= $numd-1; $i++) {
        # calculating TR, -DM, +DM as before but not keeping old values
        $tr = max( ($ph[$i]-$pl[$i], abs($ph[$i]-$pc[$i-1]), abs($pc[$i-1]-$pl[$i])) );
        if ($ph[$i]-$ph[$i-1] > $pl[$i-1]-$pl[$i]  &&  $ph[$i]-$ph[$i-1] > 0.0) {
            $pdm = $ph[$i]-$ph[$i-1];
            $mdm = 0.0;
        } elsif ($pl[$i-1]-$pl[$i] > $ph[$i]-$ph[$i-1]  &&  $pl[$i-1]-$pl[$i] > 0.0) {
            $mdm = $pl[$i-1]-$pl[$i];
            $pdm = 0.0;
        } else {
            $pdm = 0.0;  $mdm = 0.0;
        }
        # now starts the Wilder smoothing 
        $tr14 = ( ($peri-1)*$tr14 + $peri*$tr)/$peri;
        $pdm14 = ( ($peri-1)*$pdm14 + $peri*$pdm)/$peri;
        $mdm14 = ( ($peri-1)*$mdm14 + $peri*$mdm)/$peri;
        $pdi = 100.0 * $pdm14 / $tr14;    $mdi = 100.0 * $mdm14 / $tr14;
        $didif = abs( $pdi - $mdi );  $disum = $pdi + $mdi;
        $dx = 100.0 * $didif / $disum;
        #printf "$i:\t%.2f %.2f %.2f  %.2f %.2f %.2f  %.2f %.2f %.2f %.2f %.2f  %.2f", $ph[$i], $pl[$i], $pc[$i], $tr, $pdm, $mdm, $tr14, $pdm14, $mdm14, $pdi, $mdi, $dx;
        if ($i <= 2*$peri-1) {
            push @dx, $dx;
        }
        if ($i == 2*$peri-1) {
            $adx = sum(@dx)/$peri;
            #printf " %.2f", $adx;
        } elsif ($i > 2*$peri-1) {
            $prv = $adx;
            $adx = ( ($peri-1)*$adx + $dx)/$peri;
            #printf " %.2f", $adx;
        }
        #print "\n";
    }
    $slope = $adx - $prv;
    return ($adx, $slope, $tr14, $pdm14, $mdm14);    
}

# $rsi = rsi($tick, $dbfile, $period, $day)
sub rsi {
    # $rsi = rsi($tick, $dbfile, $period, $day)
    # this is the original Wilders way of the RSI
    use strict;
    my ($tick, $dbfile, $peri, $end) = @_;
#     if (1) {
#         open DA, "<data4adx.txt";
#         $da = <DA>;
#         $i = 0;
#         while ($da = <DA>) {
#             chomp $da;
#             ($ph[$i], $pl[$i], $pc[$i]) = split /\s+/, $da;
#             $i++;
#         }
#         $numd = @ph;
#     } else {
#             
    my ($i,$rsi, $rs,$tr,$pdm,$mdm,$gain14,$loss14,@gain,@loss);

    my $pback = 10*($peri+1);
    my @datel = reverse `sqlite3 "$dbfile" "SELECT date \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $pback"`; 
    chomp @datel;
    my @pc = reverse `sqlite3 "$dbfile" "SELECT day_close \\
                           FROM stockprices \\
                           WHERE symbol = '$tick' AND date<='$end'\\
                           ORDER BY date \\
                           DESC LIMIT $pback"`;
    chomp @pc;
    my $numd = @datel;
#    }
    for ($i = 1; $i <= $peri; $i++) {
        # first 14 periods to establish baseline
        $tr = $pc[$i]-$pc[$i-1];
        if ($tr > 0.0) {
            $pdm = $tr;
            $mdm = 0.0;
        } else {
            $pdm = 0.0;
            $mdm = abs($tr);
        }
        push @gain, $pdm;
        push @loss, $mdm;
    }
    # create the seeds...
    $gain14 = sum( @gain )/$peri; 
    $loss14 = sum( @loss )/$peri;
    if ($loss14 == 0.0) {
        $rs = 1000;
        $rsi = 100.0;
    } else {
        $rs = $gain14/$loss14;
        $rsi = 100.0 - 100.0/(1+$rs);
    }
    for ($i = $peri+1; $i <= $numd-1; $i++) {
        # calculating as before but not keeping old values
        $tr = $pc[$i]-$pc[$i-1];
        if ($tr > 0.0) {
            $pdm = $tr;
            $mdm = 0.0;
        } else {
            $pdm = 0.0;
            $mdm = abs($tr);
        }
        # now starts the Wilder smoothing 
        $gain14 = ($gain14*($peri-1) + $pdm )/$peri;
        $loss14 = ($loss14*($peri-1) + $mdm )/$peri;
        if ($loss14 == 0.0) {
            $rs = 1000;
            $rsi = 100.0;
        } else {
            $rs = $gain14/$loss14;
            $rsi = 100.0 - 100.0/(1+$rs);
        }
    }
    return $rsi;    
}

# ($ind, $ind2, $ind5) = getIndicator($tick, $dbfile, $indicator, $ndays, $dayEnd) 
sub getIndicator {
    # ($ind, $slope2, $slope5) = getIndicator($tick, $dbfile, $indicator, $ndays, $dayEnd) 
    # returns the indicator, its 2 day slope, and its $ndays day linear-fit slope
    # the proper date must be given or it returns garbage (I think)...
    # If $ndays is given as 0 (or < 3), then only the current day will be returned, slopes will be zero.
    #   $day is the day for which we want results
    #   $ndays is how many days to include in the $slope5 slope, normally we call with this = 5.
    use strict;
    my ($tick, $dbfile, $indicator, $days, $day1) = @_;
    my @res;
    my @x = (1 .. $days) if $days >= 3; # x-axis for linear fit
    my @y = (); my @dates;
    my ($a, $a2, $a5, $doslope, @a);
    my ($peri, $mod, $i, $in, $aa, $siga, $sigb, $end, $indcall);

    # other period for the indicator - goes at the end of the command
    if ($indicator =~ /ATR(\d+\D\d+)/) {
        $peri = $1;
    } else {
        $indicator =~ /([A-Za-z]+)(\d*)/;
        $indicator = $1;
        $peri = $2;
        $peri = 14 unless $peri;   #print "Ind = $indicator, period = $peri\n";
    }
    if ($days < 3) {
        $doslope = 0;
    } else {
        $doslope = 1;
    }
    # cannot call display_indicator with the modified indicators...
    # also allow here for the Kaufman efficiency ratio
    my $returnsarray = 0;
    if ($indicator =~ /ATR\d+\D/) {
        $indcall = \&atrRatio;
    } elsif ($indicator =~ /ADX/) {
        $indcall = \&adx;
        $returnsarray = 1;
    } elsif ($indicator =~ /BPI/) {
        $indcall = \&marketStance;
        $returnsarray = 1;
    } elsif ($indicator =~ /ATRPN/) {
        $indcall = \&atrpn;
    } elsif ($indicator =~ /ATRP/) {
        $indcall = \&atrp;
    } elsif ($indicator =~ /ATR/) {
        $indcall = \&atr;
    } elsif ($indicator =~ /obv/i) {
        $indcall = \&OBVs;
    } elsif ($indicator =~ /SMA/) {
        $indcall = \&sma;
    } elsif ($indicator =~ /aroonu/i) {
        $indcall = \&aroonUp;
    } elsif ($indicator =~ /aroond/i) {
        $indcall = \&aroonDown;
    } elsif ($indicator =~ /RSI/) {
        $indcall = \&rsi;
    } elsif ($indicator =~ /KaufmanE/) {
        $indcall = "Prices"; $mod = "";
    } else {
        die "Error: no such indicator '$indicator' is known $!...\n"
    }
    @res = ();
    if ($doslope) {
        @y = ();
        chomp( @dates = `sqlite3 "$dbfile" "SELECT date \\
									   FROM stockprices \\
									   WHERE symbol = '$tick' \\
									   AND date <= '$day1' \\
									   ORDER BY date \\
									   DESC LIMIT $days"` );
        for ($i = 0; $i < $days; $i++) {
            @_ = ($tick, $dbfile, $peri, $dates[$i]);
            @_ = ($day1) if ($indicator =~ /BPI/);
            if ($returnsarray) {
                @a = &$indcall;
                push @y, $a[0];
            } else {
                $a = &$indcall;
                push @y, $a;
            }
        }
        $a = $y[0];
        $a2 = $y[0] - $y[1];
        ($aa, $siga, $a5, $sigb) = linfit( \@x, \@y );
    } else {
        @_ = ($tick, $dbfile, $peri, $day1);
        @_ = ($day1) if ($indicator =~ /BPI/);
        if ($returnsarray) {
            ($a, @a) = &$indcall;
        } else {
            $a = &$indcall;
        }
        $a2 = 0.0;  $a5 = 0.0; print "BPI = $a ... ";
    } 
    
    return ($a, $a2, $a5);
}

sub getIndicatorOLD {
# using the old/geniustrader tools
    # ($ind, $ind2, $ind5) = getIndicator($tick, $indicator, $ndays, $dayEnd) 
    # returns the indicator, its 2 day slope, and its $ndays day linear-fit slope
    # the proper date must be given or it returns garbage (I think)...
    # If $ndays is given as 0 (or < 3), then only the current day will be returned, slopes will be zero.
    #   $dayEnd is the last day (--end), i.e., the day for which we want results when backtesting
    #   $ndays is how many days to include in the $ind5 slope, normally we call with this = 5.
    use strict;
    #old :    my ($tick, $indicator, $day2, $day1) = @_;
    my ($tick, $indicator, $days, $day1) = @_;
    my @res;
    my @x = (1 .. $days) if $days >= 3; # x-axis for linear fit
    my @y = ();
    my ($a, $a2, $a5);
    my ($mod, $i, $in, $aa, $siga, $sigb, $end, $indcall);

    # other period for the indicator - goes at the end of the command
    $indicator =~ /([A-Za-z]+)(\d*)/;
    $indicator = $1;
    my $period = $2; #print "Ind = $indicator, period = $period\n";
    if ($period) {
        $mod = "'".$period." {I:Prices CLOSE}'";
    } else {
        $mod = "";
    }
    if ($days < 3) {
        $end = "--nb-item=1";
    } else {
        $end = "--nb-item=$days";
    }
    # cannot call display_indicator with the modified indicators...
    # also allow here for the Kaufman efficiency ratio
    if ($indicator =~ /MACD/) {
        $indcall = "MACD";
    } elsif ($indicator =~ /STO/) {
        $indcall = "STO";
    } elsif ($indicator =~ /KaufmanE/) {
        $indcall = "Prices"; $mod = "";
    } else {
        $indcall = $indicator;
    }
    @res = `display_indicator.pl --end $day1 $end I:$indcall $tick $mod`;
    #print "display_indicator.pl --end $day1 $end I:$indcall $tick $mod\n";
    # ADX: (4 lines per day; ADX, +DMI, -DMI, DMI)
    # MACD: (3 lines per day; MACD, MACD-Signal, MACD-Diff.)
    # STO: (4 lines, %K Fast, %D Fast, %K Slow (stochastic), %D Slow (Signal line))
    # one line only: ATR, RSI
    #
    shift @res;
    if ($days > 0) {
        for ($i = 0; $i < $days; $i++) {
            $in = shift @res;
            if ($indicator =~ /ADX/) {
                shift @res; shift @res; shift @res; 
            } elsif ($indicator =~ /MACDH/) { # MACD histogram or difference
                shift @res; $in = shift @res;
            } elsif ($indicator =~ /MACDS/) { # MACD signal line
                $in = shift @res; shift @res;
            } elsif ($indicator =~ /MACD/) {
                shift @res; shift @res;
            } elsif ($indicator =~ /STOs/) { # Slow stochastic, signal line
                shift @res; 
                shift @res;
                $in = shift @res; 
            } elsif ($indicator =~ /STO/) { # Slow stochastic
                shift @res; 
                $in = shift @res;
                shift @res; 
            } elsif ($indicator =~ /KaufmanE/) {
                # TODO make the Kaufman E= ( c_day-1 - c_day-10 ) / sum abs c_day,i - c_day-1,i
            }     
    
            $in =~ /.* = (-*\d+.\d+)/; 
            push @y, $1;
            last if ($days < 3);
        }
    } else {
        $in = shift @res;
        $in =~ /.* = (-*\d+.\d+)/; 
        push @y, $1;
    }
    if ($days < 3) {
        $a = $y[0];
        $a2 = 0; $a5 = 0;
    } else {
        ($aa, $siga, $a5, $sigb) = linfit( \@x, \@y );
        $a = $y[-1];
        $a2 = ($y[-1] - $y[-2]);
        @y = ();
    }
    
    return ($a, $a2, $a5);
}


1;
