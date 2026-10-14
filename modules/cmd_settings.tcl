#####################################################################
# service.tcl - module: cmd_settings
# Commands: per-channel feature settings (protect, spamscan, flood, vip,
# badword, topic, chanflags, status, ...).
#####################################################################

# protection, protect
proc service::cmd_protection {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_prot]
	set hard [channel get $channel service_prot_hard]
	set cmd [lindex [split $text] 0]
	switch -exact -- $cmd {
		"on" - "enable" {
			if {$status} {
				putserv "NOTICE $nickname :$channel protection is already enabled."
			} elseif {![onchan L $channel] && ![onchan Q $channel]} {
				putserv "NOTICE $nickname :No network service bot \{Q/L\} at $channel."
			} else {
				if {[onchan L $channel]} { channel set $channel service_servicebot "L" }
				if {[onchan Q $channel]} { channel set $channel service_servicebot "Q" }
				channel set $channel +service_prot
				putserv "NOTICE $nickname :Done (Service bot: [channel get $channel service_servicebot])."
			}
		}
		"off" - "disable" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel protection is already disabled."
			} else {
				channel set $channel -service_prot
				putserv "NOTICE $nickname :Done."
			}
		}
		"status" {
			putserv "NOTICE $nickname :$channel protection is \002[expr {$status ? "enabled" : "disabled"}]\002 - hard protection is \002[expr {$hard ? "enabled" : "disabled"}]\002."
		}
		"hard" {
			switch -exact -- [set sub [lindex [split $text] 1]] {
				"on" - "enable" {
					if {$hard} {
						putserv "NOTICE $nickname :Hard protection is already enabled."
					} else {
						channel set $channel +service_prot_hard
						putserv "NOTICE $nickname :Hard protection is now enabled."
					}
				}
				"off" - "disable" {
					if {!$hard} {
						putserv "NOTICE $nickname :Hard protection is already disabled."
					} else {
						channel set $channel -service_prot_hard
						putserv "NOTICE $nickname :Hard protection is now disabled."
					}
				}
				"status" {
					if {$hard} {
						putserv "NOTICE $nickname :Hard protection is: \002enabled\002."
					} else {
						putserv "NOTICE $nickname :Hard protection is :\002disabled\002."
					}
				}
				"default" {
					putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd on|off|status."
				}
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status."
		}
	}
}
service::register {protection protect} service::cmd_protection

# spamscan
proc service::cmd_spamscan {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_spamscan]
	set cmd [lindex [split $text] 0]
	switch -exact -- $cmd {
		"on" - "enable" {
			if {$status} {
				putserv "NOTICE $nickname :$channel spamscan is already enabled."
			} else {
				channel set $channel +service_spamscan
				putserv "NOTICE $nickname :Done."
			}
		}
		"off" - "disable" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel spamscan is already disabled."
			} else {
				channel set $channel -service_spamscan
				putserv "NOTICE $nickname :Done."
			}
		}
		"status" {
			if {$status} {
				putserv "NOTICE $nickname :$channel spamscan is enabled."
			} else {
				putserv "NOTICE $nickname :$channel spamscan is disabled."
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status."
		}
	}
}
service::register spamscan service::cmd_spamscan

# flood
proc service::cmd_flood {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_flood]
	switch -exact -- [set cmd [lindex [split $text] 0]] {
		"on" {
			if {$status} {
				putserv "NOTICE $nickname :$channel anti-flood is already enabled."
			} else {
				channel set $channel +service_flood
				putserv "NOTICE $nickname :$channel anti-flood is now enabled."
			}
		}
		"off" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel anti-flood is already disabled."
			} else {
				channel set $channel -service_flood
				putserv "NOTICE $nickname :$channel anti-flood is now disabled."
			}
		}
		"set" {
			set chan "[string map { " " \: } [channel get $channel flood-chan]]"
			set join "[string map { " " \: } [channel get $channel flood-join]]"
			set ctcp "[string map { " " \: } [channel get $channel flood-ctcp]]"
			set mjoin "[string map { " " \: } [channel get $channel service_flood_massjoin]]"
			switch -exact -- [set cmd_ [lindex [split $text] 1]] {
				"chan" {
					set chan_ [lindex [split $text] 2]
					if {$chan_ == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $cmd $cmd_ <x:y>. (where x is lines and y is per seconds)"
					} elseif {$chan_ == "$chan"} {
						putserv "NOTICE $nickname :flood-chan is already set to $chan_. ([lindex [split $chan :] 0] lines in [lindex [split $chan :] 1] seconds)"
					} elseif {![regexp -nocase {^[\d]{1,3}\:[\d]{1,3}$} $chan_]} {
						putserv "NOTICE $nickname :Invalid setting - Must be in the format: \002x\002:\002y\002 (x lines :(in) y seconds  - where x and y must be positive (not minus) digits)"
					} else {
						channel set $channel flood-chan "$chan_"
						putserv "NOTICE $nickname :flood-chan setting is now set to '$chan_'. ([lindex [split $chan_ :] 0] lines in [lindex [split $chan_ :] 1] seconds)"
					}
				}
				"join" {
					set join_ [lindex [split $text] 2]
					if {$join_ == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $cmd $cmd_ <x:y>. (where x is joins and y is per seconds)"
					} elseif {$join_ == "$join"} {
						putserv "NOTICE $nickname :flood-join is already set to $join_. ([lindex [split $join_ :] 0] joins in [lindex [split $join_ :] 1] seconds)"
					} elseif {![regexp -nocase {^[\d]{1,3}\:[\d]{1,3}$} $join_]} {
						putserv "NOTICE $nickname :Invalid setting - Must be in the format: \002x\002:\002y\002 (x joins :(in) y seconds  - where x and y must be positive (not minus) digits)"
					} else {
						channel set $channel flood-join "$join_"
						putserv "NOTICE $nickname :flood-join setting is now set to '$join_'. ([lindex [split $join_ :] 0] joins in [lindex [split $join_ :] 1] seconds)"
					}
				}
				"ctcp" {
					set ctcp_ [lindex [split $text] 2]
					if {$ctcp_ == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $cmd $cmd_ <x:y>. (where x is ctcps and y is per seconds)"
					} elseif {$ctcp_ == "$ctcp"} {
						putserv "NOTICE $nickname :flood-ctcp is already set to $ctcp_. ([lindex [split $ctcp :] 0] ctcps in [lindex [split $ctcp :] 1] seconds)"
					} elseif {![regexp -nocase {^[\d]{1,3}\:[\d]{1,3}$} $ctcp_]} {
						putserv "NOTICE $nickname :Invalid setting - Must be in the format: \002x\002:\002y\002 (x ctcps :(in) y seconds  - where x and y must be positive (not minus) digits)"
					} else {
						channel set $channel flood-ctcp "$ctcp_"
						putserv "NOTICE $nickname :flood-ctcp setting is now set to '$ctcp_'. ([lindex [split $ctcp :] 0] ctcps in [lindex [split $ctcp :] 1] seconds)"
					}
				}
				"massjoin" {
					set mjoin_ [lindex [split $text] 2]
					if {$mjoin_ == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $cmd $cmd_ <x:y>. (where x is joins and y is per seconds)"
					} elseif {$mjoin_ == "$mjoin"} {
						putserv "NOTICE $nickname :flood-join is already set to $mjoin_. ([lindex [split $mjoin_ :] 0] joins in [lindex [split $mjoin_ :] 1] seconds)"
					} elseif {![regexp -nocase {^[\d]{1,3}\:[\d]{1,3}$} $mjoin_]} {
						putserv "NOTICE $nickname :Invalid setting - Must be in the format: \002x\002:\002y\002 (x joins :(in) y seconds  - where x and y must be positive (not minus) digits)"
					} else {
						channel set $channel service_flood_massjoin "$mjoin_"
						putserv "NOTICE $nickname :flood-join setting is now set to '$mjoin_'. ([lindex [split $mjoin_ :] 0] joins in [lindex [split $mjoin_ :] 1] seconds)"
					}
				}
				"default" {
					putserv "NOTICE $nickname :anti-flood settings are either 'chan' or 'join' or 'ctcp'."
				}
			}
		}
		"bantime" {
			set btime "[lindex [split $text] 1]"
			if {$btime == ""} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd <bantime>."
			} elseif {![regexp -nocase {^[\d]{1,}$} $btime]} {
				putserv "NOTICE $nickname :Bantime must be an integer (number)."
			} elseif {$btime == "0"} {
				putserv "NOTICE $nickname :Bantime must be greater than 0."
			} elseif {$btime == [channel get $channel service_bantime_flood]} {
				putserv "NOTICE $nickname :Bantime is already set at '$btime' minute(s)"
			} else {
				channel set $channel service_bantime_flood "$btime"
				putserv "NOTICE $nickname :flood-bantime set to '$btime' minute(s)."
			}
		}
		"status" {
			set status "[expr {$status == 1 ? "enabled" : "disabled"}]"
			set chan "[string map { " " \: } [channel get $channel flood-chan]]"
			set join "[string map { " " \: } [channel get $channel flood-join]]"
			set ctcp "[string map { " " \: } [channel get $channel flood-ctcp]]"
			set btime "[channel get $channel service_bantime_flood]"
			if {$btime == "" || $btime == "0"} {
				channel set $channel service_bantime_flood "2"
				set btime "2"
			}
			putserv "NOTICE $nickname :$channel anti-flood is \002$status\002. Flood-chan is set to '$chan' ([lindex [split $chan :] 0] lines in [lindex [split $chan :] 1] seconds). Flood-join is set to '$join' ([lindex [split $join :] 0] joins in [lindex [split $join :] 1] seconds). Flood-ctcp is set to '$ctcp' ([lindex [split $ctcp :] 0] ctcps in [lindex [split $ctcp :] 1] seconds). Flood-bantime is set to '$btime' minute(s)."
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|set|bantime|status."
		}
	}
}
service::register flood service::cmd_flood

# flyby
proc service::cmd_flyby {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_flyby]
	set cmd [lindex [split $text] 0]
	switch -exact -- $cmd {
		"on" - "enable" {
			if {$status} {
				putserv "NOTICE $nickname :$channel flyby is already enabled."
			} else {
				channel set $channel +service_flyby
				putserv "NOTICE $nickname :Done."
			}
		}
		"off" - "disable" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel flyby is already disabled."
			} else {
				channel set $channel -service_flyby
				putserv "NOTICE $nickname :Done."
			}
		}
		"status" {
			if {$status} {
				putserv "NOTICE $nickname :$channel flyby is enabled."
			} else {
				putserv "NOTICE $nickname :$channel flyby is disabled."
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status."
		}
	}
}
service::register flyby service::cmd_flyby

# autoop, ao
proc service::cmd_autoop {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_ao]
	set cmd [lindex [split $text] 0]
	switch -exact -- $cmd {
		"on" - "enable" {
			if {$status} {
				putserv "NOTICE $nickname :$channel auto-op is already enabled."
			} else {
				channel set $channel +service_ao
				putserv "NOTICE $nickname :Done."
			}
		}
		"off" - "disable" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel auto-op is already disabled."
			} else {
				channel set $channel -service_ao
				putserv "NOTICE $nickname :Done."
			}
		}
		"status" {
			if {$status} {
				putserv "NOTICE $nickname :$channel auto-op is enabled."
			} else {
				putserv "NOTICE $nickname :$channel auto-op is disabled."
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status."
		}
	}
}
service::register {autoop ao} service::cmd_autoop

# autovoice, av
proc service::cmd_autovoice {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_av]
	set cmd [lindex [split $text] 0]
	switch -exact -- $cmd {
		"on" - "enable" {
			if {$status} {
				putserv "NOTICE $nickname :$channel auto-voice is already enabled."
			} else {
				channel set $channel +service_av
				putserv "NOTICE $nickname :Done."
			}
		}
		"off" - "disable" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel auto-voice is already disabled."
			} else {
				channel set $channel -service_av
				putserv "NOTICE $nickname :Done."
			}
		}
		"status" {
			if {$status} {
				putserv "NOTICE $nickname :$channel auto-voice is enabled."
			} else {
				putserv "NOTICE $nickname :$channel auto-voice is disabled."
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status."
		}
	}
}
service::register {autovoice av} service::cmd_autovoice

# known
proc service::cmd_known {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_known]
	set cmd [lindex [split $text] 0]
	switch -exact -- $cmd {
		"on" - "enable" {
			if {$status} {
				putserv "NOTICE $nickname :$channel known-only is already enabled."
			} else {
				channel set $channel +service_known
				putserv "NOTICE $nickname :Done."
			}
		}
		"off" - "disable" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel known-only is already disabled."
			} else {
				channel set $channel -service_known
				putserv "NOTICE $nickname :Done."
			}
		}
		"status" {
			if {$status} {
				putserv "NOTICE $nickname :$channel known-only is enabled."
			} else {
				putserv "NOTICE $nickname :$channel known-only is disabled."
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status."
		}
	}
}
service::register known service::cmd_known

# clonescan
proc service::cmd_clonescan {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set scan [channel get $channel service_clonescan]
	foreach {y z} "bantime $service::bantime(clonescan) maxclones $service::clonescan(maxclones) hosttype $service::clonescan(hosttype)" {
		set x [channel get $channel service_clonescan_$y]
		if {$x == "" && $z != ""} {
			channel set $channel service_clonescan_$y "$z"
		}
	}
	switch -exact -- [set option [lindex [split $text] 0]] {
		"on" - "enable" {
			if {$scan} {
				putserv "NOTICE $nickname :$channel clonescan on-join is already enabled."
			} else {
				channel set $channel +service_clonescan
				putserv "NOTICE $nickname :$channel clonescan on-join is now enabled."
			}
		}
		"off" - "disable" {
			if {!$scan} {
				putserv "NOTICE $nickname :$channel clonescan on-join is already disabled."
			} else {
				channel set $channel -service_clonescan
				putserv "NOTICE $nickname :$channel clonescan on-join is now disabled."
			}
		}
		"set" {
			switch -exact -- [set sub [lindex [split $text] 1]] {
				"bantime" {
					if {[set bantime [lindex [split $text] 2]] == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option $sub ?#bantime? (Where bantime is digits only)."
					} elseif {![regexp -nocase -- {\#([\d]{1,})} $bantime -> bantime]} {
						putserv "NOTICE $nickname :You must specify a valid bantime. You must enter # followed by your bantime in minutes (Where bantime is digits only)."
					} elseif {$bantime == [set curr [channel get $channel service_clonescan_bantime]]} {
						putserv "NOTICE $nickname :The new bantime matches the current bantime. Please select a different bantime and try again."
					} elseif {$bantime < 1} {
						putserv "NOTICE $nickname :The bantime must be 1 minute or higher."
					} else {
						channel set $channel service_clonescan_bantime "$bantime"
						putserv "NOTICE $nickname :New bantime of '$bantime minute(s)' set."
					}
				}
				"maxclones" {
					if {[set max [lindex [split $text] 2]] == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option $sub ?#maxclones? (Where maxclones is digits only)."
					} elseif {![regexp -nocase -- {\#([\d]{1,})} $max -> max]} {
						putserv "NOTICE $nickname :You must specify a valid entery. You must enter # followed by maxclones (Where maxclones is digits only)."
					} elseif {$max == [set curr [channel get $channel service_clonescan_maxclones]]} {
						putserv "NOTICE $nickname :The new maxclones matches the current maxclones. Please specify a different maxclones setting and try again."
					} elseif {$max < 3} {
						putserv "NOTICE $nickname :The maxclones setting must be 3 or higher."
					} else {
						channel set $channel service_clonescan_maxclones "$max"
						putserv "NOTICE $nickname :New maxclones setting of '$max clone(s)' set."
					}
				}
				"hosttype" {
					if {[set host [lindex [split $text] 2]] == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option $sub ?#hosttype? (Where hosttype must be digits only)."
					} elseif {![regexp -nocase {\#(1|2)} $host -> host]} {
						putserv "NOTICE $nickname :You must specify a valid hosttype entery. You must enter # followed by your hosttype (Hosttype #1 = *!*@evil.host - Hosttype #2 = *!*ident@evil.host (~ is striped from hosts))."
					} elseif {$host == [set curr [channel get $channel service_clonescan_hosttype]]} {
						putserv "NOTICE $nickname :The new hosttype setting matches the current hosttype. Please specify a different hosttype setting and try again."
					} else {
						channel set $channel service_clonescan_hosttype "$host"
						putserv "NOTICE $nickname :New hosttype setting of '$host [expr {$host == 1 ? "*!*" : "*!*ident"}]@evil.host' set."
					}
				}
				"default" {
					putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option bantime ?#bantime?|maxclones ?#maxclones?|hosttype ?#hosttype?."
				}
			}
		}
		"status" {
			putserv "NOTICE $nickname :Clonescan on-join is: \002[expr {$scan == 1 ? "enabled" : "disabled"}]\002. Bantime is \002[channel get $channel service_clonescan_bantime]\002, maxclones is \002[channel get $channel service_clonescan_maxclones]\002, and hosttype is \002[channel get $channel service_clonescan_hosttype]\002."
		}
		"scan" {
			putserv "NOTICE $nickname :Performing clonescan for $channel... for big channels this could take several minutes..."
		set botlist "[list Q S wowbot snailbot catbot fishbot]"
			array set clones {}
			set total [llength [chanlist $channel]]
			set count 0
			#set id 0
			foreach x [chanlist $channel] {
				if {[string equal -nocase $x $botnick] || [lsearch -exact "[string tolower $botlist]" "[string tolower $x]"] != -1} { continue }
				set xh [string tolower [lindex [split [getchanhost $x $channel] @] 1]]
				#incr id
				#putlog "CLONESCAN: Scanning user #$id of $total: $x ($xh) on $channel"
				if {![info exists clones($xh)]} {
					set clones($xh) "$x"
				} else {
					set clones($xh) "$clones($xh) $x"
				}
			}
			foreach {h n} [array get clones] {
				set n [lsort -unique "[string tolower $n]"]
				if {[llength $n] > 1} {
					incr count [set z [expr {[llength $n] - 1}]]
									if {[string equal -nocase "-list" "[lindex [split $text] 1]"]} {
										putserv "NOTICE $nickname :(${z}) clone(s) from (${h}) on ${channel}: [join $n ", "]"
									}
				}
			}
			array unset clones
			set bots [list]
			foreach bot $botlist {
				if {$bot == ""} { continue }
				if {[onchan $bot $channel]} {
					lappend bots "$bot"
				}
			}
			set final [expr {$total - 1 - [llength $bots] - $count}]
			putserv "NOTICE $nickname :$channel - Total: $total - Clones detected: $count - [expr {[llength $bots]+1}] bot(s) removed from list: [join "$botnick $bots" ", "] - Final usercount: $final."
		}
		"default" {
			putserv "NOTICE $nickname :Syntax: ${lastbind}$command on|off|set|scan|status."
		}
	}
}
service::register clonescan service::cmd_clonescan

# welcome
proc service::cmd_welcome {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_welcome]
	set notice [channel get $channel service_welcome_notice]
	if {[set skin [channel get $channel service_welcome_skin]] == ""} {
		channel set $channel service_welcome_skin "[set skin $service::welcomeskin]"
	}
	switch -exact -- [set cmd [lindex [split $text] 0]] {
		"on" {
			if {$status} {
				putserv "NOTICE $nickname :$channel welcome is already enabled."
			} else {
				channel set $channel +service_welcome
				putserv "NOTICE $nickname :$channel welcome is now enabled."
			}
		}
		"off" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel welcome is already disabled."
			} else {
				channel set $channel -service_welcome
				putserv "NOTICE $nickname :$channel welcome is now disabled."
			}
		}
		"notice" {
			switch -exact -- [lindex [split $text] 1] {
				"on" {
					if {$notice} {
						putserv "NOTICE $nickname :$channel welcome notice is already enabled."
					} else {
						channel set $channel +service_welcome_notice
						putserv "NOTICE $nickname :$channel welcome notice is now enabled."
					}
				}
				"off" {
					if {!$notice} {
						putserv "NOTICE $nickname :$channel welcome notice is already disabled."
					} else {
						channel set $channel -service_welcome_notice
						putserv "NOTICE $nickname :$channel welcome notice is now disabled."
					}
				}
				"status" {
					putserv "NOTICE $nickname :$channel welcome notice is: \002[expr {$notice ? "enabled" : "disabled"}]\002."
				}
				"default" {
					putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd on|off|status."
				}
			}
		}
		"set" {
			set newskin [join [lrange [split $text] 1 end]]
			if {$newskin == ""} {
				putserv "NOTICE $nickname :Current: $skin."
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd ?skin?."
			} elseif {[string length $newskin] < 10} {
				putserv "NOTICE $nickname :Welcome skin must be more than 10 letters."
			} elseif {[string length $newskin] > 250} {
				putserv "NOTICE $nickname :Welcome skin must be less than 250 letters."
			} elseif {[string equal -nocase $skin $newskin]} {
				putserv "NOTICE $nickname :The new welcome skin is the same as the current one."
			} else {
				channel set $channel service_welcome_skin "$newskin"
				putserv "NOTICE $nickname :Done. Welcome Skin set to: $newskin."
			}
		}
		"status" {
			putserv "NOTICE $nickname :$channel welcome is: \002[expr {$status ? "enabled" : "disabled"}]. $channel welcome notice is: \002[expr {$notice ? "enabled" : "disabled"}]."
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|notice|set|status ?on/off/skin?."
		}
	}
}
service::register welcome service::cmd_welcome

# badword
proc service::cmd_badword {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_badword]
	set words [channel get $channel service_badwords]
	set time [channel get $channel service_badword_bantime]
	if {$time == ""} {
		channel set $channel service_badword_bantime "[set time 1]"
	}
	switch -exact -- [set cmd [lindex [split $text] 0]] {
		"on" {
			if {$status} {
				putserv "NOTICE $nickname :$channel badwords is already enabled."
			} else {
				channel set $channel +service_badword
				putserv "NOTICE $nickname :$channel badwords is now enabled."
			}
		}
		"off" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel badwords is already disabled."
			} else {
				channel set $channel -service_badword
				putserv "NOTICE $nickname :$channel badwords is now disabled."
			}
		}
		"add" {
			set badword [join [lrange [split $text] 1 end]]
			if {$badword == ""} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd ?badword?."
			} elseif {[llength [split $badword]] > 1} {
				putserv "NOTICE $nickname :A badword may only consist of one word."
			} elseif {[regexp -nocase {\*} $badword]} {
				putserv "NOTICE $nickname :A badword is not to incldue '\*'."
			} elseif {[lsearch -exact [string tolower $words] [string tolower $badword]] != -1} {
				putserv "NOTICE $nickname :Badword '$badword' is already added to my badwords list."
			} else {
				channel set $channel service_badwords "[string tolower $words] [string tolower $badword]"
				putserv "NOTICE $nickname :Badword '$badword' added to my badwords list."
			}
		}
		"del" {
			set badword [join [lrange [split $text] 1 end]]
			if {$badword == ""} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd ?badword?."
			} elseif {[llength [split $badword]] > 1} {
				putserv "NOTICE $nickname :A badword may only consist of one word."
			} elseif {[regexp -nocase {\*} $badword]} {
				putserv "NOTICE $nickname :A badword is not to incldue '\*'."
			} elseif {[set index [lsearch -exact [string tolower $words] [string tolower $badword]]] == -1} {
				putserv "NOTICE $nickname :Badword '$badword' is not added to my badwords list."
			} else {
				channel set $channel service_badwords "[lreplace $words $index $index]"
				putserv "NOTICE $nickname :Badword '$badword' removed from my badwords list."
			}
		}
		"list" {
			set list [list]
			putserv "NOTICE $nickname :$channel badwords list:"
			foreach badword $words {
				if {$badword == ""} { continue }
				lappend list $badword
				if {[llength $list] >= 20} {
					putserv "NOTICE $nickname :[join $list ", "]"
					set list [list]
				}
			}
			if {[llength $list] > 0} {
				putserv "NOTICE $nickname :[join $list ", "]."
			}
			putserv "NOTICE $nickname :End of badwords list. (Total: [llength $words])"
		}
		"status" {
			putserv "NOTICE $nickname :$channel badwords is: \002[expr {$status ? "enabled" : "disabled"}]. $channel badwords-bantime is: \002$time minute(s)\002."
		}
		"bantime" {
			set bantime [lindex [split $text] 1]
			if {$bantime == ""} {
				putserv "NOTICE $nickname :Current: $time minute(s)."
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd ?integer?."
			} elseif {![string is integer $bantime]} {
				putserv "NOTICE $nickname :Bantime must consist of digits only."
			} elseif {$bantime < 1 || $bantime > 30} {
				putserv "NOTICE $nickname :Bantime must be between 1 and 30 minutes."
			} elseif {$bantime == $time} {
				putserv "NOTICE $nickname :The new bantime is the same as the current."
			} else {
				channel set $channel service_badword_bantime $bantime
				putserv "NOTICE $nickname :Bantime set to '$bantime' minute(s)."
			}
		}
		"check" {
			set badword [lindex [split $text] 1]
			if {[lsearch -exact [string tolower $words] [string tolower $badword]] != -1} {
				putserv "NOTICE $nickname :'$badword' is a badword."
			} else {
				putserv "NOTICE $nickname :'$badword' is not a badword."
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|add|del|list|check|bantime|status ?badword?."
		}
	}
}
service::register badword service::cmd_badword

# antiadvertise, advert, advertise
proc service::cmd_antiadvertise {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_antiadvertise]
	set time [channel get $channel service_antiadvertise_bantime]
	if {$time == ""} {
		channel set $channel service_antiadvertise_bantime "[set time 1]"
	}
	switch -exact -- [set cmd [lindex [split $text] 0]] {
		"on" {
			if {$status} {
				putserv "NOTICE $nickname :$channel anti-advertise is already enabled."
			} else {
				channel set $channel +service_antiadvertise
				putserv "NOTICE $nickname :$channel anti-advertise is now enabled."
			}
		}
		"off" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel anti-advertise is already disabled."
			} else {
				channel set $channel -service_antiadvertise
				putserv "NOTICE $nickname :$channel anti-advertise is now disabled."
			}
		}
		"status" {
			putserv "NOTICE $nickname :$channel anti-advertise is: \002[expr {$status ? "enabled" : "disabled"}]. $channel anti-advertise-bantime is: \002$time minute(s)\002."
		}
		"bantime" {
			set bantime [lindex [split $text] 1]
			if {$bantime == ""} {
				putserv "NOTICE $nickname :Current: $time minute(s)."
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $cmd ?integer?."
			} elseif {![string is integer $bantime]} {
				putserv "NOTICE $nickname :Bantime must consist of digits only."
			} elseif {$bantime < 1 || $bantime > 30} {
				putserv "NOTICE $nickname :Bantime must be between 1 and 30 minutes."
			} elseif {$bantime == $time} {
				putserv "NOTICE $nickname :The new bantime is the same as the current."
			} else {
				channel set $channel service_antiadvertise_bantime $bantime
				putserv "NOTICE $nickname :Bantime set to '$bantime' minute(s)."
			}
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|bantime|status ?arguements?."
		}
	}
}
service::register {antiadvertise advert advertise} service::cmd_antiadvertise

# bitchmode
proc service::cmd_bitchmode {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_bitchmode]
	switch -exact -- [set cmd [lindex [split $text] 0]] {
		"on" {
			if {$status} {
				putserv "NOTICE $nickname :$channel bitchmode is already enabled."
			} else {
				channel set $channel +service_bitchmode
				putserv "NOTICE $nickname :$channel bitchmode is now enabled."
			}
		}
		"off" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel bitchmode is already disabled."
			} else {
				channel set $channel -service_bitchmode
				putserv "NOTICE $nickname :$channel bitchmode is now disabled."
			}
		}
		"status" {
			putserv "NOTICE $nickname :$channel bitchmode is: \002[expr {$status ? "enabled" : "disabled"}]\002."
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status."
		}
	}
}
service::register bitchmode service::cmd_bitchmode

# status
proc service::cmd_status {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command"
	set prot "disabled"
	set hard "disabled"
	set spam "disabled"
	set flyby "disabled"
	set ao "disabled"
	set av "disabled"
	set al "disabled"
	set flood "disabled"
	set vip "disabled"
	set vips "disabled"
	set vipn "channel"
	set badchan "disabled"
	set authban "disabled"
	set welcome "disabled"
	set known "disabled"
	set bitchmode "disabled"
	set badword "disabled"
	set advert "disabled"
	if {[channel get $channel service_prot]} {
		set prot "enabled"
	}
	if {[channel get $channel service_prot_hard]} {
		set hard "enabled"
	}
	if {[channel get $channel service_spamscan]} {
		set spam "enabled"
	}
	if {[channel get $channel service_flyby]} {
		set flyby "enabled"
	}
	if {[channel get $channel service_ao]} {
		set ao "enabled"
	}
	if {[channel get $channel service_av]} {
		set av "enabled"
	}
	if {[channel get $channel service_autolimit]} {
		set al "enabled"
	}
	if {[channel get $channel service_flood]} {
		set flood "enabled"
	}
	if {[channel get $channel service_vip]} {
		set vip "enabled"
	}
	if {[channel get $channel service_vips]} {
		set vips "enabled"
	}
	if {[channel get $channel service_vipn]} {
		set vipn "notice"
	}
	if {[channel get $channel service_badchan]} {
		set badchan "enabled"
	}
	if {[channel get $channel service_authban]} {
		set authban "enabled"
	}
	if {[channel get $channel service_welcome]} {
		set welcome "enabled"
	}
	if {[channel get $channel service_known]} {
		set known "enabled"
	}
	if {[channel get $channel service_bitchmode]} {
		set bitchmode "enabled"
	}
	if {[channel get $channel service_badword]} {
		set badword "enabled"
	}
	if {[channel get $channel service_antiadvertise]} {
		set advert "enabled"
	}
	putserv "NOTICE $nickname :Service status for $channel: (Protection: \002$prot\002 (Hard protection: \002$hard\002)) - (Vip-scanner: \002$vip\002 (Vip-skin: \002$vips\002) (Vip message type: \002$vipn\002)) - (Badchan: \002$badchan\002) - (Authban: \002$authban\002) - (Badword: \002$badword\002) -"
	putserv "NOTICE $nickname : (Anti-Advertise: \002$advert\002) - (Welcome: \002$welcome\002) - (Known-only: \002$known\002) - (Spamscan: \002$spam\002) - (Anti-Flood: \002$flood\002) - (Flyby: \002$flyby\002) - (Auto-op: \002$ao\002) - (Auto-voice: \002$av\002) - (Auto-limit: \002$al\002) - (Bitchmode: \002$bitchmode\002)."
	set lock [channel get $channel service_lockdown]
	set enf [expr {[channel get $channel service_enforcemodes] ? [channel get $channel service_enforcedmodes] : "disabled"}]
	set qstate [expr {[info exists ::service::qauth_state] ? $::service::qauth_state : "n/a"}]
	set qbot [expr {[onchan Q $channel] ? "on channel" : "NOT on channel"}]
	putserv "NOTICE $nickname : (Takeover protection: \002[expr {[channel get $channel service_prot] ? "on" : "off"}]\002) - (Lockdown: \002[expr {$lock eq "" ? "off" : "+[lindex [split $lock] 0]"}]\002) - (Enforced modes: \002$enf\002) - (Peak: \002[expr {[channel get $channel service_peak] ? [channel get $channel service_peak_count] : "off"}]\002) - (Q: \002$qbot\002, bot auth: \002$qstate\002) - (Bot: \002[expr {[botisop $channel] ? "opped" : "NOT opped"}]\002)."
}
service::register status service::cmd_status

# chanflags
proc service::cmd_chanflags {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set flags [lindex [split $text] 0]
	array set current { {+} {} {-} {} }
	foreach {x y} [array get service::chanflags] {
		if {$x == "" || $y == ""} { continue }
		if {[channel get $channel [lindex [split $service::chanflags($x)] 0]]} {
			lappend current(+) $x
		} else {
			lappend current(-) $x
		}
	}
	if {$flags == ""} {
		putserv "NOTICE $nickname :Current: [join "+ [lsort -unique [join $current(+)]] - [lsort -unique [join $current(-)]]" ""]."
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command +-flags. Available flags: [join [lsort -unique [array names service::chanflags]] ""]."
	} else {
		if {[string index $flags 0] != "+" && [string index $flags 0] != "-"} {
			set flags "+$flags"
		}
		set unknown [list]
		foreach flag [split $flags ""] {
			if {$flag == "" || $flag == "+" || $flag == "-"} { continue }
			if {![info exists service::chanflags($flag)]} {
				lappend unknown $flag
			}
		}
		if {[llength $unknown] > 0} {
			putserv "NOTICE $nickname :Invalid or disallowed flag(s) '[join $unknown ", "]' specified."
		} else {
			array set done { {+} {} {-} {} }
			set lastmode ""
			foreach flag [split $flags ""] {
				if {$flag == "+" || $flag == "-"} {
					set lastmode "$flag"
					continue
				}
				if {$lastmode == "+" && ![channel get $channel [lindex [split $service::chanflags($flag)] 0]]} {
					lappend done(+) $flag
					channel set $channel +[lindex [split $service::chanflags($flag)] 0]
				} elseif {$lastmode == "-" && [channel get $channel [lindex [split $service::chanflags($flag)] 0]]} {
					lappend done(-) $flag
					channel set $channel -[lindex [split $service::chanflags($flag)] 0]
				}
			}
			array set after { {+} {} {-} {} }
			foreach {x y} [array get service::chanflags] {
				if {$x == "" || $y == ""} { continue }
				if {[channel get $channel [lindex [split $service::chanflags($x)] 0]]} {
					lappend after(+) $x
				} else {
					lappend after(-) $x
				}
			}
			putserv "NOTICE $nickname :Done. Before: [join "+ [lsort -unique $current(+)] - [lsort -unique $current(-)]" ""] - After: [join "+ [lsort -unique "$after(+) $done(+)"] - [lsort -unique "$after(-) $done(-)"]" ""] - Changes: [join "+ [lsort -unique $done(+)] - [lsort -unique $done(-)]" ""]."
		}
	}
}
service::register chanflags service::cmd_chanflags

# automsg
proc service::cmd_automsg {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set status [channel get $channel service_automsg]
	set int [channel get $channel service_automsg_int]
	set mode [channel get $channel service_automsg_modes]
	set line1 [channel get $channel service_automsg_line1]
	set line2 [channel get $channel service_automsg_line2]
	set line3 [channel get $channel service_automsg_line3]
	switch -exact -- [set option [lindex [split $text] 0]] {
		"on" - "enable" {
			if {$status} {
				putserv "NOTICE $nickname :$channel automsg is already enabled."
			} else {
				channel set $channel +service_automsg
				channel set $channel service_automsg_lastmsg "[unixtime]"
				putserv "NOTICE $nickname :$channel automsg is now enabled."
			}
		}
		"off" - "disable" {
			if {!$status} {
				putserv "NOTICE $nickname :$channel automsg is already disabled."
			} else {
				channel set $channel -service_automsg
				putserv "NOTICE $nickname :$channel automsg is now disabled."
			}
		}
		"list" {
			putserv "NOTICE $nickname :$channel automsg list:"
			putserv "NOTICE $nickname :LINE1: [expr {$line1 == "" ? "Empty." : "$line1"}]"
			putserv "NOTICE $nickname :LINE2: [expr {$line2 == "" ? "Empty." : "$line2"}]"
			putserv "NOTICE $nickname :LINE3: [expr {$line3 == "" ? "Empty." : "$line3"}]"
			putserv "NOTICE $nickname :End of $channel automsg list."
		}
		"set" {
			set line [lindex [split $text] 1]
			if {![regexp -nocase -- {^#(1|2|3)$} $line]} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option <#digit> ?text?. (Where digit must be a integer between 1 and 3)"
			} else {
				switch -exact -- [string trimleft $line #] {
					{1} {set current "$line1"}
					{2} {set current "$line2"}
					{3} {set current "$line3"}
					{default} {set current ""}
				}
				if {[set info [join [lrange [split $text] 2 end]]] == ""} {
					putserv "NOTICE $nickname :LINE[string trimleft $line #] is currently set as: $current"
				} elseif {[string equal -nocase $info $current]} {
					putserv "NOTICE $nickname :ERROR: The new line matches the current line."
				} else {
					channel set $channel service_automsg_line[string trimleft $line #] "$info"
					putserv "NOTICE $nickname :Done. LINE[string trimleft $line #] is now set as: $info"
				}
			}
		}
		"interval" {
			set interval [lindex [split $text] 1]
			if {![regexp -nocase -- {^#[\d]{1,}$} $interval] || [string trimleft $interval #] < 10} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option <#digit>. (Where digit must be a number higher than 10)"
			} elseif {$interval == $int} {
				putserv "NOTICE $nickname :ERROR: Interval is already set as $int."
			} else {
				channel set $channel service_automsg_int "[string trimleft $interval #]"
				putserv "NOTICE $nickname :Done. Interval set to: $interval."
			}
		}
		"modes" {
			set modes [lindex [split $text] 1]
			if {![regexp -nocase -- {\+[a-z]|\-[a-z]} $modes]} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option <+-modes>."
			} elseif {$modes == $mode} {
				putserv "NOTICE $nickname :ERROR: The new modes match the current modes."
			} else {
				channel set $channel service_automsg_modes "$modes"
				putserv "NOTICE $nickname :Done. Modes set to: $modes."
			}
		}
		"status" {
			putserv "NOTICE $nickname :$channel automsg is: \002[expr {$status ? "enabled" : "disabled"}]\002. Interval is set to: \002$int\002. Modes are set as: \002$mode\002."
		}
		"default" {
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|set|list|interval|modes ?arguements?."
		}
	}
}
service::register automsg service::cmd_automsg

# vip
proc service::cmd_vip {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	switch -exact -- [set option [lindex [split $text] 0]] {
		"add" {
			set chan [lindex [split $text] 1]
			set status [lindex [split $text] 2]
			if {$chan == ""} {
				putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option #channel @/+."
			} else {
				if {[string index $chan 0] != "#"} {
					set chan "#$chan"
				}
				if {$status == ""} {
					set status "@"
				}
				if {![regexp {^\@|\+$} $status]} {
					putserv "NOTICE $nickname :Vip status must be one of '@ +'. (@ means ops only | + means both ops and voice)"
					return
				}
				set vlist [string tolower [channel get $channel service_vipc]]
				set index "-1"
				foreach x $vlist {
					if {$x == ""} { continue }
					if {[string equal -nocase $chan [string range $x 1 end]]} {
						set index [lsearch -exact $vlist $x]; break
					}
				}
				if {$index == -1} {
					lappend vlist ${status}${chan}
					channel set $channel service_vipc $vlist
					putserv "NOTICE $nickname :Vip channel '$chan' has been added with status '$status' successfully."
				} else {
					set vstatus [string index [lindex [split $vlist] $index] 0]
					if {$vstatus == $status} {
						putserv "NOTICE $nickname :Vip channel '$chan' is already added as status '$status'."
					} else {
						set vlist [lreplace $vlist $index $index ${status}${chan}]
						channel set $channel service_vipc $vlist
						putserv "NOTICE $nickname :Vip channel '$chan' was already added as status '$vstatus' but has now been modifed to '$status'."
					}
				}
			}
		}
		"del" {
			set chan [lindex [split $text] 1]
			if {$chan == ""} {
				putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option #channel."
			} else {
				if {[string index $chan 0] != "#"} {
					set chan "#$chan"
				}
				set vlist [string tolower [channel get $channel service_vipc]]
				set index "-1"
				foreach x $vlist {
					if {$x == ""} { continue }
					if {[string equal -nocase $chan [string range $x 1 end]]} {
						set index [lsearch -exact $vlist $x]; break
					}
				}
				if {$index == "-1"} {
					putserv "NOTICE $nickname :Vip channel '$chan' does not exist."
				} else {
					set vlist [lreplace $vlist $index $index]
					channel set $channel service_vipc $vlist
					putserv "NOTICE $nickname :Vip channel '$chan' was removed successfully."
				}
			}
		}
		"list" {
			set status [lindex [split $text] 1]
			if {$status == ""} {
				set total 0
				set op 0
				set voice 0
				set list [list]
				foreach vchan [channel get $channel service_vipc] {
					if {$vchan == ""} { continue }
					incr total
					if {[string range $vchan 0 0] == "@"} {
						incr op
					} else {
						incr voice
					}
					lappend list "$vchan"
					if {[llength $list] == "20"} {
						putserv "NOTICE $nickname :[join $list ", "]"
						set list [list]
					}
				}
				if {[llength $list] > 0} {
					putserv "NOTICE $nickname :[join $list ", "]."
				}
				putserv "NOTICE $nickname :End of vip list. (Total: $total - @: $op - +: $voice)"
			} elseif {![regexp {\@|\+} $status]} {
				putserv "NOTICE $nickname :Invalid status '$status'. Status must be one of '@ +'."
			} else {
				set total 0
				set i 0
				set list [list]
				foreach vchan [channel get $channel service_vipc] {
					if {$vchan == ""} { continue }
					if {[string equal -nocase $status [string range $vchan 0 0]]} {
						lappend list "$vchan"
						incr i
					}
					if {[llength $list] == "20"} {
						putserv "NOTICE $nickname :[join $list ", "]"
						set list [list]
					}
				}
				if {[llength $list] > 0} {
					putserv "NOTICE $nickname :[join $list ", "]."
				}
				putserv "NOTICE $nickname :End of vip list. (${i}/$total @)"
			}
		}
		"skin" {
			if {[channel get $channel service_vipskin] == ""} {
				channel set $channel service_vipskin "$service::vipskin"
			}
			set skin [join [lrange [split $text] 1 end]]
			if {$skin == ""} {
				putserv "NOTICE $nickname :$channel vip-skin: [join [channel get $channel service_vipskin]] - Keyword(s) available: :nickname: :hostname: :channel: :vipchannel: :status: :id:."
			} else {
				if {[string length $skin] < "2"} {
					putserv "NOTICE $nickname :The minimum vip-skin length allowed is 2."
				} elseif {[string length $skin] > "300"} {
					putserv "NOTICE $nickname :The maxium vip-skin length allowed is 300. The current skin length is [string length $skin]."
				} else {
					channel set $channel service_vipskin "$skin"
					putserv "NOTICE $nickname :$channel vip-skin set to: [join [channel get $channel service_vipskin]]."
				}
			}
		}
		"set" {
			switch -exact -- [set opt [lindex [split $text] 1]] {
				"skin" {
					switch -exact -- [set cmd [lindex [split $text] 2]] {
						"on" {
							if {[channel get $channel service_vips]} {
								putserv "NOTICE $nickname :$channel vip-skin is already enabled."
							} else {
								channel set $channel +service_vips
								putserv "NOTICE $nickname :$channel vip-skin is now enabled."
							}
						}
						"off" {
							if {![channel get $channel service_vips]} {
								putserv "NOTICE $nickname :$channel vip-skin is already disabled."
							} else {
								channel set $channel -service_vips
								putserv "NOTICE $nickname :$channel vip-skin is now disabled."
							}
						}
						"status" {
							putserv "NOTICE $nickname :$channel vip-skin is [expr {[channel get $channel service_vips] ? "enabled" : "disabled"}]."
						}
						"default" {
							putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option $opt on|off|status."
						}
					}
				}
				"notice" {
					switch -exact -- [set cmd [lindex [split $text] 2]] {
						"on" {
							if {[channel get $channel service_vipn]} {
								putserv "NOTICE $nickname :$channel vip-notice is already enabled."
							} else {
								channel set $channel +service_vipn
								putserv "NOTICE $nickname :$channel vip-notice is now enabled."
							}
						}
						"off" {
							if {![channel get $channel service_vipn]} {
								putserv "NOTICE $nickname :$channel vip-notice is already disabled."
							} else {
								channel set $channel -service_vipn
								putserv "NOTICE $nickname :$channel vip-notice is now disabled."
							}
						}
						"status" {
							putserv "NOTICE $nickname :$channel vip-notice is [expr {[channel get $channel service_vipn] ? "enabled" : "disabled"}]."
						}
						"default" {
							putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option $opt on|off|status."
						}
					}
				}
				"authed" {
					switch -exact -- [set cmd [lindex [split $text] 2]] {
						"on" {
							if {[channel get $channel service_vip_authed]} {
								putserv "NOTICE $nickname :$channel vip-authed is already enabled."
							} else {
								channel set $channel +service_vip_authed
								putserv "NOTICE $nickname :$channel vip-authed is now enabled."
							}
						}
						"off" {
							if {![channel get $channel service_vip_authed]} {
								putserv "NOTICE $nickname :$channel vip-authed is already disabled."
							} else {
								channel set $channel -service_vip_authed
								putserv "NOTICE $nickname :$channel vip-authed is now disabled."
							}
						}
						"status" {
							putserv "NOTICE $nickname :$channel vip-authed is [expr {[channel get $channel service_vip_authed] ? "enabled" : "disabled"}]."
						}
						"default" {
							putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option $opt on|off|status."
						}
					}
				}
				"default" {
					putserv "NOTICE $nickname :Vip-skin is: \002[expr {[channel get $channel service_vips] ? "enabled" : "disabled"}]\002. Vip-notice is: \002[expr {[channel get $channel service_vipn] ? "enabled" : "disabled"}]\002. Vip-authed is: \002[expr {[channel get $channel service_vip_authed] ? "enabled" : "disabled"}]\002."
					putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option skin|notice|authed ?on|off|status?."
				}
			}
		}
		"authbl" {
			switch -exact -- [set cmd [lindex [split $text] 1]] {
				"add" {
					set authname [string tolower [lindex [split $text] 2]]
					if {$authname == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option authname."
						return
					}
					set blist [string tolower [channel get $channel service_vip_authblist]]
					set index "-1"
					foreach x $blist {
						if {$x == ""} { continue }
						if {[string equal -nocase $authname $x]} {
							set index [lsearch -exact $blist $x]; break
						}
					}
					if {$index == "-1"} {
						lappend blist $authname
						channel set $channel service_vip_authblist $blist
						putserv "NOTICE $nickname :Vip authname '$authname' was successfully blacklisted."
					} else {
						putserv "NOTICE $nickname :Vip authname '$authname' is already blacklisted."
					}
				}
				"del" {
					set authname [string tolower [lindex [split $text] 2]]
					if {$authname == ""} {
						putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option authname."
						return
					}
					set blist [string tolower [channel get $channel service_vip_authblist]]
					set index "-1"
					foreach x $blist {
						if {$x == ""} { continue }
						if {[string equal -nocase $authname $x]} {
							set index [lsearch -exact $blist $x]; break
						}
					}
					if {$index == "-1"} {
						putserv "NOTICE $nickname :Vip authname '$authname' is not blacklisted."
					} else {
						set blist [lreplace $blist $index $index]
						channel set $channel service_vip_authblist $blist
						putserv "NOTICE $nickname :Vip authname '$authname' was successfully removed from my blacklist."
					}
				}
				"list" {
					set total 0
					set list [list]
					foreach auth [channel get $channel service_vip_authblist] {
						if {$auth == ""} { continue }
						incr total
						lappend list "$auth"
						if {[llength $list] == "20"} {
							putserv "NOTICE $nickname :[join $list ", "]"
							set list [list]
						}
					}
					if {[llength $list] > 0} {
						putserv "NOTICE $nickname :[join $list ", "]."
					}
					putserv "NOTICE $nickname :End of vip blacklist. (Total: $total)"
				}
				"on" {
					if {[channel get $channel service_vip_authbl]} {
						putserv "NOTICE $nickname :$channel vip-authbl is already enabled."
					} else {
						channel set $channel +service_vip_authbl
						putserv "NOTICE $nickname :$channel vip-authbl is now enabled."
					}
				}
				"off" {
					if {![channel get $channel service_vip_authbl]} {
						putserv "NOTICE $nickname :$channel vip-authbl is already disabled."
					} else {
						channel set $channel -service_vip_authbl
						putserv "NOTICE $nickname :$channel vip-authbl is now disabled."
					}
				}
				"status" {
					putserv "NOTICE $nickname :$channel vip-authbl is [expr {[channel get $channel service_vip_authbl] ? "enabled" : "disabled"}]. ([llength [channel get $channel service_vip_authblist]] auth(s) blacklisted)"
				}
				"default" {
					putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option add|del|list|on|off|status."
				}
			}
		}
		"mode" {
			if {[channel get $channel service_vipm] == ""} {
				channel set $channel service_vipm "$service::vipmode"
			}
			set status "[lindex [split $text] 1]"
			if {$status == ""} {
				putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option @/+."
			} elseif {![regexp {\@|\+} $status]} {
				putserv "NOTICE $nickname :Vip-mode must be one of '@ +'."
			} elseif {$status == [channel get $channel service_vipm]} {
				putserv "NOTICE $nickname :Vip-mode is already set to '$status'."
			} else {
				channel set $channel service_vipm "$status"
				putserv "NOTICE $nickname :Vip-mode is now set to '$status'."
			}
		}
		"on" {
			if {[channel get $channel service_vip]} {
				putserv "NOTICE $nickname :Vip is already \002enabled\002."
			} else {
				channel set $channel +service_vip
				putserv "NOTICE $nickname :Vip is now \002enabled\002."
			}
		}
		"off" {
			if {![channel get $channel service_vip]} {
				putserv "NOTICE $nickname :Vip is already \002disabled\002."
			} else {
				channel set $channel -service_vip
				putserv "NOTICE $nickname :Vip is now \002disabled\002."
			}
		}
		"default" {
			set vip [expr {[channel get $channel service_vip] ? "enabled" : "disabled"}]
			set vips [expr {[channel get $channel service_vips] ? "enabled" : "disabled"}]
			set vipn [expr {[channel get $channel service_vipn] ? "enabled" : "disabled"}]
			set vipa [expr {[channel get $channel service_vip_authed] ? "enabled" : "disabled"}]
			set vipab [expr {[channel get $channel service_vip_authbl] ? "enabled" : "disabled"}]
			if {[set vipm [channel get $channel service_vipm]] == ""} {
				channel set $channel service_vipm "[set vipm $service::vipmode]"
			}
			if {[set vipid [channel get $channel service_vipid]] == ""} {
				channel set $channel service_vipid "[set vipid 0]"
			}
			putserv "NOTICE $nickname :Vip is: \002$vip\002 - Vip-skin is: \002$vips\002 - Vip-notice is: \002$vipn\002 - Vip-mode is: \002$vipm\002 - Vip-id is: \002#$vipid\002 - Vip-channel(s): \002[llength [channel get $channel service_vipc]]\002."
			putserv "NOTICE $nickname :Vip-authed is: \002$vipa\002 - Vip-authblacklist is: \002$vipab\002 - \002[llength [channel get $channel service_vip_authblist]] blacklisted auth(s)\002."
			putserv "NOTICE $nickname :Syntax: ${lastbind}$command on|off|add|del|set|list|authbl|mode ?arguments?."
		}
	}
}
service::register vip service::cmd_vip

# badchan
proc service::cmd_badchan {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	switch -exact -- [set option [lindex [split $text] 0]] {
		"add" {
			set chan [lindex [split $text] 1]
			if {$chan == ""} {
				putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option #channel."
			} else {
				if {[string index $chan 0] != "#"} {
					set chan "#$chan"
				}
				if {[string equal -nocase $chan $channel]} {
					putserv "NOTICE $nickname :Error: You can't bad channel your own channel!"
					return
				}
				if {[string equal -nocase $service::homechan $chan] || [string equal -nocase $service::adminchan $chan] || [string equal -nocase $service::helpchan $chan]} {
					putserv "NOTICE $nickname :Error: Can't add '$chan' to my bad channel list. (Protected channel)"
					return
				}
				set found 0
				set list [list]
				foreach bchan [channel get $channel service_badchans] {
					if {$bchan == ""} { continue }
					if {[string equal -nocase $chan $bchan]} {
						putserv "NOTICE $nickname :Bad Channel '$chan' is already added."
						set found 1
					} else {
						lappend list "$bchan"
					}
				}
				if {!$found} {
					channel set $channel service_badchans "[channel get $channel service_badchans] $chan"
					putserv "NOTICE $nickname :Bad Channel '$chan' added successfully."
				}
			}
		}
		"del" {
			set chan [lindex [split $text] 1]
			if {$chan == ""} {
				putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option del #channel."
			} else {
				if {[string index $chan 0] != "#"} {
					set chan "#$chan"
				}
				set found 0
				set list [list]
				foreach bchan [channel get $channel service_badchans] {
					if {$bchan == ""} { continue }
					if {[string equal -nocase $chan $bchan]} {
						set found 1
					} else {
						lappend list "$bchan"
					}
				}
				if {$found} {
					channel set $channel service_badchans "[join $list " "]"
					putserv "NOTICE $nickname :Removed bad channel '$chan' successfully."
				} else {
					putserv "NOTICE $nickname :Bad Channel '$chan' is not added."
				}
			}
		}
		"list" {
			set total 0
			set list [list]
			foreach bchan [channel get $channel service_badchans] {
				if {$bchan == ""} { continue }
				incr total
				lappend list "$bchan"
				if {[llength $list] == "20"} {
					putserv "NOTICE $nickname :[join $list ", "]"
					set list [list]
				}
			}
			if {[llength $list] > 0} {
				putserv "NOTICE $nickname :[join $list ", "]."
				set list [list]
			}
			putserv "NOTICE $nickname :End of bad channels list. (Total: $total)"
		}
		"on" {
			if {[channel get $channel service_badchan]} {
				putserv "NOTICE $nickname :Bad Channel is already \002enabled\002."
			} else {
				channel set $channel +service_badchan
				putserv "NOTICE $nickname :Bad Channel is now \002enabled\002."
			}
		}
		"off" {
			if {![channel get $channel service_badchan]} {
				putserv "NOTICE $nickname :Bad Channel is already \002disabled\002."
			} else {
				channel set $channel -service_badchan
				putserv "NOTICE $nickname :Bad Channel is now \002disabled\002."
			}
		}
		"default" {
			set status [expr {[channel get $channel service_badchan] ? "enabled" : "disabled"}]
			set badchans [llength [channel get $channel service_badchans]]
			if {[set id [channel get $channel service_bid]] == ""} {
				channel set $channel service_bid "[set id 0]"
			}
			putserv "NOTICE $nickname :Bad Channel is: \002$status\002 - Bad Channel(s): \002$badchans\002 - Bad Channel ID: \002#$id\002."
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|add|del|list ?arguments?."
		}
	}
}
service::register badchan service::cmd_badchan

# authban
proc service::cmd_authban {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	switch -exact -- [set option [lindex [split $text] 0]] {
		"add" {
			set auth [lindex [split $text] 1]
			if {$auth == ""} {
				putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option authname."
			} elseif {[regexp -- {(.+)!(.+)@(.+)} $auth]} {
				putserv "NOTICE $nickname :Error: Your input matches a hostmask layout, if you want to ban a hostmask please use the BAN command."
			} else {
				if {[string match -nocase *users.quakenet.org $hostname] && [string equal -nocase $auth [lindex [split [lindex [split $hostname @] 1] .] 0]]} {
					putserv "NOTICE $nickname :Error: You can't ban your own authname!"
					return
				}
				if {[matchattr [finduser *!*@$auth.users.quakenet.org] nmobSBF]} {
					putserv "NOTICE $nickname :Error: You can't ban this authname - Protected authname."
					return
				}
				set found 0
				set list [list]
				foreach bauth [channel get $channel service_authbans] {
					if {$bauth == ""} { continue }
					if {[string equal -nocase $auth $bauth]} {
						putserv "NOTICE $nickname :Authname '$auth' is already added."
						set found 1
					} else {
						lappend list "$bauth"
					}
				}
				if {!$found} {
					channel set $channel service_authbans "[channel get $channel service_authbans] $auth"
					putserv "NOTICE $nickname :Authname '$auth' added successfully."
				}
			}
		}
		"del" {
			set auth [lindex [split $text] 1]
			if {$auth == ""} {
				putserv "NOTICE $nickname :Syntax: ${lastbind}$command $option del authname."
			} elseif {[regexp -- {(.+)!(.+)@(.+)} $auth]} {
				putserv "NOTICE $nickname :Error: Your input matches a hostmask layout, if you want to unban a hostmask please use the UNBAN command."
			} else {
				set found 0
				set list [list]
				foreach bauth [channel get $channel service_authbans] {
					if {$bauth == ""} { continue }
					if {[string equal -nocase $auth $bauth]} {
						set found 1
					} else {
						lappend list "$bauth"
					}
				}
				if {$found} {
					channel set $channel service_authbans "[join $list " "]"
					putserv "NOTICE $nickname :Removed authname '$auth' successfully."
				} else {
					putserv "NOTICE $nickname :Authname '$auth' is not added."
				}
			}
		}
		"list" {
			set total 0
			set list [list]
			foreach bauth [channel get $channel service_authbans] {
				if {$bauth == ""} { continue }
				incr total
				lappend list "$bauth"
				if {[llength $list] == "20"} {
					putserv "NOTICE $nickname :[join $list ", "]"
					set list [list]
				}
			}
			if {[llength $list] > 0} {
				putserv "NOTICE $nickname :[join $list ", "]."
				set list [list]
			}
			putserv "NOTICE $nickname :End of authbans list. (Total: $total)"
		}
		"on" {
			if {[channel get $channel service_authban]} {
				putserv "NOTICE $nickname :Authbans is already \002enabled\002."
			} else {
				channel set $channel +service_authban
				putserv "NOTICE $nickname :Authbans is now \002enabled\002."
			}
		}
		"off" {
			if {![channel get $channel service_authban]} {
				putserv "NOTICE $nickname :Authbans is already \002disabled\002."
			} else {
				channel set $channel -service_authban
				putserv "NOTICE $nickname :Authbans is now \002disabled\002."
			}
		}
		"default" {
			set status [expr {[channel get $channel service_authban] ? "enabled" : "disabled"}]
			set authbans [llength [channel get $channel service_authbans]]
			if {[set id [channel get $channel service_aid]] == ""} {
				channel set $channel service_aid "[set id 0]"
			}
			putserv "NOTICE $nickname :Authbans is: \002$status\002 - Authname(s): \002$authbans\002 - Authbans ID: \002#$id\002."
			putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|add|del|list ?arguments?."
		}
	}
}
service::register authban service::cmd_authban

# autolimit
proc service::cmd_autolimit {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set limit [lindex [split $text] 0]
	if {$limit == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status|#limit."
	} else {
		set status [channel get $channel service_autolimit]
		switch -exact -- $limit {
			"on" {
				if {$status} {
					putserv "NOTICE $nickname :$channel autolimit is already enabled."
				} else {
					channel set $channel +service_autolimit
					channel set $channel service_limit "10"
					set curr [llength [chanlist $channel]]
					set newlimit [expr {$curr + 10}]
					pushmode $channel +l $newlimit
					putserv "NOTICE $nickname :Done."
				}
			}
			"off" {
				if {!$status} {
					putserv "NOTICE $nickname :$channel autolimit is already disabled."
				} else {
					channel set $channel -service_autolimit
					channel set $channel service_limit ""
					putserv "NOTICE $nickname :Done."
				}
			}
			"status" {
				if {$status} {
					putserv "NOTICE $nickname :$channel autolimit is enabled."
					putserv "NOTICE $nickname :Current setting: #[channel get $channel service_limit]."
				} else {
					putserv "NOTICE $nickname :$channel autolimit is disabled."
				}
			}
			"default" {
				if {[string index $limit 0] == "#"} {
					set limit [string trimleft $limit #]
					if {$limit < 3} {
						putserv "NOTICE $nickname :The limit must be 3 or higher."
					} elseif {[channel get $channel service_limit] == $limit} {
						putserv "NOTICE $nickname :The new limit must be different from the current limit."
					} else {
						channel set $channel service_limit "$limit"
						if {[string match *l* [getchanmode $channel]]} {
							if {[string match *k* [getchanmode $channel]]} {
								set curr [lindex [split [getchanmode $channel]] 2]
							} else {
								set curr [lindex [split [getchanmode $channel]] 1]
							}
							set newlimit [expr {[llength [chanlist $channel]] + $limit}]
							if {$newlimit != "$curr"} {
								pushmode $channel +l $newlimit
							}
						} else {
							pushmode $channel +l [expr {[llength [chanlist $channel]] + $limit}]
						}
						putserv "NOTICE $nickname :New limit successfully set to: #$limit."
					}
				} else {
					putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command on|off|status|#limit."
				}
			}
		}
	}
}
service::register autolimit service::cmd_autolimit

# topic
proc service::cmd_topic {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set filename [file join [pwd] service topic ${channel}.topc]
	if {![file isdir [file join [pwd] service topic]]} {
		file mkdir [file join [pwd] service topic]
	}
	if {![file exists $filename]} {
		set file [open $filename w]
		close $file
	}
	switch -exact -- [set option [lindex [split $text] 0]] {
		"create" {
			set topic [join [lrange [split $text] 1 end]]
			set current [channel get $channel service_topicskin]
			if {$topic == ""} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option ?topicskin?. All words enclosed in :'s will be detected as keywords (Example: :news: :bnc: (no spaces allowed))."
			} elseif {[string equal $topic $current]} {
				putserv "NOTICE $nickname :Error creating topic... It apears to be the same as the current."
			} else {
				set keywords [list]
				set c 0
				set cc 0
				foreach word [split $topic " "] {
					if {$word == ""} { continue }
					if {[regexp {:(\w+):} $word -> word]} {
						incr c 1
						if {![service::validtopickey $channel $word]} {
							lappend keywords "[string tolower $word]"
							incr cc 1
						}
					}
				}
				if {[set curr [channel get $channel service_topic_keywords]] == "" && $c != "0"} {
					set list [list]
					foreach keyword $keywords {
						lappend list "\{$keyword \}"
					}
					if {[llength $list] > 0} {
						channel set $channel service_topic_keywords "[join $list " "]"
					}
				} else {
					array set temp {}
					foreach entry $curr {
						set temp([string tolower [lindex [split $entry] 0]]) "[lrange $entry 1 end]"
					}
					set list [list]
					foreach keyword $keywords {
						if {![info exists temp([string tolower $keyword])]} {
							lappend list "\{$keyword \}"
						} else {
							lappend list "\{$keyword $temp([string tolower $keyword])\}"
						}
					}
					if {[llength $list] > 0} {
						channel set $channel service_topic_keywords "[join $list " "]"
					}
				}
				channel set $channel service_topicskin "$topic"
				channel set $channel service_topicskin_old "$current"
				putserv "NOTICE $nickname :Topic created successfully with '$cc' new keyword(s) (Total keywords: $c). I've also backed up your old topic skin (not keyword values) incase its ever needed!"
			}
		}
		"delete" {
			set current [channel get $channel service_topicskin]
			if {$current == ""} {
				putserv "NOTICE $nickname :You need to create a topic before you can delete it."
			} else {
				channel set $channel service_topicskin ""
				channel set $channel service_topicskin_old "$current"
				channel set $channel service_topic_keywords ""
				set file [open $filename w]
				close $file
				putserv "NOTICE $nickname :Topic deleted successfully. I've also backed up your old topic skin (not keyword values) incase its ever needed!"
			}
		}
		"keywords" {
			if {[set curr [channel get $channel service_topic_keywords]] == ""} {
				putserv "NOTICE $nickname :No keywords created. Create keywords via the 'create' command by enclosing words with :'s (Exampe: :news: :bnc: (no spaces allowed))."
			} else {
				set list [list]
				set count 0
				foreach entry $curr {
					lappend list "[string tolower [lindex [split $entry] 0]]"
					incr count 1
				}
				putserv "NOTICE $nickname :$count keyword(s) found: [join $list ", "]."
			}
		}
		"preview" {
			set current [channel get $channel service_topicskin]
			if {$current == ""} {
				putserv "NOTICE $nickname :You must create a topic first before you can preview a topic."
			} else {
				if {[set curr [channel get $channel service_topic_keywords]] != ""} {
					array set temp {}
					foreach entry $curr {
						set temp([string tolower [lindex [split $entry] 0]]) "[join [lrange $entry 1 end]]"
					}
					if {[llength [array names temp]] > 0} {
						foreach keyword [array names temp] {
							if {$keyword == ""} { continue }
							if {[set value "$temp($keyword)"] == ""} {
								set value ":${keyword}:"
							}
							set current [string map -nocase [list ":${keyword}:" $value] $current]
						}
					}
				}
				set length [string length $current]
				if {$length > 250} {
					set i [expr {$length - 250}]
					putserv "NOTICE $nickname :Topic length: $length ($i chars above max topic length 250)."
				} else {
					set i [expr {250 - $length}]
					putserv "NOTICE $nickname :Topic length: $length ($i chars below max topic length 250)."
				}
				putserv "NOTICE $nickname :$current"
				putserv "NOTICE $nickname :End of topic preview."
			}
		}
		"set" {
			set current [channel get $channel service_topicskin]
			if {$current == ""} {
				putserv "NOTICE $nickname :You need to create a topic before you can set a topic."
			} elseif {![botisop $channel]} {
				putserv "NOTICE $nickname :I need op to set the topic!"
			} else {
				if {[set curr [channel get $channel service_topic_keywords]] != ""} {
					array set temp {}
					foreach entry $curr {
						set temp([string tolower [lindex [split $entry] 0]]) "[join [lrange $entry 1 end]]"
					}
					if {[llength [array names temp]] > 0} {
						foreach keyword [array names temp] {
							if {$keyword == ""} { continue }
							if {[set value "$temp($keyword)"] == ""} {
								set value ":${keyword}:"
							}
							set current [string map -nocase [list ":${keyword}:" $value] $current]
						}
					}
				}
				#channel set $channel service_topic_save "$current"
				if {[channel get $channel service_topic_Q]} {
					putserv "PRIVMSG Q :SETTOPIC $channel $current"
				} else {
					putserv "TOPIC $channel :$current"
				}
				putserv "NOTICE $nickname :Topic set successfully."
			}
		}
		"q" - "Q" {
			set q [channel get $channel service_topic_Q]
			switch -exact -- [set cmd [lindex [split $text] 1]] {
				"on" - "enable" {
					if {$q} {
						putserv "NOTICE $nickname :Topic Q is already enabled."
					} else {
						channel set $channel +service_topic_Q
						putserv "NOTICE $nickname :Topic Q is now enabled."
					}
				}
				"off" - "disable" {
					if {!$q} {
						putserv "NOTICE $nickname :Topic Q is already disabled."
					} else {
						channel set $channel -service_topic_Q
						putserv "NOTICE $nickname :Topic Q is now disabled."
					}
				}
				"status" {
					putserv "NOTICE $nickname :Topic Q is: \002[expr {$q == "1" ? "enabled" : "disabled"}]\002."
				}
				"default" {
					putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option on|off|status."
				}
			}
		}
		"default" {
			if {$option != ""} {
				set keyword $option
				if {$keyword == ""} {
					putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $option ?value?."
				} elseif {![service::validtopickey $channel $keyword]} {
					putserv "NOTICE $nickname :Invalid keyword specified. Use the 'keywords' command to view all current keywords."
				} else {
					set value [join [lrange [split $text] 1 end]]
					if {$value == ""} {
						set current ""
						foreach entry [channel get $channel service_topic_keywords] {
							if {[string equal -nocase [lindex [split $entry] 0] $keyword]} {
								set current "[join [lrange $entry 1 end]]"
								break
							}
						}
						if {$current == ""} {
							putserv "NOTICE $nickname :Keyword '$keyword' is currently unset."
						} else {
							putserv "NOTICE $nickname :Keyword '$keyword' is currently set as: $current."
						}
					} else {
						if {[set curr [channel get $channel service_topic_keywords]] == ""} {
							channel set $channel service_topic_keywords "\{$keyword $value\}"
						} else {
							array set temp {}
							foreach entry $curr {
								set temp([string tolower [lindex [split $entry] 0]]) "[join [lrange $entry 1 end]]"
							}
							set list [list]
							foreach {k v} [array get temp] {
								if {[string equal -nocase $k $keyword]} {
									lappend list "\{$keyword $value\}"
								} else {
									lappend list "\{$k $v\}"
								}
							}
							if {[llength $list] > 0} {
								channel set $channel service_topic_keywords "[join $list " "]"
							}
						}
						putserv "NOTICE $nickname :Keyword '$keyword' successfully set to: $value."
					}
				}
			} else {
				putserv "NOTICE $nickname :SYTAX: ${lastbind}$command create|delete|preview|keywords|Q|set|<keyword> ?arguments?."
			}
		}
	}
}
service::register topic service::cmd_topic
