#####################################################################
# service.tcl - module: updater
# Checks GitHub for new releases and installs them on request.
#  - checks every update(interval) hours and tells the admin channel when a
#    newer release exists (it never installs on its own)
#  - "update apply" (global owners) downloads the release files listed in
#    manifest.sha256, verifies every SHA-256, backs up the current files to
#    backup/<version>-<date>/ and then rehashes the bot
#  - HTTPS only, with certificate verification; no credentials are sent
#  - service.conf is never touched
# Needs Tcl's http package and the tls package (tcl-tls).
#####################################################################

namespace eval service {
	bind time - {00 * * * *} [namespace current]::update_tick

	variable upd
	if {![array exists upd]} {
		array set upd {state idle latest "" ref "" checked 0 notified ""}
	}
}

# Files the updater may write (relative to the script folder).
proc service::update_allowed {path} {
	if {[string match "*..*" $path] || [string index $path 0] eq "/" || [string match "*\\*" $path]} { return 0 }
	if {[string equal -nocase $path service.conf]} { return 0 }
	return [regexp {^(service\.tcl|VERSION|LICENSE|README\.md|CHANGELOG\.md|service\.conf\.example|modules/[A-Za-z0-9_]+\.tcl|docs/[A-Za-z0-9_.-]+\.md)$} $path]
}

# Sets up HTTPS with certificate verification. Returns "" or an error text.
proc service::update_https {} {
	if {[catch {package require http} err]} { return "Tcl http package not available: $err" }
	if {[catch {package require tls} err]} { return "Tcl tls package not installed (install tcl-tls): $err" }
	set opts [list -require 1]
	set cafile [service::cfg update cafile ""]
	if {$cafile eq ""} {
		foreach f {/etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem /usr/local/share/certs/ca-root-nss.crt /usr/local/etc/ssl/cert.pem} {
			if {[file readable $f]} { set cafile $f; break }
		}
	}
	if {$cafile ne "" && [file readable $cafile]} {
		lappend opts -cafile $cafile
	} elseif {[file isdirectory /etc/ssl/certs]} {
		lappend opts -cadir /etc/ssl/certs
	} else {
		return "no CA certificates found - set update(cafile) in service.conf"
	}
	# GitHub needs SNI (tls 1.7+: -autoservername)
	if {[package vcompare [package present tls] 1.7] >= 0} {
		lappend opts -autoservername 1
	} else {
		return "tls [package present tls] is too old (1.7 or newer is needed for GitHub)"
	}
	http::register https 443 [concat ::tls::socket $opts]
	http::config -useragent "service.tcl/$service::version (Eggdrop)"
	return ""
}

# Asynchronous GET. Calls: {*}$callback ok|error <data or error text>
proc service::update_get {url callback} {
	if {[catch {http::geturl $url -timeout 20000 -binary 1 -command [list service::update_got $callback]} err]} {
		{*}$callback error $err
	}
}

proc service::update_got {callback token} {
	set status [http::status $token]
	set code [http::ncode $token]
	set data [http::data $token]
	http::cleanup $token
	if {$status ne "ok"} {
		{*}$callback error "connection $status"
	} elseif {$code != 200} {
		{*}$callback error "HTTP $code"
	} else {
		{*}$callback ok $data
	}
}

proc service::update_tell {target text} {
	putlog "service.tcl - updater: $text"
	if {$target ne "" && $target ne "-"} {
		putserv "NOTICE $target :$text"
	}
}

proc service::update_staff {text} {
	if {[validchan $service::adminchan] && [botonchan $service::adminchan]} {
		putserv "PRIVMSG $service::adminchan :$text"
	}
}

# --- check -------------------------------------------------------------------

proc service::update_tick {min hour day month year} {
	variable upd
	set hours [service::cfg update interval 6]
	if {$hours <= 0 || [clock seconds] - $upd(checked) < $hours * 3600 - 60} { return }
	service::update_check -
}

# Looks up the latest release. who = nickname to answer, or "-" (silent).
proc service::update_check {who {then ""}} {
	variable upd
	if {$upd(state) ne "idle"} {
		service::update_tell $who "An update operation is already running ($upd(state))."
		return
	}
	if {[set err [service::update_https]] ne ""} {
		service::update_tell $who "Can't check for updates: $err"
		return
	}
	set repo [service::cfg update repo "sauk1337/service.tcl"]
	set upd(state) checking
	if {[service::cfg update source release] eq "branch"} {
		set branch [service::cfg update branch main]
		service::update_get "https://raw.githubusercontent.com/$repo/$branch/VERSION" [list service::update_checked $who $then $branch]
	} else {
		service::update_get "https://api.github.com/repos/$repo/releases/latest" [list service::update_checked $who $then ""]
	}
}

proc service::update_checked {who then ref status data} {
	variable upd
	set upd(state) idle
	set upd(checked) [clock seconds]
	if {$status ne "ok"} {
		service::update_tell $who "Update check failed: $data"
		return
	}
	if {$ref eq ""} {
		# GitHub API answer: take the tag name of the latest release
		if {![regexp {"tag_name"\s*:\s*"([^"]+)"} $data -> ref]} {
			service::update_tell $who "Update check failed: no release found."
			return
		}
		set latest [string trimleft $ref vV]
	} else {
		set latest [string trim $data]
	}
	if {![regexp {^[0-9]+(\.[0-9]+)*$} $latest]} {
		service::update_tell $who "Update check failed: invalid version '$latest'."
		return
	}
	set upd(latest) $latest
	set upd(ref) $ref
	if {[package vcompare $latest $service::version] <= 0} {
		service::update_tell $who "service.tcl is up to date (v$service::version)."
		return
	}
	set msg "service.tcl v$latest is available (running v$service::version) - a global owner can install it with 'update apply'. Changes: https://github.com/[service::cfg update repo sauk1337/service.tcl]/releases"
	service::update_tell $who $msg
	if {$upd(notified) ne $latest} {
		set upd(notified) $latest
		service::update_staff $msg
	}
	if {$then ne ""} {
		{*}$then
	}
}

# --- apply -------------------------------------------------------------------

proc service::update_apply {who} {
	variable upd
	if {[file isdirectory [file join $service::basedir .git]]} {
		service::update_tell $who "This copy was installed with git: update it with 'git pull' in $service::basedir and rehash."
		return
	}
	if {$upd(latest) eq "" || [clock seconds] - $upd(checked) > 600} {
		service::update_check $who [list service::update_apply $who]
		return
	}
	if {[package vcompare $upd(latest) $service::version] <= 0} {
		return
	}
	if {$upd(state) ne "idle"} {
		service::update_tell $who "An update operation is already running ($upd(state))."
		return
	}
	set upd(state) downloading
	set base "https://raw.githubusercontent.com/[service::cfg update repo sauk1337/service.tcl]/$upd(ref)"
	service::update_tell $who "Downloading v$upd(latest)..."
	service::update_get "$base/manifest.sha256" [list service::update_manifest $who $base]
}

proc service::update_fail {who text} {
	variable upd
	set upd(state) idle
	catch {file delete -force [file join $service::basedir .update]}
	service::update_tell $who "Update failed: $text"
	service::update_staff "Update to v$upd(latest) failed: $text"
}

proc service::update_manifest {who base status data} {
	variable upd
	if {$status ne "ok"} { service::update_fail $who "manifest: $data"; return }
	set files [list]
	foreach line [split $data \n] {
		set line [string trim $line]
		if {$line eq "" || [string index $line 0] eq "#"} { continue }
		if {![regexp {^([0-9a-f]{64})\s+\*?(\S+)$} $line -> sum path]} {
			service::update_fail $who "invalid manifest line: $line"; return
		}
		if {![service::update_allowed $path]} {
			service::update_fail $who "manifest lists a file the updater may not write: $path"; return
		}
		lappend files $path $sum
	}
	if {[lsearch -exact $files service.tcl] == -1 || [lsearch -exact $files modules/core.tcl] == -1} {
		service::update_fail $who "manifest is incomplete"; return
	}
	set staging [file join $service::basedir .update]
	catch {file delete -force $staging}
	file mkdir $staging
	service::update_next $who $base $files 0
}

# Downloads the files one by one (asynchronously) into .update/
proc service::update_next {who base files index} {
	variable upd
	if {$index >= [llength $files]} {
		service::update_install $who $files
		return
	}
	set path [lindex $files $index]
	service::update_get "$base/$path" [list service::update_file $who $base $files $index]
}

proc service::update_file {who base files index status data} {
	set path [lindex $files $index]
	set sum [lindex $files [expr {$index + 1}]]
	if {$status ne "ok"} { service::update_fail $who "$path: $data"; return }
	set target [file join $service::basedir .update $path]
	file mkdir [file dirname $target]
	set fh [open $target wb]
	puts -nonewline $fh $data
	close $fh
	if {[service::crypto::sha256_file $target] ne $sum} {
		service::update_fail $who "$path: SHA-256 mismatch (download corrupted or tampered with)"; return
	}
	# next file on the next event, so the bot keeps working between files
	utimer 0 [list service::update_next $who $base $files [expr {$index + 2}]]
}

proc service::update_install {who files} {
	variable upd
	set upd(state) installing
	set staging [file join $service::basedir .update]
	set fh [open [file join $staging VERSION] r]
	set newversion [string trim [read $fh]]
	close $fh
	if {$newversion ne $upd(latest)} {
		service::update_fail $who "VERSION file says $newversion, expected $upd(latest)"; return
	}
	set backup [file join $service::basedir backup "$service::version-[clock format [clock seconds] -format %Y%m%d-%H%M%S]"]
	set done [list]
	if {[catch {
		foreach {path sum} $files {
			set dest [file join $service::basedir $path]
			if {[file exists $dest]} {
				file mkdir [file dirname [file join $backup $path]]
				file copy -force $dest [file join $backup $path]
			}
		}
		foreach {path sum} $files {
			set dest [file join $service::basedir $path]
			file mkdir [file dirname $dest]
			file copy -force [file join $staging $path] $dest
			lappend done $path
		}
	} err]} {
		# roll back whatever was already replaced
		foreach path $done {
			catch {file copy -force [file join $backup $path] [file join $service::basedir $path]}
		}
		service::update_fail $who "installing files: $err (rolled back)"
		return
	}
	catch {file delete -force $staging}
	set upd(state) idle
	service::update_tell $who "Updated to v$newversion (backup in $backup). Rehashing..."
	service::update_staff "service.tcl updated from v$service::version to v$newversion by $who - rehashing."
	utimer 2 rehash
}

# update ?check|apply|status?
proc service::cmd_update {nickname hostname handle channel text lastbind command} {
	variable upd
	if {![matchattr $handle n]} {
		putserv "NOTICE $nickname :Only global bot owners can update the script."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	switch -exact -- [string tolower [lindex [split $text] 0]] {
		"apply" - "install" { service::update_apply $nickname }
		"status" {
			putserv "NOTICE $nickname :Running v$service::version - latest known: [expr {$upd(latest) eq "" ? "not checked yet" : "v$upd(latest)"}] - last check: [expr {$upd(checked) ? [clock format $upd(checked) -format "%Y-%m-%d %H:%M"] : "never"}] - state: $upd(state) - source: [service::cfg update repo sauk1337/service.tcl] ([service::cfg update source release])"
		}
		"check" - "" { service::update_check $nickname }
		default { putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command ?check|apply|status?" }
	}
}
service::register update service::cmd_update
