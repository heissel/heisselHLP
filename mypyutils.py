#!/usr/bin/env python
#
# 2006-12-06  got snippet from Cedric

import pyfits, numpy
#
#-----------------------------------
def getfits( fitsfile ):
  """Return the header and the data of a fits file, as a text string and a numpy array respectively."""
  import pyfits
  f = pyfits.open( fitsfile )
  return f[0].header, f[1].data
#	
#-----------------------------------
def getspec( fitsfile ):
  """Return wavelength and flux from a fitsfile that contains a 1D spectrum.
  Also prints information about the spectrum itself."""
  f = pyfits.open( fitsfile )
  cdelt1 = f[0].header['CDELT1']
  crval1 = f[0].header['CRVAL1']
  try:
      start = crval1 - f[0].header['CRPIX1'] * cdelt1
  except:
      start = crval1		
  end = start + cdelt1 * len(f[0].data) - cdelt1/10.
  x = numpy.arange( start, end, cdelt1 )
  print '%s %.6f + %i * %.6f = %.6f (%.6f)'%(fitsfile,start,len(x),cdelt1,end,(start+end)/2.) 
  f.close()
  return x, f[0].data
