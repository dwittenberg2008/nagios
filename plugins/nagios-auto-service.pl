#!/usr/bin/perl

# Simple script to take a service name as argument and try and restart
# it if we can.  Assumes the nagios user has sudo rights to the 
# /sbin/service command
# Daniel Wittenberg <dwittenberg2008@gmail.com>
# Josh Means <josh@joshmeans.com>

use strict;
use warnings;
use Getopt::Std;

my %opts;
getopts('dhps:t:u:f', \%opts);

if($opts{d}) { print("DEBUG MODE\n"); }

if($opts{h}) { USAGE(); }
if(! $opts{s}) { USAGE(); }
$opts{s} =~ s/^check_nrpe_proc_//g;
$opts{s} =~ s/^local_process_//g;

$opts{s}=&process_exceptions($opts{s});

&debug("Working with service $opts{s}\n");

# For some reason it's disabled, abort!
if(! chkconfig($opts{s}) && ! $opts{f}) { &debug("Disabled in chkconfig, abort!\n"); exit(0); }

# This has already failed multiple times, abort!
if($opts{t} ne "SOFT" && ! $opts{f}) { &debug("Not in soft state ($opts{t}), abort!\n"); exit(0); }

if($opts{u} eq "WARNING" && ! check_ps($opts{s})) { &debug("In WARNING, and NOT running!\n"); &restart($opts{s}); }

# If it gets here and is something other than critical, abort!
if($opts{u} ne "CRITICAL" && ! $opts{f}) { &debug("Not in CRITICAL state ($opts{u}), abort!\n"); exit(0); }

&debug("Preparing to restart service $opts{s} in a $opts{t} type with state of $opts{u}\n");
&restart($opts{s});

# One last check to see if anything is running
if(check_ps($opts{s})) { 
   &debug("Process $opts{s} appears to be running\n");
   exit(0);
} else {
   &debug("Process $opts{s} appears DEAD\n");
   exit(1);
}

exit(0);



###############
sub USAGE {
   print("$0 [-h | -d] -s <service>\n");
   print("\n
-h	help
-d	debug
-p 	preview - don't actually do anything
-s	service description (\$SERVICEDESCRIPTION\$)
-t	type (soft, hard - \$SERVICESTATETYPE\$)
-u 	state (OK, WARNING, UNKNOWN, CRITICAL - \$SERVICESTATE\$)
-f 	force (run even when safety checks say no)
\n");
exit(0);
}

sub chkconfig {
   my $svc="@_";
   if(! -e "/etc/init.d/$svc") {
	&debug("/etc/init.d/$svc does not exist, abort!\n");
	exit(1);
   }
   my $runlevel=`/sbin/runlevel 2>/dev/null |awk '{print \$2}'`;
   chomp($runlevel);
   &debug("Checking for service $svc at runlevel $runlevel\n");
   $runlevel=$runlevel+2;
   my $chk=`/sbin/chkconfig --list $svc |awk '{print \$$runlevel}' |awk -F: '{print \$2}'`;
   chomp($chk);
   if($chk eq "on") { 
   	&debug("Chkconfig says this SHOULD be running\n");
	return 1;
   } else {
   	&debug("Chkconfig says this service is DISABLED at this runlevel\n");
	return 0;
   }
}

sub restart {
  my $svc="@_";
  my $hostname=`hostname`;
  chomp($hostname);
  system("date |mail -s \"Restarting $svc service on $hostname\" user\@example.com");
  if($opts{p}) {
	&debug("PREVIEW: /usr/bin/sudo /sbin/service $svc restart\n");
  } else {
    	&debug("Issuing /usr/bin/sudo /sbin/service $svc restart command\n");
  	system("/usr/bin/sudo /sbin/service $svc restart 1>/dev/null 2>/dev/null");
  }
}

sub check_ps {
  my $svc="@_";
  sleep 2;
  my $ps=`ps -el |grep $svc |grep -ve grep |wc -l`;
  chomp($ps);
  &debug("check_ps says there are $ps processes running\n");
  if($ps) {
	return 1;
  } else {
	return 0;
  }
}

sub debug {
   my $msg="@_";
   if($opts{d}) {
  	my $date=`date +%b" "%d" "%H":"%m":"%S`; 
 	chomp($date);
	print("DEBUG: $msg");
 	open(OUT, ">>/var/log/nagios/nagios-auto-service.log");
	print(OUT "$date $opts{s} $msg");
	close(OUT);
   }
}

# Sometimes the names don't exactly match between service and real name
sub process_exceptions {
   my $svc="@_";
   
   if($svc eq "puppetd") { $svc="puppet"; }
   if($svc eq "ldap") { $svc="dirsrv"; }

   return $svc;
}
