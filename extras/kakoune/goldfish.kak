# source this file from your kakrc
#  then add a binding to 'goldfish' under your user modes.
# 
# For example:
#   map global user t ':enter-user-mode goldfish<ret>'
#
# You do NEED to make cli/gfcli.fish as "gfcli" available in your path

define-command -override goldfish-edit -docstring "edit the 1st task/group" %{
 	edit -scratch *goldfish*
	set current filetype goldfish.tasks
	exec <percent>|gfcli<space>curtask<ret>
}
define-command goldfish-put -docstring "put contents of buffer as the head to goldfish" -override %{
	exec <percent>|gfcli<space>multi<space>puthead<ret>
	delete-buffer *goldfish*
}
define-command goldfish-send -docstring "send to goldfish" -params 1.. %{
	info -title "goldfish responds:" %sh{
		echo $@ | socat /tmp/goldfish.sock -
	}
}
declare-user-mode goldfish
map -docstring 'Done'      global goldfish d ':goldfish-send done<ret>'
map -docstring 'Add (nxt)' global goldfish a ':goldfish-send next '
map -docstring 'Add (btm)' global goldfish l ':goldfish-send insert '
map -docstring 'Add (top)' global goldfish A ':goldfish-send push '
map -docstring 'Join'      global goldfish j ':goldfish-send join<ret>'
map -docstring 'Pop'       global goldfish p ':goldfish-send pop<ret>'
map -docstring 'Quit'      global goldfish Q ':goldfish-send quit<ret>'
map -docstring 'Rotate O'  global goldfish R ':goldfish-send rot out<ret>'
map -docstring 'Rotate I'  global goldfish r ':goldfish-send rot in<ret>'
map -docstring 'Edit head' global goldfish e ':goldfish-edit<ret>'
map -docstring ':'         global goldfish <:> ':goldfish-send '
