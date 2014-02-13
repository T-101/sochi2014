#### SOCHI 2014 Hockeygame IRC flooder
####
#### V0.10 - first release - thanks to truck for api link
#### V0.11 - typo fixes
#### V0.20 - better json code - thanks to ente
#### V0.30 - fixed massive bugs, added penalties
#### V0.31 - added assists, fixed times
#### V0.32 - added endgame stats, and upcoming gamecodes
#### V0.33 - fixed some buggage

setudef flag sochiih

bind pub - !now pub:sochiIH
bind pub - !changegame pub:changegame
bind pub - !toggle pub:toggleresults
bind time - * pub:updategame

package require http
package require json

set gamecode IHM400B02

#### UPCOMING GAMES, times in UTC
####
#### 14.2
#### IHM400C03 CZE-LAT 08:00
#### IHM400C04 SWE-SUI 12:30
#### IHM400B04 NOR-FIN 17:00
#### 15.2
#### IHM400A03 SVK-SLO 08:00
#### IHM400A04 USA-RUS 12:30
#### IHM400C05 SUI-CZE 17:00
#### IHM400C06 SWE-LAT 17:00
#### 16.2
#### IHM400B05 AUT-NOR 08:00
#### IHM400A05 RUS-SVK 12:30
#### IHM400A06 SLO-USA 12:30
#### IHM400B06 FIN-CAN 17:00

set admin "T-101"

set lastmessage ""

proc pub:changegame {nick mask hand channel arguments} {
global admin
if {[channel get $channel sochiih] && [onchan $nick $channel] && [string tolower $nick] == [string tolower $admin]} {
	global gamecode
	if {$arguments == ""} {putquick "PRIVMSG $channel :Current game is $gamecode"} {else} {set gamecode $arguments}
} }

proc pub:updategame {minute hour day month year} {
#	putlog "updategame"
 pub:sochiIH nick mask hand #fapahtaja timer;
}

proc pub:toggleresults {nick mask hand channel arguments} {
global admin
if {[string tolower $nick] == [string tolower $admin]} {
	if {[channel get $channel sochiih]} {
		channel set $channel -sochiih
		putquick "PRIVMSG $channel :Sochi Icehockey disabled"
	} else {
		channel set $channel +sochiih
		putquick "PRIVMSG $channel :Sochi Icehockey enabled"
		pub:sochiIH $nick $mask $hand $channel $arguments
	}
} }

proc dlz {value} {
if {[string index $value 0] == "0"} {return [expr [string replace $value 0 0]]} else {return [expr $value]}
}

proc pub:sochiIH {nick mask hand channel arguments} {

set types { "GK_OUT" "Goalkeeper out" "GK_IN" "Goalkeeper in" "P" "Penalty" "G" "\002Goal\002" "TP" "Team Penalty" "TMO" "Timeout"
						"HOOK" "Hooking" "TOO_M" "Too many men on ice" "TRIP" "Tripping" "BD_CK" "Body check" "ROUGH" "Roughing" "INTRF" "Interference" "HOLD" "Holding" }

set addendum ""
set score ""
set time ""
set type ""
set player ""
set playernumber ""
set nationality ""
set goaltype ""

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
	if {[dict get $jsondata resultStatus] == "INTERMEDIATE"} {
			set message "Intermission"
			if {$message != $lastmessage} {foreach item [channels] { if {[channel get $item sochiih]} {putquick "NOTICE $item :${message}"} }}
			set lastmessage $message
			return
	}
	set teams [dict get $jsondata homeCode]-[dict get $jsondata awayCode]
	if {[dict exists $jsondata game]} {set score [dict get $jsondata game homeScore]-[dict get $jsondata game awayScore]}
	if {[dict exists $jsondata actions] && [dict get $jsondata actions] != ""} {
		set lastaction [lindex [dict get $jsondata actions] 0]
		set time [dict get $lastaction time]
		set type [dict get $lastaction type]
		if {$type == "P" && [dict get $lastaction isTeamPenalty] == "true"} {set type "TP"}
		set nationality [dict get $lastaction competitorCode]
		if {[dict exists $lastaction athlete]} {set player [dict get $lastaction athlete shortName]}
		if {[dict exists $lastaction athleteNumber]} {set playernumber "#[dict get $lastaction athleteNumber]"}
		if {$type == "P" || $type == "TP"} {
			if {[dict exists $lastaction athlete]} {set player [dict get $lastaction athlete shortName]} else {set player [dict get $lastaction athleteServing shortName]}
			if {[dict exists $lastaction athleteNumber]} {set playernumber "#[dict get $lastaction athleteNumber]"} else {set playernumber "#[dict get $lastaction athleteServingNumber]"}
			set penalty [dict get $lastaction penaltyDesc]
			set penaltymin [dict get $lastaction penaltyPIM]
			set addendum "([string map $types $penalty] ${penaltymin}min)"
		}
	if {$type == "G"} {
		if {[dict get $lastaction goalType] != "EQ" && [dict get $lastaction goalType] != "EQ_EA"} {set goaltype " ([dict get $lastaction goalType])"}
		set participants [dict get $lastaction participants]
		foreach item $participants {
			if {[dict get $item role] != "SCR"} { set addendum "$addendum [dict get $item athlete shortName]," }
		}
	if {[string length $addendum] != 0} {set addendum "([string range [string trim $addendum] 0 end-1])"}
		}
}

# has the game started?
	if {![dict exists $jsondata game] && $arguments != "timer"} {
		set starttime [split [dict get $jsondata eventUnit start] "T"]
		set utchour [lindex [split [lindex $starttime 1] ":"] 0]
		set message "$teams will start at [dlz $utchour] UTC"
		set message "$teams will start [lindex $starttime 0], at [expr [dlz $utchour] +2]:[lrange [split [lindex $starttime 1] ":"] 1 1] finnish time"
		foreach item [channels] {
			if {[channel get $item sochiih] && $item == $channel} {putquick "NOTICE $item :$message" } }
		set lastmessage $message
		return 0
	}

# it has? cool!
	set message "$teams $score $time, [string map $types $type]$goaltype $nationality $playernumber $player $addendum"
	if {$message != $lastmessage && [dict get $jsondata periods] != "" && $arguments != "timer"} {
		foreach item [channels] { if {[channel get $item sochiih]} {putquick "NOTICE $item :${message}"} }
	set lastmessage $message
#        return $data
    } else {
#        return 0
    }
    
# has the game ended?
	if {$type == "GK_OUT" && $time == "60:00"} {
			set homeSOG [dict get $jsondata game homeSOG]
			set awaySOG [dict get $jsondata game awaySOG]
			set homePIM [dict get $jsondata game homePIM]
			set awayPIM [dict get $jsondata game awayPIM]
			set message "Final score $teams $score. Shots on goal: [dict get $jsondata homeCode] ${homeSOG}, [dict get $jsondata awayCode] $awaySOG. Penalties in minutes: [dict get $jsondata homeCode] ${homePIM}, [dict get $jsondata awayCode] $awayPIM"
			if {$message != $lastmessage} {
			foreach item [channels] { if {[channel get $item sochiih]} {
					putquick "NOTICE $item :$message"
					set lastmessage $message
				}
			} }
}
} }

putlog "SOCHI 2014 Olympic IceHockey script by T-101 loaded"
