#!  /usr/bin/wish

package require Tk

source /home/imt/imt/robot4/crob_ASU/shm.tcl

global ob

bind . <Key-q> done

# If want to run an IE study, set studyDirection to 1
global studyDirection
set studyDirection 1
 
#start_rtl

# Define fonts to be used in GUI
global arr font
set font(time)   {Helvetica 32 bold }
set font(big)  {Helvetica 16 bold }
set font(medium) {Helvetica 13 bold}
set font(small)  {Helvetica 12 }
set font(button)  {Helvetica 14 bold}

# Define initial values for variables
set calx 0
set caly 0
set disttarg 1000
set targactive 0
set m 0
set n 0
set i 0
set vecpos 0
set stablevecpos 0
#newlog
set logNumber 0

# Create vectors for perturbation randomization
# "1" corresponds to the negitive x or y, "2" to the positive
set rei {1 1 2 2 1 1 2 2}
set rdf { 1    1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2
  1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2
  1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2 
  1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2 
  1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2   1 2 1 2 1 2 1 2 1 2 
}
# set stablevector { 2 3 1 }
set stablevector { 1 2 3 4 5 }

set endpos 160
#Create frame which encloses entire GUI
frame .f2 -relief ridge -borderwidth 5

# Subject
label .f2.l_setName -text Subject   -font $font(medium) -width 6
entry .f2.e_setName -validate focusout -font $font(medium) -bd 4 -textvariable subjectName -justify center -width 8
set subjectName "JA"
set trialType "_initial"

label .f2.l_gravComp -text GravComp  -font $font(small) -width 10

# Radio Buttons for activation modes
label .f2.1_activationMode -text Activation -font $font(medium) -width 10
radiobutton .f2.chk_relaxed -text "Relaxed  " -variable activationMode -value 0 -width 8
radiobutton .f2.chk_DFactive -text "IE Active" -variable activationMode -value 1 -width 8
radiobutton .f2.chk_PFactive -text "DP Active" -variable activationMode -value 2 -width 8
radiobutton .f2.chk_cocontraction -text "DF+PF    " -variable activationMode -value 3 -width 8
radiobutton .f2.chk_stable -text "Stable     " -variable stableMode -value 0 -width 8
radiobutton .f2.chk_unstable -text "Unstable " -variable stableMode -value 1 -width 8
radiobutton .f2.chk_passive -text "Passive   " -variable stableMode -value 2 -width 8

# If trialStatus = 1, then "ACTIVE" (trials are being run)
radiobutton .f2.chk_begin -text "ACTIVE      " -variable trialStatus -value 1 -width 8
# If trialStatus = 0, then "Not Running" (trials are not being run)
radiobutton .f2.chk_notrun -text "Not Running" -variable trialStatus -value 0 -width 10

# Gravity compenstation calibration
button .f2.b1 -text "Grav Comp Calibrate" -command { set j 1 }
radiobutton .f2.chk_gravcompon -text "ON" -variable gravCompStatus -value 1 -width 8
radiobutton .f2.chk_gravcompoff -text "OFF" -variable gravCompStatus -value 0 -width 8
# Layout
grid .f2 -column 0 -row 0 -pady 4
grid .f2.l_setName -column 0 -row 0 -rowspan 2
grid .f2.e_setName -column 1 -row 0 -rowspan 2 -padx 4

grid .f2.1_activationMode -column 0 -row 2
grid .f2.chk_relaxed -column 0 -row 3
grid .f2.chk_DFactive -column 0 -row 4
grid .f2.chk_PFactive -column 0 -row 5
grid .f2.chk_cocontraction -column 0 -row 6
grid .f2.chk_stable -column 0 -row 7
grid .f2.chk_unstable -column 0 -row 8
grid .f2.chk_passive -column 0 -row 9

grid .f2.chk_begin -column 1 -row 4
grid .f2.chk_notrun -column 1 -row 3

grid .f2.l_gravComp -column 1 -row 6 -columnspan 2
grid .f2.chk_gravcompon -column 1 -row 7
grid .f2.chk_gravcompoff -column 1 -row 8
grid .f2.b1 -column 1 -row 9

# Defines file name and location for logged data
proc logsetup {name type} {
  global ob
  global logNumber
  
  set curtime [clock seconds]
  set datestamp [clock format $curtime -format "%Y%m%d"]
  
  #newlog
  #The log number appends on the name for when you have multiple log files
  set logNumber [expr {$logNumber + 1 }]
  set fn $name$logNumber$type.dat
  puts $name$logNumber$type.dat

  # Directory where the logs are to be saved
  set baselogdir /home/imt/logs/Hyunglae/AnkleReflexStudy
  set logdir [file join $baselogdir $datestamp]
  file mkdir $logdir
  set ob(logf) [file join $logdir $fn]
}

# given a center position and radius, like 100 100 10,
# ballxy returns x1 y1 x2 y2, like 90 90 110 110.
proc ballxy {x y rad} {
  set x1 [expr {$x - $rad}]
  set y1 [expr {$y - $rad}]
  set x2 [expr {$x + $rad}]
  set y2 [expr {$y + $rad}]
  list $x1 $y1 $x2 $y2
}

# calculate Euclidean distance.
proc edist {x1 y1 x2 y2} {
  expr {hypot($x1 - $x2, $y1 - $y2)}
}

# do body every ms milliseconds

proc every {ms body} {eval $body; after $ms [info level 0]}

# returns a random int between min and max-1

proc irand {min max} {
  set RAND [expr {int(rand() * ($max-$min)) + $min}]
}

# IE Study can be zoomed in
if { $studyDirection == 0 } {
  #DP Study
  set scale 2500
} elseif { $studyDirection == 1 } {
  #IE Study
  set scale 2800
}

set pi [expr {atan(1) * 4.}]
# retreives displacement data from Anklebot
# mulitibply by 5000 for scale
proc getcurxy {w} {
  global scale
  set x [rshm ankle_ie_pos]
  set y [rshm ankle_dp_pos]
  set x [expr {$x * $scale }]
  set y [expr {$y * -1 * $scale }]
  list $x $y
}

set min 100
set max 300
set RAND [expr {int(rand() * ($max-$min)) + $min}]


# binded to "q", ends all procedures
proc done {} {
  global ob
  if {[info exists ob(saverefpid)]} {
    puts "stopping wrefloop, pid $ob(saverefpid)"
    exec kill $ob(saverefpid)
  }
  
  after 100
  
  stop_movebox 0
  
  if {[info exists ob(logging)]} {
    if {$ob(logging)} {
      puts "stopping log $ob(logf)"
      stop_log
      after 100
    }
  }

  stop_loop
  stop_shm
  stop_log
  
  # give it time to exit
  after 1000
  
  puts "unloading robot kernel module"
  stop_lkm
  stop_rtl
  puts "done"
  exit
}

set ::donevar 0

proc loop {} {
  checkfault
  after 100 loop
  if {$::donevar > 0} {done}
}

proc bgerror {mes} {
  puts "\nerror: $mes"
  done
}

if {[info exists env(CROB_HOME)]} {
  set ob(crobhome) $env(CROB_HOME)
} else {
  set ob(crobhome) /home/imt/crob_ASU
}

source $ob(crobhome)/shm.tcl

cd $ob(crobhome)/tools 

set ob(nlog) 32
set ob(ankle_pt_ctl) 15
set ob(ankle_ctl_independent) 30
#set ob(ankle_ctl) 8
#set ob(reffnid) 1

puts "Loading robot kernel module..."
exec /home/imt/imt/robot4/crob_ASU/tools/acenter
after 200
set ob(calibrated) yes

start_lkm
start_shm
start_loop

wshm no_safety_check 1
after 200

if {[rshm paused]} {
  checkfault
  puts "Hit enter to exit"
  gets stdin in
  done
}

wshm logfnid 22
#wshm reffnid $ob(reffnid)

# load ankle parameters from shm.tcl
wshm ankle_stiff 300.0
wshm ankle_damp 2.0
wshm stiff 0.0
wshm damp 0.0

#wshm restart_stiff 0
#wshm restart_damp 0

#if { $i == 0 } {
#    set i [expr {$i + 1}]
# set measurement rate
# Measurement rate may be manually entered
set Hz 1000
#    puts "Set measurement rate, and hit enter."
#    gets stdin Hz
wshm restart_Hz $Hz
wshm Hz $Hz
wshm restart_go 1

puts "Please enter subject name"
gets stdin subjectName

puts "Hit enter to move ankle to neutral..."
gets stdin in

# move the ankle to neutral, until stopped.
set x [rshm ankle_ie_pos]
set y [rshm ankle_dp_pos]
movebox 0 $ob(ankle_ctl_independent) {0 $Hz 1} {$x $y 0 0} {0 0 0 0}

after 100

canvas .c -width 990 -height 990 -bg {slate gray}

grid .c -column 2 -row 0 -rowspan 10

set cursor [.c create oval [ballxy 100 100 [ expr { 0.5 * $pi / 180 * $scale } ]] -fill red]

.c config -scrollregion [list -495 -495 495 495]

if { $studyDirection == 0 } {
  #DP Study
  set targoffset 10
  set torquerange 10
} elseif { $studyDirection == 1 } {
  #IE Study
  set targoffset 7.5
  set torquerange 7.5
}

set safteywall 20
set up [expr { $pi / 2 }]
set left [expr { $pi }]
set down [expr { 3 * $pi / 2}]
set right 0

#.c create oval [ballxy $calx $caly [ expr { 1 * $pi / 180 * $scale } ]] -fill grey50 -tags cal
.c create oval [ballxy $calx $caly [ expr { 0.5 * $pi / 180 * $scale } ]] -fill grey50 -tags target
.c create line $calx 100 $calx [expr { 100 * -1 }] -width 5 -fill blue -tags cross
.c create line [expr { 100 * -1 }] $caly 100 $caly  -width 5 -fill blue -tags cross
#.c create line -50 [ expr { $torquerange * $pi / 180 * $scale } ] 50 [ expr { $torquerange * $pi / 180 * $scale } ] -width 2 -fill yellow -tags top
#.c create line -50 [ expr { $torquerange * $pi / 180 * $scale * -1 } ] 50 [ expr { $torquerange * $pi / 180 * $scale * -1 } ] -width 2 -fill yellow -tags bottom

if { $studyDirection == 0 } {
  #DP Lines
  .c create line -50 [ expr { $torquerange * $pi / 180 * $scale } ] 50 [ expr { $torquerange * $pi / 180 * $scale } ] -width 2 -fill yellow -tags top
  .c create line -50 [ expr { $torquerange * $pi / 180 * $scale * -1 } ] 50 [ expr { $torquerange * $pi / 180 * $scale * -1 } ] -width 2 -fill yellow -tags bottom
} elseif { $studyDirection == 1 } {
  #IE lines
  .c create line [ expr { $torquerange * $pi / 180 * $scale } ] -50 [ expr { $torquerange * $pi / 180 * $scale } ] 50 -width 2 -fill yellow -tags top
  .c create line [ expr { $torquerange * $pi / 180 * $scale * -1 } ] -50 [ expr { $torquerange * $pi / 180 * $scale * -1 } ] 50 -width 2 -fill yellow -tags bottom
}

set stableMode 0
set activationMode 0
set trialStatus 0
set gravCompStatus 0
logsetup $subjectName $trialType
start_log $ob(logf) $ob(nlog)
set gravity 0
set g 0
set c 0
set j 0
set stiff 0
set damp 0
set grav 0
set trialno 0
set waittime 0
set plswait 0
set pauseno 0
set trialtime 0
set e 0
set d 0
set b 0
set q 1
set calcycle 0
set targx $calx
set targy $caly
set rest 750
set bz 0
set t 40
set vel 0
set accel 0
set bh 2
set k 0.5
set v5 0
set v4 0
set v3 0
set v2 0
set v1 0
set t5 0
set t4 0
set t3 0
set t2 0
set t1 0

if { $studyDirection == 0 } {
  #DP Study
  set b_UB 2.0
  set b_LB -1.0
} elseif { $studyDirection == 1 } {
  #IE Study
  set b_UB 1.0
  set b_LB -0.5
}

# Variables initialized for the variable damping tuning
set maxVal -999999899; set minVal 999999899; set maxTime 0; set maxTime 0;

every 10 {
  set ob(ankle_ctl_independent) 30
}