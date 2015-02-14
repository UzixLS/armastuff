#!/bin/sh

PROGDIR=/opt/arma
HOMDIR=/var/games/arma/$1

if [ -z "$1" ]; then echo "Usage: $0 <servername>"; exit 1; fi
if [ ! -r "$HOMDIR" ]; then echo "$0: cannot read $HOMDIR"; exit 3; fi

touch "$HOMDIR/var/ladderlog.txt" "$HOMDIR/var/won_rounds.txt" "$HOMDIR/var/won_matches.txt"
test -e "$HOMDIR/var/commands" && rm "$HOMDIR/var/commands" ; mkfifo "$HOMDIR/var/commands"


start() {
    if pgrep -f -- "--userdatadir $HOMDIR" >/dev/null ; then
        echo "$0: $HOMDIR already in use"
        exit 2
    fi

    nice -n 2 perl -T $PROGDIR/scripts/armatop.pl --workdir="$HOMDIR/var" &
    echo -n $! >"$HOMDIR/var/pid.armatop"

    $PROGDIR/bin/armagetronad-dedicated --userdatadir "$HOMDIR" --input "$HOMDIR/var/commands" >"$HOMDIR/var/log" 2>&1 &
    echo -n $! >"$HOMDIR/var/pid.core"
}

reload() {
    test -r $HOMDIR/var/pid.core && kill -HUP `cat $HOMDIR/var/pid.core`
}

stoppid() {
    p=$1
    if [ -r $p ]; then
        for i in `seq 10`; do
            if ps `cat $p` >/dev/null; then
                kill `cat $p`
            else
                break
            fi
            sleep 1
        done
        if ps `cat $p` >/dev/null; then
            kill -9 `cat $p`
        fi
        rm $p
    fi
}

stop() {
    stoppid $HOMDIR/var/pid.armatop
    stoppid $HOMDIR/var/pid.core
    exit $1
}

trap ":;stop" TERM INT EXIT
trap ":;reload" HUP

echo -n $$ >"$HOMDIR/var/pid"

start
while jobs %2 >/dev/null 2>&1; do sleep 1; done 
stop 1
