setudef flag sochiv2

bind cron - "* 10-23 * * *" sochiExecute

package require json
package require http

set games { IHM400404 IHM400301 IHM400302 IHM400303 IHM400304 IHM400201 IHM400202 IHM400102 IHM400101 }
set games {IHM400404 }
set homescore 0
set awayscore 0
set gamedata ""
set cache "sochi2014_cache"
set lastmessage ""

set types {     "PP1" "Powerplay" "PP2" "Powerplay 2" "SH1" "Shorthanded" "SH2" "Shorthanded 2" "ENG" "Empty net" "GWG" "Game winning goal"
		"GK_OUT" "Goalkeeper out" "GK_IN" "Goalkeeper in" "P" "Penalty" "G" "\002Goal\002" "TP" "Team Penalty" "TMO" "Timeout"
                "HOOK" "Hooking" "TOO_M" "Too many men on ice" "TRIP" "Tripping" "BD_CK" "Body check" "ROUGH" "Roughing" "INTRF" "Interference" "HO_ST" "Holding the stick"
                "HOLD" "Holding" "HI_ST" "High stick" "CROSS" "Cross-checking" "DELAY" "Delaying the game" "HAND_Penalty" "Closing hand on puck" "KNEE" "Kneeing" "SLASH" "Slashing"
                }



#### UPCOMING GAMES, times in UTC
#### http://mapi.sochi2014.com/v1/en/olympic/results/${gamecode}
#### 18.2
#### IHM400401 Q1
#### IHM400402 Q2
#### IHM400403 Q3
#### IHM400404 Q4
#### 19.2
#### IHM400301 QF1
#### IHM400302 QF2
#### IHM400303 QF3
#### IHM400304 QF4
#### 21.2
#### IHM400201 SF1
#### IHM400202 SF2
#### 22.2
#### IHM400102 Bronze
#### 23.2
#### IHM400101 Final

proc output {value} {
foreach channel [channels] { if {[channel get $channel sochiv2]} {putquick "NOTICE $channel :$value"} } }

proc settopic {value} {
foreach channel [channels] { if {[channel get $channel sochiv2]} {putquick "TOPIC $channel :$value"} } }

proc dlz {value} {
while {[string index $value 0] == "0"} {set value [string range $value 1 end]}
if {$value == ""} {return 0} else {return $value}
}

proc pub:sochiToggle {nick mask hand channel arguments} {
}

proc sochiInit {} {
global gamedata cache games homescore awayscore
file mkdir $cache

if {[dict exists $gamedata game homeScore]} {set homescore [dict get $gamedata game homeScore]} else {set homeScore 0}
if {[dict exists $gamedata game awayScore]} {set awayscore [dict get $gamedata game awayScore]} else {set awayScore 0}

if {![file exists "$cache\/[lindex $games 0]"]} {
    set fileindex [open "$cache\/[lindex $games 0]" w]
    puts $fileindex "-1"
    close $fileindex
}
}

proc gameStatus {} {
global gamedata
if {[dict exists $gamedata status]} {return [dict get $gamedata status]}
}

proc pub:sochiPre {} {
global gamedata lastmessage homescore
if {![dict exists $gamedata eventUnit start]} {return}
set home [dict get $gamedata homeCode]
set away [dict get $gamedata awayCode]
set homescore 0
set awayscore 0
set startdate [split [dict get $gamedata eventUnit start] "T"]
set starttime [lindex [split [lindex $startdate 1] ":"] 0]
set message "${home}-${away} will start [lindex $startdate 0] at [expr [dlz $starttime] +2]:[lindex [split [lindex $startdate 1] ":"] 1] finnish time"
if {$message != $lastmessage} {output $message; settopic "$message \| https://github.com/T-101/sochi2014"}
set lastmessage $message
}

proc pub:sochiGame {} {
global types games cache lastmessage gamedata homescore awayscore
set actions [dict get $gamedata actions]
set fileindex [open "$cache\/[lindex $games 0]" r]
set lastindexed [read $fileindex]
if {$lastindexed == -1} {set lastindexed 0}
close $fileindex
for {set x [expr [llength $actions] -1 -$lastindexed]} {$x >= 0} {incr x -1} {
	if {$lastindexed < [llength $actions]} {
		set addendum ""
		set home [dict get $gamedata homeCode]
		set away [dict get $gamedata awayCode]
		set time [dict get [lindex $actions $x] time]
		set type [dict get [lindex $actions $x] type]
		set nationality [dict get [lindex $actions $x] competitorCode]
		if {[dict exists [lindex $actions $x] athleteNumber]} {set playernumber "#[dict get [lindex $actions $x] athleteNumber]"; set addendum $playernumber}
                if {[dict exists [lindex $actions $x] athleteServingNumber]} {set playernumber "#[dict get $[lindex $actions $x] athleteServingNumber]"; set addendum $playernumber}
		if {[dict exists [lindex $actions $x] athlete shortName]} {set player [dict get [lindex $actions $x] athlete shortName]; set addendum "$addendum $player"}
		if {[dict exists [lindex $actions $x] athleteServing shortName]} {set player [dict get $[lindex $actions $x] athleteServing shortName]; set addendum "$addendum $player"}
		if {$type == "P"} {
			if {[dict get [lindex $actions $x] isTeamPenalty] == "true"} {set type "TP"}
			set penalty [dict get [lindex $actions $x] penaltyDesc]
                        set penaltymin [dict get [lindex $actions $x] penaltyPIM]
                        set addendum "$playernumber $player ([string map $types $penalty] ${penaltymin}min)"
		}
	        if {$type == "G"} {
		set addendum ""
                if {[dict get [lindex $actions $x] goalType] != "EQ" && [dict get [lindex $actions $x] goalType] != "EQ_EA"} {set goaltype "([string map $types [dict get [lindex $actions $x] goalType]])"} else {set goaltype ""}
		
                set participants [dict get [lindex $actions $x] participants]
                foreach item $participants {
                        if {[dict get $item role] != "SCR"} { set addendum "$addendum [dict get $item athlete shortName]," }
                }
        	if {[string length $addendum] != 0} {set addendum "([string range [string trim $addendum] 0 end-1])"}
		if {$goaltype != ""} {set addendum "${goaltype} ${playernumber} $player $addendum"} else {set addendum "${playernumber} $player $addendum"}
		set homescore [dlz [lindex [split [dict get [lindex $actions $x] result] ":"] 0]]
		set awayscore [dlz [lindex [split [dict get [lindex $actions $x] result] ":"] 1]]
                }
		if {$type == "GWG"} {
		set goaltype [dict get [lindex $actions $x] type]
                set homescore [dlz [lindex [split [dict get [lindex $actions $x] result] ":"] 0]]
                set awayscore [dlz [lindex [split [dict get [lindex $actions $x] result] ":"] 1]]
		}

		if {$addendum != ""} {set addendum ", $addendum"}
		set message "${home}-${away} ${homescore}-${awayscore} ${time}, [string map $types $type] ${nationality}$addendum"
		if {$message != $lastmessage} {output $message}
		set lastmessage $message
	}
}
set lastindexed [llength $actions]
set fileindex [open "$cache\/[lindex $games 0]" w]
puts $fileindex $lastindexed
close $fileindex
}

proc pub:sochiEndgame {} {
global games gamedata lastmessage
set teams "[dict get $gamedata homeCode]-[dict get $gamedata awayCode]"

set homeSOG [dict get $gamedata game homeSOG]
set awaySOG [dict get $gamedata game awaySOG]
set homePIM [dict get $gamedata game homePIM]
set awayPIM [dict get $gamedata game awayPIM]
set homescore [dict get $gamedata game homeScore]
set awayscore [dict get $gamedata game awayScore]
set message "Final score: $teams ${homescore}-${awayscore}. Shots on goal: [dict get $gamedata homeCode] $homeSOG, [dict get $gamedata awayCode] $awaySOG. Penalties in minutes: [dict get $gamedata homeCode] $homePIM, [dict get $gamedata awayCode] $awayPIM"
if {$message != $lastmessage} {output $message}
set lastmessage $message
set games [lreplace $games 0 0]
}

proc getSochiData {url} {
global gamedata
    # send the http request, -timeout sets up a timeout to occur after the specified number of milliseconds
    # we use catch to avoid an abort of the script in case of an error when executing http::geturl (e.g. due to an unsupported url)
    if { [catch { set token [http::geturl $url -timeout 3000]} error] } {
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
#	set hanska [open "scripts/401.txt" r]
#	set data [read $hanska]
#	close $hanska
    if { [info exists data] } {
        set gamedata [json::json2dict $data]
} else { return 0 }

}

proc sochiExecute {min hour day month year} {
global games
if {[llength $games] != 0} {
    getSochiData http://mapi.sochi2014.com/v1/en/olympic/results/[lindex $games 0]
    sochiInit
    if {[gameStatus] == 2} {pub:sochiPre}
    if {[gameStatus] == 4} {pub:sochiGame}
    if {[gameStatus] == 7} {pub:sochiEndgame}
} else { return }
}

putlog "Sochi 2014 Icehockey flooder V2 by T-101"
