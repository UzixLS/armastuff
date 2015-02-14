#!/usr/bin/env perl
# Armagetron server list v0.3
# Eugene Uzix <uzix.ls@gmail.com>

use 5.010;
use strict;
use POSIX qw(strftime);
use Getopt::Long;
use WWW::Curl::Easy;
use Encode;
$ENV{XML_SIMPLE_PREFERRED_PARSER} = 'XML::Parser';
use XML::Simple;

my $debug = 0;
my $noempty = 0;
my $watch = 0;
my $html = 0;
my $stdout = 0;
my $file = 'armalist.xml';
my $logfile = 'armalist.log';
my $url;
my @urls = (
	'http://crazy-tronners.com/grid/serverxml.php',
    'http://browser.hashpickup.net/serverxml.xml',
	'http://simamo.de/~manuel/arma-serverlist.js/serverxml.php',
	'http://wrtlprnft.ath.cx/serverlist/serverxml.php',
);

GetOptions (
	"debug" => \$debug,
	"noempty" => \$noempty,
	"watch" => \$watch,
	"html" => \$html,
	"stdout" => \$stdout,
	"url=s" => \$url,
	"file=s" => \$file,
	"logfile=s" => \$logfile,
	);


sub process
{
	my $string = join ' ', @_;
	Encode::from_to($string, 'ISO_8859-1', 'UTF-8');
	$string =~ s/0x......//g;
	$string =~ s/^\ *//g;
	if ($html) {
		$string =~ s/</&lt;/g;
		$string =~ s/>/&gt;/g;
	}
	return $string;
}

sub read_inet
{
	my ($inurl, $outfile) = @_;
	my $curl = WWW::Curl::Easy->new;
	my $response_body;
	my $retcode;

	print "Fetching $inurl...\n" if $debug;
	$curl->setopt(CURLOPT_HEADER, 0);
	$curl->setopt(CURLOPT_URL, $inurl);
	$curl->setopt(CURLOPT_WRITEDATA, \$response_body);
	
	$retcode = $curl->perform;
	if ($retcode != 0) {
		die ("Curl error $retcode: ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
	}
	print "...done\n" if $debug;

	XMLin($response_body, ForceArray => 1, parseropts => [ load_ext_dtd => 0 ]) or die "Incorrect HTTP data";

	if ($outfile) {
		print "Writting file $outfile\n" if $debug;
		open my $out, '>', $outfile or die "Cannot open file $outfile: $!\n";
		print $out $response_body;
		close $out;
	}

	return XMLin($response_body, ForceArray => 1, parseropts => [ load_ext_dtd => 0 ]);
}

sub read_file
{
	my $in = shift;
	print "Reading file $in\n" if $debug;
	return (XMLin($in, ForceArray => 1, parseropts => [ load_ext_dtd => 0 ]) or die "Incorrect file data");
}

sub bold
{
	if ($html) {
		return "<b>@_</b>";
	} else {
		return "@_";
	}
}

sub endl
{
	if ($html) {
		return "<br>\n";
	} else {
		return "\n";
	}
}

sub print_html_header
{
	print '
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
	<html xmlns="http://www.w3.org/1999/xhtml">
	  <head>
		<title>Armagetron server list script</title>
		<meta http-equiv="content-type" content="text/html;charset=utf-8" />
		<link rel="stylesheet" type="text/css" href="serverlist.css" />
	  </head>
	  <body>
';

}

sub print_html_footer
{
	print '
	  </body>
	 </html>
';
}

sub print_html
{
	my $servers = shift;
	&print_html_header;
	print '
	  <table><tr>
		<th>Server Name</th>
		<th>Address</th>
		<th>Players</th>
	  </tr>';
	for my $i (sort {"\L$a" cmp "\L$b"} keys %{$servers}) {
		print "
		<tr>
			<td><a href='$servers->{$i}{url}'>$i</a></td>
			<td>$servers->{$i}{addr}</td>
			<td>". join (', ', @{$servers->{$i}{players}}) ."</td>
		</tr>\n";
	}
	print '</table>';
	&print_html_footer;
}

sub print_plain
{
	my $servers = shift;
	for my $i (sort {"\L$a" cmp "\L$b"} keys %{$servers}) {
		print "$i ### $servers->{$i}{addr} ### ". join (', ', @{$servers->{$i}{players}}) ."\n";
	}
}

sub compare_log
{
	my ($old, $new, $outfile) = @_;
	my $time = strftime "%Y/%m/%d %H:%M", gmtime;
	if ($html) {
		$time = "<i>$time</i>";
	}
	print "Comparing server lists\n" if $debug;
	
	print "Open file $outfile\n" if $debug;
	my $out;
	if ($stdout) {
		open $out, '>-';
	} else {
		open $out, '>>', $outfile or die "Cannot open file $outfile: $!\n";
	}

	if (! keys %{$new}) {
		print $out "$time: Error upgrading server list.".&endl;
		die "$time: error upgrading server list.";
	}
	if (! keys %{$old}) {
		print "No old data found\n" if $debug;
		print $out "$time: Start watching.".&endl;
	}
	
	my @whoremoved = grep { ! ($_ ~~ @{[keys %{$new}]}) } keys %{$old};
	print $out "$time: Server ".&bold($_)." offline".&endl for sort @whoremoved;

	my @whoadded = grep { ! ($_ ~~ @{[keys %{$old}]}) } keys %{$new};
	print $out "$time: Server ".&bold($_)." on ".&bold($new->{$_}{addr})." online".&endl for sort (@whoadded);

	for my $sname (keys %{$new}) {
		if (defined $old->{$sname}) {
			for (qw/addr descr url ver maxpl/) {
				if (! ($old->{$sname}{$_} ~~ $new->{$sname}{$_})) {
					print $out "$time: Server ".&bold($sname)." changed ".&bold($_).
						" from ".&bold($old->{$sname}{$_})." to ".&bold($new->{$sname}{$_}).&endl;
				}
			}
		}
	}

	my %playerlist;
	for my $s ($old, $new) {
		for my $sname (sort keys %{$s}) {
			for my $pname (@{$s->{$sname}{players}}) {
				if ($pname ~~ %playerlist && defined $playerlist{$pname}{$s}) {
					print $out "$time: Clones for ".&bold($pname)." detected on ".
						&bold($playerlist{$pname}{$s})." and ".&bold($sname).&endl if ($s == $new);
					$pname .= '_' while (defined $playerlist{$pname}{$s});
				}
				$playerlist{$pname}{$s} = $sname;
			}
		}
	}
	for my $pname (keys %playerlist) {
		if (! defined $playerlist{$pname}{$old}) {
			print $out "$time: Player ".&bold($pname)." joined to server ".&bold($playerlist{$pname}{$new}).&endl;
		} elsif (! defined $playerlist{$pname}{$new}) {
			print $out "$time: Player ".&bold($pname)." left from server ".&bold($playerlist{$pname}{$old}).&endl;
		} elsif (! ($playerlist{$pname}{$old} ~~ $playerlist{$pname}{$new})) {
			print $out "$time: Player ".&bold($pname)." moved from server ".
				&bold($playerlist{$pname}{$old})." to server ".&bold($playerlist{$pname}{$new}).&endl;
		}
	}

	print "Comparing complete\n" if $debug;
	close $out;
}

sub fill_serverhash
{
	my $serverlist = shift;
	my %servers;

	for my $i (keys $serverlist->{'Server'}) {
		my $sname = &process($i);
		while (defined($servers{$sname})) { $sname = $sname . "_"; }
		if (defined $serverlist->{'Server'}->{$i}->{'Player'}) {
			for my $ii (keys $serverlist->{'Server'}->{$i}->{'Player'}) {
				if (ref($serverlist->{'Server'}->{$i}->{'Player'}->{$ii}) eq "HASH" &&
					defined $serverlist->{'Server'}->{$i}->{'Player'}->{$ii}->{'global_id'}) {
					push @{$servers{$sname}{players}},
						&process($ii)."($serverlist->{'Server'}->{$i}->{'Player'}->{$ii}->{'global_id'})";
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
	return %servers;
}

print "Starting " if $debug;

$url = $urls[0] if (length($url) < 1);

if ($watch) {
	print "watcher\n" if $debug;
	my %savedservers = &fill_serverhash (&read_file ($file)) if (-r $file);
	my %activservers = &fill_serverhash (&read_inet ($url, $file));
	&compare_log (\%savedservers, \%activservers, $logfile);
} else {
	print "lister\n" if $debug;
	my %activservers = &fill_serverhash (&read_inet ($url));
	$html && &print_html(\%activservers) || &print_plain(\%activservers);
}

print "Stopping.\n" if $debug;
