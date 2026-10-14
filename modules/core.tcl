#####################################################################
# service.tcl - module: core
# Command dispatcher, message filters, channel settings, user data
# helpers and startup tasks. Required by every other module.
#####################################################################

namespace eval service {

	# command name -> proc (filled by service::register from the cmd_* modules)
	variable cmdmap
	if {![array exists cmdmap]} { array set cmdmap {} }

	array set global_user_levels {
		{admin} {A +A}
		{administrator} {A +A}
		{dev} {A +D}
		{developer} {A +D}
		{service} {AD +Samo}
		{owner} {n +anmovf}
		{master} {nm -n+amovf}
		{operator} {nm -nm+aovf}
		{op} {nm -nm+aovf}
		{voice} {nm -anmo+gvf}
		{friend} {nm -anmo+gvf}
		{ban} {nm -anmogvf+b}
		{none} {nm -SADanmogvfb}
		{clear} {nm -SADanmogvfb}
	}

	array set channel_user_levels {
		{owner} {ADnm|n +anmovf}
		{master} {ADnm|nm -n+amovf}
		{operator} {ADnm|nm -nm+aovf}
		{op} {ADnm|nm -nm+aovf}
		{voice} {ADnm|nm -anmo+gvf}
		{friend} {ADnm|nm -anmo+gvf}
		{ban} {ADnm|nm -anmogvf+b}
		{none} {ADnm|nm -anmogvfb}
		{clear} {ADnm|nm -anmogvfb}
	}

	bind pubm - {*} [namespace current]::central
	# evnt binds match the event name exactly: a "*" mask never fires
	bind evnt - init-server [namespace current]::evnt
	bind evnt - prerehash [namespace current]::evnt
	bind msg nm {rejoin} [namespace current]::rejoin
	bind join - {*} [namespace current]::login
	bind part - {*} [namespace current]::logout
	bind sign - {*} [namespace current]::logout
	bind raw - {315} [namespace current]::raw_endofwho
	bind time - {?0 * * * *} [namespace current]::auto
	bind time - {?5 * * * *} [namespace current]::auto
}

# All channel settings are defined here (even for disabled modules) so
# existing chanfiles keep their values.
setudef flag service

setudef flag service_prot; # The protection flag
setudef flag service_prot_hard; # The hard protection flag
setudef flag service_spamscan; # The spamscan flag
setudef flag service_flood; # The antiflood flag
setudef flag service_flyby; # The flyby flag
setudef flag service_ao; # The auto-op flag
setudef flag service_av; # The auto-voice flag
setudef flag service_autolimit; # The auto-limit flag
setudef flag service_authban; # The authbans flag
setudef flag service_badchan; # The badchannel flag
setudef flag service_vip; # The vip flag
setudef flag service_vips; # The show vip skin flag
setudef flag service_vipn; # The notice vip skin flag
setudef flag service_vip_authed; # The vip authed only flag
setudef flag service_vip_authbl; # the vip auth blacklist flag
setudef flag service_clonescan; # The onjoin clonescan flag
setudef flag service_known; # The known-only flag
setudef flag service_topic_safe; # The topicsave flag
setudef flag service_topic_force; # The forcetopic flag
setudef flag service_topic_Q; # The topic Q flag
setudef flag service_bitchmode; # The bitchmode flag
setudef flag service_badword; # The badwords flag
setudef flag service_welcome; # The welcome/greet flag
setudef flag service_welcome_notice
setudef flag service_enforcemodes
setudef flag service_startup; # The startup flag

setudef str service_badwords
setudef str service_badword_kickmsg
setudef int service_badword_bantime
setudef int service_badword_bwkid
setudef int service_badword_bwid

setudef flag service_automsg
setudef str service_automsg_line1
setudef str service_automsg_line2
setudef str service_automsg_line3
setudef str service_automsg_modes
setudef int service_automsg_int
setudef int service_automsg_lastmsg

setudef flag service_key

setudef str service_enforcedmodes

setudef flag service_antiadvertise
setudef str service_kickmsg_antiadvertise
setudef str service_antiadvertise_bantime
setudef int service_aakid

setudef flag service_netsplit
setudef str service_netsplit_time

setudef str service_topic_skin
setudef str service_topic_save

setudef str service_topicskin
setudef str service_topicskin_old
setudef str service_topic_keywords

setudef str service_servicebot
setudef str service_kickmsg_kick
setudef str service_kickmsg_ban
setudef str service_kickmsg_protkick
setudef str service_kickmsg_userkick
setudef str service_kickmsg_userban
setudef str service_kickmsg_gban
setudef str service_kickmsg_badchan
setudef str service_kickmsg_authban
setudef str service_kickmsg_defaultban
setudef str service_kickmsg_spamkick
setudef str service_kickmsg_spamban
setudef str service_kickmsg_known
setudef str service_vipskin; # The vipskin string which holds the vip skin
setudef str service_vipm; # The vipmode string which holds the vip mode
setudef str service_vipc; # The vipc chanflag which holds the vip channels
setudef str service_vip_authblist; # the vip auth blacklist str which holds the blacklist authnames
setudef str service_bantime_flood; # The antiflood bantime
setudef str service_clonescan_bantime
setudef str service_clonescan_maxclones
setudef str service_clonescan_hosttype
setudef str service_flood_massjoin
setudef str service_badchans
setudef str service_authbans
setudef str service_welcome_skin

setudef int service_kid
setudef int service_kid_known
setudef int service_gkid
setudef int service_sid
setudef int service_limit
setudef int service_vipid; # The vipid integer which holds the current vip id
setudef int service_stype; # The spamscan_type integer which holds the spamscan excempt type
setudef int service_bid
setudef int service_aid
setudef int service_jid

setudef int service_userid

setudef str service_saveops; # saved ops (saveop/reop), survives restarts
setudef str service_lockdown; # modes set by an active lockdown
setudef flag service_peak; # peak (record number of users) tracking
setudef int service_peak_count
setudef int service_peak_time
setudef str service_peak_nick

# Registers a command (and its aliases) for the dispatcher.
proc service::register {names procname} {
	foreach name $names {
		set ::service::cmdmap([string tolower $name]) $procname
	}
}

# Updates the per-user command statistics (shown in whois/whoami).
proc service::track {handle what} {
	if {![validuser $handle]} { return }
	set count [getuser $handle XTRA cmdcount]
	if {![string is integer -strict $count]} { set count 0 }
	setuser $handle XTRA lastcmd $what
	setuser $handle XTRA lastcmdset [clock seconds]
	setuser $handle XTRA cmdcount [incr count]
}

# pubm entry point: runs a command or passes the line through the filters.
# Commands are looked up in an array (O(1)) instead of a long switch.
proc service::central {nickname hostname handle channel text} {
	global botnick
	if {![validuser $handle]} {
		set handle [service::resolve $nickname $handle]
	}
	set words [split $text]
	set first [lindex $words 0]
	if {[string equal -nocase $botnick $first]} {
		# "BotNick command args"
		set lastbind "$botnick "
		set command [lindex $words 1]
		set args [join [lrange $words 2 end]]
	} elseif {[lsearch -exact $service::triggers [string index $first 0]] != -1 && [validuser $handle]} {
		# "<trigger>command args" - only the user's own trigger is accepted,
		# except for mytrigger so a forgotten trigger can be recovered
		set lastbind [string index $first 0]
		set command [string range $first 1 end]
		set args [join [lrange $words 1 end]]
		if {$lastbind ne [getuser $handle XTRA mytrigger] && [lsearch -exact {mytrigger mytrig trig trigger} [string tolower $command]] == -1} {
			service::filters $nickname $hostname $handle $channel $text
			return
		}
	} else {
		service::filters $nickname $hostname $handle $channel $text
		return
	}
	set key [string tolower $command]
	if {$key eq "" || ![validuser $handle] || ![info exists ::service::cmdmap($key)]} {
		service::filters $nickname $hostname $handle $channel $text
		return
	}
	if {[catch {$::service::cmdmap($key) $nickname $hostname $handle $channel $args $lastbind $command} err]} {
		# never let a broken command fail silently: tell the user, report to staff
		set info $::errorInfo
		putserv "NOTICE $nickname :ERROR: '$command' failed. (Reported to the bot staff)"
		if {[validchan $service::adminchan]} {
			putserv "PRIVMSG $service::adminchan :Error in '$lastbind$command $args' by $nickname ($handle) on $channel: $err"
		}
		putlog "service.tcl - error in command '$command': $info"
	}
}

# Value from a configuration array, or a default when service.conf does not
# set it (keeps old configuration files working after an update).
proc service::cfg {array key {default ""}} {
	upvar #0 ::service::$array arr
	if {[info exists arr($key)]} {
		return $arr($key)
	}
	return $default
}

# Sends a line to the server immediately (no queue) when Eggdrop supports
# putnow (1.8.4+), otherwise at the front of the quick queue. Used for
# anti-takeover reactions, where every millisecond counts.
proc service::now {line} {
	if {[info commands ::putnow] ne ""} {
		putnow $line
	} else {
		putquick $line -next
	}
}

# --- QuakeNet accounts --------------------------------------------------

# Q account of a nickname, or "" when not authed/unknown. Uses Eggdrop's
# account tracking (1.9+, WHOX) and falls back to the +x hidden host.
proc service::account {nickname {userhost ""}} {
	if {[info commands ::getaccount] ne ""} {
		if {![catch {getaccount $nickname} acct] && $acct ne "" && $acct ne "*"} {
			return $acct
		}
	}
	if {$userhost eq ""} {
		set userhost [getchanhost $nickname]
	}
	set host [lindex [split $userhost @] end]
	if {[string match -nocase *.users.quakenet.org $host]} {
		return [lindex [split $host .] 0]
	}
	return ""
}

# Rebuilds the account -> handle index from the XTRA "account" field.
proc service::acct_rebuild {} {
	variable acct2hand
	array unset acct2hand
	array set acct2hand {}
	foreach user [userlist] {
		if {[set acct [getuser $user XTRA account]] ne ""} {
			set acct2hand([string tolower $acct]) $user
		}
	}
}

# Adds the Q hidden host of an account (*!*@<account>.users.quakenet.org) to
# a user, and links the account if the user has none, so a user added with
# their real host is still recognised after they auth and set +x.
# Returns the mask added, or "" when there was nothing to add.
proc service::add_authhost {hand acct} {
	if {$acct eq "" || ![validuser $hand]} { return "" }
	if {![regexp {^[A-Za-z0-9\[\]\\`^\{\}|_-]+$} $acct]} { return "" }
	if {[getuser $hand XTRA account] eq ""} {
		setuser $hand XTRA account $acct
		service::acct_rebuild
	}
	set mask "*!*@$acct.users.quakenet.org"
	foreach host [getuser $hand HOSTS] {
		if {[string equal -nocase $host $mask]} { return "" }
	}
	setuser $hand HOSTS $mask
	return $mask
}

# Handle for a nickname: the given handle when it is valid, otherwise the
# user whose Q account matches the nickname's account, otherwise "*".
proc service::resolve {nickname {handle "*"}} {
	if {[validuser $handle]} { return $handle }
	variable acct2hand
	if {[array size acct2hand] == 0} { return $handle }
	set acct [string tolower [service::account $nickname]]
	if {$acct ne "" && [info exists acct2hand($acct)] && [validuser $acct2hand($acct)]} {
		return $acct2hand($acct)
	}
	return $handle
}

# --- persistent saveop list ------------------------------------------------

proc service::saveops_store {channel} {
	if {![validchan $channel]} { return }
	set chan [string tolower $channel]
	set nicks [list]
	foreach key [array names ::service::saveops $chan:*] {
		lappend nicks [string range $key [string length $chan:] end]
	}
	channel set $channel service_saveops [join $nicks " "]
}

proc service::saveops_load {} {
	foreach channel [channels] {
		set chan [string tolower $channel]
		foreach nick [split [channel get $channel service_saveops]] {
			if {$nick ne ""} {
				set ::service::saveops($chan:$nick) 1
			}
		}
	}
}

# Message filters for normal lines: badwords, anti-advertise, spamscan.
# Each check runs in turn; the first one that punishes the user stops the rest.
proc service::filters {nickname hostname handle channel text} {
	if {![matchattr $handle nm|nmo $channel]} {
		if {[service::filter_badword $nickname $hostname $channel $text]} { return }
		if {[service::filter_advertise $nickname $hostname $channel $text]} { return }
	}
	if {[info commands ::service::spamscan] ne ""} {
		service::spamscan $nickname $hostname $handle $channel $text
	}
}

proc service::filter_badword {nickname hostname channel text} {
	if {![channel get $channel service_badword] || [set words [channel get $channel service_badwords]] == ""} { return 0 }
	set words [string tolower $words]
	set list [list]
	foreach word [split $text] {
		if {$word == ""} { continue }
		if {[lsearch -exact $words [string tolower $word]] != -1} {
			lappend list $word
		}
	}
	if {[llength $list] == 0} { return 0 }
	if {[set kickmsg [channel get $channel service_badword_kickmsg]] == ""} {
		channel set $channel service_badword_kickmsg "[set kickmsg $service::kickmsg(badword)]"
	}
	channel set $channel service_badword_bwkid "[set bwkid [expr {[channel get $channel service_badword_bwkid] + 1}]]"
	channel set $channel service_badword_bwid "[set bwid [expr {[channel get $channel service_badword_bwid] + [llength $list]}]]"
	if {![botisop $channel]} { return 1 }
	set kickmsg [string map [list :nickname: $nickname :hostname: $hostname :badword: [join $list ", "] :found: [llength $list] :channel: $channel :id: $bwkid :bid: $bwid] $kickmsg]
	set banmask [service::banmask $hostname]
	putquick "MODE $channel -o+b $nickname $banmask"
	putquick "KICK $channel $nickname :$kickmsg"
	if {[set bantime [channel get $channel service_badword_bantime]] < 1} {
		channel set $channel service_badword_bantime "[set bantime 1]"
	}
	utimer [expr {$bantime * 60}] [list pushmode $channel -b $banmask]
	return 1
}

proc service::filter_advertise {nickname hostname channel text} {
	if {![channel get $channel service_antiadvertise]} { return 0 }
	set list [list]
	foreach word [split $text] {
		if {$word eq "" || [string equal -nocase $channel $word]} { continue }
		if {[regexp -nocase -- {https?://[a-z0-9-]+\.[a-z0-9-]+|www\.[a-z0-9-]+\.[a-z0-9-]+|#[a-z0-9]+|\xA4[a-z0-9]+|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}} $word]} {
			if {[info commands ::service::protected] ne "" && [service::protected $word]} { continue }
			lappend list $word
		}
	}
	if {[llength $list] == 0} { return 0 }
	if {[set kickmsg [channel get $channel service_kickmsg_antiadvertise]] == ""} {
		channel set $channel service_kickmsg_antiadvertise "[set kickmsg $service::kickmsg(antiadvertise)]"
	}
	channel set $channel service_aakid "[set id [expr {[channel get $channel service_aakid] + 1}]]"
	if {![botisop $channel]} { return 1 }
	set kickmsg [string map [list :nickname: $nickname :hostname: $hostname :word: [join $list ", "] :found: [llength $list] :channel: $channel :id: $id] $kickmsg]
	set banmask [service::banmask $hostname]
	putquick "MODE $channel -o+b $nickname $banmask"
	putquick "KICK $channel $nickname :$kickmsg"
	if {![string is integer -strict [set bantime [channel get $channel service_antiadvertise_bantime]]] || $bantime < 1} {
		channel set $channel service_antiadvertise_bantime "[set bantime 1]"
	}
	utimer [expr {$bantime * 60}] [list pushmode $channel -b $banmask]
	return 1
}

# Builds a ban mask from user@host: *!*@account.users.quakenet.org for
# authed (+x) users, *!*user@host otherwise ("~" is stripped).
proc service::banmask {userhost} {
	set userhost [string trimleft $userhost ~]
	set host [lindex [split $userhost @] end]
	if {[string match -nocase *.users.quakenet.org $host]} {
		return "*!*@$host"
	}
	return "*!*$userhost"
}

proc putservlog {text} {
	global botnick
	if {![file isdir [file join [pwd] logs service $botnick]]} {
		file mkdir [file join [pwd] logs service $botnick]
	}
	set file [open [file join [pwd] logs service $botnick [clock format [unixtime] -format %d%m%y].log] a]
	puts $file "\[[clock format [unixtime] -format %H:%M:%S]\] $text"
	close $file
}

proc service::evnt {type} {
	switch -exact -- $type {
		"init-server" {
			foreach channel [channels] {
				channel set $channel +service_startup
			}
			if {[info commands ::service::qauth] ne ""} {
				service::qauth 1
			}
		}
		"prerehash" {
			foreach bind [binds] {
				if {[string match "*service::*" [lindex $bind 4]]} {
					catch {unbind [lindex $bind 0] [lindex $bind 1] [lindex $bind 2] [lindex $bind 4]}
				}
			}
			foreach command [info commands ::service::*] {
				if {$command ne "::service::evnt"} {
					rename $command ""
				}
			}
			array unset ::service::cmdmap
			save
		}
		"default" {
			return
		}
	}
}

proc service::raw_endofwho {from raw arg} {
	set channel [lindex [split $arg] 1]
	if {[validchan $channel] && [channel get $channel service_startup]} {
		channel set $channel -service_startup
	}
	return 0
}

proc service::auto {minute hour day month year} {
	putquick "JOIN $service::adminchan" -next
	if {$minute == "15" || $minute == "30" || $minute == "45" || $minute == "00"} {
	#    service::authenticate
	}
	putlog "\[ $service::script - auto \] - Performing autosave..."
	save
}

proc service::login {nickname hostname handle channel} {
	if {[isbotnick $nickname]} {
		# the bot joined: mark every known user already in the channel
		foreach user [chanlist $channel] {
			set hand [nick2hand $user $channel]
			if {[validuser $hand] && [getuser $hand XTRA loggedin] != "1"} {
				service::setlogin $hand [getchanhost $user $channel]
			}
		}
	} elseif {[validuser $handle] && [getuser $handle XTRA loggedin] != "1"} {
		service::setlogin $handle $hostname
	}
}

proc service::setlogin {handle hostname} {
	setuser $handle XTRA loggedin "1"
	setuser $handle XTRA lastlogin "[clock seconds]"
	setuser $handle XTRA lasthost "[string trimleft $hostname ~]"
}

proc service::logout {nickname hostname handle channel {info ""}} {
    global botnick
	if {[string equal -nocase $botnick $nickname]} {
	    foreach user [userlist] {
		    if {[getuser $user XTRA loggedin] == "1" && [hand2nick $user] == ""} {
			    setuser $user XTRA loggedin "0"
			}
		}
	} elseif {[validuser $handle] && [getuser $handle XTRA loggedin] == "1" && ![onchan $nickname]} {
	    setuser $handle XTRA loggedin "0"
	}
}

proc service::hand2nicks {handle} {
    set nicks [list]
	foreach channel [channels] {
	    if {$channel == ""} { continue }
		foreach nick [chanlist $channel] {
		    if {$nick == "" || [set x [nick2hand $nick]] == "" || $x == "*"} { continue }
			if {[string equal -nocase $handle $x]} {
			    lappend nicks $nick
			}
		}
	}
	return [lsort -unique $nicks]
}

proc service::accesslevel {handle {channel ""}} {
    if {$channel == ""} {
	    if {[matchattr $handle A]} {
		    return 8
		} elseif {[matchattr $handle D]} {
		    return 7
		} elseif {[matchattr $handle S]} {
		    return 6
		} elseif {[matchattr $handle n]} {
		    return 5
		} elseif {[matchattr $handle m]} {
		    return 4
		} elseif {[matchattr $handle o]} {
		    return 3
		} elseif {[matchattr $handle vf]} {
		    return 2
		} elseif {[matchattr $handle B]} {
		    return 1
		} else {
		    return 0
		}
	} elseif {![validchan $channel]} {
	    return 0
	} else {
	    if {[matchattr $handle |n $channel]} {
		    return 5
		} elseif {[matchattr $handle |m $channel]} {
		    return 4
		} elseif {[matchattr $handle |o $channel]} {
		    return 3
		} elseif {[matchattr $handle |vf $channel]} {
		    return 2
		} elseif {[matchattr $handle |B $channel]} {
		    return 1
		} else {
		    return 0
		}
	}
	return 0
}

proc service::tduration {string} {
	set result "0"
	array set duration {
		{minute} {60}
		{hour} {3600}
		{day} {86400}
		{week} {604800}
		{month} {2419200}
		{year} {31536000}
	}
	if {[regexp -nocase -- {([\d]{1,})m} $string full minute]} {
		set result "[expr {$result+($duration(minute)*$minute)}]"
	}
	if {[regexp -nocase -- {([\d]{1,})h} $string full hour]} {
		set result "[expr {$result+($duration(hour)*$hour)}]"
	}
	if {[regexp -nocase -- {([\d]{1,})d} $string full day]} {
		set result "[expr {$result+($duration(day)*$day)}]"
	}
	if {[regexp -nocase -- {([\d]{1,})w} $string full week]} {
		set result "[expr {$result+($duration(week)*$week)}]"
	}
	if {[regexp -nocase -- {([\d]{1,})y} $string full year]} {
		set result "[expr {$result+($duration(year)*$year)}]"
	}
	return "$result"
}

proc service::btduration {string} {
  if {![regexp -- {[0-9]+(s|m|h|d|w|y)} $string]} { return 0 }
  set duration 0
  if {[regexp -- {([0-9]+)s} $string -> number]} {
    set duration [expr {$duration+$number}]
  }
  if {[regexp -- {([0-9]+)m} $string -> number]} {
    set duration [expr {$duration+($number*60)}]
  }
  if {[regexp -- {^([0-9]+)h$} $string -> number]} {
    set duration [expr {$duration+($number*3600)}]
  }
  if {[regexp -- {^([0-9]+)d$} $string -> number]} {
    set duration [expr {$duration+($number*86400)}]
  }
  if {[regexp -- {^([0-9]+)w$} $string -> number]} {
    set duration [expr {$duration+($number*604800)}]
  }
  if {[regexp -- {^([0-9]+)y$} $string -> number]} {
    set duration [expr {$duration+($number*31536000)}]
  }
  if {[regexp -- {-} $duration]} {
    return 0
  }
  return $duration
}

proc service::host2hand {host} {
	set who "*"
	foreach user [userlist] {
		if {[llength [getuser $user HOSTS]] > 1} {
			foreach mask [getuser $user HOSTS] {
				if {[string equal -nocase $host $mask]} {
					set who $user
					break
				}
			}
		} elseif {[string equal -nocase $host [getuser $user HOSTS]]} {
			set who $user
			break
		}
	}
	return "$who"
}

proc service::validtopickey {channel keyword} {
	if {[set curr [channel get $channel service_topic_keywords]] == ""} {
		return "0"
	} else {
		array set temp {}
		set result 0
		foreach entry $curr {
			set temp([string tolower [lindex [split $entry] 0]]) "1"
		}
		return "[info exists temp([string tolower $keyword])]"
	}
}

proc service::rejoin {nickname hostname handle text} {
	if {![matchattr $handle nm]} { return }
	set channel [lindex [split $text] 0]
	if {[string index $channel 0] ne "#"} {
		putserv "NOTICE $nickname :SYNTAX: /msg $::botnick rejoin #channel"
	} elseif {[validchan $channel]} {
		channel set $channel +inactive
		putquick "PART $channel"
		# non-blocking: "after 2000" would freeze the whole bot for 2 seconds
		utimer 2 [list channel set $channel -inactive]
		putserv "NOTICE $nickname :Rejoined '$channel' successfully."
	} elseif {[llength [channels]] >= 20} {
		putserv "NOTICE $nickname :Could not (re)join '$channel' - I'm already 20/20."
	} else {
		channel add $channel
		chattr $handle |+amno $channel
		putserv "NOTICE $nickname :(Re)joined '$channel' successfully."
	}
}

proc service::service {channel} {
	if {[onchan L $channel]} {
		return L
	} elseif {[onchan Q $channel]} {
		return Q
	} else {
		return ""
	}
}

proc service::services {channel} {
	set list ""
	foreach x "L Q S" {
		if {$x == ""} { return }
		if {[onchan $x $channel]} {
			lappend list $x
		}
	}
	return "[join $list " "]"
}

# Never allow catch-all bans, whatever code tries to add them.
if {[info commands anewban] == ""} {
	rename newban anewban
	proc newban {ban creator comment {lifetime "60"} {options "none"}} {
		if {$ban == "*!*@" || $ban == "*!*@*" || $ban == "*!**@*" || $ban == "*!**@"} {
			putlog "newban: (bad banmask: $ban) - $ban $creator '$comment' $lifetime $options"
		} else {
			anewban $ban $creator $comment $lifetime $options
		}
	}
}

if {[info commands anewchanban] == ""} {
	rename newchanban anewchanban
	proc newchanban {channel ban creator comment {lifetime "60"} {options "none"}} {
		if {$ban == "*!*@" || $ban == "*!*@*" || $ban == "*!**@*" || $ban == "*!**@"} {
			putlog "newchanban: (bad banmask: $ban) - $channel $ban $creator '$comment' $lifetime $options"
		} else {
			anewchanban $channel $ban $creator $comment $lifetime $options
		}
	}
}

# Startup tasks, run by the loader once every module is loaded.
proc service::init {} {
	service::acct_rebuild
	service::saveops_load
	foreach channel [channels] {
		# remove dangerous catch-all bans left over from older versions
		foreach ban [list *!*@ *!*@* *!**@ *!**@* *@*] {
			catch {killchanban $channel $ban}
			if {[botisop $channel] && [ischanban $ban $channel]} {
				pushmode $channel -b $ban
			}
		}
		if {[botonchan $channel] && [onchan Q $channel]} {
			channel set $channel service_servicebot "Q"
		}
	}
	# default user data (XTRA fields)
	foreach user [userlist] {
		if {$user == ""} { continue }
		if {[getuser $user XTRA mytrigger] == ""} {
			setuser $user XTRA mytrigger "$service::trigger"
			setuser $user XTRA mytriggerset "[clock seconds]"
		}
		if {[getuser $user XTRA mytriggerset] == ""} {
			setuser $user XTRA mytriggerset "[clock seconds]"
		}
		if {[getuser $user XTRA userid] == "" && [validchan $service::adminchan]} {
			channel set $service::adminchan service_userid "[set userid [expr {[channel get $service::adminchan service_userid]+1}]]"
			setuser $user XTRA userid "$userid"
		}
		foreach {field value} {loggedin 0 lasthost N/A email N/A cmdcount 0 lastcmd N/A} {
			if {[getuser $user XTRA $field] == ""} {
				setuser $user XTRA $field $value
			}
		}
	}
}

proc service::loaded {} {
	set ms [format %.1f [expr {([clock microseconds] - $service::start) / 1000.0}]]
	putlog "$service::copyright - [llength $service::loadedmodules] modules ([join $service::loadedmodules {, }]) - [array size ::service::cmdmap] commands - loaded in ${ms}ms"
}
