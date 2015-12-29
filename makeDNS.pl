#!/usr/bin/perl -w

# Copyright (c) 1999, 2015 Ross A. Hamilton <ross@rah.org>

# User configuration block

my $dom="home.rah.org";			# DNS domain for zone
my $priserver="services";		# Primary server name for SOA
my $mailaddr="hostmaster.rah.org";	# e-mail address for SOA

# Test Directories
my $dir="./test/named";			# Output directory
my $hostfile="./test/hosts";	# Hosts file to source

# Prod Directories
#my $dir="/var/named";			# Output directory
#my $hostfile="/etc/hosts";		# Hosts file to source

# End of user configuration block

use strict;
use Getopt::Std;

# Globals
my ($snum, %revaddr, %haddr, %cnamelist);

sub print_header {

	# Standard header for all zones

	print DBFILE "@\t\t\tIN\tSOA\t$priserver $mailaddr (\n";
	print DBFILE "\t\t\t\t$snum\t; serial\n";
	print DBFILE "\t\t\t\t1800\t; refresh\n";
	print DBFILE "\t\t\t\t900\t; retry\n";
	print DBFILE "\t\t\t\t604800\t; expire\n";
	print DBFILE "\t\t\t\t86400 )\t; minimum\n\n";
}

sub include_header {

	my $srcfile = shift;

	if (open SRCFILE, $dir . "/include/" . $srcfile) {
		while (<SRCFILE>) {
			print DBFILE;
		}
		print DBFILE "\n";
		close SRCFILE;
	} else {
		print STDERR
			"include_header: WARN: can't open header $srcfile\n";
	}
}

sub gen_revision {

	open REVFILE, "< $dir/.revfile"
		|| die "gen_revision: can't open revision file $dir/.revfile\n";
	$_ = (<REVFILE>);
	chop;
	my ($oldyr,$oldmonth,$oldday,$oldversion)=unpack("a4a2a2a2", $_);
	close REVFILE;

	my @arr = gmtime();
	if(($arr[5]+1900 == $oldyr)
		&& ($arr[4]+1 == $oldmonth)
		&& ($arr[3] == $oldday)) {

		$snum  = "0" x (4-length($oldyr)) . $oldyr;
		$snum .= "0" x (2-length($oldmonth)) . $oldmonth;
		$snum .= "0" x (2-length($oldday)) . $oldday;
		$snum .= "0" x (2-length(++$oldversion)) . $oldversion;
	} else {
		$snum  = "0" x (4-length($arr[5] + 1900)) . ($arr[5] + 1900);
		$snum .= "0" x (2-length($arr[4] + 1)) . ($arr[4] + 1);
		$snum .= "0" x (2-length($arr[3])) . $arr[3];
		$snum .= "00";
	}

	open REVFILE, "> $dir/.revfile"
		|| die "gen_revision: can't open revision file $dir/.revfile\n";
	print REVFILE "$snum\n";
	close REVFILE;
}

sub handle_cnames {

	my ($priname, $othernames) = @_;

	my @cnames = split "\\s+", $othernames;

	foreach my $cname (@cnames) {
		if (!($cname =~ /\./)) {
			$cnamelist{$cname} = $priname;
		} 
	}
}

sub create_host {

	my ($ip, $names) = @_;

	my ($priname, $othernames) = ($names =~ m/(\S+)\s*(.*)/);
	my ($a1, $a2, $a3, $a4) = ($ip =~ m/(\d+)\.(\d+)\.(\d+)\.(\d+)/);

	if (!($priname =~ m/(\.$)/)) {
		$revaddr{$a1}{$a2}{$a3}{$a4} = "$priname" . "." . $dom . ".";
		push @{$haddr{$priname}}, $ip;
		handle_cnames("$priname" . "." . $dom . "." , $othernames);
	} else {
		$revaddr{$a1}{$a2}{$a3}{$a4} = "$priname" . ".";
		handle_cnames("$priname" . ".", $othernames);
	}
}

sub output_rev {

	my ($a1, $a2, $a3) = @_;

	my $dbfile = $dir
		. "/" . $a3 . "." . $a2 . "." . $a1 . "." . "in-addr.arpa";
	my $dbfile_new = $dbfile." . new";

	open DBFILE, "> $dbfile_new" || die "can't open output zonefile";
	print_header;
	include_header ("reverse");

	foreach my $a4 (sort keys %{$revaddr{$a1}{$a2}{$a3}}) {
		print DBFILE "$a4\tIN\tPTR\t";
		print DBFILE "$revaddr{$a1}{$a2}{$a3}{$a4}";
		print DBFILE "\n";
	}
	close DBFILE;
	rename $dbfile_new, $dbfile;
}

sub output_zone {

	my $zonefile = "$dir/$dom";
	my $zonefile_new = "$zonefile.new";
	open DBFILE, "> $zonefile_new" || die "can't open output zonefile";

	print_header;
	include_header ("forward");

	# Print A records
	print DBFILE ";;\n;; A records\n;;\n";
	foreach my $name (sort keys %haddr) {
		print DBFILE $name;
		foreach my $addr (@{$haddr{$name}}) {
			print DBFILE "\tIN\tA\t$addr\n";
		}
	}

	# Print CNAMES
	print DBFILE ";;\n;; CNAME records\n;;\n";
	foreach my $name (sort keys %cnamelist) {
		print DBFILE "$name\tIN\tCNAME\t$cnamelist{$name}\n";
	}

	close DBFILE;

	rename $zonefile_new, $zonefile;
}

open HOSTS, "<$hostfile" || die "can't open host file";

# Read in the hosts file
while (<HOSTS>) {

	chomp;
	next if m/^(\#|\D|$)/;

	my ($validpart, $comment) = split "#";
	my ($ip, $names) = ($validpart =~ m/(\S+)\s+(.*)/);
	my @ips = split ",", $ip;

	foreach $ip (@ips) {
		create_host ($ip, $names);
	}
}

close HOSTS;

gen_revision;
output_zone;

# Print reverse zones
foreach my $a1 (keys %revaddr) {
	foreach my $a2 (keys %{$revaddr{$a1}}) {
		foreach my $a3 (keys %{$revaddr{$a1}{$a2}}) {
			output_rev ($a1, $a2, $a3);
		}
	}
}
