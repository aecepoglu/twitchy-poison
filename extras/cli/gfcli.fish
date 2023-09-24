#!/bin/env fish

function multiline
	echo $argv
	cat /dev/stdin
end

multiline $argv \
| sed -e '$ ! s/^/... /' \
| socat /tmp/goldfish.sock -
