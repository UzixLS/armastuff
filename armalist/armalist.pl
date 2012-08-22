#!/usr/bin/env perl
# Armagetron server list v0.2
# Eugene Uzix <uzix.ls@gmail.com>

use 5.010;
use strict;
use Getopt::Long;
use WWW::Curl::Easy;
use XML::Simple;
use Encode;

my $curl = WWW::Curl::Easy->new;
my $response_body;
my $retcode;
my %servers;
my $html = 0;
my $noempty = 0;

GetOptions ("html" => \$html, "noempty" => \$noempty);

sub process {
	my $temp = join ' ', @_;
	Encode::from_to($temp, 'ISO_8859-1', 'UTF-8');
	$temp =~ s/0x......//g;
	$temp =~ s/^\ *//g;
	if ($html) {
		$temp =~ s/</&lt;/g;
		$temp =~ s/>/&gt;/g;
	}
	return $temp;
}

$curl->setopt(CURLOPT_HEADER, 0);
$curl->setopt(CURLOPT_URL, 'http://simamo.de/~manuel/arma-serverlist.js/serverxml.php');
$curl->setopt(CURLOPT_WRITEDATA, \$response_body);

$retcode = $curl->perform;
if ($retcode != 0) {
	die ("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
}

my $serverlist = XMLin($response_body);

for my $i (keys $serverlist->{'Server'}) {
	my $sname = &process($i);
	while (defined($servers{$sname})) { $sname = $sname . "_"; }
	if (defined $serverlist->{'Server'}->{$i}->{'Player'}) {
		for my $ii (keys $serverlist->{'Server'}->{$i}->{'Player'}) {
			if (ref($serverlist->{'Server'}->{$i}->{'Player'}->{$ii}) eq "HASH" &&
				defined $serverlist->{'Server'}->{$i}->{'Player'}->{$ii}->{'global_id'}) {
				push @{$servers{$sname}{players}},
					$serverlist->{'Server'}->{$i}->{'Player'}->{$ii}->{'global_id'}; 
			} else {
				push @{$servers{$sname}{players}}, &process($ii);
			}
		}
	} else {
		if ($noempty) { next; }
		else { @{$servers{$sname}{players}} = (); }
	}
	
	$servers{$sname}{addr}  = $serverlist->{'Server'}->{$i}->{'ip'}.
						  ':'.$serverlist->{'Server'}->{$i}->{'port'};
	$servers{$sname}{descr} = &process($serverlist->{'Server'}->{$i}->{'description'});
	$servers{$sname}{url}   = &process($serverlist->{'Server'}->{$i}->{'url'});
	$servers{$sname}{ver}   = $serverlist->{'Server'}->{$i}->{'version'};
	$servers{$sname}{maxpl} = $serverlist->{'Server'}->{$i}->{'maxplayers'};
	$servers{$sname}{numpl} = $serverlist->{'Server'}->{$i}->{'numplayers'};
	unless ($servers{$sname}{url} =~ /^http:/) { $servers{$sname}{url} =~ s/(.*)/http:\/\/\1/; }
}
if ($html) {
	print '
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
	<html xmlns="http://www.w3.org/1999/xhtml">
	  <head>
		<title>Armagetron server list</title>
		<meta http-equiv="content-type" content="text/html;charset=utf-8" />
		<link rel="stylesheet" type="text/css" href="serverlist.css" />
	  </head>
	  <body>
	  <table><tr>
		<th>Server Name</th>
		<th>Address</th>
		<th>Players</th>
	  </tr>';
	for my $i (sort {"\L$a" cmp "\L$b"} keys %servers) {
		print "
		<tr>
			<td><a href='$servers{$i}{url}'>$i</a></td>
			<td>$servers{$i}{addr}</td>
			<td>". join (', ', @{$servers{$i}{players}}) ."</td>
		</tr>\n";
	}
	print '</table></body></html>';
}
else {
	for my $i (sort {"\L$a" cmp "\L$b"} keys %servers) {
		print "$i ### $servers{$i}{addr} ### ". join (', ', @{$servers{$i}{players}}) ."\n";
	}
}
