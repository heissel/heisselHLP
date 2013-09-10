use Carp;
$|=1;

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

# $gain = exitTrade($whichway, $inprice, $psize, $price);
sub exitTrade {
	# $gain = exitTrade($whichway, $inprice, $psize, $price);
	# $stop is the expected exit price, either the stop or the close price in case of an end-of-day exit signal
	use strict;
	my ($whichway, $inprice, $psize, $price) = @_;
    my $c = @_; die "only $c elements to exitTrade(), should be 4\n" unless ($c == 4);
	my ($gain);

	unless ($price) {
        die "ERROR: must provide exit price to exitTrade - found $price\n";
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
	return $gain;
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

# $newstop = getStop($sysStop, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $today, $stop, $istop, $tick, $whichway, $inprice, $priceNow, $target, $daysInTrade, $WorN)
sub getStop {
	# $newstop = getStop($sysStop, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $today, $stop, $istop, $tick, $whichway, $inprice, $priceNow, $target, $daysInTrade, $WorN)
	#
	# arguments:    stop-system name, date-hash, day_index-hash, [open,high,low,close]-price-hash, current date, current stop, initial stop, ...
	#               ticker, long/short, entry price, current price, target price, number of days in trade
	#				wide-or-narrow priority
	#               -- if no target price is defined, just set to 0 and it will not be used
	use strict;
	my ($sysStop, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, $stop, $istop, $tick, $whichway, $inprice, $priceNow, $target, $daysInTrade, $worn) = @_;
    my $c = @_; die "only $c elements to getStop(), should be 17\n" unless ($c == 17);
	my ($mystop, $factor, $newstop, $amount, $d, $y,$in, $max, $min, $mean, $narr, $peri, $dum, $dev, $r, $val, $ispercent, $begin, $qmin);
	my ($atr, $finamount, $thisday, $atr0, $exclude, $day0, $day1, $i, $sma, $md0, $md1, $md2, $ms0, $ms1, $ms2, $df0, $df1, $df2, $addval);
	my @y; my @atr; my @dum; my @data; my @pdays; my @rval; my @rsi;
    my ($po, $ph, $pl, $pc, $yo, $yh, $yl, $yc, $yyh, $yyl, $yyc, $yyo, $tr, $dout, $mdperi, $periFast, $periSlow, $periSmooth, $pmax); #, $dbfile); 
	# calc current gains etc.
	my $curR = ($priceNow - $inprice)/($inprice - $istop);
    my %openp = %$h_o;  my %closep = %$h_c;  my %maxp = %$h_h;  my %minp = %$h_l;
    my %hday = %$h_d;  my %dayindex = %$h_i;
	my $yesterday = $hday{$dayindex{$day}-1};
	my $yyday = $hday{$dayindex{$day}-2};

    # stop at absolute value - practical for making sure a trade runs indefinately
    if ($sysStop =~ /^D(\d{4}-\d{2}-\d{2})/) {
        $dout = $1;
        if ($day ge $dout) {
            return $closep{$day};
        } else {
            return $minp{$hday{$dayindex{$day}+1}}-0.01;  # never stopped out...
        }
    }    
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
    # stop at an SMA plus a certain percentage of that price. Should ALWAYS be used in combination except for pure trend following.
    # a trailing 'x' means to exclude the current day, i.e., use the previous day instead.
    # example:  "SMA 10 1", "SMA 5 0.1"
    if ($sysStop =~ /SMA\s+(\d+)\s+(\d+.?\d*)(x*)/) {
        $peri = $1; $factor = $2/100.0;   $exclude = $3;
        if ($exclude eq "x") {
        	$thisday = $yesterday
        } else {
        	$thisday = $day;
        }
        $sma = sma($tick, $h_d, $h_i, $h_c, $peri, $thisday);
        # only valid if the SMA is actually in the "right" place, i.e. for counter-trend use, care must be taken to get meaningful results
#        if ( ($whichway eq 'long' && $sma < $closep{$day}) || ($whichway eq 'short' && $sma > $closep{$day}) ) {
        if ( ($whichway eq 'long' && $sma < $closep{$day} && $sma < $openp{$day}) || ($whichway eq 'short' && $sma > $openp{$day} && $sma > $closep{$day}) ) {
            $amount = abs( $closep{$thisday} - $sma) + $closep{$thisday}*$factor; 
        } else {
            $amount = $closep{$day}*0.99;  # 99% of the close price...
        }
        $finamount = getFinAmount($worn, $finamount, $amount); 
    }
	# Percentage of H/L used as stop from close price [c] or from high/low of the day.
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
            $val = $closep{$thisday};
        ### TODO: 'h' and 'l' options to take the percentage from the high (low) of the day.
        } elsif ($d eq "h") {
            $val = maxp{$thisday};
        } elsif ($d eq "l") {
            $val = $minp{$thisday};
        } elsif ($whichway eq "long") {
            $val = $minp{$thisday};
        } elsif ($whichway eq "short") {
            $val = $maxp{$thisday};
        } else {
            die "ERROR; don't know what direction=$whichway is\n"; 
        }
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
        ($ph, $pl, $pc, $po) = ($maxp{$day}, $minp{$day}, $closep{$day}, $openp{$day});
        ($yh, $yl, $yc, $yo) = ($maxp{$yesterday}, $minp{$yesterday}, $closep{$yesterday}, $openp{$yesterday});
        $dum = $hday{$dayindex{$day}-2};
        ($yyh, $yyl, $yyc, $yyo) = ($maxp{$day}, $minp{$day}, $closep{$day}, $openp{$day});  # day before yesterdays prices
        $tr = max( ($yh-$yl, $yh-$yyc, $yyc-$yl) );
        if ($worn =~ /i/) {
            # intraday setting of the stop, i.e. wrt the day before
            $tr = max( ($ph-$pl, $ph-$yc, $yc-$pl) ); print "(iday) ";
        }
        $amount = $factor * $tr;    #printf "$factor x $tr = %.3f -> ", $amount;
        $finamount = getFinAmount($worn, $finamount, $amount);     #printf "%.3f -> ", $finamount;
    }
    # Volatility stop based on ATR(<period>), stop to be placed a <multiple> of the ATR away from the entry/close price
    # a trailing 'x' means to exclude the current day, i.e., use the <period> previous days instead.
    # example: "Vola 10 2.8", "Vola 14 3.0x" --- NOTE: Must give factor as N.M format
    #
    if ($sysStop =~ /Vola\s+(\d+)\s+(\d+.\d+)(x?)/) {
        $peri = $1; $factor = $2;       #  print "peri = $peri, factor = $factor, ending = $3 "; exit;
        if ($3) {
        	$thisday = $yesterday
        } else {
        	$thisday = $day;
        }
        $atr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri, $thisday);
        $amount = $atr * $factor;
        $finamount = getFinAmount($worn, $finamount, $amount);
    }
    # Dev stop; ATR plus <factor> times 110% stddev of ATR(<period>) for last 30 days
    # a trailing 'x' means to exclude the current day, i.e., use the <period> previous days instead.
    # example: "Dev 1 10", "Dev 2 12x"
    #  TODO: transfer to using price hashes instead of db-call
#     if ($sysStop =~ /Dev\s+(\d+)\s+(\d+)(x*)/) { #print "dev";
#         $factor = $1;
#         $peri = $2;
#         if ($3) {
#         	$thisday = $yesterday
#         } else {
#         	$thisday = $day;
#         }
#         $atr0 = atr($tick, $dbfile, $peri, $thisday);
#         @atr = ();  #getIndicator($tick, "ATR$peri", 0, $day);
# 		push @atr, $atr0;
#         chomp( @data = `sqlite3 "$dbfile" "SELECT date \\
# 							   FROM stockprices \\
# 							   WHERE symbol = '$tick' \\
# 							   AND date < '$thisday' \\
# 							   ORDER BY date \\
# 							   DESC LIMIT 29"` ); 
#         foreach $thisday (@data) {
#         	$atr = atr($tick, $dbfile, $peri, $thisday);
#         	push @atr, $atr;
#         }
#         $mean = sum(@atr)/30.0;
#         $dev = sigma($mean, @atr);
#         $amount = $atr0 + $dev * $factor * 1.10;
#         $finamount = getFinAmount($worn, $finamount, $amount);
#     }
    # Stop at absolute <distance>/percentage from local min/max of last <n> days (including today)
    # a trailing 'x' means to exclude the current day, i.e., use the <n> previous days instead.
    # example: "Local 6 0.2", "Local 5 1p", "Local 4 0.5px", "Local 14 0.1pM12-26-9-3"
            ### TODO:  code a Locam_initp_maxp_0.1p stop; period can go to 1 but not longer than maxp.
            ###
    if ($sysStop =~ /Loca[ln]\s+(\d+)\s+(\d+.?\d*)(p*)(x*)/) { #print "local";
        $peri = $1;
        $factor = $2;
        $ispercent = $3;
        $exclude = $4;
        $pmax = $peri;
        $addval = 2;    
    } elsif ($sysStop =~ /Locam\s+(\d+)\s+(\d+)\s+(\d+.?\d*)(p*)(x*)/) {
        $peri = $1;
        $pmax = $2;
        $factor = $3;
        $ispercent = $4;
        $exclude = $5;
        $addval = 1.5;
    }
    if ($sysStop =~ /Loca/) {
        if ($exclude) {
            $begin = 1;
        } else {
            $begin = 0;
        }
        if ($sysStop =~ /M(\d+)-(\d+)-(\d+)-(\d+)/) {  # check if MACD diff. diminished
            $periFast = $1; $periSlow = $2; $periSmooth = $3;   $mdperi = $4;
            ($md0, $ms0) = macd($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $periFast, $periSlow, $periSmooth, $day);
            ($md1, $ms1) = macd($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $periFast, $periSlow, $periSmooth, $yesterday);
            ($md2, $ms2) = macd($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $periFast, $periSlow, $periSmooth, $yyday);
            $df0 = $md0 - $ms0; $df1 = $md1 - $ms1; $df2 = $md2 - $ms2;
            if ($whichway eq 'long' && $df0 < $df1 && $df1 > $df2) {
                $peri = $mdperi;
            } elsif ($whichway eq 'short' && $df0 > $df1 && $df1 < $df2) {
                $peri = $mdperi;
            }
        } elsif ($sysStop =~ /Loca[nm]/) {    # Candle-color adjustment. Not together with MACD-adjustment
            # walk forward from beginnig and change the Local-period for every candle  ### consider using close-close span in addition...
            for ($i = $dayindex{$day}-$daysInTrade; $i <= $dayindex{$day}; $i++) {
                if ($whichway eq 'long') {
                    if ($closep{$hday{$i}} < $openp{$hday{$i}}) {
                        $peri--;
                    } else {
                        $peri += $addval;
                    }
                } elsif ($whichway eq 'short') {
                    if ($closep{$hday{$i}} > $openp{$hday{$i}}) {
                        $peri--;
                    } else {
                        $peri += $addval;
                    }                
                }
                $peri = $pmax if ($peri > $pmax);
                $peri = 1 if ($peri < 1);
            }
            $peri = int($peri);
        }
        @y = ();
        if ($whichway eq "long") {
            for ($i = $begin; $i < $peri+$begin; $i++) {
                push @y, $minp{$hday{$dayindex{$day}-$i}};
            }
        } else {
            for ($i = $begin; $i < $peri+$begin; $i++) {
                push @y, $maxp{$hday{$dayindex{$day}-$i}};
            }
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
        $finamount = getFinAmount($worn, $finamount, $amount);  #print "becoming $finamount\n";
    }
    # Stop at absolute distance/percentage from yd high/low if today made a new low/high
    # a trailing 'x' means to exclude the current day, i.e., use the two previous days instead.
    # example:  'HiLo 0.10', 'HiLo 0.2p', 'HiLo 0.5px'
    if ($sysStop =~ /HiLo\s+(\d+.?\d*)(p*)(x*)/) { #print "hilo";
        if ($daysInTrade == 0) {
            warn "Error: HiLo will not work with initial stop (for now) - use 'Local' instead\n";
        }
        $factor = $1;
        $ispercent = $2;
        $exclude = $3;
        if ($exclude) {
            $day0 = $yesterday;
            $day1 = $hday{$dayindex{$day}-2};
        } else {
            $day0 = $day;
            $day1 = $yesterday;
        }
        ($pl, $ph) = ($minp{$day0}, $maxp{$day0});  # todays prices
        ($yl, $yh) = ($minp{$day1}, $maxp{$day1});  # yesterdays prices
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

	# Done with the stops as such.
	# Below follows the modifications to the current stop
	$amount = $finamount; 

    # Modify stop: according to the current value of the R-multiple $curR (usually based on the close)
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
    # Modify stop; give away a progressively lesser fraction of the profits as the position turns more and more positive
    # example:  Rprof_1.5_0.2_3.0    (Rprof_[R_breakeven]_[q_min]_[gamma]
    # where the stop is at breakeven when R = R_breakeven (q=1), the minimum give-back fraction (q) is q_min, lower gamma is faster decline in q
    # (see formula and plot in folder 'System dev.', note dated 11.MRZ.2013
    if ($sysStop =~ /Rprof\s+(\d+.\d+)\s+(\d+.\d+)\s+(\d+.\d+)\s+(\d+.\d+)/) {
        $factor = $1;   $qmin = $2;     $peri = $3;     $pmax = $4;
#        if ($curR >= $factor) {     # only start this when higher that the breakeven level - arbitrary!
        if ($curR >= 0.0 && $curR < $pmax) {     # only start this when positive - arbitrary!
            $dum = abs($priceNow - $inprice) * ( (1.0 - $qmin)/(1.0 + ($curR-$factor)/$peri) + $qmin );
            if ($dum < $amount) {
                print "changing stop with q = ", ( (1.0 - $qmin)/(1.0 + ($curR-$factor)/$peri) + $qmin );
                $amount = $dum;
            }
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
    # TimeLim; time limit; if not above <factor> R after <peri> days, then set the stop at the given R or current close (if 0) 
    # examples: "TimLim 3 1.5 0" to set stop=close after day 3 if not above 1.5R. "TimLim 4 1.0 -0.5"
    if ($sysStop =~ /TimLim\s+(\d+)\s+(-*\d+.?\d*)\s+(-*\d+.?\d*)/) { 
        $peri = $1;
        $factor = $2;
        $val = $3;
        if ($daysInTrade >= $peri && $curR < $factor) {
            if ($val == 0) {
                $amount = 0.0;
            } else {
                    $y = $inprice + $val*($inprice-$istop);
                    if ($whichway eq "long") {
                        $dum = $priceNow - $y;   
                        printf "...R=%.2f so %.2f -> %.2f (via $val) giving R=%.2f\n", $curR, $amount, $dum, (($priceNow-$dum)-$inprice)/($inprice-$istop);
                    } else {
                        $dum = $y - $priceNow;   
                        printf "...R=%.2f so %.2f -> %.2f (via $val) giving R=%.2f\n", $curR, $amount, $dum, (($priceNow+$dum)-$inprice)/($inprice-$istop);
                    }
                    $amount = $dum if ($dum < $amount); 
            
            }
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
        @y = ($openp{$day}, $closep{$day});
        ($min, $max) = low_and_high(@y);
        ($pl, $ph) = ($minp{$day}, $maxp{$day});
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

# ($lentry, $lstop, $sentry, $sstop) = getIntraDayEntry($tick, $dbfile, $system, $sysInitStop, $day)
# used only for tradeManager
sub getIntraDayEntryOLD { # old tradeManager, calls to other routines will not work!!!
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

# ($lentry, $lstop, $sentry, $sstop) = getIntraDayEntry($tick, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $system, $sysInitStop, $day)
# used only for tradeManager
sub getIntraDayEntry {
    # ($lentry, $lstop, $sentry, $sstop) = getIntraDayEntry($tick, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $system, $sysInitStop, $day)
    use strict;
    my ($tick, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $system, $sysInitStop, $day) = @_;
    my $c = @_; die "only $c elements to getIntraDayEntry(), should be 10 - $!\n" unless ($c == 10);
    my %closep = %$h_c;
    my ($tr, $ok, @my, $peri1, $peri2, $frac, $p, $atr1, $atr2, $ptxt, $a, $siga, $b, $sigb, $tralt);
    my ($lentry, $lstop, $sentry, $sstop);
    if ($system =~ /^VolB(\w{1})(\d+)/) {
        # calc the TR of current day. If price on next day goes beyond yc|po +/- fac % of TR, then enter at that price.
        # two stop-buy orders are to be entered at the close|open of the day
        my $when = $1;
        my $fac = $2/100.0;
        $tr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, 1, $day);
        $ok = 1;
        if ($system =~ /VolB[CO]\d+A(\d+)R(\d+)l(\d+)/) {
            $peri1 = $1; $peri2 = $2; $frac = $3/100.0;
            $ok = 1;
            $atr1 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
            $atr2 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri2, $day);
            # testing influence of current slope...
            ($a, $siga, $b, $sigb) = getSlope($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
            if ($atr1/$atr2 < $frac) {
                $ok = 1;
#                printf "ATR-ratio = %.2f ... slope = %.3f +/- %.3f ", $atr1/$atr2, $b, $sigb;
            }
        } elsif ($system =~ /VolB[CO]\d+([AT])(\d+)/) {
            my $trtest = $1;   $peri1 = $2;
            $tr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
            # experimental:  take the larger of the ranges, either ATR or TR...
            if ($trtest eq "T") {
                $tralt = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, 1, $day);
                if ($tralt > $tr) {
                    $tr = $tralt;
                }
            }
            $ok = 1;
        }
        if ($when eq "O") {
            # base on opening tomorrow...just let me know delta
            $lentry = $fac*$tr;
            $sentry = -$fac*$tr;
        } elsif ($when eq "C") {
            $p = $closep{$day};
            $lentry = $p + $fac*$tr;
            $sentry = $p - $fac*$tr; #printf "today close = $p, delta = %.3f => entry at %.3f ", $fac*$tr, $p-$fac*$tr;
            $lstop = getStop($sysInitStop, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, 0, 0, $tick, "long", $lentry, $lentry, 0, 0, "ni");
            $sstop = getStop($sysInitStop, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, 0, 0, $tick, "short", $sentry, $sentry, 0, 0, "ni");
        } else {
            die "Error; must give C or O, not \"$when\"\n";
        }
        
    }
    return ($lentry, $lstop, $sentry, $sstop);
}


#   %sma = smaHash($tick, $h_d, $h_i, $h_c, $sper, $daybeg, $dayend); # gets $sma{$day}...
sub smaHash {
    use strict;
    my $c = @_; die "only $c elements to smaHash(), should be 7\n" unless ($c == 7);
    my ($tick, $h_d, $h_i, $h_c, $sper, $daybeg, $dayend) = @_;
    my %closep = %$h_c; my %hday = %$h_d;  my %dayindex = %$h_i;
    my %sma = ();
    my ($close2sub, $oldsma, $i, $day, $tmps);
    # TODO; check that we don't get beyond the date range; only fill hash from first allowed day based on the SMA-period
    $sma{$dayend} = sma($tick, $h_d, $h_i, $h_c, $sper, $dayend);
    $close2sub = $closep{$dayend};
    $oldsma = $sma{$dayend}; #print $dayindex{$dayend}," $oldsma\n";
    $i = 0;
    while (1) {
        $i++;
        $day = $hday{$dayindex{$dayend}-$i};
        last if $day lt $daybeg;
        $sma{$day} = $oldsma + ($closep{$hday{$dayindex{$dayend}-$i-($sper-1)}} - $close2sub)/$sper;
        $close2sub = $closep{$day};
        $oldsma = $sma{$day}; 
#         if ($i > 630) {
#             $tmps = sma($tick, $h_d, $h_i, $h_c, $sper, $day);
#             print $dayindex{$dayend}-$i," $oldsma $tmps\n";
#             exit if $i > 640;
#         }
    }
    return %sma;
}


#            ($hilo, $datehl, $ishigh, $th, $tl) = getHiLo(\%sma); # getting highs and lows in the series as well as tredn directions
sub getHiLo {
    use strict;
    my $c = @_; die "$c elements to getHiLo(), should be 1\n" unless ($c == 1);
    my ($s) = @_;
    my %sma = %$s;
    my @hilo = (); my @datehl = (); my @ishigh = ();    my %trendh = (); my %trendl = ();
    my ($day, $yd, $yyd, $n, $s2, $s1, $s0, $sdir1, $sdir0, $ixLow0, $ixLow1, $ixHigh0, $ixHigh1, $trendh, $trendl);

    # walking forward through the series
    $c = 0;
    foreach $day (sort keys %sma) {
        $c++;
#        $s4 = $s3; $s3 = $s2; 
        $s2 = $s1;  $s1 = $s0; $s0 = $sma{$day};
        next if $c < 3;  # wait until we can look back a bit
        if ($c == 3) {  # setting initial directions
            $sdir0 = ($s0-$s2)/abs($s0-$s2);
            $sdir1 = $sdir0;
        }
        if ($s0 > $s1 && $sdir0 == -1) {
            $sdir1 = $sdir0;
            $sdir0 = 1;
        } elsif ($s0 < $s1 && $sdir0 == 1) {
            $sdir1 = $sdir0;
            $sdir0 = -1;
        } else {
            $sdir1 = $sdir0;
        }
        if ($sdir0 != $sdir1) { # change of direction - a top/bottom
            push @hilo, $s1;  # print "$day: change from $sdir1 to $sdir0\n";
            push @datehl, $yd;
            if ($sdir1 == -1) {     # old direction was down, so current extreme is a low
                $ixLow0 = -1;   $ixLow1 = -3;
                $ixHigh0 = -2;  $ixHigh1 = -4;
                push @ishigh, 0;   #print "low  ";
            } else {
                $ixLow0 = -2;   $ixLow1 = -4;
                $ixHigh0 = -1;  $ixHigh1 = -3;
                push @ishigh, 1;   #print "high ";
            }
            $n = @hilo;
            if ($n >=4) {  # need at least two lows and two highs in order to compare.
                if ( $hilo[$ixLow0] < $hilo[$ixLow1] ) {  # lower low
                    $trendl = -1;
                } else {                                # higher low
                    $trendl = 1;
                }
                if ( $hilo[$ixHigh0] > $hilo[$ixHigh1] ) {  # higher high
                    $trendh = 1;
                } else {                                # lower high
                    $trendh = -1;
                }
                #print "on $yd: hereafter h/l = $trendh/$trendl\n";
            }
        }
        # even if no top/bottom, we could still have sma value higher than previous high
        $n = @hilo;
        if ($n >= 2) {     # need one high and low to compare
            if ($s0 > $hilo[$ixHigh0]) { # direction is surely up for the highs
                $trendh = 1;    # print "  fp on $day: (highs) h/l = $trendh/$trendl\n";
            } elsif ($s0 < $hilo[$ixLow0]) { # direction is surely down for the lows
                $trendl = -1;   # print "  fp on $day: (lows)  h/l = $trendh/$trendl\n";
            }
            # fill the trendh/l hashes if we've gathered enough data
            if ($trendl && $trendh) {
                $trendl{$day} = $trendl; 
                $trendh{$day} = $trendh;
            }
        }
        $yyd = $yd;
        $yd = $day;
    }
    return (\@hilo, \@datehl, \@ishigh, \%trendh, \%trendl);
}

sub getSetup {
    use strict;
    my $c = @_; die "Found $c elements to getSetup(), should be 9\n" unless ($c == 9);
    my ($suCond, $dir, $h_o, $h_h, $h_l, $h_c, $h_v, $day, $dix) = @_;
    my %openp = %$h_o;  my %closep = %$h_c;  my %maxp = %$h_h;  my %minp = %$h_l;   my %volume = %$h_v;
    my @d = sort keys %closep;
    my $n = @d;
    die "$day != $d[$dix]\n" unless ($day eq $d[$dindex]);
    
    if ($suCond =~ /SMA(\d+)([fxc])(\d+.?\d*)/) { # SMA slope up for long, down for short

    }
    if ($suCond =~ /EMA(\d+)([fxc])(\d+.?\d*)/) { # EMA slope up for long, down for short
        $per = $1; 
        @ma = emaArray(\%closep, $per);
    }
}

# ($setupOK, $donotenter, $stopBuy,$stopBuyS) = getSetupCondition($tick, $system, $suCond, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, $setupOld);
# old setupOK could have some meaning. donotenter is calc on the spot and is either "long" or "short"
#       ###### OLD ##### for new backtest, use the getSetup routine above.
sub getSetupCondition {
    # ($setupOK, $donotenter,$stopBuyL,$stopBuyS) = getSetupCondition($tick, $system, $suCond, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $h_v, $day, $setupOld);
    #
    # $setupOK is either "long", "short", "longshort", or "".
    use strict;
    my $c = @_; die "only $c elements to getSetupCondition(), should be 12\n" unless ($c == 12);
    my ($tick, $system, $suCond, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $h_v, $day, $olds) = @_;
    my %openp = %$h_o;  my %closep = %$h_c;  my %maxp = %$h_h;  my %minp = %$h_l;
    my %hday = %$h_d;  my %dayindex = %$h_i; my %volume = %$h_v;
	my $yd = $hday{$dayindex{$day}-1};  my $yyd = $hday{$dayindex{$day}-2}; my $closep = $closep{$day};
    my ($adx,$perFast, $perSlow, $slow1, $slow2, $fast1, $fast2, $cross, $a5, $a50, $aPar, $rPar, @bpi, $sdir0, $sdir1, $repeat, $whichd, $whichyd);
    my ($sper, $rsi9, $sval, $s0, $s1, $s2, $greaterless, $localm, $i, $p, $peri1, $fac, $mean, $rmsf, $fac2, $rmsf2, $th, $tl, $min, $max);
    my (%sma, $hilo, $datehl, $ishigh, $ixLow0, $ixLow1, $ixHigh0, $ixHigh1, @hilo, @datehl, @ishigh, $trendh, $trendl, $oldh, $oldl, $what);
    my @p = (); my (%trendh, %trendl);  my @a = ();
    my $donotenter = "";
    my $stopBuyL = 0;   my $stopBuyS = 0;
    my $setupOK = "longshort";  # default is OK in both directions. If no conditions defined for a strategy then no changes.
                                # Each condition-test will change only to a lower subset, e.g. "longshort" -> "short" -> "", but
                                # *not* e.g. "longshort" -> "short" -> "long"  - only removing, not adding.
                                # Otherwise it will either be set to the old value ($olds) or be changed.
    
# BPI setup. Turns either on or off
# 	if ($suCond =~ /BPI([XO])/) {
# 	    $fac = $1;
# 	    @bpi = marketStance($day);
# 	    if ($bpi[0] eq $fac) {
# 	        $setupOK = "longshort";
# 	    } else {
# 	        $setupOK = "";
# 	    }
# 	}
    # LUXOR crossover system - should probably not be run with other setup conditions...
    # returns +1 if fast cross above slow, -1 if fast cross below slow (== slow "cross above" fast), 0 if no crossing
    if ($system =~ /LUXcross(\d+)x(\d+)/) {
        $perFast = $1; $perSlow = $2;
        $slow1 = sma($tick, $h_d, $h_i, $h_c, $perSlow, $yd);
        $slow2 = sma($tick, $h_d, $h_i, $h_c, $perSlow, $day);
        $fast1 = sma($tick, $h_d, $h_i, $h_c, $perFast, $yd);
        $fast2 = sma($tick, $h_d, $h_i, $h_c, $perFast, $day);
        $cross = crossover($fast1, $fast2, $slow1, $slow2);
        if ($cross == 0) {
            $setupOK = $olds;   # no change...
        } elsif ($cross == 1) {
            $setupOK = "long"; #print "L1 ";
            $stopBuyL = $maxp{$day};
        } else {
            $setupOK = "short"; #print "S1 ";
            $stopBuyS = $minp{$day};
        }
        if ($setupOK eq "longshort") {
            $setupOK = ""; #print "n1 "; # cannot have OK for both directions at the same time
        }
	}
	
	# Below the actual setup conditions
	#
	if ($suCond =~ /HiLo(\d+)([x]*)/) { 
	    $sper = $1; $fac = $2;
        ($trendh, $trendl) = split /:/, $olds;
        if ($trendh && $trendl) {
            if ($trendh == 1 && $trendl == 1) {
                $setupOK = 'long';
            } elsif ($trendh == -1 && $trendl == -1) {
                $setupOK = 'short';
            } elsif ($fac eq 'x') {
                $setupOK = '';
            } else {
                $setupOK = 'longshort';
            }
            $donotenter = "$trendh:$trendl";
        }
	}
	if ($suCond =~ /ADX(\d+)f(\d+)-(\d+)([r]*)/) {
	    # ADX < $2: start setup OK, when cross > $3 setup not OK. r: reverse significance (to be implemented)
	    $peri1 = $1; $fac = $2; $fac2= $3;
        @a = adx($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
        $adx = $a[0];
	    if ($adx > $fac2) {
	        $setupOK = '';
	        $stopBuyL = $fac2;  # the last limit value encountered
	    } elsif ($adx < $fac) {
	        $setupOK = 'longshort';
	        $stopBuyL = $fac;
	    } else {
	        # walk backwards: if first encounter value > 50 => not OK, if first see value < 20 => OK
            if ($olds == $fac2) {
                $setupOK = '';
                $stopBuyL = $fac2;  # the last limit value encountered            
            } elsif ($olds == $fac) {
                $setupOK = 'longshort';
                $stopBuyL = $fac;            
            } else {
                $i = 1;
                while (1) {
                    @a = adx($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $hday{$dayindex{$day}-$i});
                    if ($a[0] > $fac2) {
                        $setupOK = '';
                        $stopBuyL = $fac2;  # the last limit value encountered            
                        last;
                    } elsif ($a[0] < $fac) {
                        $setupOK = 'longshort';
                        $stopBuyL = $fac;            
                        last;
                    }
                    $i++;
                }
            }
	    }
	}
	if ($suCond =~ /Volu(\d+)f(\d+.?\d*):(\d+.?\d*)/) {
	    # volume must be above average. Default value of fac should be 1.0
	    $peri1 = $1;    $fac = $2;  $fac2 = $3;
        $mean = sma($tick, \%hday, \%dayindex, \%volume, $peri1, $day);
        if ($mean > 0.0) {
            if ($volume{$day}/$mean < $fac || $volume{$day}/$mean > $fac2) {
                $setupOK = '';
            }
        } else {
            warn "average volume is zero. No setup filter applied!\n";
        }
	}
	if ($suCond =~ /Vol(\d+)TR(\d+):(\d+)/) {
	    # volatility-breakout; percentage move in % of the ATR, e.g,  Vol10TR50:200
	    $peri1 = $1;    $fac = $2;   $fac2 = $3;
        $a5 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
        $a50 = abs($closep{$day} - $closep{$yd}) * 100.0 / $a5;
        if ($a50 < $fac || $a50 > $fac2) {
            $setupOK = "";
        }
	}
	if ($suCond =~ /AllT(\d+)/) {
	    # last breakout was long|short...
        $peri1 = $1;
        $setupOK = $olds;   # per default no change
	    # this is valid for both long and short - no distinction
        $p = $closep{$day};
        if ($olds =~ /short/ || $olds eq '') {
            for ($i=1; $i<=$peri1; $i++) {
                push @p, $maxp{$hday{$dayindex{$day}-$i}};
            }
            $localm = max(@p);
            if ($p > $localm) {
                $setupOK = "long";
            }
        }
        if ($olds =~ /long/ || $olds eq '') {
            for ($i=1; $i<=$peri1; $i++) {
                push @p, $minp{$hday{$dayindex{$day}-$i}};
            }
            $localm = min(@p);
            if ($p < $localm) {
                $setupOK = "short";
            }
        }
	}
	if ($suCond =~ /AllT([nw])(\d+)f(\d+.?\d*)/) {
	    # breakout must be from a narrow [wide] base (max-min)_n/max < f [> f]
	    $what = $1; $peri1 = $2;    $fac = $3;
        @p = @closep{@hday{($dayindex{$day}-$peri1-1 .. $dayindex{$day}-1)}};
	    ($min,$max) = low_and_high(@p); #print "$max > $min and close = $closep{$day}..."; exit;
	    if ( ($max-$min)/$closep{$day} < $fac && $what eq 'n') {
	        $setupOK = 'longshort';
#	    } elsif ( ($max-$min)/$closep{$day} > $fac && $what eq 'w') {
	    } elsif ( ($max-$min)/$max > $fac && $what eq 'w') {
	        $setupOK = 'longshort';
	    } else {
	        $setupOK = "";
	    }
	}
	if ($suCond =~ /Candle/) {  # candle color
	    if ($closep{$day} > $openp{$day} && $setupOK =~ /long/) { # white candle
	        $setupOK = "long";
        } elsif ($closep{$day} < $openp{$day} && $setupOK =~ /short/) { #black candle
            $setupOK = "short";
        } else {
            $setupOK = "";  # no entry if we're unsure of the direction
        }
	}
	if ($suCond =~ /ATRS(\d+)f(\d+.?\d*)/) {    # ATR slope normalized by the ATR itself, ok if ATR is increasing
	    $peri1 = $1;    $fac = $2;
        $s1 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
        $s0 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $yd);
        $a5 = ($s1 - $s0)/$s0;
        if ($a5 > $fac) {
            1; # no change to the setup
        } else {
            $setupOK = ""; 
        }
	}
	if ($suCond =~ /KSO(\d+)([fl])(\d+.?\d*)/) {    # Kaufman's Strength Oscillator; slope-value is the absolute val, understood to be + (long) or - (short)
        # f: must be greater that this,  l: must be less than this (still in absolute numbers)
        $sper = $1; $greaterless = $2;  $fac = $3;
	    $s1 = kso($h_d, $h_i, $h_h, $h_l, $h_c, $sper, $day);
	    $s0 = kso($h_d, $h_i, $h_h, $h_l, $h_c, $sper, $yd);
	    if ($greaterless eq 'f' && $s1 - $s0 > $fac && $setupOK =~ /long/) {
            $setupOK = "long"; 
        } elsif ($greaterless eq 'f' && $s1 - $s0 < -$fac && $setupOK =~ /short/) {
            $setupOK = "short"; 
        } elsif ($greaterless eq 'l' && $s1 - $s0 < $fac && $s1 - $s0 > 0 && $setupOK =~ /long/) {
            $setupOK = "long"; 
        } elsif ($greaterless eq 'l' && $s1 - $s0 > -$fac && $setupOK =~ /short/) {
            $setupOK = "short"; 
        } else {
            $setupOK = "";
        }
	}
	if ($suCond =~ /KSO(\d+)V(\d+.?\d*)/) {    # Kaufman's Strength Oscillator; absolute val, understood to be + (long) or - (short)
        $sper = $1; $fac = $2;
	    $s1 = kso($h_d, $h_i, $h_h, $h_l, $h_c, $sper, $day);
	    if ($s1 > $fac && $setupOK =~ /long/) {
            $setupOK = "long"; 
        } elsif ($s1 < -$fac && $setupOK =~ /short/) {
            $setupOK = "short"; 
        } else {
            $setupOK = "";
        }
	}
    if ($suCond =~ /KSO(\d+)r(-*\d+\.\d*):(-*\d+\.\d*)/) { # KSO slope range of ok values
        $sper = $1; $fac = $2;  $fac2 = $3; 
        $s1 = kso($h_d, $h_i, $h_h, $h_l, $h_c, $sper, $day);
        $s0 = kso($h_d, $h_i, $h_h, $h_l, $h_c, $sper, $yd);
        if ($s1 - $s0 > $fac && $s1 - $s0 < $fac2) {
            1; # ok...
        } else {
            $setupOK = "";
        }
    }  
    if ($suCond =~ /SMAprice(\d+)/) { # price above or below the SMA
        $sper = $1;
        $s0 = sma($tick, $h_d, $h_i, $h_c, $sper, $day);
        if ($closep > $s0 && $setupOK =~ /long/) {
            $setupOK = 'long';
        } elsif ($closep < $s0 && $setupOK =~ /short/) {
            $setupOK = 'short';
        }
    }
    if ($suCond =~ /SMA(\d+)([fxc])(\d+.?\d*)/) { # SMA slope up for long, down for short
        $sper = $1; $greaterless =$2; $fac = $3;
        if ($greaterless eq 'x') {
            $whichd = $yd;  $whichyd = $yyd;
        } else {
            $whichd = $day; $whichyd = $yd;
        }
        $s1 = sma($tick, $h_d, $h_i, $h_c, $sper, $whichd);
        $s0 = sma($tick, $h_d, $h_i, $h_c, $sper, $whichyd);
        if ($greaterless eq 'c') {  # counter-trend, so switch s1 and s0
            $s2 = $s0;
            $s0 = $s1;
            $s1 = $s2;
        }
        $rmsf = $sper**.5 * ($s1 - $s0)/$s1;
        if ($rmsf > $fac && $setupOK =~ /long/) {
            $setupOK = "long";
        } elsif ($rmsf < -$fac && $setupOK =~ /short/) {
            $setupOK = "short";
        } else {
            $setupOK = ""; #print "n2 "
        }
    }
    if ($suCond =~ /SMA(\d+)r(-*\d+\.\d*):(-*\d+\.\d*)/) { # SMA slope up for long, down for short and abs(slope) > ATR14/(sper/10)*factor
        $sper = $1; $fac = $2;  $fac2 = $3; 
        $s1 = sma($tick, $h_d, $h_i, $h_c, $sper, $day);
        $s0 = sma($tick, $h_d, $h_i, $h_c, $sper, $yd);
        $rmsf = $sper**.5 * ($s1 - $s0)/$s1;
        if ($rmsf > $fac && $rmsf < $fac2) {
            1; # ok...
        } else {
            $setupOK = "";
        }
    }    
    if ($suCond =~ /ATR(\d+)f(\d+.\d+)/) {  # TODO; make option to make value > limit OK
        $sper = $1; $aPar = $2;
        $a5 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $sper, $day);
        $a50 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $sper*10, $day);
        if ($a5/$a50 < $aPar) { 
            1;
        } else {
            $setupOK = ""; 
        }

    }
    if ($suCond =~ /([sl])sma(\d+)([gl])(\d+)/) {    # for [s]hort and [l]ong setups   #### TODO: check the logic!
        $aPar = $1; $perFast = $2;  $greaterless = $3; $perSlow = $4;
        $fast1 = sma($tick, $h_d, $h_i, $h_c, $perFast, $day);
        $slow1 = sma($tick, $h_d, $h_i, $h_c, $perSlow, $day); 
        if ( ($fast1 < $slow1 && $greaterless eq 'g') || ($fast1 > $slow1 && $greaterless eq 'l') ) {
            $donotenter = "short" if ($aPar eq 's');
            $donotenter = "long" if ($aPar eq 'l');
        }
    }
    if ($suCond =~ /RSI(\d+)(x*)/) {    # RSI overb/s, if 'x' only OK on a crossing
        $rPar = $1; $what = $2;
        $rsi9 = rsi($tick, $h_d, $h_i, $h_c, $rPar, $day);
        if ($rsi9 < 30) {
            $setupOK = 'long';
        } elsif ($rsi9 > 70) {
            $setupOK = 'short';
        } else {
            $setupOK = '';
        }
        ### TODO; implement the 'x'
    }
    
    return ($setupOK, $donotenter, $stopBuyL, $stopBuyS);
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

# ($dir, $swhigh, $swlow) = getSwing($atrper, $h_d, $h_i, $h_h, $h_l, $h_c, $day, $dir, $swhigh, $swlow, $swfiltfac);
#       set dir = 0 to get it to calculate a big chunk backwards. $atrper != 0 means to use the percentage with the ATR as filter
sub getSwing {
    #
    # determine direction of the swing (see Kaufman p.153-160)
    use strict;
    my ($atrper, $h_d, $h_i, $h_h, $h_l, $h_c, $day, $dir, $swhigh, $swlow, $swfiltfac) = @_;
    my $c = @_; die "only $c elements to getSwing(), should be 11 - $!\n" unless ($c == 11);
    my %closep = %$h_c;  my %maxp = %$h_h;  my %minp = %$h_l;
    my %hday = %$h_d;  my %dayindex = %$h_i;
    my ($i, $n, $swfilt, $iday, $a5, $a50, $af);
    
    if ($dir && $swhigh) {
        $n = 0;
    } else {
        $dir = 1;   # initial value
        $swlow = $minp{$day};
        $swhigh = $maxp{$day};
        $n = int(10 * $swfiltfac);  print "...initial testing: n = $n..."; # probably needs adjustment
    }
    if ($atrper) {
        $a5 = atr("", $h_d, $h_i, $h_h, $h_l, $h_c, $atrper, $day);
        $a50 = atr("", $h_d, $h_i, $h_h, $h_l, $h_c, 10*$atrper, $day);
        $af = $a5/$a50;
    } else {
        $af = 1.0;
    }

    for ($i = $n; $i >= 0; $i--) {
        $iday = $hday{$dayindex{$day}-$i};
        $swfilt = $swfiltfac * $af * $closep{$iday} / 100.0;
        if ($dir == 1) {    # current dir is up
            if ($maxp{$iday} > $swhigh) {
                $swhigh = $maxp{$iday};
            } elsif ( $swhigh-$minp{$iday} >= $swfilt ) {
                $dir = -1;
                $swlow = $minp{$iday};
            } else {
                1;  # do nothing - all is well
            }
        } elsif ($dir == -1) {  # current dir is down
            if ($minp{$iday} < $swlow) {
                $swlow = $minp{$iday};
            } elsif ( $maxp{$iday}-$swlow >= $swfilt ) {
                $dir = 1;
                $swhigh = $maxp{$iday};
            } else {
                1;  # do nothing - all is well
            }
        }
        #printf "$iday: dir = $dir, swhigh = %.2f, swlow = %.2f (HL = %.2f, %.2f)\n", $swhigh, $swlow, $maxp{$iday}, $minp{$iday};
    }
    
    return ($dir, $swhigh, $swlow);
}

# ($entrySig, $exitSig, $txt, $ptxt, $exitp) = getSignal($tick, $system, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, 
#                                                       $opentrade, $daysIn, $inprice, $istop, $priceNow, $setupOK);    
sub getSignal {
	# ($entrySig, $exitSig, $txt, $ptxt, $exitp) = getSignal($tick, $system, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, 
	#                                                       $opentrade, $daysIn, $inprice, $istop, $priceNow, $setupOK);   
	# $entrySig and $exitSig is either "long", "short", or "". Return value is "none" if strategy is not defined
	# $txt is a string 
	# containing useful output either for plots or for file dumping. $exitp is the exit price unless it's the close in which case it's 0.
	# $opentrade is "long" or "short", corresponding to the current open trade
	# $priceNow contains ($dir, $swhigh, $swlow) of yesterday if system is a Swing. Returns new values in $txt.
	# incomplete systems moved to subroutine sysInDev  in order to unclutter this
	# 
    use strict;
    my ($tick, $system, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, $opentrade, $daysIn, $inprice, $istop, $priceNow, $setupOK) = @_;
    my $c = @_; die "only $c elements to getSignal(), should be 15 - $!\n" unless ($c == 15);
    my ($entrySig, $exitSig) = ("", "");
    #my ($bpi, $bpisig, $macd) = marketStance($day);
    my ($macd, $rsi, $dum, $doji, @atr, @adx, @sto, @rsi9, @stos, $ok, $ud, $in, @in, $candle, $a, $siga, $b, $sigb, $rlim, $reenter);
    my (@xx, @yy, @my, @mx, @lf, $dir, @p, @py, @pyy, $min, $max, $i, $ok2, $altdir, $p, $tr, $peri1, $peri2, $frac, $xorc);
    my ($po, $ph, $pl, $pc, $when, $fac, $yo, $yh, $yl, $yc, $yyo, $yyh, $yyl, $yyc, $localm, $swdir, $swdir0, $swlow, $swhigh);
    my ($atr, $au, $ad, $tralt, $pp, $sm1, $sm2, $typ, $gap, $fac2, $swfac, @macd, @sline);
    my ($perFast, $perSlow, $smaFast, $smaSlow, $sline, $pfast, $pslow, $psig, $macd0, $sline0,$nmdarr);
    my $txt = ""; my $ptxt = ""; my $exitp = 0; 
	my $curR;
    my %openp = %$h_o;  my %closep = %$h_c;  my %maxp = %$h_h;  my %minp = %$h_l;
    my %hday = %$h_d;  my %dayindex = %$h_i;
	my $ydate = $hday{$dayindex{$day}-1};   my $yy2 = $hday{$dayindex{$day}-2};
    srand();

    # "systems" for testing; always long or short
    if ($system eq "long" || $system eq "short") {
        $entrySig = $system;
        $exitSig = "";
    }
    # system == HiLo; only with HiLo setup. Signal when series of highs/lows indicate a trend change or confirms trend direction
    #
    if ($system =~ /HiLo(Long|Short)/) {
        $dir = $1;  # TODO; a parameter that waits for a retracement before entering...
        # either 0 (no change), +2 (change to up), or -2 (change to down). reenter is 0 or +/-1.
        ($swhigh, $swlow, $reenter) = @$priceNow; #print "HiLo swing Hi = ",$swhigh," Lo = ",$swlow,"\n";
        if ($swhigh == 2 || $swlow == 2) {
            $entrySig = 'long' if ($dir eq 'Long');
        } elsif ($swhigh == -2 || $swlow == -2) {
            $entrySig = 'short' if ($dir eq 'Short');
        } elsif ($reenter == 1) {
            $entrySig = 'long' if ($dir eq 'Long');
        } elsif ($reenter == -1) {
            $entrySig = 'short' if ($dir eq 'Short');
        }        
    }
    # system == Swing; simple swing, signal when direction changes, S for exit by stop only, E for exit signal when swing changes
    #
    if ($system =~ /Swing([SE])(\d+.{1}\d+)/) {
        $typ = $1;
        $swfac = $2;
        if ($system =~ /Swing${typ}${swfac}A(\d+)/) {
            $a = $1;
        } else {
            $a = 0;
        }
        ($swdir0, $swhigh, $swlow) = @$priceNow; # params for yesterday
        # if there are no parameters, then we need to call with initialization:
        if ($swdir0 == 0) {
            ($swdir0, $swhigh, $swlow) = getSwing($a, $h_d, $h_i, $h_h, $h_l, $h_c, $ydate, 0, 0, 0, $swfac);
        }
        ($swdir, $swhigh, $swlow) = getSwing($a, $h_d, $h_i, $h_h, $h_l, $h_c, $day, $swdir0, $swhigh, $swlow, $swfac);
        if ($swdir - $swdir0 == 2) {    # went to 1 from -1; swing changes to up
            $entrySig = 'long';
            $exitSig = 'short' if ($typ eq 'E');
        } elsif ($swdir - $swdir0 == -2) {  # went to -1 from 1; swing changes to down
            $entrySig = 'short';
            $exitSig = 'long' if ($typ eq 'E');
        } #printf " %d ", $swdir-$swdir0;
        $txt = [$swdir, $swhigh, $swlow];
    }
    # system == SMA; enter when SMA changes direction
    #
    if ($system =~ /SMA(\d+)/) {    # to be used with HiLo or Swing supplied in the $priceNow variable.
        $peri1 = $1;
        ($p, $typ) = @$priceNow;
        if ($p) {
            print "SMA${peri1} = $p (ishigh = $typ)...";
            if ($typ == 1) { # ishigh = yes
                $entrySig = 'short';
            } else {
                $entrySig = 'long';
            }
#             $sm0 = sma($tick, $h_d, $h_i, $h_c, $peri1, $day);
#             $sm1 = sma($tick, $h_d, $h_i, $h_c, $peri1, $ydate);
#             $sm2 = sma($tick, $h_d, $h_i, $h_c, $peri1, $yy2);
#             $tr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
#             $a = $tr/$peri;
#             if ($sm1 > $sm2) {
#                 $entrySig = 'long';
#                 #$exitSig = 'short';
#             } elsif ($sm1 < $sm2) {
#                 $entrySig = 'short';
#                 #$exitSig = 'long';
#             }
        } else {
            $entrySig = '';
        }
    }
    # system == AllTime; surpassing "all-time" high or low at the close
    #
    if ($system =~ /AllTime([CXS]*)(\d+)([xc])(Long|Short)/) {
        $typ = $1;
        $peri1 = $2;
        $xorc = $3;
        $dir = $4;
        @p = ();
        if ($typ eq 'X') {  # buy at the close if price goes above localm during the day. A level of logic is needed in the calling routine
            $p = $maxp{$day} if $dir eq 'Long';  # TODO: || $setupOK eq 'Long', etc....
            $p = $minp{$day} if $dir eq 'Short';
        } elsif ($typ eq 'S') { # stop-buy when price goes above localm during the day. A level of logic is needed in the calling routine
            $p = $maxp{$day} if $dir eq 'Long';
            $p = $minp{$day} if $dir eq 'Short';
        } else {  # typ 'C' is default; buy on close if close > localm
            $p = $closep{$day};
        }
        if ($dir eq "Long") {
            if ($xorc eq 'x') {
                for ($i=1; $i<=$peri1; $i++) {
                    push @p, $maxp{$hday{$dayindex{$day}-$i}};  # using high prices for comparison
                }
            } elsif ($xorc eq 'c') {
                for ($i=1; $i<=$peri1; $i++) {
                    push @p, $closep{$hday{$dayindex{$day}-$i}};  # using close prices for comparison
                }            
            }
            $localm = max(@p);
            if ($p > $localm) {
                $entrySig = "long";
                if ($typ eq 'X' || $typ eq 'S') {
                    if ($localm < $openp{$day}) {   # assuming we're using a stop-buy without limit order
                        $exitp = $openp{$day};
                    } else {
                        $exitp = $localm;
                    }
                }
            }
        } elsif ($dir eq "Short") {
            if ($xorc eq 'x') {
                for ($i=1; $i<=$peri1; $i++) {
                    push @p, $minp{$hday{$dayindex{$day}-$i}};  # using low prices for comparison
                }
            } elsif ($xorc eq 'c') {
                for ($i=1; $i<=$peri1; $i++) {
                    push @p, $closep{$hday{$dayindex{$day}-$i}};  # using close prices for comparison
                }                        
            }
            $localm = min(@p);
            if ($p < $localm) {
                $entrySig = "short";
                if ($typ eq 'X' || $typ eq 'S') {
                    if ($localm > $openp{$day}) {   # assuming we're using a stop-buy without limit order
                        $exitp = $openp{$day};
                    } else {
                        $exitp = $localm;
                    }
                }
            }
        } else {
            die "Must be Short or Long in strategy AllTime, not $dir\n";
        }
        $txt = $localm; # the breakout level returned
        ($p, $pp) = low_and_high(@p);
        $ptxt = abs($p - $pp);  # the price range inside the N days 
    }
    ### experimental system: Spike
    #
    if ($system =~ /Spike/) {
	    @p = ($openp{$day}, $maxp{$day}, $minp{$day}, $closep{$day});
	    @py = ($openp{$ydate}, $maxp{$ydate}, $minp{$ydate}, $closep{$ydate});
	    @pyy = ($openp{$hday{$dayindex{$day}-2}}, $maxp{$hday{$dayindex{$day}-2}}, $minp{$hday{$dayindex{$day}-2}}, $closep{$hday{$dayindex{$day}-2}});
	    @my = (@p, @py, @pyy);
        ($min,$max) = low_and_high(@my);  # local, 3-day, min or max
        if ($max == $maxp{$day}) {
            $dir = 1;
        } elsif ($min == $minp{$day}) {
            $dir = -1;
        } else {
            $dir = 0;
        }
        if ($dir) {
            ($candle,$txt) = candleType(\@p, \@py, $dir); # @p contains prices in the order OHLC
            if ($candle =~ /Spike/) {
                @my = ($closep{$day}, $openp{$day});
                ($min,$max) = low_and_high(@my);
                if ($dir == 1) {
                    # direction was up, so we go short
                    $ptxt = ($maxp{$day} - $max)/($maxp{$day}-$minp{$day});  # consider which values to return...
                    $entrySig = 'short';
                } else {
                    $ptxt = ($min - $minp{$day})/($maxp{$day}-$minp{$day});
                    $entrySig = 'long';
                }
                $tr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, 14, $day);
                $txt = ($maxp{$day}-$minp{$day})/$tr;
            }
        }
    }
    # system == buy at the open - other conditions must be in setupOK
    #
    if ($system =~ /BuyOpen/) {
        $entrySig = "long" if $setupOK eq "long";
        $entrySig = "short" if $setupOK eq "short";
        $exitp = $openp{$day} if ($entrySig);
    }
    # system == InsideDay; enter on the open if ydate was an inside day and todays open gaps away
    #
        ### TODO:  look at the last N days; did we ehave a series of lower/higher closes which could mean a move+reaction?
    if ($system =~ /InsideDay([gG])/) {
        $typ = $1;
        if ($maxp{$ydate} < $maxp{$yy2} && $minp{$ydate} > $minp{$yy2}) {   # inside day yesterday...
            if ($typ eq 'G') {  # big gap away from full candle
                if ($openp{$day} > $maxp{$ydate}) {
                    $exitp = $openp{$day};
                    $entrySig = 'long';
                } elsif ($openp{$day} < $minp{$ydate}) {
                    $exitp = $openp{$day};
                    $entrySig = 'short';            
                }
            } elsif ($typ eq 'g') { # gaps away from real body only
                if ($openp{$day} > $openp{$ydate} && $openp{$day} > $closep{$ydate}) {
                    $exitp = $openp{$day};
                    $entrySig = 'long';
                } elsif ($openp{$day} < $openp{$ydate} && $openp{$day} < $closep{$ydate}) {
                    $exitp = $openp{$day};
                    $entrySig = 'short';            
                }            
            }
            # $exitSig = $entrySig;  ### removed; use Exit0 to force exit at EOD.
        } else {
            $entrySig = '';
        }
    }
    # system == LUXOR SMA crossover with delayed entry
    #
    if ($system =~ /LUXcross(\d+)x(\d+)/) {
        $peri1 = $1; $peri2 = $2;
        @p = ($openp{$day}, $maxp{$day}, $minp{$day}, $closep{$day});
        # entry if close is above (below) the stop-buy and it did not gap away
        if ($priceNow < $maxp{$day} && $priceNow > $minp{$day}) {
            $entrySig = "long" if $setupOK eq "long";
            $entrySig = "short" if $setupOK eq "short";
            $exitp = $priceNow;
        }
        # exit signal on the close (for now) is when the SMA cross in the opposite direction
        ($ok2, $ok, $a, $b) = getSetupCondition($tick, $system, $h_d, $h_i, $h_o, $h_h, $h_l, $h_c, $day, "");
        if ($ok2 eq "long") {
            $exitSig = "short";
            $exitp = 0; # meaning on the close
        } elsif ($ok2 eq "short") {
            $exitSig = "long";
            $exitp = 0; # meaning on the close
        }
    }
    # system == Simple cross-over of two SMA's, designed to use a wide stop and exit when close price crosses back over SLOW
    #
    if ($system =~ /Simcross(\d+)x(\d+)/) {
        $perFast = $1; $perSlow = $2;
        $smaFast = sma($tick, $h_d, $h_i, $h_c, $perFast, $day);
        $smaSlow = sma($tick, $h_d, $h_i, $h_c, $perSlow, $day);
        # entry and re-entry signals; candle must be right color. 
        # and calling program will check if it's first entry or a re-entry
        unless ($opentrade) {    ### more conservative; high/low must not be on the wrong side of SLOW
            if ($closep{$day} > $openp{$day} && $smaFast > $smaSlow) {
                $entrySig = 'long';
                if ($minp{$day} < min($minp{$ydate}, $minp{$yy2})) {    # cancel long entry if today made a new low
                    $entrySig = '';                                     # TODO; consider cancel if close was lower today
                }
            } elsif ($closep{$day} < $openp{$day} && $smaFast < $smaSlow) {
                $entrySig = 'short';
                if ($maxp{$day} > max($maxp{$ydate}, $maxp{$yy2})) {    # cancel short entry if today made a new high
                    $entrySig = '';
                }
            } else {
                $entrySig = '';
            }
        }
        # exit signal
        if ($opentrade) { 
            if ( ( ($closep{$day} < $smaSlow || $smaSlow > $smaFast) && $opentrade eq 'long') ||
                 ( ($closep{$day} > $smaSlow || $smaSlow < $smaFast) && $opentrade eq 'short') ) {
                $exitSig = $opentrade;
            } else {
                $exitSig = "";
            }
        }
        $txt = [$smaFast, $smaSlow];
    }
    # system == Always
    #
    if ($system eq 'Always') {
        $entrySig = "long" unless $opentrade;
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
    # system == MACD crossing of signal line, or changing directions
    #
    if ($system =~ /^MACD(\d+)x(\d+)s(\d+)/) {  # crossing (x) of signal (s); no reentry
        $pfast = $1;    $pslow = $2;    $psig = $3;
        ($macd, $sline) = macd($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $pfast, $pslow, $psig, $day);
        ($macd0, $sline0) = macd($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $pfast, $pslow, $psig, $ydate);
        if ($macd > $sline && $macd0 < $sline0) {
            $entrySig = 'long';
        } elsif ($macd < $sline && $macd0 > $sline0) {
            $entrySig = 'short';
        } else {
            $entrySig = '';
        }
    } elsif ($system =~ /^MACD(\d+)d(\d+)t(\d+)/) { # direction (d) changes in direction of trend (t) of macd-signal; re-entry automatic
        $pfast = $1;    $pslow = $2;    $psig = $3;
        $nmdarr = 5;    # last N (was 10) values of MACD
        ($macd, $sline) = macdArr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $pfast, $pslow, $psig, $day, $nmdarr);
        @macd = @$macd; @sline = @$sline;
        # experiment: signal line must be in overall up(down) trend and be moving up(down) from yesterday
        ($a, $siga, $b, $sigb) = linfit( [1..$nmdarr], $sline);  # $b is slope
        ($macd, $sline) = ($macd[-1], $sline[-1]);      # today
        ($macd0, $sline0) = ($macd[-2], $sline[-2]);    # yesterday
#        if ( $macd-$sline >= $macd0-$sline0 ) {     # histogram moving up; setup for a long position
        if ( $macd-$sline >= $macd0-$sline0 && $sline > $sline0 && $b > 0 ) {     # histogram moving up; setup for a long position ## experimental
            $fac = sigmaptpt(@macd);
            if ( $macd > $macd0 && $macd-$macd0 > $fac ) {
                $entrySig = 'long';
            }
        } elsif ( $macd-$sline < $macd0-$sline0 && $sline < $sline0 && $b < 0 ) { # histogram moving down; setup for a short position
            $fac = sigmaptpt(@macd);
            if ( $macd < $macd0 && $macd0-$macd > $fac ) {
                $entrySig = 'short';
            }        
        }
    } elsif ($system =~ /^MACD/) {  # a catch-all
        die "No such system $system\n";
    }
    # system == Daybreak; breaking the high/low of the last candle
    #           Extensions (e.g. N days of white or black candles) are controlled via $setupOK.
    if ($system =~ /DaybreakG(\d+)/) {
        $gap = $1;
        # controls how to handle a price gap - se folder 'sys:Daybreak' for drawings
        # if there is a gap and we're looking for a long position, i.e. open > priceNow:
        #       1:  buy if priceNow is within daily range --- i.e. a stop-buy with limit order
        #       2:  forget it, no trade --- i.e. waiting till after market open with entering order and rejecting if it gaps
        #       3:  buy it at the open, exitp = openp --- i.e. monitoring the market after opening and adjusting the stop to conform to risk
        if ($maxp{$day} > $maxp{$ydate} && $setupOK =~ /long/) {
            if ($openp{$day} > $maxp{$ydate}) {     # gapping...
                if ($gap == 2) {
                    $entrySig = "";
                } elsif ($gap == 3) {
                    $entrySig = "long";
                    $exitp = $openp{$day};
                } elsif ($gap == 1 && $minp{$day} < $maxp{$ydate}) {
                    $entrySig = "long";
                    $exitp = $maxp{$ydate};
                }
            } else {
                $entrySig = "long";
                $exitp = $maxp{$ydate};
            }
        } elsif ($minp{$day} < $minp{$ydate} && $setupOK =~ /short/) {
            if ($openp{$day} < $minp{$ydate}) {
                if ($gap == 2) {
                    $entrySig = "";
                } elsif ($gap == 3) {
                    $entrySig = "short";
                    $exitp = $openp{$day};
                } elsif ($gap == 1 && $maxp{$day} > $minp{$ydate}) {
                    $entrySig = "short";
                    $exitp = $minp{$ydate};
                }
            } else {
                $entrySig = "short";
                $exitp = $minp{$ydate};
            }
        } else {
            $entrySig = "";
        }
    }
    # system == RSI; overbought/sold conditions followed by a crossing below/above 70/30
    #   examples:  "RSI14" combined with setup "RSI14P5"; 14-period RSI at least 5 periods in over... before crossing
    #               The setup condition is to be controlled via $setupOK
    if ($system =~ /^RSI(\d+)/) {
    
    }
    # system == VolEOD; volatility breakout based on close/high/low price with eod-entry
    #   examples: "VolEOD90X5M180" (extreme price based 5-day ATR, not above 180% move), "VolEOD85C10M0" (closing price, no limit on size of move)
    if ($system =~ /^VolEOD(\d+)([CX])(\d+)M(\d+)/) {
        $fac = $1/100.0;
        $when = $2;
        $peri1 = $3;
        $fac2 = $4/100.0;
        if ($fac2 == 0) {
            $fac2 = 20.0;   # i.e. in practice no limit
        }
        ($po, $ph, $pl, $pc) = ($openp{$day}, $maxp{$day}, $minp{$day}, $closep{$day});  # todays prices
        $yc = $closep{$ydate};  # yesterdays close price
        $tr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
        if ($when eq 'C') {
            if ( ($pc-$yc) > $fac*$tr && ($pc-$yc) < $fac2*$tr) {
                $entrySig = "long" unless $system =~ /Short/;
            } elsif ( ($yc-$pc) > $fac*$tr && ($yc-$pc) < $fac2*$tr) {
                $entrySig = "short" unless $system =~ /Long/;
            }
        } elsif ($when eq 'X') {
            # if both limits up/down are hit, then it's a confused day and we do not enter
            if ( ($ph-$yc) > $fac*$tr && ($yc-$pl) > $fac*$tr ) {
                $entrySig = "";
            } elsif ( ($ph-$yc) > $fac*$tr && ($pc-$yc) < $fac2*$tr) {
                $entrySig = "long" unless $system =~ /Short/;
            } elsif ( ($yc-$pl) > $fac*$tr && ($yc-$pc) < $fac2*$tr) {
                $entrySig = "short" unless $system =~ /Long/;
            }
        } else {
            die "ERROR: found type = $when.\n";
        }
    }
    # system == VolB; volatility breakout intraday, i.e. stop-buy as soon as the limit has been reached
    #   examples: "VolBO60", "VolBC105", "VolBO40A14", "VolBC90A5R50l60"
    #               based on opening price
    #                           based on yesterday close
    #                                       use ATR14 instead of TR
    #                                                   use ATR5, only when <ATR5>/<ATR50> < 0.60
    if ($system =~ /^VolB(\w{1})(\d+)/) {
        # calc the TR of yesterday. If price today goes beyond yc|po +/- fac % of TR, then enter at that price.
        # in real life, two stop-buy orders would be entered at the close|open of the day, each with a stop-loss at the other price
        $when = $1;
        $fac = $2/100.0;
        $ok = 1;
        ($po, $ph, $pl, $pc) = ($openp{$day}, $maxp{$day}, $minp{$day}, $closep{$day});  # todays prices
        ($yo, $yh, $yl, $yc) = ($openp{$ydate}, $maxp{$ydate}, $minp{$ydate}, $closep{$ydate});  # yesterdays prices
        $dum = $hday{$dayindex{$day}-2};
        ($yyo, $yyh, $yyl, $yyc) = ($openp{$dum}, $maxp{$dum}, $minp{$dum}, $closep{$dum});  # day before yesterdays prices
        if ($system =~ /VolB[CO]\d+A(\d+)R(\d+)l(\d+)/) {
            $peri1 = $1; $peri2 = $2; $frac = $3/100.0;
            $ok = 0;
            $tr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $ydate);
            $atr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri2, $ydate);
            # testing influence of current slope...
            ($a, $siga, $b, $sigb) = getSlope($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $day);
            if ($tr/$atr < $frac) {
                $ok = 1;
                printf "ATR-ratio = %.2f ... slope = %.3f +/- %.3f ", $tr/$atr, $b, $sigb;
                $ptxt = sprintf "ATR-ratio = %.2f, slope = %.3f +/- %.3f", $tr/$atr, $b, $sigb;
            }
        } elsif ($system =~ /VolB[CO]\d+([AT])(\d+)/) {
            my $trtest = $1;   $peri1 = $2;
            $tr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri1, $ydate); #print "ATR${peri1} = $tr "; exit;
            # experimental:  take the larger of the ranges, either ATR or TR...
            if ($trtest eq "T") {
                $tralt = max( ($yh-$yl, $yh-$yyc, $yyc-$yl) );
                if ($tralt > $tr) {
                    $tr = $tralt;
                }
            }
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
#        printf " entry level = %.3f (range = $pl to $ph) ", $p-$fac*$tr;
        if ($ok) {
            if ( $ph > $p+$fac*$tr && $pl < $p-$fac*$tr && ($system !~ /Long/ && $system !~ /Short/) ) { # both limits hit on the same day!
                # assuming one position 'survives'. Conservative could assume both will get stopped out for a net -2R loss.
                if ($pc > $po) {  # upday; assume we entered short early and got stopped out, then entered a long
                    $entrySig = "long";
                    $exitp = $p+$fac*$tr;
                    $txt = sprintf "%.4f_%.4f_%.4f_short%.4f", $p+$fac*$tr,$tr,$fac,$p-$fac*$tr;
                } else {
                    $entrySig = "short";
                    $exitp = $p-$fac*$tr;
                    $txt = sprintf "%.4f_%.4f_%.4f_long%.4f", $p-$fac*$tr,$tr,$fac,$p+$fac*$tr;
                }
                print " Both limits hit! ";
            } elsif ( $ph > $p+$fac*$tr && $pl < $p+$fac*$tr) { # requires crossing the limit, i.e. not entering if it gaps away
                $entrySig = "long";
                $exitp = $p+$fac*$tr;
                $txt = $p+$fac*$tr . "_" . $tr . "_" . $fac;
            } elsif ( $pl < $p-$fac*$tr && $ph > $p-$fac*$tr) { # requires crossing the limit, i.e. not entering if it gaps away
                $entrySig = "short";
                $exitp = $p-$fac*$tr;
                $txt = $p-$fac*$tr . "_" .$tr . "_" . $fac;
            } else {
                $entrySig = "";
                $txt = "";
            }
        } else {
            $entrySig = "";
            $txt = "";
        }
    }
    # system == Candle; Reversal candles
    #
    # TODO: if yesterday was a star and today is confirming, then entry...
    if ($system =~ /^Candle(\d*)x*(\d*)/) {
        # find the direction of the market over the past 3-4 days, using CLOSE prices
        # TODO: proper time interval. plus... should we rather use high/low? or just rely on a SMA or SMA-pair?
        $peri1 = $1; $peri2 = $2;
        if ($peri1 && $peri2) {
            # use teh SMA pair to determine direction
            $sm1 = sma($tick, $h_d, $h_i, $h_c, $peri1, $day);
            $sm2 = sma($tick, $h_d, $h_i, $h_c, $peri2, $day);
            if ($sm1 > $sm2) {
                $dir = 1;
            } else {
                $dir = -1;
            }
            $altdir = $dir;
        } else {
            my $trendper = 4;  # previous $trendper days used
            ($a, $siga, $b, $sigb) = getSlope($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $trendper, $day);
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
        }
        #printf " slope +/- rms = %.3f +/- %.3f\n", $b, $sigb;
        # identify the candle of today, comparing the daily range with ATR(20), except for the doji's, return range/ATR for monitoring
        # bullish hammer, spikes, stars, doji
        #
	    @p = ($openp{$day}, $maxp{$day}, $minp{$day}, $closep{$day});
	    @py = ($openp{$ydate}, $maxp{$ydate}, $minp{$ydate}, $closep{$ydate});
	    @pyy = ($openp{$hday{$dayindex{$day}-2}}, $maxp{$hday{$dayindex{$day}-2}}, $minp{$hday{$dayindex{$day}-2}}, $closep{$hday{$dayindex{$day}-2}});
	    @my = (@p, @py, @pyy);
        ($min,$max) = low_and_high(@my);  # local, 3-day, min or max
        ($candle,$txt) = candleType(\@p, \@py, $dir); # @p contains prices in the order OHLC
        unless ($candle || $dir == $altdir) {
            ($candle,$txt) = candleType(\@p, \@py, $altdir); # if direction is uncertain and the first one did not return anything...
            $dir = $altdir;  # no candle for the other direction, but maybe for this...
            $altdir = 0;
        }
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
        } elsif ($candle =~ /HangingMan/) {
            $txt = "HM:" . $txt;
            $entrySig = "short" if ($dir > 0 && $p[1] == $max);
        } else {
            $entrySig = "";
        }
        $txt = $doji . $txt; # . sprintf "ADX=%.2f, sl=%.2f", $adx, $adxs;
# now check if ADX is well-behaved according to this signal... (not active!)
#         if ($entrySig) {
#             #printf "$entrySig signal. ADX = %.2f, slope = %.2f\n", $adx, $adxs;
#             #$entrySig = "";
#         }
    }
    
    # Hard<R>; hard target - exit at the given <R> at the **close** - to exit intraday, use Targ
    #
    if ($system =~ /Hard(\d+.?\d*)/ && $opentrade) {
        $rlim = $1;
        $curR = ($priceNow - $inprice)/($inprice - $istop);
        if ($curR > $rlim) {
            $exitSig = $opentrade;
            $exitp = $curR * ($inprice - $istop) + $inprice;
        }
    }
    
    # Targ<R>; fixed target R; exit intraday when price exceeds this mark
    if ($system =~ /Targ(\d+.?\d*)/ && $opentrade) {
        $rlim = $1;
        if ($opentrade eq "long") {
            $pp = $maxp{$day};
        } else {
            $pp = $minp{$day};
        }
        $curR = ($pp - $inprice)/($inprice - $istop);
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
    #                   or to avoid overnight positions by giving Exit0
    if ($system =~ /Exit(\d+)/) {
        if ($daysIn >= $1 && $opentrade) {
            $exitSig = $opentrade;
        } elsif ($daysIn >= 0 && $entrySig) {
            $exitSig = $entrySig;
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

# ($a, $siga, $b, $sigb) = getSlope($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $period, $today);
sub getSlope {
    use strict;
    my $c = @_; die "only $c elements to getSlope(), should be 8\n" unless ($c == 8);
    my ($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $trendper, $day) = @_;
    my %closep = %$h_c;  my %maxp = %$h_h;  my %minp = %$h_l;
    my %hday = %$h_d;  my %dayindex = %$h_i;
    my (@mx, @p);  my @my = ();
    my ($dum, $i, $a, $siga, $b, $sigb, @xx, @yy);
    for ($i=1; $i <= $trendper; $i++) {  # not using current day in determining the direction
        unshift @my, "$maxp{$hday{$dayindex{$day}-$i}} $minp{$hday{$dayindex{$day}-$i}} $closep{$hday{$dayindex{$day}-$i}}";
    }
    @mx = (1 .. $trendper); @xx = (); @yy = (); 
    for ($i=0; $i < $trendper; $i++) {
        @p = split /\s+/, $my[$i]; #print "$my[$i]\n";
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
	my ($whichway, $price, $stop, $risk) = @_;  print "sub: $whichway, $price, $stop, $risk ";
	my ($psize, $pprice);
	
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

# @price = getPriceAfterDays($tick, \%hday, \%dayindex, \%closep, $day, \@days)
sub getPriceAfterDays {
	# @price = getPriceAfterDays($tick, \%hday, \%dayindex, \%closep, $day, \@days)
	# returns an array with the close price for @days after $day.
	use strict;
	my ($tick, $h_d, $h_i, $h_c, $day, $arr) = @_;
    my $c = @_; die "only $c elements to getPriceAfterDays(), should be 6\n" unless ($c == 6);
    my %hday = %$h_d;  my %dayindex = %$h_i;
	my @days = @$arr; 
	my %closep = %$h_c;
	my @price = ();
	my ($i, $in, $count, $num);
	foreach $in (@days) {
	    push @price, $closep{$hday{$dayindex{$day}+$in}}
	}
	return @price;
}

# @price = getOHLCAfterDays($tick, $h_d, $h_i, \%ohlc, $day, \@days)
sub getOHLCAfterDays {
	# @price = getOHLCAfterDays($tick, $h_d, $h_i, \%ohlc, $day, \@days)
	# returns an array with the close price for @days after $day.
	use strict;
	my ($tick, $h_d, $h_i, $ohlc, $day, $arr) = @_;
    my $c = @_; die "only $c elements to getOHLCAfterDays(), should be 6\n" unless ($c == 6);
    my %hday = %$h_d;  my %dayindex = %$h_i;
	my @days = @$arr; 
	my %whatp = %$ohlc;
    my @price = ();
	my ($i, $in, $count, $num);
	
	foreach $in (@days) {
	    push @price, $whatp{$hday{$dayindex{$day}+$in}}
	}
	return @price;
}

#	($mae, $mpe) = getMAE($tick, $h_d, $h_i, $h_h, $h_l, $inprice, $istop, $daysintrade, $day);
sub getMAE {
    my ($tick, $h_d, $h_i, $h_h, $h_l, $inprice, $istop, $daysintrade, $day) = @_;
    my $c = @_; die "only $c elements to .....(), should be 9\n" unless ($c == 9);
    my ($d1, $rmax, $rmin, $mae, $mpe);
    my @tdays = (0 .. $daysintrade);  #print "Trade on $day, from day 0 to $daysintrade .::. ";
	my @prH = getOHLCAfterDays($tick, $h_d, $h_i, $h_h, $day, \@tdays);
	my @prL = getOHLCAfterDays($tick, $h_d, $h_i, $h_l, $day, \@tdays);
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
    if ($day gt "2012-10-26") {
        $macdH = -1;
    } elsif ($day gt "2012-08-03") {
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
    if ($day gt "2012-12-20") {
        $bpi = "X";
    } elsif ($day gt "2012-11-12") {
        $bpi = "O";
    } elsif ($day gt "2012-07-03") {
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


#  $mystamp = getStamp();
#
sub getStamp {
    use strict;
    my $stamp;
    chomp( $stamp = `date "+%Y%m%dT%H%M%S"` );
    return $stamp;
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
    return ($candle, $txt) if ($ph == $pl);
    # bullish key reversal/spike
    # bearish key reversal/spike
    if ($uw/($ph-$pl) > 0.5 && $minb > $maxby) {
        $candle = 'BearSpike';
    } elsif ($lw/($ph-$pl) > 0.5 && $maxb < $minby) {
        $candle = 'BullSpike';
    }
    if ($candle) {
        return ($candle, $txt);
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
        $txt .= sprintf "r0/r1=%.2f",($pc-$po)/($yo-$yc);
        $candle = "BullishEngulfing";
    }
    # bearish engulfing:
    elsif ( $cdir < 0 && ($yo - $yc < 0) && $pc < $yo && $po > $yc && $dir > 0) {
        $txt .= sprintf "r0/r1=%.2f",($pc-$po)/($yc-$yo);  # negative by def.
        $candle = "BearishEngulfing";
    }
    # dark cloud cover
    elsif ( $cdir < 0 && ($yo - $yc < 0) && ($yc-$pc)*100.0/($yc-$yo) > 50.0 && $po > $yc && $dir > 0) {
        $txt .= sprintf "overlap=%.1f",($yc-$pc)*100.0/($yc-$yo); # must be > 50%
        $candle = "DarkCloudCover";
    }
    # piercing pattern
    elsif ( $cdir > 0 && ($yo - $yc > 0) && ($pc-$yc)*100.0/($yo-$yc) > 70.0 && $po < $yc && $dir < 0) {
        $txt .= sprintf "overlap=%.1f",($pc-$yc)*100.0/($yo-$yc); # must be > 70%
        $candle = "PiercingPattern";
    }
    # bullish hammer
    elsif ( $dir < 0 && $lw > 2.0*$body && $uw < $body ) {
        $txt .= sprintf "r=%.2f", $ph-$pl;
        $candle = "BullishHammer";
    }
    # bearish hanging man
    elsif ( $dir > 0 && $lw > 2.5*$body && $uw < $body ) {
        $txt .= sprintf "lw/body=%.1f", $lw/$body;
        $candle = "HangingMan";
    }
    # bearish shooting star
    elsif ( $dir > 0 && $uw > 2.0*$body && $lw < 0.3*$body && ($yo - $yc < 0) && $minb > $maxby && 2 * $body < abs($yo-$yc) ) {
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

# $atr = atr($tick, $dbfile, $peri, $date) -- TODO; fix it...
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

sub macdArr {
    # returns array pointers with the last $ndays MACD data, ending at $day
    use strict;
    my ($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $periFast, $periSlow, $periSmooth, $day, $ndays) = @_;    
    my $c = @_; die "only $c elements to macdArr(), should be 11\n" unless ($c == 11);
    my %hday = %$h_d;  
    my %closep = %$h_c;  
    my %maxp = %$h_h;  
    my %minp = %$h_l;
    my %dayindex = %$h_i;
    my ($macd, $msig, $i, $eFast, $eSlow);
    my @macd = ();  my @msig = ();
    
    my $ef0 = $closep{$hday{$dayindex{$day}-$periSlow*2}};
    my $es0 = $closep{$hday{$dayindex{$day}-$periSlow*2}};
    my $ma0 = 0.0;
    
    if ($ndays > $periSlow*2-1) {
        $ndays = $periSlow*2-1;
    }
    for ($i = $periSlow*2-1; $i >= 0 ; $i--) {
        $eFast = $ef0 + (2/($periFast+1)) * ($closep{$hday{$dayindex{$day}-$i}} - $ef0);
        $eSlow = $es0 + (2/($periSlow+1)) * ($closep{$hday{$dayindex{$day}-$i}} - $es0);
        $macd = $eFast-$eSlow;
        $msig = $ma0 + (2/($periSmooth+1)) * ($macd - $ma0);
        if ($i < $ndays) {
            push @macd, $macd;
            push @msig, $msig;
        }
        $ma0 = $msig;
        $ef0 = $eFast;
        $es0 = $eSlow;
    }

    return (\@macd, \@msig);
}

sub macd {
    # returns current value of MACD
    use strict;
    my ($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $periFast, $periSlow, $periSmooth, $day) = @_;    
    my $c = @_; die "only $c elements to macd(), should be 10\n" unless ($c == 10);
    my %hday = %$h_d;  
    my %closep = %$h_c;  
    my %maxp = %$h_h;  
    my %minp = %$h_l;
    my %dayindex = %$h_i;
    my ($macd, $msig, $i, $eFast, $eSlow);
    
    my $ef0 = $closep{$hday{$dayindex{$day}-$periSlow*2}};
    my $es0 = $closep{$hday{$dayindex{$day}-$periSlow*2}};
    my $ma0 = 0.0;
    
    for ($i = $periSlow*2-1; $i >= 0 ; $i--) {
        $eFast = $ef0 + (2/($periFast+1)) * ($closep{$hday{$dayindex{$day}-$i}} - $ef0);
        $eSlow = $es0 + (2/($periSlow+1)) * ($closep{$hday{$dayindex{$day}-$i}} - $es0);
        $macd = $eFast-$eSlow;
        $msig = $ma0 + (2/($periSmooth+1)) * ($macd - $ma0);
        $ma0 = $msig;
        $ef0 = $eFast;
        $es0 = $eSlow;
    }

    return ($macd, $msig);
}

#sub atrRaw {
sub atr {
    # $atr = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri, $date)
    use strict;
    my ($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri, $end) = @_;    
    my $c = @_; die "only $c elements to atr(), should be 8\n" unless ($c == 8);
    my %hday = %$h_d;  
    my %closep = %$h_c;  
    my %maxp = %$h_h;  
    my %minp = %$h_l;
    my %dayindex = %$h_i;
    my ($m, $i); my @ph = (); my @pl = (); my @pc = ();
    my $qperi = $peri + 1;
    for ($i = 0; $i < $qperi; $i++) {
        push @ph, $maxp{$hday{$dayindex{$end}-$i}};
        push @pl, $minp{$hday{$dayindex{$end}-$i}};
        push @pc, $closep{$hday{$dayindex{$end}-$i}};
    }
    my $atr = 0.0;
    for ($i = 0; $i < $peri; $i++) {  
        $m = max( ($ph[$i]-$pl[$i], $ph[$i]-$pc[$i+1], $pc[$i+1]-$pl[$i]) );
        $atr += $m;
    }
    $atr /= $peri;
    return $atr;
}

sub atrArray {
    # returns a full array of ATR values
    # @atr = atr($h_h, $h_l, $h_c, $peri)
    use strict;
    my ($h_h, $h_l, $h_c, $peri) = @_;    
    my $c = @_; die "only $c elements to atrArray(), should be 4\n" unless ($c == 4);
    my %closep = %$h_c;  
    my %maxp = %$h_h;  
    my %minp = %$h_l;
    my @d = sort keys %closep;
    my $n = @d;
    my @atr = ();
    my ($m,$mpop,$i,$atr);
    
    $atr[0] = abs($maxp{$d[0]}-$minp{$d[0]});
    # first $peri days will be just the TR, gradually becoming the ATR
    $atr = $atr[0];
    for ($i = 1; $i < $peri; $i++) {
        $m = max( ($maxp{$d[$i]}-$minp{$d[$i]}, $maxp{$d[$i]}-$closep{$d[$i-1]}, $closep{$d[$i-1]}-$minp{$d[$i]} ) );
        $atr += $m;
        $atr[$i] = $atr/($i+1);
    }
    # one more special case...
    $m = max( ($maxp{$d[$peri]}-$minp{$d[$peri]}, $maxp{$d[$peri]}-$closep{$d[$peri-1]}, $closep{$d[$peri-1]}-$minp{$d[$peri]} ) );
    $atr += $m;
    $atr -= $atr[0];
    $atr[$peri] = $atr/$peri;
    # ... and teh rest runs smoothly
    for ($i = $peri+1; $i < $n; $i++) {
        $m = max( ($maxp{$d[$i]}-$minp{$d[$i]}, $maxp{$d[$i]}-$closep{$d[$i-1]}, $closep{$d[$i-1]}-$minp{$d[$i]} ) );
        $atr += $m;
        $mpop = max( ($maxp{$d[$i-$peri]}-$minp{$d[$i-$peri]}, $maxp{$d[$i-$peri]}-$closep{$d[$i-$peri-1]}, $closep{$d[$i-$peri-1]}-$minp{$d[$i-$peri]} ) );
        $atr -= $mpop;
        $atr[$i] = $atr/$peri;
    }
    return @atr;
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
    
    @days = `sqlite3 "$dbfile" "SELECT date \\
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

# $sma = sma($tick, $h_d, $h_i, $h_c, $per, $day);
sub sma {
    use strict;
    my ($tick, $h_d, $h_i, $h_c, $per, $day) = @_;
    my $c = @_; die "only $c elements to sma(), should be 6\n" unless ($c == 6);
    my %closep = %$h_c;
    my %hday = %$h_d;  my %dayindex = %$h_i;
    my @pc = ();
    my $i;
    for ($i = 0; $i < $per; $i++) {
        push @pc, $closep{$hday{$dayindex{$day}-$i}};
    }
    my $ma = sum( @pc )/$per;
    return $ma;
}

# $ema = ema($tick, $h_d, $h_i, $h_c, $per, $day);
sub ema {
    use strict;
    my ($tick, $h_d, $h_i, $h_c, $per, $day) = @_;
    my $c = @_; die "only $c elements to ema(), should be 6\n" unless ($c == 6);
    my %closep = %$h_c;
    my %hday = %$h_d;  my %dayindex = %$h_i;
    my @pc = ();
    my ($i, $ma0, $ma);
    my $a = 2.0/($per + 1);   # EMA smoothing constant
    for ($i = 0; $i < 2*$per; $i++) {   # lookback 2 x the period
        die "error in date range for EMA!\n" unless exists $closep{$hday{$dayindex{$day}-$i}};
        unshift @pc, $closep{$hday{$dayindex{$day}-$i}};
    }
    $ma0 = $pc[0];
    for ($i = 1; $i < 2*$per; $i++) {
        $ma = $ma0 + $a * ($pc[$i] - $ma0);
        $ma0 = $ma;
    }
    return $ma;
}

sub smaArray {
    use strict;
    my ($h_c, $per) = @_;
    my $c = @_; die "only $c elements to emaArray(), should be 2\n" unless ($c == 2);
    my %closep = %$h_c;
    my @d = sort keys %closep;
    my $n = @d;
    my ($i, $ma0);
    my @sma = (); 
    return unless $n > $per;
    $ma0 = 0.0; # print "last date: $d[$n-1]\n";
    for ($i = 0; $i < $per; $i++) {
        $ma0 += $closep{$d[$i]};
        $sma[$i] = 0.0;
    }
    $sma[$per-1] = $ma0/$per;
    for ($i = $per; $i < $n; $i++) {
        $sma[$i] = $sma[$i-1] + ($closep{$d[$i]} - $closep{$d[$i-$per]})/(1.0*$per);
    }
    return @sma;
}

sub emaArray {
    use strict;
    my ($h_c, $per) = @_;
    my $c = @_; die "only $c elements to emaArray(), should be 2\n" unless ($c == 2);
    my %closep = %$h_c;
    my @d = sort keys %closep;
    my $n = @d;
    my ($i, $ma0, $ma);
    my @ema = ();
    my $a = 2.0/($per + 1);   # EMA smoothing constant
    $ema[0] = $closep{$d[0]};   # initializing the EMA
    for ($i = 1; $i < $n; $i++) {
        $ema[$i] = $closep{$d[$i]}*$a + $ema[$i-1]*(1.0-$a);
    }
    return @ema;
}

sub adxArray {
    # ($adx, $slope) = adx($h_h, $h_l, $h_c, $period)
    #       where return values are array references
    # this is the simple averages version of the ADX
    use strict;
    my ($h_h, $h_l, $h_c, $peri) = @_;
    my $c = @_; die "only $c elements to adx(), should be 4\n" unless ($c == 4);
    my %pc = %$h_c;  my %ph = %$h_h;  my %pl = %$h_l;
    my ($i,$tr,$pdm,$mdm,$tr14,$pdm14,$mdm14,$pdi,$mdi,$didif,$disum,$dx,$adx, $slope,$prv,$tmp);
    my @dx = ();    my @adx = (); my @dadx = ();
    my @tr = ();  my @mdm = ();  my @pdm = ();   #  TR, -DM, +DM
    my @d = sort keys %pc;
    my $n = @d;
 
    $adx[0] = 0.0;
    for ($i = 1; $i <= $peri; $i++) {
        # first N periods to establish baseline
        $tr = max( ($ph{$d[$i]}-$pl{$d[$i]}, abs($ph{$d[$i]}-$pc{$d[$i-1]}), abs($pc{$d[$i-1]}-$pl{$d[$i]})) );
        push @tr, $tr;
        if ($ph{$d[$i]}-$ph{$d[$i-1]} > $pl{$d[$i-1]}-$pl{$d[$i]}  &&  $ph{$d[$i]}-$ph{$d[$i-1]} > 0.0) {
            $pdm = $ph{$d[$i]}-$ph{$d[$i-1]};
            $mdm = 0.0;
        } elsif ($pl{$d[$i-1]}-$pl{$d[$i]} > $ph{$d[$i]}-$ph{$d[$i-1]}  &&  $pl{$d[$i-1]}-$pl{$d[$i]} > 0.0) {
            $mdm = $pl{$d[$i-1]}-$pl{$d[$i]};
            $pdm = 0.0;
        } else {
            $pdm = 0.0;  $mdm = 0.0;
        }
        push @pdm, $pdm;
        push @mdm, $mdm;
        $adx[$i] = 0.0;
    }
    # create the seeds...
    $tr14 = sum( @tr ); $pdm14 = sum( @pdm ); $mdm14 = sum( @mdm );
    $pdi = 100.0 * $pdm14 / $tr14;    $mdi = 100.0 * $mdm14 / $tr14;
    $didif = abs( $pdi - $mdi );  $disum = $pdi + $mdi;
    $dx = 100.0 * $didif / $disum;
    push @dx, $dx;
    for ($i = $peri+1; $i < $n; $i++) {
        $tr = max( ($ph{$d[$i]}-$pl{$d[$i]}, abs($ph{$d[$i]}-$pc{$d[$i-1]}), abs($pc{$d[$i-1]}-$pl{$d[$i]})) );
        if ($ph{$d[$i]}-$ph{$d[$i-1]} > $pl{$d[$i-1]}-$pl{$d[$i]}  &&  $ph{$d[$i]}-$ph{$d[$i-1]} > 0.0) {
            $pdm = $ph{$d[$i]}-$ph{$d[$i-1]};
            $mdm = 0.0;
        } elsif ($pl{$d[$i-1]}-$pl{$d[$i]} > $ph{$d[$i]}-$ph{$d[$i-1]}  &&  $pl{$d[$i-1]}-$pl{$d[$i]} > 0.0) {
            $mdm = $pl{$d[$i-1]}-$pl{$d[$i]};
            $pdm = 0.0;
        } else {
            $pdm = 0.0;  $mdm = 0.0;
        }
        shift @pdm; shift @mdm; shift @tr;  # remove the oldest values
        push @pdm, $pdm;
        push @mdm, $mdm;
        push @tr, $tr;
        $tr14 = sum( @tr ); $pdm14 = sum( @pdm ); $mdm14 = sum( @mdm );
        $pdi = 100.0 * $pdm14 / $tr14;    $mdi = 100.0 * $mdm14 / $tr14;
        $didif = abs( $pdi - $mdi );  $disum = $pdi + $mdi;
        $dx = 100.0 * $didif / $disum;
        push @dx, $dx;
        if ($i > 2*$peri-1) {
            shift @dx;  # remove oldest value
            $adx = sum(@dx)/$peri;
#             if ($i == 2*$peri+4) {
#                 $tmp = @dx; print "$tmp elements - should be $peri\n";
#             }
        } else {
            $adx = 0.0;
        }
        $adx[$i] = $adx;
        if ($i>= 2*$peri+1) {
            $dadx[$i] = $adx - $adx[$i-1];
        } else {
            $dadx[$i] = 0;
        }
    }
    return (\@adx, \@dadx);
}

sub adxArrayW {
    # ($adx, $slope) = adx($h_h, $h_l, $h_c, $period)
    #       where return values are array references
    # this is the original Wilders way of the ADX
    use strict;
    my ($h_h, $h_l, $h_c, $peri) = @_;
    my $c = @_; die "only $c elements to adx(), should be 4\n" unless ($c == 4);
    my %pc = %$h_c;  my %ph = %$h_h;  my %pl = %$h_l;
    my ($i,$tr,$pdm,$mdm,$tr14,$pdm14,$mdm14,$pdi,$mdi,$didif,$disum,$dx,$adx, $slope,$prv);
    my @dx = ();    my @adx = (); my @dadx = ();
    my @tr = ();  my @mdm = ();  my @pdm = ();   #  TR, -DM, +DM
    my @d = sort keys %pc;
    my $n = @d;
 

    for ($i = 1; $i <= $peri; $i++) {
        # first 14 periods to establish baseline
        $tr = max( ($ph{$d[$i]}-$pl{$d[$i]}, abs($ph{$d[$i]}-$pc{$d[$i-1]}), abs($pc{$d[$i-1]}-$pl{$d[$i]})) );
        push @tr, $tr;
        if ($ph{$d[$i]}-$ph{$d[$i-1]} > $pl{$d[$i-1]}-$pl{$d[$i]}  &&  $ph{$d[$i]}-$ph{$d[$i-1]} > 0.0) {
            $pdm = $ph{$d[$i]}-$ph{$d[$i-1]};
            $mdm = 0.0;
        } elsif ($pl{$d[$i-1]}-$pl{$d[$i]} > $ph{$d[$i]}-$ph{$d[$i-1]}  &&  $pl{$d[$i-1]}-$pl{$d[$i]} > 0.0) {
            $mdm = $pl{$d[$i-1]}-$pl{$d[$i]};
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
    for ($i = $peri+1; $i < $n; $i++) {
        # calculating TR, -DM, +DM as before but not keeping old values
        $tr = max( ($ph{$d[$i]}-$pl{$d[$i]}, abs($ph{$d[$i]}-$pc{$d[$i-1]}), abs($pc{$d[$i-1]}-$pl{$d[$i]})) );
        if ($ph{$d[$i]}-$ph{$d[$i-1]} > $pl{$d[$i-1]}-$pl{$d[$i]}  &&  $ph{$d[$i]}-$ph{$d[$i-1]} > 0.0) {
            $pdm = $ph{$d[$i]}-$ph{$d[$i-1]};
            $mdm = 0.0;
        } elsif ($pl{$d[$i-1]}-$pl{$d[$i]} > $ph{$d[$i]}-$ph{$d[$i-1]}  &&  $pl{$d[$i-1]}-$pl{$d[$i]} > 0.0) {
            $mdm = $pl{$d[$i-1]}-$pl{$d[$i]};
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
        $adx[$i] = $adx;
        $dadx[$i] = $adx - $prv;
    }
    return (\@adx, \@dadx);
}

sub rsiArrayW {
    # @rsi = rsi($h_c, $period)
    # this is the original Wilders way of the RSI
    use strict;
    my ($h_c, $peri) = @_;
    my $c = @_; die "only $c elements to rsi(), should be 2\n" unless ($c == 2);
    my %closep = %$h_c;
    my @d = sort keys %closep;
    my $n = @d;
    my ($i,$rsi, $rs,$tr,$pdm,$mdm,$gain14,$loss14,@gain,@loss);
    my @rsi = ();

    $rsi[0] = 0.0;
    for ($i = 1; $i <= $peri; $i++) {
        # first $peri periods to establish baseline
        $tr = $closep{$d[$i]}-$closep{$d[$i-1]};
        if ($tr > 0.0) {
            $pdm = $tr;
            $mdm = 0.0;
        } else {
            $pdm = 0.0;
            $mdm = abs($tr);
        }
        push @gain, $pdm;
        push @loss, $mdm;
        $rsi[$i] = 0.0;
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
    for ($i = $peri+1; $i < $n; $i++) {
        # calculating as before but not keeping old values
        $tr = $closep{$d[$i]}-$closep{$d[$i-1]};
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
        $rsi[$i] = $rsi;
    }
    return @rsi;    
}

sub rsiArray {
    # @rsi = rsi($h_c, $period)
    # this is the simple averaging way of the RSI
    use strict;
    my ($h_c, $peri) = @_;
    my $c = @_; die "only $c elements to rsi(), should be 2\n" unless ($c == 2);
    my %closep = %$h_c;
    my @d = sort keys %closep;
    my $n = @d;
    my ($i,$rsi, $rs,$tr,$pdm,$mdm,$gain14,$loss14,@gain,@loss,$tmp);
    my @rsi = ();

    $rsi[0] = 0.0;
    for ($i = 1; $i <= $peri; $i++) {
        # first $peri periods to establish baseline
        $tr = $closep{$d[$i]}-$closep{$d[$i-1]};
        if ($tr > 0.0) {
            $pdm = $tr;
            $mdm = 0.0;
        } else {
            $pdm = 0.0;
            $mdm = abs($tr);
        }
        push @gain, $pdm;
        push @loss, $mdm;
        $rsi[$i] = 0.0;
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
    $rsi[$peri] = $rsi;
    for ($i = $peri+1; $i < $n; $i++) {
        # calculating as before but not keeping old values
        $tr = $closep{$d[$i]}-$closep{$d[$i-1]};
        if ($tr > 0.0) {
            $pdm = $tr;
            $mdm = 0.0;
        } else {
            $pdm = 0.0;
            $mdm = abs($tr);
        }
        # now starts the Wilder smoothing 
        shift @gain;
        shift @loss;
        push @gain, $pdm;
        push @loss, $mdm;
    $gain14 = sum( @gain )/$peri; 
    $loss14 = sum( @loss )/$peri;
            if ($i == $peri+4) {
                $tmp = @gain; print "$tmp elements - should be $peri\n";
            }
        if ($loss14 == 0.0) {
            $rs = 1000;
            $rsi = 100.0;
        } else {
            $rs = $gain14/$loss14;
            $rsi = 100.0 - 100.0/(1+$rs);
        }
        $rsi[$i] = $rsi;
    }
    return @rsi;    
}

# Kaufman's strength oscillator, Kaufman p.379
# $kso = kso($h_d, $h_i, $h_h, $h_l, $h_c, $per, $day);
sub kso {
    use strict;
    my ($h_d, $h_i, $h_h, $h_l, $h_c, $per, $day) = @_;
    my $c = @_; die "only $c elements to kso(), should be 7\n" unless ($c == 7);
    my %closep = %$h_c; my %maxp = %$h_h;   my %minp = %$h_l;
    my %hday = %$h_d;  my %dayindex = %$h_i;
    my @pc = ();    my @hl = ();
    my ($i, $mc, $mx);  my $kso = 0.0;
    for ($i = 0; $i < $per; $i++) {
        push @pc, $closep{$hday{$dayindex{$day}-$i}} - $closep{$hday{$dayindex{$day}-$i-1}};
        push @hl, $maxp{$hday{$dayindex{$day}-$i}} - $minp{$hday{$dayindex{$day}-$i}};
    }
    $mc = sum( @pc )/$per;
    $mx = sum( @hl )/$per;
    $kso = $mc/$mx unless $mx == 0.0;
    return $kso;
}

sub atrRatio {
    use strict;
    my ($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $per, $day) = @_;
    my @p = split /\D+/, $per;
    my $atr1 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $p[0], $day);
    my $atr2 = atr($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $p[1], $day);
    my $atrR = $atr1/$atr2;
    return $atrR;
}

# ($adx, $slope, $tr14, $pdm14, $mdm14) = adx($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $period, $day)
sub adx {
    # ($adx, $slope, $tr14, $pdm14, $mdm14) = adx($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $period, $day)
    # this is the original Wilders way of the ADX
    use strict;
    my ($tick, $h_d, $h_i, $h_h, $h_l, $h_c, $peri, $day) = @_;
    my $c = @_; die "only $c elements to adx(), should be 8\n" unless ($c == 8);
    my @ph = ();  my @pl = ();  my @pc = (); my @datel = ();
    my %closep = %$h_c;  my %maxp = %$h_h;  my %minp = %$h_l;
    my %hday = %$h_d;  my %dayindex = %$h_i;
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

    for ($i = 0; $i < $pback; $i++) {  # entering in arrays with oldest on top
        unshift @ph, $maxp{$hday{$dayindex{$day}-$i}};
        unshift @pl, $minp{$hday{$dayindex{$day}-$i}};
        unshift @pc, $closep{$hday{$dayindex{$day}-$i}};
        unshift @datel, $hday{$dayindex{$day}-$i};
    }
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

# $rsi = rsi($tick, $h_d, $h_i, $h_c, $period, $day)
sub rsi {
    # $rsi = rsi($tick, $h_d, $h_i, $h_c, $period, $day)
    # this is the original Wilders way of the RSI
    use strict;
    my ($tick, $h_d, $h_i, $h_c, $peri, $day) = @_;
    my $c = @_; die "only $c elements to rsi(), should be 6\n" unless ($c == 6);
    my %closep = %$h_c;
    my %hday = %$h_d;  my %dayindex = %$h_i;
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
    my @pc = ();  my @datel = ();

    my $pback = 10*($peri+1);
    for ($i = 0; $i < $pback; $i++) {  # entering in arrays with oldest on top
        unshift @pc, $closep{$hday{$dayindex{$day}-$i}};
        unshift @datel, $hday{$dayindex{$day}-$i};
    }
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
    } elsif ($indicator =~ /KSO/) {
        $indcall = \&kso;
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


# ($sym, $col) = populatePlottingArrays($rmult);
#
sub populatePlotArrays {
    # for the plotting of R color and size coded as function of two indicator values
    use strict;
    my ($rmult) = @_;
    my ($sym, $col);
    if ($rmult <= 0.0) {
        $col = 2;
    } else {
        $col = 3;
    }
    if ($rmult > 8.0) {
        $sym = 27;
    } elsif ($rmult > 6.0) {
        $sym = 26;
    } elsif ($rmult > 4.0) {
        $sym = 25;
    } elsif ($rmult > 3.0) {
        $sym = 24;
    } elsif ($rmult > 2.0) {
        $sym = 23;
    } elsif ($rmult > 1.0 || $rmult < -1.0) {
        $sym = 22;
    } else {
        $sym = 21;
    }
    return ($sym, $col);
}



1;
