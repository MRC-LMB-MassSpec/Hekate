#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;

print "Content-Type: text/plain\n\n";

open FH, 'log' or die "Cannot open log file";
{ local $/, undef $/; print <FH> };

