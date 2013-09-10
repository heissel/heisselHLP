#!/usr/bin/perl
#*******************************************************************************# E.S.O. - VLT project
#
# "@(#) $Id: CEScheckPipe.pl,v 1.26 2005/08/15 21:55:52 vltsccm Exp $"
#
# who       when        what
# --------  ----------  ----------------------------------------------
# aederocl  2005-08-06  created

$pwd = `pwd`;
chomp($pwd);

$path = $ENV{'CES_PIPE_HOME'};  print "Path = $path\n";
unless ($path) {
    die "you must copy and paste the following in the shell, 
then you re-execute this script:
CES_PIPE_HOME=\$CES_PIPE_HOME$pwd
export  CES_PIPE_HOME \n";
}

if ($path){
    print "the environmental variable CES_PIPE_HOME exists \n";
}
