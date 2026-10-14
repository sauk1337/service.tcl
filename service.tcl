#####################################################################
# service.tcl - Channel service & protection script for Eggdrop/QuakeNet
#
# Original author : r0t3n aka Eagle (#r0t3n)
# Maintained by   : sauk1337 - https://github.com/sauk1337/service.tcl
#
# This file is only the loader. It reads service.conf (same directory,
# same base name) and then loads the modules from modules/.
#
# Install: copy the whole folder to scripts/service/ and add to eggdrop.conf
#   source scripts/service/service.tcl
#####################################################################

namespace eval service {

	variable start [clock microseconds]

	variable basedir [file dirname [file normalize [info script]]]
	variable script [file tail [info script]]
	# the version comes from the VERSION file (also used by the updater)
	variable version "unknown"
	catch {
		set fh [open [file join $basedir VERSION] r]
		set version [string trim [read $fh]]
		close $fh
	}
	variable author "r0t3n aka Eagle \( #r0t3n \)"
	variable copyright "$script - v${version} - $author"

	# Modules, in load order. "core" and "crypto" are required and can't be disabled.
	# Disable optional modules with "variable disabled_modules {...}" in service.conf.
	variable modules {
		core
		crypto
		protect
		takeover
		qnet
		spamscan
		onjoin
		botnet
		cmd_users
		cmd_settings
		cmd_channel
		cmd_q
		cmd_admin
		help
		updater
	}
	variable disabled_modules {}

	# --- configuration ---
	variable configfile [file join $basedir "[file rootname $script].conf"]
	if {![file exists $configfile]} {
		putlog "$script - '$configfile' not found: copy service.conf.example to service.conf and edit it"
		return -code error "$script - '$configfile' not found: copy service.conf.example to service.conf and edit it"
	}
	if {[catch {source $configfile} error]} {
		putlog "$script - couldn't load configuration file '$configfile': $error"
		return -code error "$script - couldn't load configuration file '$configfile': $error"
	}
	putlog "$script - loaded configuration file '$configfile'"

	# --- modules ---
	variable loadedmodules [list]
	variable linecount 0
	foreach module $modules {
		if {$module ni {core crypto} && [lsearch -exact $disabled_modules $module] != -1} {
			putlog "$script - module '$module' disabled in configuration"
			continue
		}
		set path [file join $basedir modules $module.tcl]
		if {![file exists $path]} {
			if {$module eq "core"} {
				return -code error "$script - required module 'core' not found at '$path'"
			}
			putlog "$script - WARNING: module '$module' not found at '$path' - skipped"
			continue
		}
		if {[catch {uplevel #0 [list source -encoding utf-8 $path]} error]} {
			putlog "$script - ERROR loading module '$module': $error"
			if {$module eq "core"} {
				return -code error "$script - couldn't load required module 'core': $error"
			}
			continue
		}
		set fh [open $path r]
		incr linecount [llength [split [read -nonewline $fh] \n]]
		close $fh
		lappend loadedmodules $module
	}
	unset -nocomplain module path error fh

	service::init
	service::loaded
}
