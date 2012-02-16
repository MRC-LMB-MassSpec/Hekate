#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;
use Time::Local;

print "Content-Type: text/plain\n\n";

open FH, '>log' or die "Cannot open log file";

my $time = localtime(time);
print FH "[$time] *** Log Started ***\n";

print "Log Cleared";
