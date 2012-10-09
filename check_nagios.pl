#!/usr/bin/perl -w

# This will interface from the nagios server out to the client so
# cacti stats can be polled from remote nagios server


use strict;

# ARGV=http://<host>/nagios/cgi-bin/ latency view view
my $results;
my $url = $ARGV[0];
$url =~ s/\/+$//; # Remove trailing slash if needed
if($ARGV[1] eq "latency") { 
	&get_latency($url);
} elsif($ARGV[1] eq "servicechecks") {
	&get_servicechecks($url);
} elsif($ARGV[1] eq "hostchecks") {
	&get_hostchecks($url);
} elsif($ARGV[1] eq "cmd_buffers") {
	&get_buffers($url);
} elsif($ARGV[1] eq "rates") {
	&get_rates($url);
} else {	
	my $type = $ARGV[1];
	my $cmd = "wget -qO- ";
	if($ARGV[2] && $ARGV[3]) {
        $cmd .= "--user=$ARGV[2] --password=$ARGV[3] ";
	}
	$cmd .= "$url/mrtgstats.cgi?type=$type";
	#print "URL: $cmd\n";
	$results = `$cmd`;
	$results =~ s/^\s+|\s+$//g;
	print "$results\n";
}

exit;

#####################
sub get_latency {
	my $junk;
	my $host="@_";
	($junk,$junk,$host)=split(/\//,$host);
	$host =~ s/^http:\/\///g;
	my($AVGACTSVCLAT,$AVGACTSVCEXT,$AVGACTHSTLAT,$AVGACTHSTEXT);
	my $querytmp="/tmp/.query.$$";

	# First let's get service latency
	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET services\nStats: avg latency\nStats: avg execution_time\n");
	close(OUT);
	
	my $lat=`/usr/bin/nc $host 6557 < $querytmp 2>&1`;
	system("rm -f $querytmp");
	($AVGACTSVCLAT,$AVGACTSVCEXT)=split(/;/,$lat);
	$AVGACTSVCLAT=sprintf("%0.f", $AVGACTSVCLAT*1000);
	$AVGACTSVCEXT=sprintf("%0.f", $AVGACTSVCEXT*1000);

	# Next let's get host latency
	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET hosts\nStats: avg latency\nStats: avg execution_time\n");
	close(OUT);

	$lat=`/usr/bin/nc $host 6557 < $querytmp 2>&1`;
	system("rm -f $querytmp");
	($AVGACTHSTLAT,$AVGACTHSTEXT)=split(/;/,$lat);
	$AVGACTHSTLAT=sprintf("%0.f", $AVGACTHSTLAT*1000);
	$AVGACTHSTEXT=sprintf("%0.f", $AVGACTHSTEXT*1000);

	print("AVGACTSVCLAT:$AVGACTSVCLAT AVGACTSVCEXT:$AVGACTSVCEXT ");
	print("AVGACTHSTLAT:$AVGACTHSTLAT AVGACTHSTEXT:$AVGACTHSTEXT\n");
}

sub get_servicechecks {
	my $junk;
	my $host="@_";
	($junk,$junk,$host)=split(/\//,$host);
	$host =~ s/^http:\/\///g;
	my $querytmp="/tmp/.query.$$";
	my ($state,$val);
	my $NUMSVCPROB=0;
	my $NUMSVCWARN=0;
	my $NUMSVCCRIT=0;
	my $NUMSVCUNKN=0;
	my $NUMSERVICES=0;
	my $NUMSVCOK=0;
	
	# Get all service state in one call
	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET services\nStats: state != 9999\nStatsGroupBy: state\n");
	close(OUT);

	open(CMD, "/usr/bin/nc $host 6557 < $querytmp 2>&1 |");
	while(<CMD>) {
   		chomp;
   		($state,$val)=split(/;/);
   		if($state == 0) { $NUMSVCOK=$val; }
   		if($state == 1) { $NUMSVCWARN=$val; }
   		if($state == 2) { $NUMSVCCRIT=$val; }
   		if($state == 3) { $NUMSVCUNKN=$val; }
   		
	}
	close(CMD);
    system("rm -f $querytmp");
	$NUMSVCPROB=$NUMSVCWARN+$NUMSVCCRIT+$NUMSVCUNKN;
	$NUMSERVICES=$NUMSVCPROB+$NUMSVCOK;

	# Total number of services in downtime
	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET services\nFilter: scheduled_downtime_depth > 0\nFilter: host_scheduled_downtime_depth > 0\nOr: 2\nStats: state != 9999\n");
	close(OUT);
	my $NUMSVCDOWNTIME=`/usr/bin/nc $host 6557 < $querytmp 2>&1`;
	system("rm -f $querytmp");
	chomp($NUMSVCDOWNTIME);

	print("NUMSERVICES:$NUMSERVICES NUMSVCOK:$NUMSVCOK NUMSVCWARN:$NUMSVCWARN ");
	print("NUMSVCUNKN:$NUMSVCUNKN NUMSVCCRIT:$NUMSVCCRIT NUMSVCPROB:$NUMSVCPROB NUMSVCDOWNTIME:$NUMSVCDOWNTIME\n");
	
}

sub get_hostchecks {
	my $junk;
	my $host="@_";
	($junk,$junk,$host)=split(/\//,$host);
	$host =~ s/^http:\/\///g;
	my ($state,$val);
	my $querytmp="/tmp/.query.$$";
	my $NUMHSTUP=0;
	my $NUMHSTDOWN=0;
	my $NUMHSTUNR=0;
	my $NUMHOSTS=0;
	my $NUMHSTPROB=0;

	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET hosts\nStats: state != 9999\nStatsGroupBy: state\n");
	close(OUT);

	open(CMD, "/usr/bin/nc $host 6557 < $querytmp 2>&1 |");
	while(<CMD>) {
   		chomp;
   		($state,$val)=split(/;/);
   		if($state == 0) { $NUMHSTUP=$val; }
   		if($state == 1) { $NUMHSTDOWN=$val; }
   		if($state == 2) { $NUMHSTUNR=$val; }
	}
	close(CMD);

	$NUMHOSTS=$NUMHSTUP+$NUMHSTDOWN;

	# Flapping hosts
	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET hosts\nFlapping: is_flapping > 0\nStats: is_flapping > 0");
	close(OUT);
	my $NUMHSTFLAP=`/usr/bin/nc $host 6557 < $querytmp 2>&1`;
	system("rm -f $querytmp");
	chomp($NUMHSTFLAP);

	# Total number of hosts in downtime
	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET hosts\nFilter: host_scheduled_downtime_depth > 0\nOr: 2\nStats: state != 9999\n");
	close(OUT);
	my $NUMHSTDOWNTIME=`/usr/bin/nc $host 6557 < $querytmp 2>&1`;
	system("rm -f $querytmp");
	chomp($NUMHSTDOWNTIME);

	$NUMHSTPROB=$NUMHSTDOWN+$NUMHSTFLAP;

	print("NUMHOSTS:$NUMHOSTS NUMHSTUP:$NUMHSTUP NUMHSTDOWN:$NUMHSTDOWN NUMHSTUNR:$NUMHSTUNR NUMHSTPROB:$NUMHSTPROB NUMHSTDOWNTIME:$NUMHSTDOWNTIME\n");
}

sub get_buffers {
	my $junk;
	my $host="@_";
	($junk,$junk,$host)=split(/\//,$host);
	$host =~ s/^http:\/\///g;

	my $querytmp="/tmp/.query.$$";
	my $TOTCMDBUF=0;
	my $USEDCMDBUF=0;
	my $HIGHCMDBUF=0;

	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET status\nColumns: external_command_buffer_slots external_command_buffer_usage external_command_buffer_max\n");
	close(OUT);
	
	open(CMD, "/usr/bin/nc $host 6557 < $querytmp 2>&1 |");
	while(<CMD>) {
   		chomp;
   		($TOTCMDBUF,$USEDCMDBUF,$HIGHCMDBUF)=split(/;/);
	}
	close(CMD);
        system("rm -f $querytmp");
    
	print("TOTCMDBUF:$TOTCMDBUF USEDCMDBUF:$USEDCMDBUF HIGHCMDBUF:$HIGHCMDBUF\n");
}

sub get_rates {
	my $junk;
	my $host="@_";
	($junk,$junk,$host)=split(/\//,$host);
	$host =~ s/^http:\/\///g;

	my $querytmp="/tmp/.query.$$";
	my $EXTCMDSRATE=0;
	my $FRKSRATE=0;
	my $HSTCHKSRATE=0;
	my $LOGMSGRATE=0;
	my $NEBCALLRATE=0;
	my $SRVCHKSRATE=0;

	open(OUT, ">$querytmp") || die "Can't open tmp file: $!";
	print(OUT "GET status\nColumns: external_commands_rate forks_rate host_checks_rate log_messages_rate neb_callbacks_rate service_checks_rate\n");
	close(OUT);

	open(CMD, "/usr/bin/nc $host 6557 < $querytmp 2>&1 |");
	while(<CMD>) {
		chomp;
		($EXTCMDSRATE,$FRKSRATE,$HSTCHKSRATE,$LOGMSGRATE,$NEBCALLRATE,$SRVCHKSRATE)=split(/;/);
	}
	close(CMD);
	system("rm -f $querytmp");
	
	$EXTCMDSRATE=sprintf("%0.1f", $EXTCMDSRATE);
	$FRKSRATE=sprintf("%0.1f", $FRKSRATE);
	$HSTCHKSRATE=sprintf("%0.1f", $HSTCHKSRATE);
	$LOGMSGRATE=sprintf("%0.1f", $LOGMSGRATE);
	$NEBCALLRATE=sprintf("%0.1f", $NEBCALLRATE);
	$SRVCHKSRATE=sprintf("%0.1f", $SRVCHKSRATE);

	print("EXTCMDSRATE:$EXTCMDSRATE FRKSRATE:$FRKSRATE HSTCHKSRATE:$HSTCHKSRATE LOGMSGRATE:$LOGMSGRATE NEBCALLRATE:$NEBCALLRATE SRVCHKSRATE:$SRVCHKSRATE\n");
}
