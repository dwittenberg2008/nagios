#!/usr/bin/perl

# Gather basic stats about the cpu status from sar
# Make sure to have a long enough timeout, usually > 15 seconds

# Daniel Wittenberg <dwittenberg2008@gmail.com>

use strict;
use warnings;
use lib "/usr/lib64/nagios/plugins";
use utils qw(%ERRORS);
use Time::Local;

my ($junk,$cpu,$user,$nice,$system,$iowait,$steal,$idle,$perfdata);
my $sarcmd="/usr/bin/sar";

if(! -e "$sarcmd") { 
	print("WARNING - sar not found!\n");
	exit $ERRORS{"WARNING"};
}

my $sar=`$sarcmd 2 8 |tail -1`;

#09:06:38 AM       CPU     %user     %nice   %system   %iowait    %steal     %idle
#Average:          all      0.90      0.05      0.65      0.10      0.00     98.30

($junk,$cpu,$user,$nice,$system,$iowait,$steal,$idle) = split(/\s+/,$sar);

if(! $user)   { $user=0.00; }
if(! $nice)   { $nice=0.00; }
if(! $system) { $system=0.00; }
if(! $iowait) { $iowait=0.00; }
if(! $steal)  { $steal=0.00; }
if(! $idle)   { $idle=0.00; }
$perfdata = "'user'=$user% 'nice'=$nice% 'system'=$system% 'iowait'=$iowait% 'steal'=$steal% 'idle'=$idle%";

print("OK - CPU stats: user=$user% nice=$nice% system=$system% iowait=$iowait% idle=$idle% | $perfdata\n");
exit $ERRORS{"OK"};
