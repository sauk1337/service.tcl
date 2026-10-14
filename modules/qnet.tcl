#####################################################################
# service.tcl - module: qnet
# QuakeNet / Q integration:
#  - Q authentication with CHALLENGEAUTH (HMAC-SHA-256, the password never
#    leaves the bot) or plain AUTH, optionally before joining channels so
#    the +x hidden host is active from the first JOIN
#  - asking Q for op/invite/unban when the bot needs it
#  - relaying Q's answers to the user who ran a Q command
#  - tracking whether Q is on each channel
#####################################################################

namespace eval service {
	bind need - {*} [namespace current]::parseneed
	bind join - {*} [namespace current]::onjoin_Q
	bind part - {*} [namespace current]::onpart_Q
	bind notc - {*} [namespace current]::qnotice

	variable qaddr "Q@CServe.quakenet.org"
	variable qhost "TheQBot@CServe.quakenet.org"
	# auth state: idle | challenge | authing | authed | failed
	variable qauth_state
	if {![info exists qauth_state]} { set qauth_state idle }
	variable qrelay
	if {![array exists qrelay]} { array set qrelay {} }
}

# --- authentication ------------------------------------------------------

# Starts the Q login. Called on connect (init-server, hold=1) and by the auth
# command (hold=0: never hold channels the bot is already in).
# Returns 0 when no account is configured.
proc service::qauth {{hold 0}} {
	variable qauth_state
	set user [service::cfg qauth user]
	set pass [service::cfg qauth pass]
	if {$user eq "" || $pass eq ""} { return 0 }
	if {$hold && [service::cfg qauth waitjoin 1]} {
		service::qauth_hold
	}
	if {[string tolower [service::cfg qauth method challenge]] eq "auth"} {
		set qauth_state authing
		putquick "PRIVMSG $service::qaddr :AUTH $user $pass"
	} else {
		set qauth_state challenge
		putquick "PRIVMSG $service::qaddr :CHALLENGE"
	}
	set timeout [service::cfg qauth timeout 30]
	foreach t [utimers] {
		if {[string match "*service::qauth_timeout*" [lindex $t 1]]} { killutimer [lindex $t 2] }
	}
	utimer $timeout [list service::qauth_timeout]
	return 1
}

# CHALLENGEAUTH response: HMAC-SHA-256(key, challenge) where
# key = SHA256(lowercase(user) + ":" + SHA256(password truncated to 10 chars))
# Lowercasing follows RFC 1459 ([]\~ -> {}|^). Verified against QuakeNet's
# published test vectors (tests/crypto.tcl).
proc service::qauth_response {user pass challenge} {
	set lcuser [string map {[ \{ ] \} \\ | ~ ^} [string tolower $user]]
	set key [service::crypto::sha256 "$lcuser:[service::crypto::sha256 [string range $pass 0 9]]"]
	return [service::crypto::hmac_sha256 $key $challenge]
}

proc service::qauth_success {} {
	variable qauth_state
	set qauth_state authed
	putlog "service.tcl - authenticated with Q as [service::cfg qauth user]"
	if {[service::cfg qauth hidehost 1]} {
		putquick "MODE $::botnick +x"
	}
	# give the server a moment to apply +x before joining
	utimer 2 [list service::qauth_release "authed"]
}

proc service::qauth_timeout {} {
	variable qauth_state
	if {$qauth_state eq "authed"} { return }
	putlog "service.tcl - no answer from Q after [service::cfg qauth timeout 30]s (state: $qauth_state) - joining channels anyway"
	service::qauth_release "timeout"
}

# --- join hold (auth before join) ----------------------------------------
# Channels are set +inactive while the bot authenticates and released after.
# The list is also written to a file so a crash during the wait can't leave
# channels inactive forever (it is released on the next load).

proc service::qauth_heldfile {} {
	return [file join $service::basedir .qauth-held]
}

proc service::qauth_hold {} {
	set held [list]
	foreach channel [channels] {
		if {![channel get $channel inactive]} {
			lappend held $channel
			channel set $channel +inactive
		}
	}
	if {[llength $held] == 0} { return }
	if {[file exists [service::qauth_heldfile]]} {
		# a previous hold was never released: keep those channels too
		set fh [open [service::qauth_heldfile] r]
		set held [lsort -unique [concat $held [split [string trim [read $fh]] \n]]]
		close $fh
	}
	set fh [open [service::qauth_heldfile] w]
	puts $fh [join $held \n]
	close $fh
}

proc service::qauth_release {reason} {
	set file [service::qauth_heldfile]
	if {![file exists $file]} { return }
	set fh [open $file r]
	set held [split [string trim [read $fh]] \n]
	close $fh
	file delete $file
	foreach channel $held {
		if {$channel ne "" && [validchan $channel]} {
			channel set $channel -inactive
		}
	}
	putlog "service.tcl - joining [llength $held] channel(s) ($reason)"
}

# --- Q notices -------------------------------------------------------------

proc service::qnotice {nickname userhost handle text {dest ""}} {
	if {![string equal -nocase $nickname Q] || ![string equal -nocase $userhost $service::qhost]} { return 0 }
	variable qauth_state
	set text [stripcodes bcruag $text]
	if {$qauth_state eq "challenge" && [lindex [split $text] 0] eq "CHALLENGE"} {
		set challenge [lindex [split $text] 1]
		if {[lsearch -exact [lrange [split $text] 2 end] HMAC-SHA-256] == -1} {
			putlog "service.tcl - Q does not offer HMAC-SHA-256, falling back to plain AUTH"
			set qauth_state authing
			putquick "PRIVMSG $service::qaddr :AUTH [service::cfg qauth user] [service::cfg qauth pass]"
			return 0
		}
		set qauth_state authing
		set user [service::cfg qauth user]
		putquick "PRIVMSG $service::qaddr :CHALLENGEAUTH $user [service::qauth_response $user [service::cfg qauth pass] $challenge] HMAC-SHA-256"
		return 0
	}
	if {$qauth_state eq "authing"} {
		if {[string match -nocase "*logged in as*" $text] || [string match -nocase "*already authed*" $text]} {
			service::qauth_success
			return 0
		}
		if {[string match -nocase "*incorrect*" $text] || [string match -nocase "*failed*" $text] || [string match -nocase "*suspended*" $text]} {
			set qauth_state failed
			putlog "service.tcl - Q authentication FAILED: $text"
			if {[validchan $service::adminchan]} {
				putserv "PRIVMSG $service::adminchan :\002Q auth failed:\002 $text"
			}
			service::qauth_release "auth failed"
			return 0
		}
	}
	# relay Q's answers to users who just ran a Q command
	variable qrelay
	set now [clock seconds]
	foreach {nick expires} [array get qrelay] {
		if {$expires < $now} {
			unset qrelay($nick)
		} else {
			puthelp "NOTICE $nick :\[Q\] $text"
		}
	}
	return 0
}

# Sends a channel command to Q. With relayto, Q's answers for the next 15
# seconds are forwarded to that nickname.
proc service::qsend {line {relayto ""} {fast 0}} {
	if {$fast} {
		service::now "PRIVMSG Q :$line"
	} else {
		putquick "PRIVMSG Q :$line"
	}
	if {$relayto ne ""} {
		set ::service::qrelay([string tolower $relayto]) [expr {[clock seconds] + 15}]
	}
}

# --- Q help when the bot needs something -----------------------------------

proc service::parseneed {channel type} {
	switch -exact -- $type {
		"op" {
			if {[string equal -nocase $service::homechan $channel]} { return }
			if {[string equal -nocase $service::adminchan $channel]} { return }
			if {[string equal -nocase $service::helpchan $channel]} { return }
			putquick "PRIVMSG Q :OP $channel" -next
		}
		"unban" {
			if {[botonchan $channel] && ![botisop $channel]} {
				putquick "PRIVMSG Q :UNBANALL $channel" -next
			} else {
				putquick "PRIVMSG Q :UNBANME $channel" -next
				putquick "PRIVMSG Q :INVITE $channel" -next
			}
		}
		"invite" - "limit" - "key" {
			putquick "PRIVMSG Q :INVITE $channel" -next
		}
	}
}

proc service::onjoin_Q {nickname hostname handle channel} {
	if {$nickname == "Q"} {
		channel set $channel service_servicebot "$nickname"
		if {[validuser $handle]} {
			chattr $handle +S|+S $channel
		}
	}
}

proc service::onpart_Q {nickname hostname handle channel {reason ""}} {
	if {$nickname == "Q"} {
		channel set $channel service_servicebot ""
		if {[validuser $handle]} {
			chattr $handle |-S $channel
		}
	}
}

# Crash recovery: release channels held by an unfinished auth on load
if {$service::qauth_state ne "challenge" && $service::qauth_state ne "authing"} {
	service::qauth_release "startup"
}

# Loaded while already connected (.restart keeps the server connection, so
# init-server doesn't fire): log in now if the bot isn't authed yet.
proc service::qauth_onload {} {
	if {$service::qauth_state ne "idle" && $service::qauth_state ne "failed"} { return }
	if {![info exists ::server-online] || ${::server-online} == 0} { return }
	if {![info exists ::server] || ![string match -nocase "*.quakenet.org*" $::server]} { return }
	if {[info exists ::botname] && [string match -nocase "*.users.quakenet.org" $::botname]} {
		set service::qauth_state authed
		return
	}
	service::qauth 0
}
utimer 3 [list service::qauth_onload]
