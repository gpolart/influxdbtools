#!/usr/bin/perl

use strict;
use LWP::UserAgent;
use Filesys::Df;

if (scalar(@ARGV) < 3) {
    die "Usage monitoring.pl influbd_server port db_name";
}
my $url = "http://$ARGV[0]:$ARGV[1]/write?db=$ARGV[2]";


my $hostname = `hostname`;
chomp $hostname;

sub send_data {
    my ($ua, $str) = @_;

    my $req = HTTP::Request->new(POST => $url);
    $req->content_type('text/plain');
    $req->content($str);

    my $res = $ua->request($req);
    if (!$res->is_success) {
        print $res->as_string;
    }
}

my $time = time() * 1000*1000*1000;

my $user_agent = LWP::UserAgent->new;
#
# Load average
#
if (open(FILE, "/proc/loadavg")) {
    my $line = <FILE>;
    chomp $line;
    my @items = split(" ", $line);
    send_data($user_agent, "cpu_load,host=$hostname short=$items[0],mid=$items[1],long=$items[2] $time");
    close FILE;
}
#
# CPU stat (only first line)
#
open(FILE, "/proc/stat") || die "Cannot open /proc/stat";
my $line = <FILE>;
chomp $line;
$line =~ s/\s+/ /g;
my @items = split(" ", $line);
my $total = ($items[1] + $items[2] + $items[3]+ $items[4] + $items[5] + $items[7] + $items[8] + $items[9] + $items[10]) / 100;
my $str = "cpu,host=$hostname,type=user value=".$items[1]/$total." $time\n";
$str .= "cpu,host=$hostname,type=nice value=".$items[2]/$total." $time\n";
$str .= "cpu,host=$hostname,type=system value=".$items[3]/$total." $time\n";
$str .= "cpu,host=$hostname,type=idle value=".$items[4]/$total." $time\n";
$str .= "cpu,host=$hostname,type=iowait value=".$items[5]/$total." $time\n";
$str .= "cpu,host=$hostname,type=irq value=".$items[6]/$total." $time\n";
$str .= "cpu,host=$hostname,type=softirq value=".$items[7]/$total." $time\n";
$str .= "cpu,host=$hostname,type=steal value=".$items[8]/$total." $time\n";
$str .= "cpu,host=$hostname,type=guest value=".$items[9]/$total." $time\n";
$str .= "cpu,host=$hostname,type=guest_nice value=".$items[10]/$total." $time";
send_data($user_agent, $str);
close FILE;
#
# Meminfo
#
open(FILE, "/proc/meminfo") || die "Cannot open /proc/meminfo";
my $line;
my @strs;
while ($line = <FILE>) {
    chomp $line;
    $line =~ /([^:]*):(\s+)([0-9]+)/;
    if ($1 eq 'MemTotal') {
        push @strs, "meminfo,host=$hostname,type=total value=$3 $time";
    }
    elsif ($1 eq 'MemFree') {
        push @strs, "meminfo,host=$hostname,type=free value=$3 $time";
    }
    elsif ($1 eq 'Buffers') {
        push @strs, "meminfo,host=$hostname,type=buffers value=$3 $time";
    }
    elsif ($1 eq 'Cached') {
        push @strs, "meminfo,host=$hostname,type=cached value=$3 $time";
    }
}
if (scalar(@strs) > 0) {
    send_data($user_agent, join("\n", @strs));
}
close FILE;
#
# Disk free
#
my $dh;
opendir($dh, "/") || die "Cannot open root directory";
while(my $d = readdir($dh)) {
    if ($d =~ /^volume/ && -d "/$d") {
        my $df = df("/$d");
        send_data($user_agent, "disk_free,host=$hostname,dir=$d blocks=$df->{blocks},bfree=$df->{bfree},bavail=$df->{bavail},used=$df->{used},pcent=$df->{per} $time");
    }
}
closedir($dh);
#
# Diskstats
#
open(FILE, "/proc/diskstats") || die "Cannot open /proc/diskstats";
my $line;
while ($line = <FILE>) {
    chomp $line;
    $line =~ s/\s+/ /g;
    my @items = split(" ", $line);
    # only mappers for main volumes and disks ...
    if ($items[2] =~ /^dm-|^sd/) {
        my $val = 512 * $items[3];
        send_data($user_agent, "diskstats,host=$hostname,disk=$items[2],type=read value=$val $time");
        my $val = 512 * $items[7];
        send_data($user_agent, "diskstats,host=$hostname,disk=$items[2],type=write value=$val $time");
    }
}
close FILE;
#
# Network
#
open(FILE, "/proc/net/dev") || die "Cannot open /proc/diskstats";
my $line;
$line = <FILE>;
$line = <FILE>; # drop header 2 lines
while ($line = <FILE>) {
    chomp $line;
    $line =~ /([^:]*):(.*)/;
    my $if = $1;
    my $data = $2;
    $if =~ s/^\s+//;
    $if =~ s/^\s+$//;
    $data =~ s/\s+/ /g;
    my @items = split(" ", $data);
    send_data($user_agent, "network,host=$hostname,interface=$if,instance=bytes_recv value=$items[0] $time");
    send_data($user_agent, "network,host=$hostname,interface=$if,instance=bytes_send value=$items[8] $time");
}
close FILE;
#

