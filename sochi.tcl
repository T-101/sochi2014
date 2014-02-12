#### SOCHI 2014 Hockeygame flooder
####
#### V0.1  - first release
#### V0.11 - typo fixes

setudef flag sochiih

bind pub - !now pub:sochiIH
bind pub - !changegame pub:changegame
bind time - * pub:updategame

package require http
package require json

set gamecode IHM400B01

set lastmessage ""

proc pub:changegame {nick mask hand channel arguments} {
if {[channel get $channel sochiih] && [onchan $nick $channel] && [string tolower $nick] == "t-101"} {
	global gamecode
	set gamecode $arguments
} }

proc pub:updategame {minute hour day month year} {
pub:sochiIH nick mask hand channel timer;
}

proc pub:sochiIH {nick mask hand channel arguments} {
if {[channel get $channel sochiih] && [onchan $nick $channel]} {

set types { "GK_OUT" "Goalkeeper out" "GK_IN" "Goalkeeper in" "P" "Penalty" "G" "Goal" "HOOK" "Hooking" "TOO_M" "Too many players" "TRIP" "Tripping" "BD_CK" "Body check" "ROUGH" "Roughing" "INTRF" "Interference" "HOLD" "Holding" }

set times {08 10 09 11 10 12 11 13 12 14 13 15 14 16 15 17 16 18 17 19 18 20 19 21 20 22 21 23}

global gamecode lastmessage

    # send the http request, -timeout sets up a timeout to occur after the specified number of milliseconds
    # we use catch to avoid an abort of the script in case of an error when executing http::geturl (e.g. due to an unsupported url)
    if { [catch { set token [http::geturl http://mapi.sochi2014.com/v1/en/olympic/results/${gamecode} -timeout 3000]} error] } {
        putcmdlog "web2data: Error: $error"
        # if the the site does not exist
    } elseif { [http::ncode $token] == "404" } {
        putcmdlog "web2data: Error: [http::code $token]"
        # check if the request was successful, if yes -> put the html source code into $data
    } elseif { [http::status $token] == "ok" } {
        set data [http::data $token]
        # if a timeout has occurred, send "Timeout occured" to the standad output device
    } elseif { [http::status $token] == "timeout" } {
        putcmdlog "web2data: Timeout occurred"
        # send the error to the standard output device if there is one
    } elseif { [http::status $token] == "error" } {
        putcmdlog "web2data: Error: [http::error $token]"
    }
    # last but not least, release the memory which was used for these operations
    http::cleanup $token
    if { [info exists data] } {
	set jsondata [json::json2dict $data]
	set teams [lindex $jsondata 1]-[lindex $jsondata 3]
	set score [lindex [lindex $jsondata 5] 1]-[lindex [lindex $jsondata 5] 3]
	set actions [lsearch $jsondata "actions"]
	set lastaction [lindex [lindex $jsondata [expr $actions + 1]] 0]
	set timeindex [lsearch $lastaction "time"]
	set time [lindex $lastaction [expr $timeindex +1]]
	set typeindex [lsearch $lastaction "type"]
	set type [lindex $lastaction [expr $typeindex +1]]
	set nationalityindex [lsearch $lastaction "competitorCode"]
	set nationality [lindex $lastaction [expr $nationalityindex +1]]
	set athleteindex [lsearch $lastaction "athlete"]
	set athlete [lindex $lastaction [expr $athleteindex +1]]
	set playerindex [lsearch $athlete "shortName"]
	set player [lindex $athlete [expr $playerindex +1]]
	set playernumberindex [lsearch $lastaction "athleteNumber"]
	set playernumber [lindex $lastaction [expr $playernumberindex +1]]
	set assistindex [lsearch $lastaction "participants"]
	set assist1index [lindex $lastaction [expr $assistindex +1]]
	set assist1 [lindex [lindex [lindex $assist1index 1] 1] 1]
	set assist2 [lindex [lindex [lindex $assist1index 2] 1] 1]
	if {$assist1 != ""} { set assist1 "(${assist1}" }
	if {$assist2 == "" && $assist1 != ""} { set assist1 "${assist1})"}
	if {$assist1 != "" && $assist2 != ""} { set assist2 "${assist2})"}
	

# has the game started?
	if {[lindex [lindex $jsondata 5] 1] == "" && $arguments != "timer"} {
		set startingtimeindex [lsearch $jsondata "eventUnit"]
		set startingtime [lindex [lindex $jsondata [expr $startingtimeindex +1]] 7]
		set starttime [split $startingtime "T"]
		set finnishtime [string map $times [lindex [split [lindex $starttime 1] ":"] 0]]
		set message "$teams will start at $finnishtime finnish time"
		foreach item [channels] {
			if {[channel get $item sochiih]} {putquick "NOTICE $item :$message" } }
		set lastmessage $message
		return 0
	}

# it has? cool!
	set message "$teams $score $time, [string map $types $type] $nationality $player $assist1 $assist2"
	if {$message != $lastmessage && [lindex [lindex $jsondata 5] 1] != ""} {
		foreach item [channels] { if {[channel get $item sochiih]} {putquick "NOTICE $item :${message}"} }
	set lastmessage $message
        return $data
    } else {
        return 0
    }
}

} }

putlog "SOCHI 2014 IceHockey script v0.1 by T-101 loaded"