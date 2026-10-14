#####################################################################
# service.tcl - module: onjoin
# On-join features: welcome, auto-op/voice, auto-limit, user modes,
# known-only, clonescan, flyby, WHOIS checks (authban/badchan/vip), automsg.
#####################################################################

namespace eval service {
	bind join - {*} [namespace current]::onjoin_welcome
	bind join - {*} [namespace current]::onjoin_automodes
	bind join - {*} [namespace current]::onjoin_autolimit
	bind join - {*} [namespace current]::onjoin_usermodes
	bind join - {*} [namespace current]::onjoin_known
	bind join - {*} [namespace current]::onjoin_clonescan
	bind join - {*} [namespace current]::onjoin_peak
	bind part - {*} [namespace current]::onpart_check
	bind sign - {*} [namespace current]::onleave_autolimit
	bind kick - {*} [namespace current]::onleave_autolimit
	bind nick - {*} [namespace current]::nick_change
	bind raw - {319} [namespace current]::whois_raw
	bind raw - {330} [namespace current]::whois_raw
	bind raw - {318} [namespace current]::whois_raw
	bind time - {* * * * *} [namespace current]::automsg
}

proc service::onjoin_welcome {nickname hostname handle channel} {
	if {![channel get $channel service_welcome]} { return }
	if {[isbotnick $nickname]} { return }
	if {[set skin [channel get $channel service_welcome_skin]] == ""} {
		channel set $channel service_welcome_skin "[set skin $service::welcomeskin]"
	}
	set skin [string map [list :nickname: "$nickname"] $skin]
	set skin [string map [list :hostname: "$hostname"] $skin]
	set skin [string map [list :date: "[clock format [clock seconds] -format "%A %d/%m/%Y"]"] $skin]
	set t [clock format [clock seconds] -format "%T"]
	set skin [string map [list :time: "[lindex [split $t :] 0]hr [lindex [split $t :] 1]min [lindex [split $t :] 2]sec"] $skin]
	set skin [string map [list :channel: "$channel"] $skin]
	channel set $channel service_jid "[set id [expr {[channel get $channel service_jid] + 1}]]"
	set skin [string map [list :id: "$id"] $skin]
	if {$skin == ""} { return }
	if {[channel get $channel service_welcome_notice]} {
		putserv "NOTICE $nickname :$skin"
	} else {
		putserv "PRIVMSG $channel :$skin"
	}
}

proc service::onjoin_automodes {nickname hostname handle channel} {
	set handle [service::resolve $nickname $handle]
	if {![botisop $channel]} { return }
	if {[matchattr $handle dB|dB $channel]} { return }
	if {[channel get $channel service_netsplit]} { return }
	if {[channel get $channel service_known] && ![matchattr $handle nmS|RnmovfS $channel]} { return }
	set ao [channel get $channel service_ao]
	set av [channel get $channel service_av]
	if {$ao && $av} {
		pushmode $channel +o $nickname
		pushmode $channel +v $nickname
	} elseif {$ao} {
		pushmode $channel +o $nickname
	} elseif {$av} {
		pushmode $channel +v $nickname
	}
	if {[isbotnick $nickname]} { return }
	if {([channel get $channel service_vip] && [channel get $channel service_vipc] != "") || ([channel get $channel service_badchan] && [channel get $channel service_badchans] != "") || ([channel get $channel service_authban] && [channel get $channel service_authbans] != "")} {
		service::whois_queue $nickname $channel
	}
}

# WHOIS for the authban/badchan/vip checks: sent a few seconds after the
# join (users who leave at once aren't checked), once per nickname, and on
# the help queue so a join flood can't delay more important traffic.
proc service::whois_queue {nickname channel} {
	set nick [string tolower $nickname]
	if {[info exists ::service::onjoin($nick)]} { return }
	set ::service::onjoin($nick) $channel
	utimer [service::cfg whoischeck delay 3] [list service::whois_send $nickname $channel]
}

proc service::whois_send {nickname channel} {
	if {![validchan $channel] || ![onchan $nickname $channel]} {
		unset -nocomplain ::service::onjoin([string tolower $nickname])
		return
	}
	puthelp "WHOIS $nickname"
}

proc service::onjoin_autolimit {nickname hostname handle channel} {
	service::autolimit_update $channel
}

# Keeps the limit at users + service_limit (default 10). It is updated when
# it differs by 2 or more, so a burst of joins/parts can't leave the channel
# full and single joins don't cause a mode change each time.
proc service::autolimit_update {channel} {
	if {![channel get $channel service_autolimit] || ![botisop $channel]} { return }
	if {[set extra [channel get $channel service_limit]] < 1} { set extra 10 }
	set newlimit [expr {[llength [chanlist $channel]] + $extra}]
	set current [lindex [service::keylimit $channel] 1]
	if {$current eq "" || abs($newlimit - $current) >= 2} {
		pushmode $channel +l $newlimit
	}
}

proc service::onjoin_usermodes {nickname hostname handle channel} {
	set handle [service::resolve $nickname $handle]
	if {[matchattr $handle d|d $channel]} { return }
	if {[channel get $channel service_known] && ![matchattr $handle nmS|RnmovfS $channel]} { return }
	if {[matchattr $handle nm] && ![matchattr $handle S|S $channel]} {
		pushmode $channel +v $nickname
		#puthelp "PRIVMSG $channel :Staff member from $service::homechan \( $nickname \) joined $channel"
    } elseif {[matchattr $handle S|S $channel]} {
            pushmode $channel +o $nickname
	} elseif {[matchattr $handle |o $channel] && [matchattr $handle |a $channel]} {
		pushmode $channel +o $nickname
	} elseif {[matchattr $handle |vf $channel] && [matchattr $handle |g $channel]} {
		pushmode $channel +v $nickname
	} elseif {[matchattr $handle |B $channel]} {
		set hostname [service::banmask $hostname]
		if {[channel get $channel service_kickmsg_defaultban] == ""} {
			channel set $channel service_kickmsg_defaultban "$service::kickmsg(defaultban)"
		}
		set kickmsg [channel get $channel service_kickmsg_defaultban]
		channel set $channel service_kid "[set id [expr {[channel get $channel service_kid] + 1}]]"
		set kickmsg [string map [list :channel: $channel] $kickmsg]
		set kickmsg [string map [list :id: $id] $kickmsg]
		if {[botisop $channel] && [onchan $nickname $channel]} {
			putquick "MODE $channel -o+b $nickname $hostname"
			putquick "KICK $channel $nickname :$kickmsg"
		}
	}
}

proc service::onjoin_known {nickname hostname handle channel} {
	set handle [service::resolve $nickname $handle]
	if {![channel get $channel service_known]} { return }
	if {[matchattr $handle nmS|RnmovfS $channel] || [isbotnick $nickname]} { return }
	set hostname [service::banmask $hostname]
	if {[set kickmsg [channel get $channel service_kickmsg_known]] == ""} {
		channel set $channel service_kickmsg_known "[set kickmsg "$service::kickmsg(known)"]"
	}
	channel set $channel service_kid_known "[set id [expr {[channel get $channel service_kid_known] + 1}]]"
	set kickmsg [string map [list :channel: "$channel"] $kickmsg]
	set kickmsg [string map [list :id: "$id"] $kickmsg]
	if {[botisop $channel] && [onchan $nickname $channel]} {
		putquick "MODE $channel -o+b $nickname $hostname"
		putquick "KICK $channel $nickname :$kickmsg"
		utimer 300 [list pushmode $channel -b $hostname]
	}
}

proc service::onjoin_clonescan {nickname hostname handle channel} {
	if {![channel get $channel service_clonescan] || [isbotnick $nickname] || [channel get $channel service_netsplit]} { return }
	if {[matchattr [service::resolve $nickname $handle] nmovfS|nmovfS $channel]} { return }
	if {[channel get $channel service_known] && ![matchattr $handle nmS|RnmovfS $channel]} { return }
	# settings that were never set (e.g. clonescan enabled with chanflags +C)
	# fall back to the defaults in service.conf
	if {[set maxclones [channel get $channel service_clonescan_maxclones]] eq "" || $maxclones < 2} {
		channel set $channel service_clonescan_maxclones [set maxclones $service::clonescan(maxclones)]
	}
	if {[set hosttype [channel get $channel service_clonescan_hosttype]] ni {1 2}} {
		channel set $channel service_clonescan_hosttype [set hosttype $service::clonescan(hosttype)]
	}
	if {[set bantime [channel get $channel service_clonescan_bantime]] eq "" || $bantime < 1} {
		channel set $channel service_clonescan_bantime [set bantime $service::bantime(clonescan)]
	}
	set hostname [string trimleft $hostname ~]
	set hostname [expr {$hosttype == 1 ? "*!*@[lindex [split $hostname @] 1]" : "*!*$hostname"}]
	set list [list]
	foreach user [chanlist $channel] {
		if {[isbotnick $user]} { continue }
		set host [string trimleft [getchanhost $user $channel] ~]
		set host [expr {$hosttype == 1 ? "*!*@[lindex [split $host @] 1]" : "*!*$host"}]
		if {[string equal -nocase $hostname $host]} {
			# users with access are never kicked, but still count as clones
			if {![matchattr [service::resolve $user [nick2hand $user $channel]] nmovfS|nmovfS $channel]} {
				lappend list $user
			}
		}
	}
	if {$hostname eq "*!*@" || $hostname eq "*!*@*"} { return }
	if {[llength $list] >= $maxclones} {
		if {[botisop $channel]} {
			channel set $channel service_kid "[set id [expr {[channel get $channel service_kid] + 1}]]"
			set kickmsg [string map [list :clones: "[llength $list]"] $service::kickmsg(clonescan)]
			set kickmsg [string map [list :maxclones: $maxclones] $kickmsg]
			set kickmsg [string map [list :hostname: "$hostname"] $kickmsg]
			set kickmsg [string map [list :channel: "$channel"] $kickmsg]
			set kickmsg [string map [list :id: "$id"] $kickmsg]
			set kickmsg [string map [list :homechan: "$service::homechan"] $kickmsg]
			putserv "MODE $channel +b $hostname"
			foreach user $list {
				if {[onchan $user $channel] && [botisop $channel]} {
					putserv "KICK $channel $user :$kickmsg"
				}
			}
			utimer [expr {$bantime * 60}] [list puthelp "MODE $channel -b $hostname"]
		} else {
			putserv "PRIVMSG $channel :Clonescan: $nickname is a clone! The nicknames ( [join $list ", "] ) are sharing the same hostmask ( [lindex [split $hostname @] 1] ). (Clones/Maxclones: [llength $list]/$maxclones)."
		}
	}
}

proc service::onpart_check {nickname hostname handle channel {reason ""}} {
	if {[isbotnick $nickname]} { return }
	if {[channel get $channel service_flyby] && ![matchattr [service::resolve $nickname $handle] nmovfS|nmovfS $channel] && [botisop $channel] && [clock seconds] - [getchanjoin $nickname $channel] < 10} {
		set hostname [service::banmask $hostname]
		pushmode $channel +b $hostname
		utimer 300 [list pushmode $channel -b $hostname]
	}
	# the parting user is still in the channel list: update once they're gone
	utimer 1 [list service::autolimit_update $channel]
}

# quit / kick: update the limit once the user is gone
proc service::onleave_autolimit {nickname hostname handle channel args} {
	if {[channel get $channel service_autolimit]} {
		utimer 1 [list service::autolimit_update $channel]
	}
}

proc service::nick_change {nickname hostname handle channel newnick} {
	if {[info exists service::saveops([string tolower $channel]:[string tolower $nickname])]} {
		set service::saveops([string tolower $channel]:[string tolower $newnick]) "$service::saveops([string tolower $channel]:[string tolower $nickname])"
		unset service::saveops([string tolower $channel]:[string tolower $nickname])
		service::saveops_store $channel
	}
}

proc service::whois_raw {from raw arg} {
	set nickname [string tolower [lindex [split $arg] 1]]
	if {![info exists service::onjoin($nickname)]} { return }
	if {$raw == "319"} {
		# RPL_WHOISCHANNELS can arrive in several lines
		append service::whois($nickname,channels) " [string trimleft [join [lrange [split $arg] 2 end]] :]"
	} elseif {$raw == "330"} {
		set service::whois($nickname,authname) "[lindex [split $arg] 2]"
	} elseif {$raw == "318"} {
		set channel $service::onjoin($nickname)
		unset service::onjoin($nickname)
		set chanlist ""
		if {[info exists service::whois($nickname,channels)]} {
			set chanlist $service::whois($nickname,channels)
		}
		if {[info exists service::whois($nickname,authname)]} {
			set authname $service::whois($nickname,authname)
		}
		array unset service::whois $nickname,*
		if {![validchan $channel] || ![botisop $channel]} { return }
		set channels [list]
		foreach chan [split $chanlist] {
			if {$chan == ""} { continue }
			lappend channels [string trimleft $chan ~]
		}
		if {[string match -nocase *users.quakenet.org [set host *!*[getchanhost $nickname $channel]]]} {
			set host *!*@[lindex [split $host @] 1]
		}
		set cont "1"
		if {[channel get $channel service_authban] && [channel get $channel service_authbans] != "" && ![matchattr [nick2hand $nickname] nmobBFS|nmovfFS $channel] && [info exists authname] && [lsearch -exact [string tolower [channel get $channel service_authbans]] [string tolower $authname]] != -1} {
				channel set $channel service_aid "[set id [expr {[channel get $channel service_aid] + 1}]]"
				if {[set kickmsg [channel get $channel service_kickmsg_authban]] == ""} {
					channel set $channel service_kickmsg_authban "[set kickmsg $service::kickmsg(authban)]"
				}
				set kickmsg [string map [list :authname: "$authname"] $kickmsg]
				set kickmsg [string map [list :id: "$id"] $kickmsg]
				set kickmsg [string map [list :channel: "$channel"] $kickmsg]
				if {[botisop $channel] && [onchan $nickname $channel]} {
				    if {$host == "*!*@" || $host == "*!*@*" || $host == "*!**@*" || $host == "*!**@"} {
					    putquick "KICK $channel $nickname :$kickmsg"
					} else {
					    putquick "MODE $channel -o+b $nickname $host"
					    putquick "KICK $channel $nickname :$kickmsg"
					    utimer 120 [list pushmode $channel -b $host]
					}
				}
				set cont 0
			}
		if {[channel get $channel service_badchan] && [channel get $channel service_badchans] != "" && ![matchattr [nick2hand $nickname] nmobBFS|nmovfFS $channel] && $cont == "1"}  {
				set list [list]
				set chans [list]
				foreach chan $channels {
					lappend chans [string tolower [string trimleft $chan ~@+]]
				}
				foreach bchan [channel get $channel service_badchans] {
					if {$bchan == ""} { continue }
					if {[lsearch -exact $chans [string tolower $bchan]] != -1} {
						lappend list "$bchan"
					}
				}
			}
			if {[info exists list] && [llength $list] > 0} {
				channel set $channel service_bid "[set id [expr {[channel get $channel service_bid] + 1}]]"
				if {[set kickmsg [channel get $channel service_kickmsg_badchan]] == ""} {
					channel set $channel service_kickmsg_badchan "[set kickmsg $service::kickmsg(badchan)]"
				}
				set kickmsg [string map [list :badchan: "[join $list " "]"] $kickmsg]
				set kickmsg [string map [list :id: "$id"] $kickmsg]
				set kickmsg [string map [list :channel: "$channel"] $kickmsg]
				if {[botisop $channel] && [onchan $nickname $channel]} {
					if {$host == "*!*@" || $host == "*!*@*" || $host == "*!**@*" || $host == "*!**@"} {
					    putquick "KICK $channel $nickname :$kickmsg"
					} else {
					    putquick "MODE $channel -o+b $nickname $host"
					    putquick "KICK $channel $nickname :$kickmsg"
					    utimer 120 [list pushmode $channel -b $host]
					}
				}
				set cont 0
			}
		if {[channel get $channel service_vip] && [channel get $channel service_vipc] != "" && ![channel get $channel service_netsplit] && $cont == "1"} {
		        if {[channel get $channel service_vip_authed] && ![info exists authname]} { return }
				if {[channel get $channel service_vip_authbl] && [info exists authname] && [lsearch -exact -nocase [channel get $channel service_vip_authblist] $authname] != -1} { return }
				set vipchans [list]
				foreach vchan [channel get $channel service_vipc] {
					if {$vchan == ""} { continue }
					set temp [string trimleft $vchan @+]
					if {[string range $vchan 0 0] == "@"} {
						if {[lsearch -exact [string tolower $channels] @[string tolower $temp]] != -1} {
							lappend vipchans "@$temp"
						}
					} elseif {[string range $vchan 0 0] == "+"} {
						if {[lsearch -exact [string tolower $channels] @[string tolower $temp]] != -1} {
							lappend vipchans "@$temp"
						}
						if {[lsearch -exact [string tolower $channels] +[string tolower $temp]] != -1} {
							lappend vipchans "+$temp"
						}
					}
				}
			if {[llength $vipchans] < 1} { return }
			channel set $channel service_vipid "[set id [expr {[channel get $channel service_vipid] + 1}]]"
			if {[set skin [channel get $channel service_vipskin]] == ""} {
					channel set $channel service_vipskin "[set skin $service::vipskin]"
				}
				if {[set mode [channel get $channel service_vipm]] == ""} {
					channel set $channel service_vipm "[set mode $service::vipmode]"
				}
			set skin [string map [list :nickname: "$nickname"] $skin]
			set skin [string map [list :hostname: "[getchanhost $nickname $channel]"] $skin]
			set skin [string map [list :channel: "$channel"] $skin]
			set skin [string map [list :vipchannel: "[lindex [split $vipchans] [rand [llength $vipchans]]]"] $skin]
			set skin [string map [list :vipchannels: "[join $vipchans " "]"] $skin]
			set skin [string map [list :status: "$mode"] $skin]
			set skin [string map [list :id: "$id"] $skin]
			if {[channel get $channel service_vips]} {
					if {[channel get $channel service_vipn]} {
						putserv "NOTICE $nickname :$skin"
					} else {
						putserv "PRIVMSG $channel :$skin"
					}
				}
			if {![botisop $channel] || ![onchan $nickname $channel]} { return 0 }
			if {$mode == "@"} {
				putserv "MODE $channel +ov $nickname $nickname"
			} else {
				putserv "MODE $channel +v $nickname"
			}
		}
	}
	return 0
}

proc service::automsg {min hour day month year} {
    foreach channel [channels] {
	    if {[channel get $channel service_automsg] && [botonchan $channel]} {
		    if {[channel get $channel service_automsg_int] == "" || [channel get $channel service_automsg_int] < 10} { continue }
			if {[expr {[unixtime]-[channel get $channel service_automsg_lastmsg]}] >= [channel get $channel service_automsg_int]} {
			    set modes [channel get $channel service_automsg_modes]
				if {$modes != ""} {
				    putserv "MODE $channel $modes"
				}
				foreach line "line1 line2 line3" {
				    set line [channel get $channel service_automsg_$line]
					if {$line == ""} { continue }
					if {[string match *c* [getchanmode $channel]]} { set line [stripcodes bcu $line] }
					if {[string match *m* [getchanmode $channel]] && ![botisop $channel] && ![botisvoice $channel]} { continue }
					putserv "PRIVMSG $channel :$line"
				}
				if {$modes != ""} {
				    putserv "MODE $channel [string map { + - - + } $modes]"
				}
				channel set $channel service_automsg_lastmsg "[unixtime]"
			}
		}
	}
}

# --- peak (record number of users) -------------------------------------------

proc service::onjoin_peak {nickname hostname handle channel} {
	if {![channel get $channel service_peak] || [isbotnick $nickname] || [channel get $channel service_netsplit]} { return }
	set users [llength [chanlist $channel]]
	if {$users <= [channel get $channel service_peak_count]} { return }
	channel set $channel service_peak_count $users
	channel set $channel service_peak_time [clock seconds]
	channel set $channel service_peak_nick $nickname
	if {[service::cfg peak announce 1]} {
		puthelp "PRIVMSG $channel :New user record on $channel: $users users (thanks to $nickname for joining)!"
	}
}

proc service::peak_text {channel} {
	set count [channel get $channel service_peak_count]
	set ts [channel get $channel service_peak_time]
	if {$count <= 0 || $ts <= 0} { return "No peak recorded yet for $channel." }
	return "Peak for $channel: $count users, reached on [clock format $ts -format "%Y-%m-%d %H:%M"] ([duration [expr {max(1, [clock seconds] - $ts)}]] ago) when [channel get $channel service_peak_nick] joined. Now: [llength [chanlist $channel]] users."
}

# peak ?on|off|reset?
proc service::cmd_peak {nickname hostname handle channel text lastbind command} {
	service::track $handle "$channel ${lastbind}$command $text"
	set option [string tolower [lindex [split $text] 0]]
	if {$option eq "" || ![matchattr $handle nm|nm $channel]} {
		if {[channel get $channel service_peak]} {
			putserv "NOTICE $nickname :[service::peak_text $channel]"
		} else {
			putserv "NOTICE $nickname :Peak tracking is disabled on $channel."
		}
		return
	}
	switch -exact -- $option {
		"on" - "enable" {
			channel set $channel +service_peak
			if {[channel get $channel service_peak_count] < [llength [chanlist $channel]]} {
				channel set $channel service_peak_count [llength [chanlist $channel]]
				channel set $channel service_peak_time [clock seconds]
				channel set $channel service_peak_nick $nickname
			}
			putserv "NOTICE $nickname :Peak tracking enabled on $channel. [service::peak_text $channel]"
		}
		"off" - "disable" {
			channel set $channel -service_peak
			putserv "NOTICE $nickname :Peak tracking disabled on $channel (the record is kept)."
		}
		"reset" {
			channel set $channel service_peak_count [llength [chanlist $channel]]
			channel set $channel service_peak_time [clock seconds]
			channel set $channel service_peak_nick $nickname
			putserv "NOTICE $nickname :Peak reset. [service::peak_text $channel]"
		}
		default {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command ?on|off|reset?"
		}
	}
}
service::register peak service::cmd_peak
