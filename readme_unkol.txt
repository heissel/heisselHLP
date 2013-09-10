unkol er et script!
Men det bruger to programmer: unscale.f og kurkol2.f
 /ai37/bruntt/PROJ/VWA/TARS/VALD_SOURCES/unscale.f
 /ai37/bruntt/PROJ/VWA/TARS/VALD_SOURCES/kurkol2.f
Der er en ny version kurkol3, som ikke bruger unscale.

Heiters programmer: /ai4/bruntt/HEITER/ unscale.f og kurkol2.c
  f77 -o unscale -O2 unscale.f     
  gcc -o kurkol2 kurkol2.c -lm

To use:
kurkol2 T06380G393_2m01.mod HD007455.krz

