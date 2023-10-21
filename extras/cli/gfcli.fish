#!/bin/env fish

function multiline
	echo $argv
	cat /dev/stdin
end

if test (count $argv) -lt 1
	echo "no arg given"
	exit 1
end

switch $argv[1]
	case multi
		multiline $argv[2..] | sed -e '$ ! s/^/... /' | socat /tmp/goldfish.sock -
	case chat
		while read -P "say >" r
			echo "irc chat twitch whimsicallymade" $r | socat /tmp/goldfish.sock -
		end
	case '*'
		echo $argv | socat /tmp/goldfish.sock -
end
