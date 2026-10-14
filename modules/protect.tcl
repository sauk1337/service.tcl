#####################################################################
# service.tcl - module: protect
# Anti-takeover protection: reverts mode/kick/topic changes by unknown
# users, asks Q to recover the channel when the bot is attacked, netsplit
# detection and bot status reports to the admin channel.
#####################################################################

namespace eval service {
	bind raw - {MODE} [namespace current]::modeprot
	bind kick - {*} [namespace current]::kickprot
	bind raw - {TOPIC} [namespace current]::topicprot
	bind splt - {*} [namespace current]::netsplit
	bind rejn - {*} [namespace current]::netsplit_rejn
	bind join - {*} [namespace current]::netsplit_rejn
	bind raw - {INVITE} [namespace current]::info_invite
	bind mode - {* +o} [namespace current]::bot_opped
	foreach raw {471 473 474 475 477 479} {
		bind raw - $raw [namespace current]::checkraw
	}
}

proc service::info_mode {nickname hostname handle channel mode victim {reason ""}} {
	global botnick botname
	if {$nickname == ""} {
		set nickname "$hostname"
	}
	if {$mode == "+o" && [string equal -nocase $botnick $victim]} {
		putserv "PRIVMSG $service::adminchan :\00307\002INFO:\002 \003I've been \002OPED\002 on \002$channel\002 by \002$nickname\002"
	} elseif {$mode == "-o" && [string equal -nocase $botnick $victim]} {
		putserv "PRIVMSG $service::adminchan :\00307\002INFO:\002 \003I've been \002DEOPED\002 on \002$channel\002 by \002$nickname\002"
	} elseif {$mode == "+b" && [string match -nocase "*[lindex [split $botname @] 1]*" "*$victim*"]} {
		putserv "PRIVMSG $service::adminchan :\00304\002ERROR:\002 \003I've been \002BANNED\002 on \002$channel\002 by \002$nickname\002"
	} elseif {$mode == "kick" && [string equal -nocase $botnick $victim] && [info exists reason]} {
		putserv "PRIVMSG $service::adminchan :\00304\002ERROR:\002 \003I've been \002KICKED\002 on \002$channel\002 by \002$nickname\002 with the reason: \002[stripcodes bcu $reason]\002"
	}
}

proc service::info_invite {from raw arg} {
	global botnick
	if {[string equal -nocase $botnick [lindex [split $arg] 0]] && [string index [set channel [lindex [split $arg] 1]] 0] == "#"} {
		putserv "PRIVMSG $service::adminchan :\00307\002INFO:\002 \003I've been \002INVITED\002 by \002$from\002 to \002$channel\002"
		if {![validchan $channel]} {
			putserv "NOTICE [lindex [split $from !] 0] :Your channel '${channel}' is unknown to me - Bot by ${service::homechan}."
		} else {
			putquick "JOIN $channel"
			puthelp "NOTICE [lindex [split $from !] 0] :Invite successful - I (re)joined ${channel}."
		}
	}
	return 0
}

proc service::checkraw {from raw arg} {
	# 471 = channel is full
	# 473 = channel is invite-only
	# 474 = banned from channel
	# 475 = channel is +k
	# 477 = channel is +r
	# 479 = glined channel
	# arg = "<botnick> <#channel> :<reason>"
	if {[string equal -nocase $service::homechan [lindex [split $arg] 1]]} { return }
	if {[string equal -nocase $service::adminchan [lindex [split $arg] 1]]} { return }
	if {[string equal -nocase $service::helpchan [lindex [split $arg] 1]]} { return }
	switch -exact -- $raw {
		"471" - "473" - "474" - "475" {
			# can't join: Eggdrop's need binds already ask Q (qnet) or linked bots (botnet)
		}
		"477" {
			putserv "PRIVMSG $service::adminchan :\00304ERROR\00304: I could not join [set channel [string tolower [lindex [split $arg] 1]]] (+r) - Im not authed!"
		}
		"479" {
			set channel [lindex [split $arg] 1]
			putserv "PRIVMSG $service::adminchan :Gline/Badchan reason for $channel: (Glined: [string trimleft [join [lrange [split $arg] 2 end]] :])."
		}
	}
	return 0
}
# Splits a MODE change into a list of {mode param} pairs, following the
# QuakeNet (ircu) parameter rules: o v b k always take a parameter, l only
# when set. Example: "+o-k+l Nick key 50" => {{+o Nick} {-k key} {+l 50}}
proc service::parsemodes {modestr params} {
	set pre +
	set result [list]
	set i 0
	foreach chr [split $modestr ""] {
		switch -exact -- $chr {
			"+" - "-" { set pre $chr }
			"o" - "v" - "b" - "k" {
				lappend result [list $pre$chr [lindex $params $i]]
				incr i
			}
			"l" {
				if {$pre eq "+"} {
					lappend result [list +l [lindex $params $i]]
					incr i
				} else {
					lappend result [list -l ""]
				}
			}
			default { lappend result [list $pre$chr ""] }
		}
	}
	return $result
}

# Current key and limit of a channel, from Eggdrop's view (which is not yet
# updated when a raw MODE bind runs): {key limit}
proc service::keylimit {channel} {
	set words [split [getchanmode $channel]]
	set key ""; set limit ""; set i 1
	foreach chr [split [lindex $words 0] ""] {
		if {$chr eq "k"} { set key [lindex $words $i]; incr i }
		if {$chr eq "l"} { set limit [lindex $words $i]; incr i }
	}
	return [list $key $limit]
}

# Sends a list of {mode param} changes, at most 6 per MODE line (QuakeNet).
proc service::pushmodes {channel changes {fast 0}} {
	set modes ""; set params [list]; set n 0; set last ""
	foreach change $changes {
		lassign $change mode param
		set pre [string index $mode 0]
		if {$pre ne $last} { append modes $pre; set last $pre }
		append modes [string index $mode 1]
		if {$param ne ""} { lappend params $param }
		if {[incr n] == 6} {
			set line [string trim "MODE $channel $modes [join $params " "]"]
			if {$fast} { service::now $line } else { putquick $line }
			set modes ""; set params [list]; set n 0; set last ""
		}
	}
	if {$n > 0} {
		set line [string trim "MODE $channel $modes [join $params " "]"]
		if {$fast} { service::now $line } else { putquick $line }
	}
}

# Enforced modes ("enforcemodes" command / service_enforcedmodes setting):
# returns the change that undoes $mode, or "" when the mode isn't enforced.
proc service::enforcedrevert {channel mode param} {
	if {![channel get $channel service_enforcemodes]} { return "" }
	set enforced [channel get $channel service_enforcedmodes]
	if {$enforced eq ""} { return "" }
	set chr [string index $mode 1]
	set pre [string index $mode 0]
	foreach e [service::parsemodes [lindex [split $enforced] 0] [lrange [split $enforced] 1 end]] {
		lassign $e emode eparam
		if {[string index $emode 1] ne $chr} { continue }
		if {[string index $emode 0] eq $pre} {
			# same direction: only a different key/limit needs fixing
			if {$chr in {k l} && $eparam ne "" && $eparam ne $param} {
				return [list $emode $eparam]
			}
			return ""
		}
		# opposite direction: undo it
		if {$chr eq "k" && $pre eq "+"} { return [list -k $param] }
		return [list $emode $eparam]
	}
	return ""
}

# Modes without parameters that protection reverts (QuakeNet channel modes;
# d is set by the server only and is never touched).
namespace eval service {
	variable revertible {i m n p s t r c C D N T M u}
}

# Raw MODE: reverts mode changes made by users without access and kick-bans
# them. Also handles bitchmode and enforced modes. Mass attacks are handled
# separately by the takeover module.
proc service::modeprot {from raw arg} {
	set nickname [lindex [split $from !] 0]
	set userhost [lindex [split $from !] 1]
	# server modes have no "!" in the source; ignore our own changes
	if {$userhost eq "" || [isbotnick $nickname]} { return 0 }
	set words [split $arg]
	set channel [lindex $words 0]
	if {![validchan $channel] || [channel get $channel service_startup]} { return 0 }
	if {[string equal -nocase $nickname Q] || [string equal -nocase $nickname L]} { return 0 }
	set handle [service::resolve $nickname [nick2hand $nickname $channel]]
	set known [matchattr $handle [expr {[channel get $channel service_prot_hard] ? "nmNbfS|nmS" : "nmNbfS|nmoS"}] $channel]
	set prot [channel get $channel service_prot]
	lassign [service::keylimit $channel] oldkey oldlimit
	set revert [list]
	set violated [list]
	set botattacked 0
	foreach change [service::parsemodes [lindex $words 1] [lrange $words 2 end]] {
		lassign $change mode param
		set pre [string index $mode 0]
		set chr [string index $mode 1]
		set npre [expr {$pre eq "+" ? "-" : "+"}]
		service::info_mode $nickname $userhost $handle $channel $mode $param
		# enforced modes apply to everyone
		if {[set fix [service::enforcedrevert $channel $mode $param]] ne ""} {
			lappend revert $fix
			continue
		}
		if {$known} {
			# bitchmode: only users with access may be opped/voiced
			if {$pre eq "+" && [channel get $channel service_bitchmode]} {
				set target [service::resolve $param [nick2hand $param $channel]]
				if {$chr eq "o" && ![isbotnick $param] && ![matchattr $target bnmoS|nmoS $channel]} {
					lappend revert [list -o $param]
				} elseif {$chr eq "v" && ![matchattr $target bnmovfS|nmovfS $channel]} {
					lappend revert [list -v $param]
				}
			}
			continue
		}
		if {!$prot} { continue }
		switch -exact -- $chr {
			"o" - "v" {
				# users may (de)op/(de)voice themselves; never revert ops given to the bot
				if {[string equal -nocase $param $nickname]} { continue }
				if {[isbotnick $param]} {
					if {$mode eq "-o"} { set botattacked 1; lappend violated $mode }
					continue
				}
				lappend revert [list $npre$chr $param]
			}
			"b" {
				if {$pre eq "+" && [string match -nocase $param $::botname]} { set botattacked 1 }
				lappend revert [list $npre$chr $param]
			}
			"k" {
				if {$pre eq "+"} {
					lappend revert [list -k $param]
				} elseif {$oldkey ne ""} {
					lappend revert [list +k $oldkey]
				}
			}
			"l" {
				if {$pre eq "+"} {
					lappend revert [list -l ""]
				} elseif {$oldlimit ne ""} {
					lappend revert [list +l $oldlimit]
				}
			}
			default {
				if {[lsearch -exact $service::revertible $chr] == -1} { continue }
				lappend revert [list $npre$chr ""]
			}
		}
		lappend violated $mode
	}
	if {[llength $violated]} {
		if {$botattacked} {
			# the bot was deopped/banned: get it back through Q first
			service::qsend "RECOVER $channel" "" 1
			service::qsend "UNBANME $channel" "" 1
			service::qsend "OP $channel" "" 1
		}
		set mask [service::banmask $userhost]
		if {[set kickmsg [channel get $channel service_kickmsg_protkick]] == ""} {
			channel set $channel service_kickmsg_protkick [set kickmsg $service::kickmsg(protkick)]
		}
		channel set $channel service_kid [set id [expr {[channel get $channel service_kid] + 1}]]
		set kickmsg [string map [list :violate: "change channel modes ([join $violated ""])" :channel: $channel :id: $id :homechan: $service::homechan] $kickmsg]
		if {[botisop $channel] && [onchan $nickname $channel]} {
			service::now "MODE $channel -o+b $nickname $mask"
			service::now "KICK $channel $nickname :$kickmsg"
		}
		# the ban is stored even without op: Eggdrop enforces it once opped
		newchanban $channel $mask $::botnick $kickmsg [service::cfg bantime modeprot 120]
	}
	if {[llength $revert] && [botisop $channel]} {
		service::pushmodes $channel $revert 1
	}
	return 0
}

proc service::kickprot {nickname hostname handle channel target reason} {
	set handle [service::resolve $nickname $handle]
	service::info_mode $nickname $hostname $handle $channel kick $target $reason
	if {$nickname eq "" || [isbotnick $nickname] || [string equal -nocase $nickname $target]} { return }
	if {[string equal -nocase $nickname Q] || [string equal -nocase $nickname L]} { return }
	if {[channel get $channel service_startup] || ![channel get $channel service_prot]} { return }
	if {[matchattr $handle [expr {[channel get $channel service_prot_hard] ? "nmNbfS|nmS" : "nmNbfS|nmoS"}] $channel]} { return }
	set mask [service::banmask $hostname]
	if {[isbotnick $target]} {
		# the bot was kicked: Q clears the channel, then the bot rejoins and
		# Eggdrop's need-op/need-unban binds ask Q for the rest
		service::qsend "RECOVER $channel" "" 1
		utimer 2 [list putquick "JOIN $channel"]
		set violate "\002\037kick/ban\037 me\002"
	} else {
		set violate "\002\037kick\037 anyone\002"
	}
	if {[set kickmsg [channel get $channel service_kickmsg_protkick]] == ""} {
		channel set $channel service_kickmsg_protkick [set kickmsg $service::kickmsg(protkick)]
	}
	channel set $channel service_kid [set id [expr {[channel get $channel service_kid] + 1}]]
	set kickmsg [string map [list :violate: $violate :channel: $channel :id: $id :homechan: $service::homechan] $kickmsg]
	if {[botisop $channel] && [onchan $nickname $channel]} {
		service::now "MODE $channel -o+b $nickname $mask"
		service::now "KICK $channel $nickname :$kickmsg"
	}
	newchanban $channel $mask $::botnick $kickmsg [service::cfg bantime kickprot 120]
}

proc service::topicprot {from raw arg} {
	set channel [lindex [split $arg] 0]
	set nickname [lindex [split $from !] 0]
	set hostname [lindex [split $from !] 1]
	set topic [string range [join [lrange [split $arg] 1 end]] 1 end]
	# ignore servers and network services (Q sets topics for "topic Q on")
	if {$hostname eq "" || [string equal -nocase $nickname Q] || [string equal -nocase $nickname L] || ![validchan $channel]} { return 0 }
	if {[isbotnick $nickname]} {
		channel set $channel service_topic_save $topic
		return 0
	}
	set handle [service::resolve $nickname [finduser $nickname!$hostname]]
	if {([channel get $channel service_prot_hard] && [matchattr $handle nmNS|nmS $channel]) || (![channel get $channel service_prot_hard] && [matchattr $handle nmNoS|nmoS $channel])} {
		if {$topic eq ""} { return 0 }
		if {[channel get $channel service_topic_safe]} {
			channel set $channel service_topic_save $topic
			putserv "NOTICE $nickname :Topic saved."
		} elseif {[channel get $channel service_topic_force] && [set saved [channel get $channel service_topic_save]] ne ""} {
			putquick "TOPIC $channel :$saved"
		}
	} elseif {[channel get $channel service_prot] && ![channel get $channel service_startup]} {
		set mask [service::banmask $hostname]
		if {[set kickmsg [channel get $channel service_kickmsg_protkick]] == ""} {
			channel set $channel service_kickmsg_protkick [set kickmsg $service::kickmsg(protkick)]
		}
		channel set $channel service_kid [set id [expr {[channel get $channel service_kid] + 1}]]
		set kickmsg [string map [list :violate: "\002\037change the topic\037\002" :channel: $channel :id: $id :homechan: $service::homechan] $kickmsg]
		if {[botisop $channel] && [onchan $nickname $channel]} {
			service::now "MODE $channel -o+b $nickname $mask"
			service::now "KICK $channel $nickname :$kickmsg"
		}
		newchanban $channel $mask $::botnick $kickmsg [service::cfg bantime modeprot 120]
		if {[set saved [channel get $channel service_topic_save]] ne ""} {
			putquick "TOPIC $channel :$saved"
		}
	}
	return 0
}

proc service::netsplit {nickname hostname handle channel} {
	if {$nickname == "Q" && ![channel get $channel service_netsplit]} {
		channel set $channel +service_netsplit
		channel set $channel service_netsplit_time "[unixtime]"
		putserv "PRIVMSG $channel :$service::netsplit_start"
	}
}

proc service::netsplit_rejn {nickname hostname handle channel} {
	if {$nickname == "Q" && [channel get $channel service_netsplit]} {
		channel set $channel -service_netsplit
		set time [duration [expr {[unixtime] - [channel get $channel service_netsplit_time]}]]
		channel set $channel service_netsplit_time ""
		set msg [string map [list :time: $time] $service::netsplit_end]
		putserv "PRIVMSG $channel :$msg"
	}
}

# Applies the enforced modes now (only what differs from the current modes).
proc service::enforce_apply {channel} {
	if {![botisop $channel] || ![channel get $channel service_enforcemodes]} { return }
	set enforced [split [channel get $channel service_enforcedmodes]]
	set current [lindex [split [getchanmode $channel]] 0]
	lassign [service::keylimit $channel] key limit
	set changes [list]
	foreach e [service::parsemodes [lindex $enforced 0] [lrange $enforced 1 end]] {
		lassign $e mode param
		set pre [string index $mode 0]; set chr [string index $mode 1]
		set isset [string match "*$chr*" $current]
		if {$pre eq "+"} {
			if {$chr eq "k" && $isset && $key ne $param} {
				lappend changes [list -k $key] [list +k $param]
			} elseif {$chr eq "l" && $limit ne $param} {
				lappend changes [list +l $param]
			} elseif {!$isset} {
				lappend changes [list $mode $param]
			}
		} elseif {$isset} {
			lappend changes [list $mode [expr {$chr eq "k" ? $key : ""}]]
		}
	}
	if {[llength $changes]} {
		service::pushmodes $channel $changes
	}
}

# enforcemodes ?<+-modes> ?key? ?limit?|on|off|status?
proc service::cmd_enforcemodes {nickname hostname handle channel text lastbind command} {
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set words [split [string trim $text]]
	set current [channel get $channel service_enforcedmodes]
	set status [channel get $channel service_enforcemodes]
	switch -exact -- [string tolower [lindex $words 0]] {
		"" - "status" {
			putserv "NOTICE $nickname :Enforced modes on $channel: [expr {$current eq "" ? "none" : $current}] - [expr {$status ? "enabled" : "disabled"}]. (SYNTAX: ${lastbind}$command <+-modes> ?key? ?limit?|on|off)"
		}
		"on" {
			if {$current eq ""} {
				putserv "NOTICE $nickname :Set the modes first, e.g. ${lastbind}$command +nt-i"
				return
			}
			channel set $channel +service_enforcemodes
			service::enforce_apply $channel
			putserv "NOTICE $nickname :Enforcing $current on $channel."
		}
		"off" {
			channel set $channel -service_enforcemodes
			putserv "NOTICE $nickname :Mode enforcement disabled on $channel."
		}
		default {
			set modes [lindex $words 0]
			if {![regexp {^([+-][a-zA-Z]+)+$} $modes] || [regexp {[ovb]} $modes]} {
				putserv "NOTICE $nickname :Invalid modes '$modes'. Use channel modes like +nt-i, +ntk key or +ntl 50 (not o/v/b)."
				return
			}
			# check that +k/+l got their parameters
			set needed 0
			foreach e [service::parsemodes $modes [lrange $words 1 end]] {
				lassign $e mode param
				if {$mode in {+k +l} && $param eq ""} {
					putserv "NOTICE $nickname :$mode needs a parameter (${lastbind}$command $modes <[expr {$mode eq "+k" ? "key" : "limit"}]>)."
					return
				}
				if {$mode eq "+l" && ![string is integer -strict $param]} {
					putserv "NOTICE $nickname :The limit must be a number."
					return
				}
			}
			channel set $channel service_enforcedmodes [string trim $text]
			channel set $channel +service_enforcemodes
			service::enforce_apply $channel
			putserv "NOTICE $nickname :Enforcing [string trim $text] on $channel."
		}
	}
}
service::register enforcemodes service::cmd_enforcemodes

# The bot got op (from anyone, usually Q): apply the enforced modes.
proc service::bot_opped {nickname hostname handle channel mode target} {
	if {![isbotnick $target]} { return 0 }
	utimer 1 [list service::enforce_apply $channel]
	return 0
}
