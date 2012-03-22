#!/usr/bin/env perl -T
# Armatop v0.8 by Uzix <master@uzix.us.to>
# TODO:
# 1. case insensetive /stats
# 2. fix file::tail

use 5.010;
use strict;
use Getopt::Long;
use File::Tail;
$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';
$ENV{ENV} = '';

my $c1="0xff6633";
my $c2="0xcc9900";
my $c3="0xffee11";
my $waitint=1;
my $workdir=".";
my $mode;
my %stats;
GetOptions ("workdir=s" => \$workdir, "mode=s" => \$mode);

sub cmessage {
	my $message = $_[0];
	my $nick = $_[1];
	if ($nick) {
		print out "PLAYER_MESSAGE $nick \">> $message\"\n";
	} else {
		print out "CONSOLE_MESSAGE $message\n";
	}
	sleep 1;
}
sub cmdtop {
	my $nick=$_[1]?$_[1]:$_[0] or warn "cmdstats: no arg0" and return;
	my @top; my $ok=0; my $i=0; my $ii=0;
	open won_matches, "$workdir/won_matches.txt" or warn "File '$workdir/won_matches.txt' open failed: $!\n" and return;
	while (<won_matches>) {
		m/(?<score>\d+)\s+(?<nick>\S+)/;
		my $t_nick=$+{nick}; my $t_score=$+{score};
		$i++;
		if ($ii) { $ii++; }
		if (!$ok and $t_nick =~ /^\Q$nick\E$/i) {
			$ok=1; $ii=1; 
			push @top, "${c3}$.th) $t_nick ($t_score)";
		} else {
			push @top, "${c2}$.th) $t_nick ($t_score)"; 
		}
		if ($i>5) { $i--; shift @top; }
		if ($ii>2 and $i>4) { last; }
	}
	close won_matches;
	if ($ok) {
		&cmessage ("${c1}Top list for ${c3}$nick${c1}:".'\n\ '.join ('\n\ ',@top), $_[1]?$_[0]:"");
	} else {
		&cmessage ("${c3}$nick${c1} isn't in top list.", $_[1]?$_[0]:"");
	}
}
sub cmdstats {
	my $nick=$_[1]?$_[1]:$_[0] or warn "cmdstats: no arg0" and return;
	if (exists ($stats{$nick})) {
		&cmessage ("${c2}Stats for ${c3}$nick${c2}: ${c3}".($stats{$nick}{r} or 0)."${c2} rounds played (${c3}".sprintf ("%.0f", ($stats{$nick}{rw}/($stats{$nick}{r} or 1)*100))."${c2}% wins); ${c3}".($stats{$nick}{m} or 0)."${c2} matches played (${c3}".sprintf ("%.0f", ($stats{$nick}{mw}/($stats{$nick}{m} or 1)*100))."${c2}% wins); ${c3}".($stats{$nick}{k} or 0)."${c2} kills; ${c3}".($stats{$nick}{d} or 0)."${c2} deaths; ${c3}".sprintf("%.2f",$stats{$nick}{k}/($stats{$nick}{d} or 1))."${c2} KpD.", $_[1]?$_[0]:""); 
	} else {
		&cmessage ("${c3}$nick${c2} never played on this server.", $_[1]?$_[0]:"");
	}
}
sub rebuild {
	open rebuildlog, "$workdir/ladderlog.txt" or warn "File '$workdir/ladderlog.txt' open failed: $!\n" and return;
	while (chomp (my $line = <rebuildlog>)) {
		given ($line) {
			when (m<^DEATH_FRAG (?<who_died>\S+) (?<by_who>\S+).*>) { $stats{$+{who_died}}{'d'}++; $stats{$+{by_who}}{'k'}++; }
			when (m<^ROUND_SCORE (?<score>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'r'}++; }
			when (m<^MATCH_SCORE (?<score>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'m'}++; }
			when (m<^ROUND_WINNER (?<team>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'rw'}++; }
			when (m<^MATCH_WINNER (?<team>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'mw'}++; }
		}
	}
	close rebuildlog;
}
given ($mode) {
	when ('test') {
		open out, "|cat";
		&rebuild ();
		open ladderlog, "$workdir/ladderlog.txt" or die "File '$workdir/ladderlog.txt' open failed: $!\n";
		$c1=""; $c2=""; $c3="";
	} when ('stdio') {
		open out, ">-";
		&rebuild ();
		open ladderlog, "<-";
	} default {
		open out, ">$workdir/commands" or die "File '>$workdir/commands' open failed: $!\n";;
		&rebuild ();
		open ladderlog, "tail -n0 -f $workdir/ladderlog.txt |" or die "Pipe 'tail -n0 -f $workdir/ladderlog.txt |' open failed: $!\n";
		#my $ladderlogref=tie *ladderlog,"File::Tail",(maxinterval=>0.1,interval=>0.1,name=>"$workdir/ladderlog.txt");
	}
}
select((select(out), $|=1)[0]);

print out "CONSOLE_MESSAGE ***Armatop script loaded.\n";
while (chomp (my $line = <ladderlog>)) {
	given ($line) {
		when (m<^DEATH_FRAG (?<who_died>\S+) (?<by_who>\S+).*>) { $stats{$+{who_died}}{'d'}++; $stats{$+{by_who}}{'k'}++; }
		when (m<^ROUND_SCORE (?<score>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'r'}++; }
		when (m<^MATCH_SCORE (?<score>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'m'}++; }
		when (m<^ROUND_WINNER (?<team>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'rw'}++; }
		when (m<^MATCH_WINNER (?<team>\S+) (?<who>\S+).*>) { $stats{$+{who}}{'mw'}++; &cmdtop ($+{who}); }
		when (m<^PLAYER_ENTERED (\S+) .*>) { &cmdstats ($1); }
		when (m<^PLAYER_LEFT (\S+) .*>) { &cmdstats ($1); };
		when (m<^COMMAND /top (?:[0-9]?) ?(?<who>\S+) (?<ip>[0-9.]+) (?<level>[0-9]{1,3}) ?(?<parm>\S*) ?(?:\S*).*>) { if (!$+{parm}) { &cmdtop ($+{who}, $+{who}) } else { &cmdtop ($+{who}, $+{parm}) }; }
		when (m<^COMMAND /stats (?:[0-9]?) ?(?<who>\S+) (?<ip>[0-9.]+) (?<level>[0-9]{1,3}) ?(?<parm>\S*) ?(?:\S*).*>) { if (!$+{parm}) { &cmdstats ($+{who}, $+{who}) } else { &cmdstats ($+{who}, $+{parm}) }; }
	}
}

close ladderlog;
close out;
