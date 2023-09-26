#!/bin/env fish

function multiline
	echo $argv
	cat /dev/stdin
end

if test (count $argv) -lt 1
	echo "no arg given"
	exit 1
end

if test $argv[1] = multi
	multiline $argv[2..] \
	| sed -e '$ ! s/^/... /' \
	| socat /tmp/goldfish.sock -
else
	echo $argv
end | socat /tmp/goldfish.sock -

