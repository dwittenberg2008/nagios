#!/usr/binperl

# Reads all comments via livestatus and delete old/too many
# Daniel Wittenberg <dwittenberg2008@gmail.com>

use strict;
use warnings;
use Getopt::Std;
use File::Basename;
use vars qw ( %opts );
$|++;

getopts ('dhm', \%opts) or USAGE();
my $LOGFILE = basename($0);
$LOGFILE =~ s/.sh$//;
$LOGFILE =~ s/.pl$//;
$LOGFILE = "/var/log/nagios/$LOGFILE.log";
my $mailmsg="";
my $runby=`id -nu`;

Printer("Starting cleanup of old comments\n", 2);
&delete_old_comments;
&delete_too_many_comments;
Printer("Cleanup complete\n", 2);

exit;

###########################################
sub delete_old_comments {
	my ($id,$epoch,$service);
	my $tmpquery="/tmp/.query.$$";
	my $time=time();
	$time=$time-(60*60*24*30);  # 30 days worth  
	
	open(QUERY, "> $tmpquery") || die "Can't open query file ($tmpquery): $!";
	print(QUERY "GET comments\nColumns: service_description entry_time id\n");
	print(QUERY "Filter: entry_time <= $time\n");
	close(QUERY);
	
	open(IN, "/usr/bin/unixcat /var/nagios/rw/live < $tmpquery |") || die "Can't run query: $!";
	while(<IN>) {
	   chomp;
	   ($service,$epoch,$id)=split(/;/);
	   if($id) {
	      if(! $service) {
	        system("/usr/lib64/nagios/plugins/eventhandlers/del_host_comment.sh $id");
	      } else {
	        system("/usr/lib64/nagios/plugins/eventhandlers/del_svc_comment.sh $id");
	      }
	   }
	   # Too fast can cause problems
	   sleep 1;
	}
	close(IN);
	
	system("rm -f $tmpquery");
}

sub delete_too_many_comments {
	my($host,$count,@hosts,$id,$service,$epoch);
	my $limit=10;
	# Now let's find out if any one host has a lot, over any time
	my $time=time();
	my $hosts;
	my $tmpquery="/tmp/.query.$$";
	
	open(QUERY, "> $tmpquery") || die "Can't open query file ($tmpquery): $!";
	print(QUERY "GET comments\nColumns: host_name service_description entry_time id\n");
	print(QUERY "Filter: entry_time <= $time\n");
	print(QUERY "Stats: id > 0\nStatsGroupBy: host_name\n");
	close(QUERY);
	
	open(IN, "/usr/bin/unixcat /var/nagios/rw/live < $tmpquery |") || die "Can't run query: $!";
	while(<IN>) {
	   chomp;
	   ($host,$count)=split(/;/);
	   if($count > $limit) {
	        push(@hosts,$host);
	   }
	}
	close(IN);
	system("rm -f $tmpquery");


	# Now let's find out if any one host has a lot, over any time
	foreach my $hostname (@hosts) {
	   open(QUERY, "> $tmpquery") || die "Can't open query file ($tmpquery): $!";
	   print(QUERY "GET comments\nColumns: service_description host_name entry_time id\n");
	   print(QUERY "Filter: host_name = $hostname\n");
	   close(QUERY);
	
	   my $counter=0;
	   open(IN, "/usr/bin/unixcat /var/nagios/rw/live < $tmpquery | sort -r -t\\; -k2 |") || die "Can't run query: $!";
	   while(<IN>) {
	        chomp;
	        ($service,$hostname,$epoch,$id)=split(/;/);
	        $counter++;
	        if($counter > $limit && $id) { 
	           if(! $service) {
	                system("/usr/lib64/nagios/plugins/eventhandlers/del_host_comment.sh $id");
	           } else {
	                system("/usr/lib64/nagios/plugins/eventhandlers/del_svc_comment.sh $id");
	           }
	           sleep 1;
	        }
	   }
	   close(IN);
	   system("rm -f $tmpquery");
	}

}

sub Printer {
  my ($msg, $code) = @_;
  if(! $code) { $code=1 };
  
  # Syslog format timestamp
  my $time=`date +%h" "%d" "%H":"%M":"%S`;
  chomp($time);

  #--------------
  # code legend:
  # 1 = debug log only
  # 2 = both log and if debug flag on STDOUT too
  # 3 = both log and if debug flag on STDOUT too, then exit
  #--------------
  $msg .= "\n" unless ($msg =~ /\n$/);
  
  if($opts{d}) { print "DEBUG: $msg"; }
  if($opts{m} && $opts{d}) { 
  	$mailmsg .= "DEBUG: $msg"; 
  } elsif($opts{m}) {
  	$mailmsg .= "$msg";
  }
  
  open (LOG, ">>$LOGFILE") or `/bin/logger -i -p user.info "$0: Can't open log file ($LOGFILE): $!"`;
  print LOG $time . " " . $msg if ($code >= 2);
  close(LOG);
  exit if ($code == 3);
}
