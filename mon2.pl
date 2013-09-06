#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
#use File::Tee qw(tee);

# TODO: the following needs to be impimented still-
# overtemp check and handling
# GPU dropped detection and handling
# hypernova monitor - curl -s https://hypernova.pw/api/key/4fc00e01cfd5f9af1f5bc11a92a0948a1640e6e102b4ff3367ed106f7e267116/ | python -m json.tool

my $homedir = "/home/januszeal";
my $monlog = "$homedir/.mon.log";
my $fivefile = "$homedir/.five";
my $defaultcoin = "btc";
my $humanreadable = 0;
my $debuglog = 0;

if ( -e "$homedir/.devstop" ) {
  exit 100;
}

if ( ! -e "$homedir/mine_bitcoins.sh" ) {
  print "[!] $homedir/mine_bitcoins.sh doesn't exist, exiting.\n";
  exit 6
}

if ( ! -e "$homedir/mine.sh" ) {
  open( OUTPUT, q{>}, "$homedir/mine.sh" );
print OUTPUT <<EOT;
#!/bin/bash
DEFAULT_DELAY=0
if [ "x\$1" = "x" -o "x\$1" = "xnone" ]; then
   DELAY=\$DEFAULT_DELAY
else
   DELAY=\$1
fi
sleep \$DELAY

#if [ -z \$(pgrep minerd) ] && [ ! -e \$homedir/.disableminerd ]; then
#	echo "started ltc CPU mining in screen minerd"
#	screen -dmS minerd \$homedir/minerd -t 1 --url http://mining.usa.dallas.hypernova.pw:9332 --userpass januszeal.madokacpu:gsdfgdsfgs
#else
#	echo "minerd already running or minerd disabled."
#fi
#
if [ \$(pgrep cgminer) ]; then
	echo "cgminer already running"
	exit 1
fi

#if [ -e /home/januszeal/.ltc ]; then
#	echo "started ltc GPU mining in screen cgml"
#	screen -dmS cgml /home/januszeal/mine_litecoins.sh
#elif [ -e /home/januszeal/.btc ]; then
	echo "started btc mining in screen cglb"
	screen -dmS cgmb \$homedir/mine_bitcoins.sh
#fi

#if [ ! -e /home/januszeal/.ltc ] && [ ! -e /home/januszeal/.btc ]; then
#	# defaulting to ltc
#	echo "state files don't exist, defaulting to ltc GPU mining. Creating .ltc and restarting..."
#	touch /home/januszeal/.ltc
#	/home/januszeal/mine.sh &
#fi
EOT
  close(OUTPUT);
}

sub teelog {
  #print $_;
  open (TEE, "| tee -ai $monlog");
  my $ts = timestamp();
  print TEE "$ts $_[0]\n";
  close (TEE);
}

sub timestamp {
  return "[".scalar localtime."]";
}

if ( -e "$homedir/.stop" ) {
  if ( system("pidof cgminer") ) {
    teelog("warning: stopfile detected. Attempting to kill cgminer, this will fail/be pointless if the GPU is locked up.");
    system("killall cgminer");
    sleep 10;
    system("killall -9 cgminer");
    sleep 10;
    if ( system("pidof cgminer") ) {
      teelog("error: cgminer still running. Initiating ordered system reboot.");
      system("sudo reboot");
    } else {
      teelog("warning: stopfile detected.");
    }
    exit 10;
  }
}

my $tempfile = `mktemp -p /dev/shm`;
chomp $tempfile;
my $mtype = "b";

#if ( -e "$homedir/.ltc" ) {
#  $mtype = "l";
#} elsif ( -e "$homedir/.btc" ) {
#  $mtype = "b";
#} else {
#  teelog("error: no coin preference defined, assuming $defaultcoin and restarting...");
#  system("touch $homedir/.$defaultcoin");
#  exit 2
#}

system("screen -S cgm" . $mtype . " -p 0 -X hardcopy $tempfile");
if ( $? != 0 ) {
  teelog("error: screen cgm" . $mtype  . " does not appear to be running! Attempting restart...");
  system("$homedir/mine.sh 15");
  exit 1;
} elsif ( -z $tempfile ) {
  # the idea here is to have it retry, I'll have to create a readScreen() subroutine first, so for now, error out.
  teelog("error: screen is running but failed to return any data.");
}

if ( $debuglog == 1 ) {
  my $unixtime = time;
  # this system() call needs to be re-written in perl at some point
  system("cp $tempfile $homedir/.mondebug/$unixtime.$mtype.screendump");
}

open(DAT, $tempfile);
my @raw = <DAT>;
close(DAT);
unlink $tempfile;
my (@gpus, @temp, @fan, @hashrate, @accepted, $hashavg);
for my $array_ref (@raw) {
# if ( my @gpu = ( $array_ref =~ m!^ GPU \d+:\s+(\d+)\.\dC (\d+)RPM \| \d+\.\d./(\d+)\.\d.+ \| A:(\d+)!g ) ) {
  if ( my @gpu = ( $array_ref =~ m!^ AMU \d+:\s+\| \d+\.\d./(\d+)\.\d.+ \| A:(\d+)!g ) ) {
    push(@gpus, \@gpu);
  } 
}

for my $array_ref (@gpus) {
  push (@temp, $array_ref->[0]);
  push (@fan, $array_ref->[1]);
  push (@hashrate, $array_ref->[2]);
  push (@accepted, $array_ref->[3]);
}

my $logentry;
my $sumaccepted = eval(join('+', @accepted));
my $numgpus = scalar @gpus;
my $listhashes = join(",", @hashrate);
my $listtemps = join(",", @temp);
my $listfans = join(",", @fan);

if ( $humanreadable == 1 ) {
  $logentry = "accepted $sumaccepted from $numgpus devices mining ${mtype}tc - hashrates: [ $listhashes ]"; #, temps: [ $listtemps ], fans: [ $listfans ]";
} else {
  $logentry = "TA:${sumaccepted}|Gs:${numgpus}|Coin:${mtype}tc|Hs:${listhashes}"; #|Ts:${listtemps}|Fs:${listfans}";
}

teelog($logentry);

exit 0;
