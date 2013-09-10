use Carp;

# check CFITSIO status
sub check_status {
    my $s = shift;
    if ($s != 0) {
	my $txt;
      Astro::FITS::CFITSIO::fits_get_errstatus($s,$txt);
	carp "CFITSIO error: $txt";
	return 0;
    }

    return 1;
}

1;

=head1 check_status( )

	$retval = check_status($status);

Checks the CFITSIO status variable. If it indicates an error, the
corresponding CFITSIO error message is carp()ed,
and a false value is returned. If the passed status
does not indicate an error, then a true value is returned and nothing
else is done

=cut


sub read_fits_spectrum {
    # ($x, $y) = read_fits_spectrum($spec)
    # 
    # where $x and $y are references to the @x and @y arrays.
    # Requires utils.pl to be included in main program.

    my ($fptr, $status, $dim, $naxis1, $wl_start, $wl_inc, $pxoff, $i);
    my ($array, $nullarray, $anynull);
    my @x = ();  my @y = ();
    my $spec = shift;

    $fptr = Astro::FITS::CFITSIO::open_file($spec,Astro::FITS::CFITSIO::READONLY(),$status);
    check_status($status) or die;
    $fptr -> read_key_str('NAXIS', $dim, undef, $status);
    if ($dim > 1) {
	die "Multidimensional spectrum not allowed!\n";
    }
    $fptr -> read_key_str('NAXIS1', $naxis1, undef, $status);
    $fptr -> read_key_str('CRVAL1', $wl_start, undef, $status);
    $fptr -> read_key_str('CDELT1', $wl_inc, undef, $status);
    $fptr -> read_key_str('CRPIX1', $pxoff, undef, $status);
    for ($i = 0; $i < $naxis1; $i++) {
	push @x, $wl_start + ($i - $pxoff) * $wl_inc;
    }
    $fptr -> read_subset(Astro::FITS::CFITSIO::TDOUBLE(), 1, $naxis1, [1], $nullarray, $array, $anynull ,$status);
    @y = @$array or die "fatal error in fits read\n";
    $fptr -> close_file($status);
    check_status($status) or die;

    return (\@x, \@y);

}



sub read_fits_order {
    # ($x, $y) = read_fits_order($order, $wloffset, $file)
    # 
    # where $x and $y are references to the @x and @y arrays.
    # $order is logical order number. $wloffset is zeropoint of wavelength scale

    my ($fptr, $status, $dim, $naxis1, $naxis2, $crpix, $wl_start, $wl_inc, $i);
    my ($array, $nullarray, $anynull);
    my @x = ();  my @y = ();
    my $order = shift;
    my $wloffset = shift;
    my $file = shift;

    $fptr = Astro::FITS::CFITSIO::open_file($file,Astro::FITS::CFITSIO::READONLY(),$status);
    check_status($status) or die;
    $fptr -> read_key_str('NAXIS', $dim, undef, $status);
    if ($dim > 1) {
	$fptr -> read_key_str('NAXIS1', $naxis1, undef, $status);
	$fptr -> read_key_str('NAXIS2', $naxis2, undef, $status);
	$fptr -> read_key_str('CRPIX1', $crpix, undef, $status);
	$fptr -> read_key_str('CRVAL1', $wl_start, undef, $status);
	$fptr -> read_key_str('CDELT1', $wl_inc, undef, $status);
	for ($i = 0; $i < $naxis1; $i++) {
	    push @x, $wloffset + $wl_start + ($i - $crpix) * $wl_inc;
	}
	$fptr -> read_subset(Astro::FITS::CFITSIO::TDOUBLE(), [1,$order], [$naxis1,$order], [1,1], $nullarray, $array, $anynull ,$status);
	@y = @$array or die "fatal error in 2D fits read\n";

	$fptr -> close_file($status);
	check_status($status) or die;
    } else {
	print "WARNING: reading 1D image with 2D call\n";
    }

    return (\@x, \@y);

}



sub read_fits_ccf {
    # ($x, $y) = read_fits_ccf($spec)
    # 
    # where $x and $y are references to the @x and @y arrays.
    # Can only read HARPS CCF's.

    my ($fptr, $status, $dim, $naxis1, $naxis2, $wl_start, $wl_inc, $i);
    my ($array, $nullarray, $anynull);
    my $order = 73;   # will only work for HARPS!
    my @x = ();  my @y = ();
    my $file = shift;

    $stem = find_stem_of_fits($file);
    $fptr = Astro::FITS::CFITSIO::open_file($file,Astro::FITS::CFITSIO::READONLY(),$status);
    check_status($status) or die;

    $fptr -> read_key_str('NAXIS1', $naxis1, undef, $status);
    $fptr -> read_key_str('NAXIS2', $naxis2, undef, $status);
    $fptr -> read_key_str('HIERARCH ESO DRS CCF RV', $rv, undef, $status);
    $fptr -> read_key_str('HIERARCH ESO DRS BJD', $bjd, undef, $status);
    $fptr -> read_key_str('CRVAL1', $wl_start, undef, $status);
    $fptr -> read_key_str('CDELT1', $wl_inc, undef, $status);
    for ($i = 0; $i < $naxis1; $i++) {
	push @x, $wl_start + $i * $wl_inc;
    }
    $fptr -> read_subset(Astro::FITS::CFITSIO::TDOUBLE(), [1,$order], [$naxis1,$order], [1,1], $nullarray, $array, $anynull ,$status);
    @y = @$array or die "fatal error in 2D fits read\n";

    $fptr -> close_file($status);
    check_status($status) or die;

    return (\@x, \@y);

}


sub write_fits_spectrum {
    # write_fits_spectrum( $fitsfile, $wl0, $delta, $y )
    #
    # writes file $fitsfile. Spectrum starts at $wl0, increment of $delta. Pixel
    # values are stored in array @$y. If $fitsfile exsists it will be overwritten.
    # (need some error checking still...)
    use strict;
    my ($fptr, $status);
    my $newfits = shift;
    my $wl0 = shift;
    my $delta = shift;
    my $y = shift;
    my $num = @$y;    # number of points in array
 #   my $date = `date +%Y-%m-%dT%H:%M:%S`; chomp( $date );
    unlink $newfits if (-e $newfits);

    $fptr = Astro::FITS::CFITSIO::create_file($newfits,$status);
    check_status($status) or die "bzzzzfrr";

    $fptr -> create_img(-32, 1, $num, $status);            # creating basic header info
    $fptr -> update_key(Astro::FITS::CFITSIO::TDOUBLE(), "CRVAL1", $wl0, "Coordinate at reference pixel", $status);
    $fptr -> update_key(Astro::FITS::CFITSIO::TDOUBLE(), "CRPIX1", 1.0, "Reference pixel", $status);
    $fptr -> update_key(Astro::FITS::CFITSIO::TDOUBLE(), "CDELT1", $delta, "Coordinate increment per pixel", $status);
    $fptr -> update_key(Astro::FITS::CFITSIO::TSTRING(), "OBJECT", "spectrum", "Target description", $status);
    $fptr -> write_date($status);
    $fptr -> update_key(Astro::FITS::CFITSIO::TDOUBLE(), "UT", 0.0, "UT at start [sec]", $status);
    $fptr -> write_pix(Astro::FITS::CFITSIO::TDOUBLE(), [1], $num, $y, $status);
    check_status($status) or die "237242hhh2";

    $fptr -> close_file($status);
    check_status($status) or die;
}



sub find_stem_of_fits {
    my $file = shift;
    my $stem;

    $file =~ /(.*).fit/;   $stem = $1;
    if ($stem =~ /\/([^\/]*)$/) {
	$stem = $1;
    }

    return $stem;
}



sub low_and_high {
    use strict;
    my @somearr = @_;
    my $hig = $somearr[0];
    my $low = $hig;
    my $test;
    foreach $test (@somearr) {
        if ($test >= $hig) {
            $hig = $test;
        }
        if ($test <= $low) {
            $low = $test;
        }
    }
    return ($low,$hig);
}

sub median {
    use strict;
    @_ == 1 or die ('Sub usage: $median = median(\@array);');
    my ($array_ref) = @_;
    my $count = scalar @$array_ref;
    # Sort a COPY of the array, leaving the original untouched
    my @array = sort { $a <=> $b } @$array_ref;
    if ($count % 2) {
        return $array[int($count/2)];
    } else {
        return ($array[$count/2] + $array[$count/2 - 1]) / 2;
    }
}


sub max {
    use strict;
    my @arr = @_;
    my $hig = $arr[0];
    my $test;
    foreach $test (@arr) {
        if ($test >= $hig) {
            $hig = $test;
        }
    }
    return $hig;
}

sub min {
    use strict;
    my @arr = @_;
    my $low = $arr[0];
    my $test;
    foreach $test (@arr) {
        if ($test <= $low) {
            $low = $test;
        }
    }
    return $low;
}


sub low_and_high_index {
    use strict;
    my @arr = @_;
    my ($num, $i);
    my ($i_hig, $i_low) = (0,0);
    my $hig = $arr[0];  
    my $low = $hig;
    $num = @arr;
    for ($i = 1; $i < $num; $i++) {
	if ($arr[$i] > $hig) {
	    $i_hig = $i;
	    $hig = $arr[$i];
	}
	if ($arr[$i] < $low) {
	    $i_low = $i;
	    $low = $arr[$i];
	}
    }
#    print "$low, $hig, $i_low, $i_hig\n";
    return ($low, $hig, $i_low, $i_hig);
}
	



sub div_array {
    # @newarr = div_arr(\@arr, $div); 
    use strict;
    my ($ref, $div) = @_;
    my $i;
    my @arr = @$ref;
    my $num = @arr;
    for ($i = 0; $i < $num; $i++) {
        $arr[$i] /= $div;
    }
    return @arr;
}


sub mult_array {
    # @newarr = mult_arr(\@arr, $fac); 
    use strict;
    my ($ref, $fac) = @_;
    my $i;
    my @arr = @$ref;
    my $num = @arr;
    for ($i = 0; $i < $num; $i++) {
        $arr[$i] *= $fac;
    }
    return @arr;
}

sub add_array {
    # @newarr = add_array(\@arr, $const);
    use strict;
    my ($ref, $const) = @_;
    my $i;
    my @arr = @$ref;
    my $num = @arr;
    for ($i = 0; $i < $num; $i++) {
        $arr[$i] += $const;
    }
    return @arr;    
}


sub sum {  # summerer et givet array
           #
           #    $mysum = sum( @arr );
           #
           #
    use strict;
    my($sum,$e);
    $sum=0;
    foreach $e (@_) {
        $sum += $e;
    }
    return $sum;
}




sub sigma {  # finder rms scatter af et givet array, givet en middelvaerdi
             #
             # $rms = sigma( $mean, @arr )
             #
             #
    use strict;
    my $mean = shift;
    my $sig = 0.0;
    my $num123 = @_ - 1;
    return 0 if ($num123 < 1);
    foreach (@_) {
        $sig += ($_ - $mean)**2;
    }
    $sig = ( $sig / $num123 )**.5;
    return $sig;
}


sub sigmaptpt { # finder point to point scatter of array
                #
                # $sig = sigmaptpt( @arr )
                #
                #
    use strict;
    my $i;
    my $sig = 0.0;
    my $num = @_;
    return 0 if ($num < 2);
    my @arr = @_;
    for ($i = 1; $i < $num; $i++) {
        $sig += ($arr[$i] - $arr[$i-1])**2;
    }
    $sig = ($sig / (2*($num-1)))**.5;
    return $sig
}


sub linfit {  # fits a straight line to the data (x and y passed as references)
              #    usage:
              #           ($a, $siga, $b, $sigb) = linfit( \@x, \@y );
              #
              # where  y = $a + $b * x
    use strict;
    my ($chi2, $siga, $sigb, $i, $st2, $b, $a, $ss, $sxoss, $t, $sx, $sy, $x,$y,@x,@y);
    $st2 = 0.0;  $b = 0.0; $chi2 = 0.0;
    ($x, $y) = @_;
    @x = @$x;
    @y = @$y;
    my $nx = @x;  my $ny = @y;
    die "Hey!? $nx = $ny ??\n" unless ($nx == $ny);

    $sx = sum( @x );    $sy = sum( @y );    $ss = @x;
    $sxoss = $sx / $ss;
    for ($i = 0; $i < $ss; $i++) {
	$t = $x[$i] - $sxoss;
	$st2 += $t * $t;
	$b   += $t * $y[$i];
    }
    $b = $b / $st2;
    $a = ($sy - $sx * $b) / $ss;
    for ($i = 0; $i < $ss; $i++) {
	$chi2 += ( $y[$i] - $a - $b * $x[$i] )**2;
    }
    $t = ( $chi2 / ($ss - 2) )**.5;
    $siga = $t * (  (1.0 + ($sx*$sx)/($ss*$st2))/ $ss  )**.5;
    $sigb = $t * ( 1.0/$st2 )**.5;

    return ($a, $siga, $b, $sigb);

}


sub sort2arrays {
    # ($newx, $newy) = sort2arrays($x, $y)
    # all are references to arrays. Sorts $x in ascending order in $newx.
    use strict;
    my @newx = ();    my @newy = ();
    my @x = ();  my @y = ();  my %value = ();
    my $x = shift;  my $y = shift;
    @x = @$x;  @y = @$y;
    my $i;
    my $naxis = @y; 

    for ($i=0; $i < $naxis; $i++) {
        $value{$x[$i]} = $y[$i];
    }
    @newx = sort { $a <=> $b } @x;
    for ($i=0; $i < $naxis; $i++) {
        $newy[$i] = $value{$newx[$i]};
    }
    return (\@newx, \@newy);
}



sub add_slash {  # checks if a text variable (path typically) ends in a "/", and
                 # appends it if it doesn't
                 #
                 #   usage:
                 #          $path = add_slash( $oldpath )

    my $txtvar;
    $txtvar = shift;
    unless ($txtvar =~ m|/$|) {
	$txtvar = $txtvar . "/";
    }

    return $txtvar;
}




sub do_rebin_spectrum
{
    use strict;
    # ($effbin, $xnew, $ynew) = do_rebin_spectrum($bin, $x, $y, $sigma)
    # 
    # $bin is new bin in AA. Assumes linear wavelength scale.
    # $effbin is effective bin-size; can only sum integer numbers of old bins.
    # will do sigma cutting if $sigma > 0

    my @newx = ();    my @newy = ();
    my @tmpx = ();    my @tmpy = ();
    my @x = ();  my @y = ();
    my ($naxis, $cdelt, $i, $j, $num2sum, $check, $newNaxis, $newNum, $xxx, $yyy, $newX, $newY);
    my $bin = shift;
    my $x = shift;
    my $y = shift;
    my $sigma = shift;

    @x = @$x;  @y = @$y;
    $naxis = @y; 
    $cdelt = $x[1] - $x[0];  print "cdelt = $cdelt\n";
    $num2sum = int( $bin / $cdelt + 0.5 ); print "num2sum = $num2sum\n";
    my $effbin = $num2sum * $cdelt;

    if ($naxis > 12) 
    {
	($xxx, $yyy) = sigma_hi_cut($sigma, \@x, \@y);
	$newNum = @y;
	if ($newNum == $naxis)
	{
	    @x = @$xxx;   @y = @$yyy;
	}
	else
	{
	    print "WARNING: sigma clipping failed.\n";
	}
    }

    $newNaxis = int( $naxis / $num2sum );
    $check = 0;
    for ( $i = 0; $i < $naxis; $i += $num2sum )
    {
	$newX = 0;   $newY = 0;
	$check++;
	if ($check <= $newNaxis)
	{
	    @tmpx = (); @tmpy = ();
	    for ($j = $i; $j < $i + $num2sum; $j++ )
	    {
		push @tmpx, $x[$j];
		push @tmpy, $y[$j];
	    }
	    if ($sigma > 0 && $num2sum > 4)
	    {
		($xxx, $yyy) = sigma_hi_cut($sigma, \@tmpx, \@tmpy);
		@tmpx = @$xxx;   @tmpy = @$yyy;
	    }
	    $newNum = @tmpy;
	    $newX = sum( @tmpx ) / $newNum;
	    $newY = sum( @tmpy ) / $newNum;
	    push @newx, $newX;
	    push @newy, $newY;
	}
    }

    return ($effbin, \@newx, \@newy);
}


sub sigma_hi_cut
{ 
    use strict;
    # ($xnew, $ynew) = sigma_hi_cut($sigma, $x, $y)
    # 
    # cuts only points higer that $sigma times the rms scatter (i.e. for cosmic removal)
    # $x, $y and $xnew, $ynew are references to arrays. Scatter measured in $y array.
    #
    my @ttx = ();  my @tty = ();
    my ($k, $mean, $rms);
    my $num4sum = 0;
    my $sigma = shift;
    my $x = shift;
    my $y = shift;
    my @y = @$y;  my @x = @$x;
    my $num = @y;
    $mean = sum( @y ) / $num;
    $rms = sigma( $mean, @y );  #  print "mean = $mean +/- $rms\n";
    
    for ($k = 0; $k < $num; $k++)  
    {
	if ($y[$k] < $mean + $sigma * $rms)
	{
	    push @ttx, $x[$k];
	    push @tty, $y[$k];
	    $num4sum++;
	} else { 
	    if ($k-3 >= 0 && $k+3 < $num) {
		print "replacing $y[$k] ";
		$y[$k] = ($y[$k-3]+$y[$k-2]+$y[$k+2]+$y[$k+3]) / 4.0;
		print "with $y[$k] ";
		push @ttx, $x[$k];
		push @tty, $y[$k];
	    } else {
		print "cutting $y[$k] ";
	    }
	    print "at $x[$k]\n"; 
	}
    }
    if ($num4sum > 1)
    {
	return (\@ttx, \@tty);
    }
    else 
    {
	print "sigma_hi_cut:WARN: sigma cutting too many points!\n";
	return (\@x, \@y);
    }
}



sub sigma_hilo_cut
{ 
    use strict;
    # ($xnew, $ynew) = sigma_hilo_cut($sigma, $x, $y)
    # 
    # cuts points that deviates more than $sigma times the rms scatter
    # $x, $y and $xnew, $ynew are references to arrays. Scatter measured in $y array.
    #
    my @ttx = ();  my @tty = ();
    my ($k, $mean, $rms);
    my $num4sum = 0;
    my $sigma = shift;
    my $x = shift;
    my $y = shift;
    my @y = @$y;  my @x = @$x;
    my $num = @y;
    $mean = sum( @y ) / $num; 
    $rms = sigma( $mean, @y );
    
    for ($k = 0; $k < $num; $k++)  
    {
	if ($y[$k] < $mean + $sigma * $rms && $y[$k] > $mean - $sigma * $rms)
	{
	    push @ttx, $x[$k];
	    push @tty, $y[$k];
	    $num4sum++;
	}
    }
    if ($num4sum > 1)
    {
	return (\@ttx, \@tty);
    }
    else 
    {
	print "sigma_hilo_cut:WARN: sigma cutting too many points!\n";
	return (\@x, \@y);
    }
}



sub xcor {         # spectra: @x is object spectrum, @y is template/mask
    use strict;
    # ($r, $d) = xcor( \@x, \@y, $d0, $dmax)
    # 
    # where $d0 is a guess of the max correlation pixel and $dmax is the +/- pixel range. 
    # note that this is in pixel-space; need to translate to wavelength or velocity in calling routine.
    # On return, $r and $d are references to the arrays @r and @d with correlation and 'velocity'
    my ($i, $denom, $d0, $dmax, $delay, $sx, $sy, $xx, $yy, $x, $y, @x, @y, @r, @d, $sxy, $num, $j);
    ($x, $y, $d0, $dmax) = @_;
    @x = @$x;     @y = @$y;
    @r = ();      @d = ();
    $num = @x;

    $xx = sum( @x );    $yy = sum( @y );
    $xx /= $num;        $yy /= $num;

    $sx = 0.0;  $sy = 0.0;
    for ($i=0; $i<$num;$i++) {
        $sx += ($x[$i] - $xx) * ($x[$i] - $xx);
        $sy += ($y[$i] - $yy) * ($y[$i] - $yy);
    }
    $denom = sqrt( $sx * $sy );

    for ($delay=$d0-$dmax; $delay<$d0+$dmax; $delay++) {
        $sxy = 0;
        for ($i=0; $i<$num; $i++) {
            $j = $i + $delay;
            unless ($j < 0 || $j >= $num) {
                $sxy += ($x[$i] - $xx) * ($y[$j] - $yy);
            }
        }
        push @r, $sxy / $denom;
        push @d, $delay;
    }

    return (\@r, \@d);

}


1;
