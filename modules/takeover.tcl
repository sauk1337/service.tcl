#####################################################################
# service.tcl - module: takeover
# Mass-action (takeover) detection for channels with protection (+p):
# N deops / kicks / bans by the same user within T seconds trigger an
# immediate response:
#   1. deop + ban + kick the attacker (if the bot is opped)
#   2. Q: RECOVER (or OP) the channel, TEMPBAN the attacker's mask and
#      remove the attacker's Q chanlev
#   3. lock the channel (+im by default) for a while
#   4. re-op trusted users (o flag or saved ops) once the bot has op again
#   5. alert the staff channel and the linked bots
# Everything is configurable in service.conf (takeover array).
# Also provides the lockdown command.
#####################################################################

namespace eval service {
	bind raw - {MODE} [namespace current]::tk_mode
	bind kick - {*} [namespace current]::tk_kick

	variable tk
	if {![array exists tk]} { array set tk {} }
}

# Raw MODE: count -o (on others) and +b per user. Kept as small as possible,
# this runs for every mode change on every channel.
proc service::tk_mode {from raw arg} {
	set nickname [lindex [split $from !] 0]
	set userhost [lindex [split $from !] 1]
	if {$userhost eq "" || [isbotnick $nickname] || [string equal -nocase $nickname Q]} { return 0 }
	set words [split $arg]
	set channel [lindex $words 0]
	if {![validchan $channel] || ![channel get $channel service_prot] || [channel get $channel service_startup] || [channel get $channel service_netsplit]} { return 0 }
	set modes [lindex $words 1]
	set params [lrange $words 2 end]
	set pre +; set deops 0; set bans 0; set p 0
	foreach chr [split $modes ""] {
		switch -exact -- $chr {
			"+" - "-" { set pre $chr }
			"o" {
				set target [lindex $params $p]; incr p
				if {$pre eq "-" && ![string equal -nocase $target $nickname]} { incr deops }
			}
			"b" {
				incr p
				if {$pre eq "+"} { incr bans }
			}
			"v" - "k" { incr p }
			"l" { if {$pre eq "+"} { incr p } }
		}
	}
	if {$deops} { service::tk_hit $channel $nickname $userhost deops $deops }
	if {$bans} { service::tk_hit $channel $nickname $userhost bans $bans }
	return 0
}

proc service::tk_kick {nickname userhost handle channel target reason} {
	if {[isbotnick $nickname] || [string equal -nocase $nickname Q] || [string equal -nocase $nickname $target]} { return 0 }
	if {![channel get $channel service_prot] || [channel get $channel service_startup] || [channel get $channel service_netsplit]} { return 0 }
	service::tk_hit $channel $nickname $userhost kicks 1
	return 0
}

# Records n actions of a type and fires the response when the threshold is
# reached inside the time window.
proc service::tk_hit {channel nickname userhost type n} {
	variable tk
	set limit [service::cfg takeover $type 3]
	if {$limit <= 0} { return }
	set now [clock seconds]
	set window [service::cfg takeover window 10]
	set key "[string tolower $channel],[string tolower $nickname],$type"
	set times [list]
	if {[info exists tk($key)]} {
		foreach t $tk($key) {
			if {$now - $t < $window} { lappend times $t }
		}
	}
	for {set i 0} {$i < $n} {incr i} { lappend times $now }
	set tk($key) $times
	if {[llength $times] >= $limit} {
		unset tk($key)
		service::takeover $channel $nickname $userhost "mass [string trimright $type s] ([llength $times] in ${window}s)"
	}
}

proc service::takeover {channel nickname userhost why} {
	variable tk
	set now [clock seconds]
	set fired "fired,[string tolower $channel],[string tolower $nickname]"
	if {[info exists tk($fired)] && $now - $tk($fired) < [service::cfg takeover window 10]} { return }
	set tk($fired) $now
	set handle [service::resolve $nickname [finduser $nickname!$userhost]]
	if {[matchattr $handle [service::cfg takeover exempt "bn|n"] $channel]} {
		service::tk_report $channel "$nickname ($handle) did a $why - exempt user, no action taken."
		return
	}
	set mask [service::banmask $userhost]
	set account [service::account $nickname $userhost]
	set reason "Takeover protection: $why"
	set actions [list]

	# 1. local reaction - fastest, no queue
	if {[botisop $channel]} {
		service::now "MODE $channel -o+b $nickname $mask"
		service::now "KICK $channel $nickname :$reason"
		lappend actions "kickban"
	}

	# 2. Q - works even when the bot has lost op
	set recover [expr {[service::cfg takeover recover 1] && ([string match "*deop*" $why] || ![botisop $channel])}]
	if {$recover} {
		service::qsend "RECOVER $channel" "" 1
		service::qsend "OP $channel" "" 1
		lappend actions "Q RECOVER"
	} elseif {![botisop $channel]} {
		service::qsend "OP $channel" "" 1
		lappend actions "Q OP"
	}
	if {[service::cfg takeover qban 1]} {
		service::qsend "TEMPBAN $channel $mask [service::cfg takeover qban_time 1h] $reason"
		lappend actions "Q TEMPBAN $mask"
	}
	if {[service::cfg takeover qchanlev 1] && $account ne ""} {
		service::qsend "CHANLEV $channel #$account [service::cfg takeover qchanlev_flags -aogvt]"
		if {[set ownerflags [service::cfg takeover qchanlev_owner_flags -mn]] ne ""} {
			# only works when the bot is owner (+n) in Q; harmless otherwise
			service::qsend "CHANLEV $channel #$account $ownerflags"
		}
		lappend actions "Q CHANLEV #$account"
	}
	newchanban $channel $mask $::botnick $reason [service::cfg takeover ban_time 120]

	# 3. lockdown
	if {[set lock [service::cfg takeover lockdown +im]] ne ""} {
		service::lockdown_set $channel $lock [service::cfg takeover lockdown_time 300]
		lappend actions "lockdown $lock"
	}

	# 4. re-op trusted users after Q's RECOVER deopped everyone
	if {$recover && [service::cfg takeover reop 1]} {
		utimer 6 [list service::reop_trusted $channel]
		lappend actions "re-op trusted"
	}

	# 5. alerts
	service::tk_report $channel "\002TAKEOVER\002 by $nickname!$userhost[expr {$account ne "" ? " (Q: $account)" : ""}] - $why - actions: [join $actions ", "]"
	if {[info commands ::service::botnet_alert] ne ""} {
		service::botnet_alert $channel $nickname $userhost $why
	}
}

proc service::tk_report {channel text} {
	putlog "service.tcl - $channel: [stripcodes bcruag $text]"
	if {[validchan $service::adminchan] && [service::cfg takeover notify 1]} {
		putquick "PRIVMSG $service::adminchan :\[$channel\] $text"
	}
}

# Ops every user with op access (global/channel +o and above) or on the
# saved op list. Retries a few times while the bot waits for op from Q.
proc service::reop_trusted {channel {tries 0}} {
	if {![validchan $channel] || ![botonchan $channel]} { return }
	if {![botisop $channel]} {
		if {$tries < 5} {
			utimer 3 [list service::reop_trusted $channel [incr tries]]
		}
		return
	}
	set chan [string tolower $channel]
	foreach nick [chanlist $channel] {
		if {[isbotnick $nick] || [isop $nick $channel]} { continue }
		set hand [service::resolve $nick [nick2hand $nick $channel]]
		if {[matchattr $hand nmo|nmo $channel] || [info exists ::service::saveops($chan:[string tolower $nick])]} {
			pushmode $channel +o $nick
		}
	}
	flushmode $channel
}

# --- lockdown ---------------------------------------------------------------
# Only the modes that were not already set are added, and only those are
# removed again. The active lockdown is stored in the service_lockdown setting
# ("<modes> <expiry>") so it is also cleared after a restart.

proc service::lockdown_set {channel modes duration {tries 0}} {
	if {![validchan $channel]} { return }
	if {![botisop $channel]} {
		if {$tries < 3} {
			utimer 3 [list service::lockdown_set $channel $modes $duration [incr tries]]
		}
		return
	}
	set current [lindex [split [getchanmode $channel]] 0]
	set add ""
	foreach chr [split [string trimleft $modes +] ""] {
		if {![string match "*$chr*" $current]} { append add $chr }
	}
	set prev [lindex [split [channel get $channel service_lockdown]] 0]
	set expiry [expr {$duration > 0 ? [clock seconds] + $duration : 0}]
	channel set $channel service_lockdown "[join [lsort -unique [split "$prev$add" ""]] ""] $expiry"
	if {$add ne ""} {
		service::now "MODE $channel +$add"
	}
	if {$duration > 0} {
		utimer $duration [list service::lockdown_expire $channel]
	}
}

proc service::lockdown_clear {channel} {
	if {![validchan $channel]} { return "" }
	set modes [lindex [split [channel get $channel service_lockdown]] 0]
	channel set $channel service_lockdown ""
	if {$modes ne "" && [botisop $channel]} {
		putquick "MODE $channel -$modes"
	}
	return $modes
}

proc service::lockdown_expire {channel} {
	if {![validchan $channel]} { return }
	set expiry [lindex [split [channel get $channel service_lockdown]] 1]
	# a newer lockdown may have extended it
	if {$expiry ne "" && $expiry != 0 && $expiry <= [clock seconds]} {
		service::lockdown_clear $channel
		service::tk_report $channel "Lockdown expired."
	}
}

# lockdown [on [+modes] [seconds]|off|status]
proc service::cmd_lockdown {nickname hostname handle channel text lastbind command} {
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set words [split $text]
	set state [channel get $channel service_lockdown]
	switch -exact -- [string tolower [lindex $words 0]] {
		"on" {
			set modes [lindex $words 1]
			if {$modes eq "" || [string index $modes 0] ne "+"} { set modes [service::cfg takeover lockdown +im] }
			set time [lindex $words 2]
			if {![string is integer -strict $time]} { set time [service::cfg takeover lockdown_time 300] }
			if {![botisop $channel]} {
				putserv "NOTICE $nickname :I need op to lock $channel."
				return
			}
			service::lockdown_set $channel $modes $time
			putserv "NOTICE $nickname :$channel locked ($modes)[expr {$time > 0 ? " for ${time}s" : " until '${lastbind}$command off'"}]."
		}
		"off" {
			if {[set modes [service::lockdown_clear $channel]] eq ""} {
				putserv "NOTICE $nickname :$channel is not locked."
			} else {
				putserv "NOTICE $nickname :$channel unlocked (-$modes)."
			}
		}
		"status" - "" {
			if {$state eq ""} {
				putserv "NOTICE $nickname :$channel is not locked."
			} else {
				set expiry [lindex [split $state] 1]
				putserv "NOTICE $nickname :$channel is locked (+[lindex [split $state] 0])[expr {$expiry > 0 ? " - expires in [expr {$expiry - [clock seconds]}]s" : ""}]."
			}
		}
		default {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on ?+modes? ?seconds?|off|status"
		}
	}
}
service::register lockdown service::cmd_lockdown

# takeover - shows the takeover protection settings for this channel
proc service::cmd_takeover {nickname hostname handle channel text lastbind command} {
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set prot [expr {[channel get $channel service_prot] ? "on" : "OFF (enable with ${lastbind}protect on)"}]
	putserv "NOTICE $nickname :Takeover protection on $channel: $prot - triggers: [service::cfg takeover deops 3] deops / [service::cfg takeover kicks 3] kicks / [service::cfg takeover bans 3] bans in [service::cfg takeover window 10]s - exempt flags: [service::cfg takeover exempt bn|n]"
	putserv "NOTICE $nickname :Actions: Q RECOVER [expr {[service::cfg takeover recover 1] ? "on" : "off"}] - Q TEMPBAN [expr {[service::cfg takeover qban 1] ? "on ([service::cfg takeover qban_time 1h])" : "off"}] - Q CHANLEV removal [expr {[service::cfg takeover qchanlev 1] ? "on" : "off"}] - lockdown [expr {[set l [service::cfg takeover lockdown +im]] ne "" ? "$l for [service::cfg takeover lockdown_time 300]s" : "off"}] - re-op trusted [expr {[service::cfg takeover reop 1] ? "on" : "off"}]"
}
service::register takeover service::cmd_takeover

# Restart recovery: re-arm the expiry timers of active lockdowns
foreach channel [channels] {
	set state [channel get $channel service_lockdown]
	if {$state ne "" && [set expiry [lindex [split $state] 1]] > 0} {
		utimer [expr {max(1, $expiry - [clock seconds])}] [list service::lockdown_expire $channel]
	}
}
unset -nocomplain channel state expiry
