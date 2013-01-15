#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;
use Time::Local;
use lib 'lib';
use Crosslinker::HTML;

########################
#                      #
# Code	               #
#                      #
########################

print_page_top_bootstrap;
print_heading('Clear Log');

open FH, '>log' or die "Cannot open log file";

my $time = localtime(time);
print FH "[$time] *** Log Started ***\n";

print "<p> The log has been emptied</p>";

print_page_bottom_bootstrap;
