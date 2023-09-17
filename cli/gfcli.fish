#!/bin/env fish

function task_add
	echo add $argv | socat /tmp/goldfish.sock -
end
function task_del
	echo del | socat /tmp/goldfish.sock -
end
function task_join
	echo join | socat /tmp/goldfish.sock -
end
function task_disband
	echo disband | socat /tmp/goldfish.sock -
end
function task_dump
	echo curtask | socat /tmp/goldfish.sock -
end

if test (count $argv) -lt 1
	echo "supply a command"
	exit 1
end

function multiline
	echo $argv[1]
	cat /dev/stdin
end

switch $argv[1]
case "puthead"
	multiline puthead | socat /tmp/goldfish.sock -
case "dump"
	task_dump
case "add"
	task_add $argv[2..]
case "del"
	task_del
case "join"
	task_join
case "*"
	echo "unknown command"
end
