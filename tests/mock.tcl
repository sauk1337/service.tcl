# Simulated Eggdrop commands for the tests (no IRC connection needed).
set botnick TestBot; set botname TestBot!bot@test.users.quakenet.org; set server irc.quakenet.org:6667
set ::sent {}
foreach c {putserv putquick puthelp putnow} { proc $c {args} "lappend ::sent \[lindex \$args 0\]; return {}" }
# bind records {type flags mask proc} so tests can fire binds like Eggdrop does
set ::mockbinds {}
proc bind {type flags mask cmd} { lappend ::mockbinds [list $type $flags $mask $cmd]; return $mask }
foreach c {unbind putlog putloglev save pushmode flushmode killchanban newban newchanban utimer timer chattr adduser killban killutimer putallbots putbot rehash} { proc $c args { return "" } }
proc utimers {} { return {} }
proc bots {} { return {} }
proc channels {} { return {#test} }
proc userlist args { return {owner} }
proc binds args { return {} }
proc botonchan args { return 1 }
proc botisop args { return 1 }
proc botisvoice args { return 0 }
proc ischanban args { return 0 }
proc isban args { return 0 }
proc ispermban args { return 0 }
proc onchan args { return 1 }
proc isop args { return 0 }
proc isvoice args { return 0 }
proc isbotnick n { string equal -nocase $n $::botnick }
proc validuser h { expr {$h eq "owner"} }
proc validchan c { expr {[string index $c 0] eq "#"} }
proc matchattr args { expr {[lindex $args 0] eq "owner"} }
proc nick2hand args { expr {[string equal -nocase [lindex $args 0] Owner] ? "owner" : "*"} }
proc hand2nick args { return Owner }
proc finduser args { return * }
proc getchanhost args { return ~user@host.example.com }
proc getchanjoin args { return [clock seconds] }
proc chanlist args { return {Owner TestBot Q Bob} }
proc chanbans args { return {} }
proc banlist args { return {} }
proc getchanmode args { return "+nt" }
proc unixtime {} { clock seconds }
proc duration s { return "${s}s" }
proc stripcodes {f t} { return $t }
proc rand n { return 0 }
proc die args { error "die $args" }
array set ::xtra {}
proc getuser {h type args} { if {![validuser $h]} { error "No such user." }; if {$type eq "XTRA"} { set k $h,[lindex $args 0]; return [expr {[info exists ::xtra($k)] ? $::xtra($k) : ""}] }; if {$type eq "HOSTS"} { return {*!*@owner.users.quakenet.org} }; return "" }
proc setuser {h type args} { if {$type eq "XTRA"} { set ::xtra($h,[lindex $args 0]) [lindex $args 1] } }
array set ::chanset {}
proc channel {sub args} {
	switch -- $sub {
		get { set k [lindex $args 0],[lindex $args 1]; if {[info exists ::chanset($k)]} { return $::chanset($k) }; if {[info exists ::udef([lindex $args 1])] && $::udef([lindex $args 1]) eq "str"} { return "" }; return 0 }
		set { set v [lindex $args 2]; set name [lindex $args 1]; if {[regexp {^([+-])(.*)$} $name -> s n] && [llength $args] == 2} { set ::chanset([lindex $args 0],$n) [expr {$s eq "+"}] } else { set ::chanset([lindex $args 0],$name) $v } }
	}
	return ""
}
proc pwd {} { return . }

array set ::udef {}
proc setudef {type name} { set ::udef($name) $type }

# CI has no service.conf (it is git-ignored): use the example
set ::mockroot [file normalize [file join [file dirname [info script]] ..]]
if {![file exists [file join $::mockroot service.conf]]} {
	file copy [file join $::mockroot service.conf.example] [file join $::mockroot service.conf]
}

# Stricter signatures for Eggdrop's ban/mode commands: wrong argument order
# raises an error like Eggdrop does ("illegal channel").
proc mock_chan {c} { if {[string index $c 0] ne "#"} { error "illegal channel: $c" } }
proc mock_mask {m} { if {![string match "*!*@*" $m] && ![string match "*@*" $m]} { error "invalid ban mask: $m" } }
proc ischanban {ban channel} { mock_chan $channel; mock_mask $ban; return 0 }
proc killchanban {channel ban} { mock_chan $channel; mock_mask $ban; return 0 }
proc isban {ban {channel ""}} { if {$channel ne ""} { mock_chan $channel }; mock_mask $ban; return 0 }
proc ispermban {ban {channel ""}} { if {$channel ne ""} { mock_chan $channel }; mock_mask $ban; return 0 }
proc newchanban {channel ban creator comment {lifetime 60} {options ""}} { mock_chan $channel; mock_mask $ban; if {![string is integer -strict $lifetime]} { error "bad lifetime: $lifetime" }; return "" }
proc newban {ban creator comment {lifetime 60} {options ""}} { mock_mask $ban; if {![string is integer -strict $lifetime]} { error "bad lifetime: $lifetime" }; return "" }
proc pushmode {channel mode {arg ""}} { mock_chan $channel; if {![regexp {^[+-][a-zA-Z]$} $mode]} { error "bad mode: $mode" }; return "" }
proc banlist {{channel ""}} { return [list [list *!*@bad.example.com "test ban" 0 [clock seconds] [clock seconds] Owner]] }
proc chanbans {channel} { mock_chan $channel; return [list [list *!*@bad.example.com Owner 10] [list *!*@other.example.com Owner 5]] }
