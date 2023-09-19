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
	alias window w goldfish-put
	exec "%|gfcli curtask"
}
define-command goldfish-put -docstring "put contents of buffer as the head to goldfish" -params 2.. %{
	alias "%|gfcli puthead"
	nop %sh{ x="$1 $2"; shift 2; y=$(printf "\n%s" "$@"); printf "$x$y" | tr "\n" "\0" | sed "s/$/\n/" >> /tmp/goldfish.sock}
}
define-command goldfish-send -docstring "send to goldfish" -params 1.. %{
	info -title "goldfish responds:" %sh{
		echo $@ | socat /tmp/goldfish.sock -
	}
}
declare-user-mode goldfish
map -docstring 'Done'      global goldfish d ':goldfish-send done<ret>'
map -docstring 'Add'       global goldfish a ':goldfish-send add '
map -docstring 'Join'      global goldfish j ':goldfish-send join<ret>'
map -docstring 'Quit'      global goldfish Q ':goldfish-send quit<ret>'
map -docstring 'Refresh'   global goldfish r ':goldfish-send refresh<ret>'
map -docstring 'Edit head' global goldfish e ':goldfish-edit<ret>'
map -docstring ':'         global goldfish <:> ':goldfish-send '
