#####################################################################
# service.tcl - module: spamscan
# Spamscan (point based) and Eggdrop flood handling.
#####################################################################

namespace eval service {
	bind flud - {*} [namespace current]::parseflud
	bind time - {?0 * * * *} [namespace current]::spampoints
	bind time - {?5 * * * *} [namespace current]::spampoints
}

proc service::parseflud {nickname hostname handle type channel} {
	global botnick
	# 0 = let Eggdrop's own flood protection handle it, 1 = handled here
	if {![validchan $channel] || ![channel get $channel service_flood]} { return 0 }
	if {[matchattr $handle nmNbfS|nmovf $channel]} { return 1 }
	if {[string equal -nocase $botnick $nickname]} { return 1 }
	set bhost [service::banmask $hostname]
	set chan [string map { " " \: } [channel get $channel flood-chan]]
	set join [string map { " " \: } [channel get $channel flood-join]]
	set msg [expr {[info exists ::flood-msg] ? ${::flood-msg} : "?:?"}]
	set ctcp [string map { " " \: } [channel get $channel flood-ctcp]]
	set btime [channel get $channel service_bantime_flood]
	if {$btime == "" || $btime == "0"} {
		channel set $channel service_bantime_flood "2"
		set btime "2"
	}
	switch -exact -- $type {
		"pub" {
			set reason "anti-flood: you exceeded [lindex [split $chan :] 0] line(s) in [lindex [split $chan :] 1] second(s) - banned for $btime minute(s)"
			if {[botisop $channel] && [onchan $nickname $channel]} {
				putquick "MODE $channel +b $bhost"
				putquick "KICK $channel $nickname :$reason"
				utimer [expr {60 * $btime}] [list puthelp "MODE $channel -b $bhost"]
			}
			newchanban $channel $bhost $botnick "$reason" $btime
		}
		"join" {
			set reason "anti-flood: you exceeded [lindex [split $join :] 0] join(s) in [lindex [split $join :] 1] second(s) - banned for $btime minute(s)"
			if {[botisop $channel]} {
				if {![info exists service::flood([set channel [string tolower $channel]])]} {
					set service::flood([string tolower $channel]) "1"
					set modes [getchanmode $channel]
					set lock ""
					foreach mode [split $service::flood(lockmodes) ""] {
						if {$mode != "" && ![string match "*$mode*" $modes]} {
							append lock $mode
						}
					}
					if {$lock == ""} {
						putquick "MODE $channel +b $bhost"
						putquick "KICK $channel $nickname :$reason"
						utimer [expr {60 * $btime}] [list puthelp "MODE $channel -b $bhost"]
					} else {
						putquick "MODE $channel +b$lock $bhost"
						putquick "KICK $channel $nickname :$reason"
						utimer [expr {60 * $btime}] [list puthelp "MODE $channel -b $bhost"]
						utimer 60 [list service::unlock $channel $lock $modes]
					}
				} else {
					putquick "MODE $channel +b $bhost"
					putquick "KICK $channel $nickname :$reason"
					utimer [expr {60 * $btime}] [list puthelp "MODE $channel -b $bhost"]
				}
				newchanban $channel $bhost $botnick "$reason" $btime
			}
		}
		"msg" {
			set reason "anti-flood: you exceeded [lindex [split $msg :] 0] msg(s) in [lindex [split $msg :] 1] second(s) - banned for $btime minute(s)"
		}
		"ctcp" {
			set reason "anti-flood: you exceeded [lindex [split $ctcp :] 0] ctcp(s) in [lindex [split $ctcp :] 1] second(s) - banned for $btime minute(s)"
			if {[botisop $channel] && [onchan $nickname $channel]} {
				putquick "MODE $channel +b $bhost"
				putquick "KICK $channel $nickname :$reason"
				utimer [expr {60 * $btime}] [list puthelp "MODE $channel -b $bhost"]
			}
			newchanban $channel $bhost $botnick "$reason" $btime
		}
	}
	return 1
}

proc service::unlock {channel lock modes} {
	if {![info exists service::flood([set channel [string tolower $channel]])]} { return }
	if {[botisop $channel]} {
		puthelp "MODE $channel -$lock"
	}
	unset service::flood($channel)
}

proc service::spamscan {nickname hostname handle channel text} {
	global botnick
	set net [expr {[info exists ::network] && $::network ne "" ? $::network : "QuakeNet"}]
	if {![channel get $channel service_spamscan]} { return }
	if {[matchattr $handle nmNbfS|nmo $channel] || [isbotnick $nickname]} { return }
	# 1 = ops only excempt | 2 = ops + voice excepmt | 3 = all excempt | 4 = none excempt
	set type [channel get $channel service_stype]
	if {$type == "" || ($type != "1" && $type != "2" && $type != "3" && $type != "4")} {
		channel set $channel service_stype "1"
		set type 1
	}
	if {$type == "3"} { return }
	if {($type == "1" && ![isop $nickname $channel]) || ($type == "2" && ![isop $nickname $channel] && ![isvoice $nickname $channel]) || $type == "4"} {
		set hostname [service::banmask $hostname]
		if {![info exists service::spam($channel)]} {
			set service::spam($channel) 1
			utimer [lindex [split $service::spamscan(chanflood) :] 1] [list catch [list unset service::spam($channel)]]
		} else {
			incr service::spam($channel) 1
			if {$service::spam($channel) >= [lindex [split $service::spamscan(chanflood) :] 0]} {
				unset service::spam($channel)
				set lockmodes "$service::flood(lockmodes)"
				if {$lockmodes == ""} {
					set lockmodes "mr"
				}
				set chanmode [lindex [split [getchanmode $channel]] 0]
				set modes ""
				foreach mode [split $lockmodes ""] {
					if {![string match *$mode* $chanmode]} {
						append modes $mode
					}
				}
				if {$modes ne "" && [botisop $channel]} {
					putquick "MODE $channel +$modes"
					utimer 60 [list pushmode $channel -$modes]
				}
			}
		}
		set abuse 0
		if {![info exists service::spam(points:$channel:$hostname)]} {
			set service::spam(points:$channel:$hostname) 1
		}
		if {[regexp {\003[\d]{0,1}(,[\d]{0,2})?} $text]} {
			incr service::spam(points:$channel:$hostname) $service::spamscan(color)
			set abuse 1
		}
		if {[regexp {\002} $text]} {
			incr service::spam(points:$channel:$hostname) $service::spamscan(bold)
			set abuse 1
		}
		if {[regexp {\037} $text]} {
			incr service::spam(points:$channel:$hostname) $service::spamscan(underline)
			set abuse 1
		}
		if {[regexp {\026} $text]} {
			incr service::spam(points:$channel:$hostname) $service::spamscan(reverse)
			set abuse 1
		}
		if {[regexp {\001} $text]} {
			incr service::spam(points:$channel:$hostname) $service::spamscan(action)
			set abuse 1
		}
		regsub -all -- {\003[\d]{0,2}(,[\d]{0,2})?|\002|\037|\017|\026|\006|\007|\001|\t|\n} $text "" text
		foreach word [split $text] {
			if {$word eq ""} { continue }
			# count capitals in a copy: the advert check below needs the real word
			set caps [regsub -all {[^A-Z]} $word ""]
			if {[string length $caps] >= $service::spamscan(caps)} {
				incr service::spam(points:$channel:$hostname) [expr {[string length $caps] / 2}]
				set abuse 1
			}
			if {![service::protected $word] && ![string equal -nocase $channel $word] && [regexp -nocase -- {https?://[a-z0-9-]+\.[a-z0-9-]+|www\.[a-z0-9-]+\.[a-z0-9-]+|[a-z0-9-]+\.(com|net|org|info|biz|io|me|tv|cc|ru|xyz|top|site|online|es|eu|de)(/|$)|#[a-z0-9]+|\xA4[a-z0-9]+|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}} $word]} {
				incr service::spam(points:$channel:$hostname) $service::spamscan(advertise)
				set abuse 1
			}
		}
		if {![info exists service::spam(repeat:$channel:$hostname:$text)]} {
			set service::spam(repeat:$channel:$hostname:$text) 1
			utimer [lindex [split $service::spamscan(repeatflood) :] 1] [list catch [list unset service::spam(repeat:$channel:$hostname:$text)]]
		} else {
			incr service::spam(repeat:$channel:$hostname:$text)
			if {$service::spam(repeat:$channel:$hostname:$text) >= [lindex [split $service::spamscan(repeatflood) :] 0]} {
				incr service::spam(points:$channel:$hostname) $service::spamscan(repeat)
				set abuse 1
			}
		}
		if {![info exists service::spam(lines:$channel:$hostname)]} {
			set service::spam(lines:$channel:$hostname) 1
			utimer [lindex [split $service::spamscan(userflood) :] 1] [list catch [list unset service::spam(lines:$channel:$hostname)]]
		} else {
			incr service::spam(lines:$channel:$hostname)
			if {$service::spam(lines:$channel:$hostname) >= [lindex [split $service::spamscan(userflood) :] 0]} {
				incr service::spam(points:$channel:$hostname) $service::spamscan(spam)
				set abuse 1
			}
		}
		if {$abuse} {
			if {$service::spam(points:$channel:$hostname) >= $service::spamscan(banon)} {
				channel set $channel service_sid [set id [expr {[channel get $channel service_sid] +1}]]
				set kickmsg $service::spamscan(banmsg)
				set kickmsg [string map [list :channel: "$channel"] $kickmsg]
				set kickmsg [string map [list :network: $net] $kickmsg]
				set kickmsg [string map [list :points: "$service::spam(points:$channel:$hostname)"] $kickmsg]
				set kickmsg [string map [list :id: "$id"] $kickmsg]
				if {[botisop $channel] && [onchan $nickname $channel]} {
					putquick "MODE $channel +b $hostname"
					putquick "KICK $channel $nickname :$kickmsg"
					newchanban $channel $hostname $botnick "$kickmsg" $service::spamscan(duration)
					utimer [expr {$service::spamscan(duration) * 60}] [list pushmode $channel -b $hostname]
				} else {
					putserv "PRIVMSG $channel :$nickname - Please cease your abuse! (Points: $service::spam(points:$channel:$hostname) ID: $id)"
				}
				unset service::spam(points:$channel:$hostname)
			} elseif {$service::spam(points:$channel:$hostname) >= $service::spamscan(kickon)} {
				set kickmsg $service::spamscan(kickmsg)
				set kickmsg [string map [list :channel: "$channel"] $kickmsg]
				set kickmsg [string map [list :network: $net] $kickmsg]
				set kickmsg [string map [list :points: "$service::spam(points:$channel:$hostname)"] $kickmsg]
				if {[botisop $channel]} {
					putquick "KICK $channel $nickname :$kickmsg"
				}
			} elseif {$service::spamscan(warnuser) && $service::spam(points:$channel:$hostname) >= [expr {$service::spamscan(kickon) / 2}] && $service::spam(points:$channel:$hostname) < $service::spamscan(kickon)} {
				set warnmsg $service::spamscan(warnmsg)
				set warnmsg [string map [list :channel: $channel :network: $net :points: $service::spam(points:$channel:$hostname)] $warnmsg]
				putquick "NOTICE $nickname :$warnmsg"
			}
		}
	}
}

proc service::protected {argument} {
	set found 0
	foreach word $service::protectedwords {
		# entries in protectedwords may contain wildcards
		if {[string match -nocase $word $argument]} {
			set found 1
			break
		}
	}
	return "$found"
}

proc service::spampoints {min hour day month year} {
	foreach {who points} [array get service::spam points:*] {
		if {$points >= $service::spamscan(killpoints)} {
			set service::spam($who) "[expr {$points - $service::spamscan(killpoints)}]"
		} else {
			unset service::spam($who)
		}
	}
}
