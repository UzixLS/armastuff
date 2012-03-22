#!/usr/bin/env bash
# Run script for armagetron server.

PROGDIR=/opt/arma
HOMDIR=/var/games/arma/$2
#test $(id -u) = 0 && su armagetron

case "$1" in
	start|stop|restart|rehash|status)
		if [ -z "$2" ]; then echo "Please, give me servername."; exit 1; fi
		if [ ! -r "$HOMDIR" ]; then echo "Cannot read $HOMDIR"; exit 3; fi
		;;
esac; case "$1" in
	status)
		echo "Status for armagetron ($2): "
		echo -n ' Server: '
		if [ ! -r "$HOMDIR/var/pid" ]; then echo "cannot read PID file ($HOMDIR/var/pid)"; exit 2; fi
		echo -n $(cat "$HOMDIR/var/pid")" "
		if [ -r /proc/$(cat "$HOMDIR/var/pid") ]; then echo "ok"; else echo "fail"; fi

		echo -n ' Armatop: '
		if [ ! -r "$HOMDIR/var/pid.armatop" ]; then echo "cannot read PID file ($HOMDIR/var/pid.armatop)"; exit 2; fi
		echo -n $(cat "$HOMDIR/var/pid.armatop")" "
		if [ -r /proc/$(cat "$HOMDIR/var/pid") ]; then echo "ok"; else echo "fail"; fi
		;;
	stop)
		echo -n "Stopping armagetron ($2): "
		if [ ! -r "$HOMDIR/var/pid" ]; then
			echo "Cannot read PID file ($HOMDIR/var/pid)"
			exit 2
		fi
		echo -n $(cat "$HOMDIR/var/pid")" "
		kill $(cat "$HOMDIR/var/pid") 2>/dev/null
		if [ ! -r "$HOMDIR/var/pid.armatop" ]; then
			echo "Cannot read PID file ($HOMDIR/var/pid.armatop)"
			exit 2
		fi
		echo -n $(cat "$HOMDIR/var/pid.armatop")" "
		kill $(cat "$HOMDIR/var/pid.armatop") 2>/dev/null
		echo .
		;;
	start)	
		echo -n "Starting armagetron ($2): "
		touch "$HOMDIR/var/ladderlog.txt" "$HOMDIR/var/won_rounds.txt" "$HOMDIR/var/won_matches.txt"
		test -e "$HOMDIR/var/commands" && rm "$HOMDIR/var/commands" ; mkfifo "$HOMDIR/var/commands"

		nice -n 2 perl -T $PROGDIR/scripts/armatop.pl --workdir="$HOMDIR/var" &
		echo -n "$! "; echo -n $! >"$HOMDIR/var/pid.armatop"

		while true; do
			env LD_LIBRARY_PATH=/opt/arma/lib/ $PROGDIR/bin/armagetronad-dedicated --userdatadir "$HOMDIR" --input "$HOMDIR/var/commands" >"$HOMDIR/var/log" 2>&1 &
			trap "kill %1; exit;" TERM INT
			trap "kill -HUP %1; wait %1;" HUP
			wait %1
			sleep 3
		done &
		echo -n "$! "; echo -n $! >"$HOMDIR/var/pid"
		
		echo .
		;;
	restart)
		"$0" stop "$2" && "$0" start "$2"
		;;
	rehash)
		echo -n "Rehashing armagetron ($2): "
		if [ ! -r "$HOMDIR/var/pid" ]; then
			echo "Cannot read PID file ($HOMDIR/var/pid)"
			exit 2
		fi
		echo -n $(cat "$HOMDIR/var/pid")" "
		kill -HUP $(cat "$HOMDIR/var/pid") 2>/dev/null
		echo .
		;;
	*)
		echo "Unknown parameters. Try to use \"$0 <start|stop|restart|rehash|status> <servername>\""
		;;
esac
