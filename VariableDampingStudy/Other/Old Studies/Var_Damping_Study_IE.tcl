#!  /usr/bin/wish

package require Tk

source /home/imt/imt/robot4/crob_ASU/shm.tcl

global ob

bind . <Key-q> done

#start_rtl

# Define fonts to be used in GUI
global arr font
set font(time)	 {Helvetica 32 bold }
set font(big)	 {Helvetica 16 bold }
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
# Create vectors for perturbation randomization
# "1" corresponds to the negitive x or y, "2" to the positive
set rei {1 1 2 2 1 1 2 2}
set rdf { 1    1 2 1 2 1 2 1 2 1 2 1 2 1 2 1 2 1 2 1 2  1 2 1 2 1 2 1 2 1 2 1 2 1 2 1 2 1 2 1 2
}
set stablevector { 2 3 1
}

set endpos 160
#Create frame which encloses entire GUI
frame .f2 -relief ridge -borderwidth 5

# Subject
label .f2.l_setName -text Subject   -font $font(medium) -width 6
entry .f2.e_setName -validate focusout -font $font(medium) -bd 4 -textvariable subjectName -justify center -width 8
set subjectName "JA"

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

radiobutton .f2.chk_begin -text "ACTIVE      " -variable trialStatus -value 1 -width 8
radiobutton .f2.chk_notrun -text "Not Running" -variable trialStatus -value 0 -width 10

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
# defines file name and location for logged data
proc logsetup {name} {
  global ob
  
  set curtime [clock seconds]
  set datestamp [clock format $curtime -format "%Y%m%d"]
  
  set fn $name.dat
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
set scale 2300
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

# called when cursor is completly within the "callibration" oval
# for a continuous 3 second time interval.
# defines the target zone to prime muscles prior to perturbation.
proc ballenter {w} {
  puts " Hello "
  global scale
  global pi
  global rdf
  global rei
  global vecpos
  global targx
  global targy
  global activationMode
  global calx
  global caly
  global x
  global y
  # Target offsets may be added here.
  set x1 [expr { $calx + [ expr { 7 * $pi / 180 * $scale } ] }]
  set x2 [expr { $calx - [ expr { 7 * $pi / 180 * $scale } ] }]
  set y1 [expr { $caly + [ expr { 7 * $pi / 180 * $scale } ] }]
  set y2 [expr { $caly - [ expr { 7 * $pi / 180 * $scale } ] }]
  if { $activationMode == 1} {
    puts [lindex $rdf $vecpos]
    puts $vecpos
    if { [lindex $rdf $vecpos] == 1} {
      .c itemconfigure target -fill green
      .c coords target [ballxy $x1 $caly [ expr { 1 * $pi / 180 * $scale } ]]
      set targx $x1
      set targy $caly
    } elseif { [lindex $rdf $vecpos] == 2} {
      .c itemconfigure target -fill green
      .c coords target [ballxy $x2 $caly [ expr { 1 * $pi / 180 * $scale } ]]
      set targx $x2
      set targy $caly
    }
  } elseif { $activationMode == 2} {
    if { [lindex $rei $vecpos] == 1} {
      .c itemconfigure target -fill green
      .c coords target [ballxy $calx $y1 [ expr { 1 * $pi / 180 * $scale } ]]
      set targx $calx
      set targy $y1
    } elseif { [lindex $rei $vecpos] == 2} {
      .c itemconfigure target -fill green
      .c coords target [ballxy $calx $y2 [ expr { 1 * $pi / 180 * $scale } ]]
      set targx $calx
      set targy $y2
    }
  }
  
}
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

set ob(nlog) 27
set ob(ankle_pt_ctl) 15
set ob(ankle_ctl_independent) 30
#set ob(ankle_ctl) 8
#set ob(reffnid) 1

puts "loading robot kernel module"
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
  puts "hit enter to exit"
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

#}

# make a canvas within original frame and create a cursor

canvas .c -width 990 -height 990 -bg gray50

grid .c -column 2 -row 0 -rowspan 10

set cursor [.c create oval [ballxy 100 100 [ expr { 0.5 * $pi / 180 * $scale } ]] -fill red]

.c config -scrollregion [list -495 -495 495 495]
set targoffset 5
set torquerange 7
set safteywall 20
set up [expr { $pi / 2 }]
set left [expr { $pi }]
set down [expr { 3 * $pi / 2}]
set right 0

#.c create oval [ballxy $calx $caly [ expr { 1 * $pi / 180 * $scale } ]] -fill grey50 -tags cal
.c create oval [ballxy $calx $caly [ expr { 0.5 * $pi / 180 * $scale } ]] -fill grey50 -tags target
.c create line $calx 100 $calx [expr { 100 * -1 }] -width 5 -fill blue -tags cross
.c create line [expr { 100 * -1 }] $caly 100 $caly  -width 5 -fill blue -tags cross
.c create line -50 [ expr { $torquerange * $pi / 180 * $scale } ] 50 [ expr { $torquerange * $pi / 180 * $scale } ] -width 2 -fill yellow -tags top
.c create line -50 [ expr { $torquerange * $pi / 180 * $scale * -1 } ] 50 [ expr { $torquerange * $pi / 180 * $scale * -1 } ] -width 2 -fill yellow -tags bottom
.c create line -75 [ expr { $safteywall * $pi / 180 * $scale } ] 75 [ expr { $safteywall * $pi / 180 * $scale } ] -width 3 -fill red -tags top
.c create line -75 [ expr { $safteywall * $pi / 180 * $scale * -1 } ] 75 [ expr { $safteywall * $pi / 180 * $scale * -1 } ] -width 3 -fill red -tags top

set stableMode 0
set activationMode 0
set trialStatus 0
set gravCompStatus 0
logsetup $subjectName
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
set bh 1.0
set k 1
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
# called 100x per second.
every 10 {
  global v5
  global v4
  global v3
  global v2
  global v1
  global t5
  global t4
  global t3
  global t2
  global t1
  global bh
  global k
  global vel
  global accel
  global t
  global bz
  global rest
  global q
  global damp
  global calcycle
  global b
  global safteywall
  global e
  global d
  global trialtime
  global pauseno
  global scale
  global torquerange
  global plswait
  global waittime
  global trialno
  global grav
  global endpos
  global stablevector
  global stablevecpos
  global stiff
  global gravity
  global q1
  global q2
  global q3
  global q3
  global q4
  global q5
  global j
  global gravCompStatus
  global c
  global trialStatus
  global pi
  global g
  global up
  global down
  global left
  global right
  global x
  global y
  global RAND
  global min
  global max
  global Hz
  global ob
  global rdf
  global rei
  global vecpos
  global stableMode
  global targactive
  global targx
  global targy
  global disttarg
  global m
  global n
  global activationMode
  global calx
  global caly
  global targoffset
  wshm butcutoff 5
  #    puts "[rshm butcutoff]"
  set x1 [expr { $calx + [ expr { $targoffset * $pi / 180 * $scale } ] }]
  set x2 [expr { $calx - [ expr { $targoffset * $pi / 180 * $scale } ] }]
  set y1 [expr { $caly + [ expr { $targoffset * $pi / 180 * $scale } ] }]
  set y2 [expr { $caly - [ expr { $targoffset * $pi / 180 * $scale } ] }]
  set perturb 0
  set targactive 1
  wshm ankle_perturb_DP $perturb
  
  if { $c == 0 } {
    if { $trialStatus == 1 } {
      set stableMode 1
      set activationMode 2
    }
  } else { }
  
  if { $j == 1 } {
    #	puts "GRAVITY COMPENSATION"
    #	puts "RELAX ANKLE COMPLETLY"
    .c itemconfigure cross -fill black
    wshm ankle_stiff_DP 200
    wshm ankle_stiff_IE 400.0
    wshm ankle_damp_DP 0.0
    wshm ankle_damp_IE 1.0
    set g [ expr { $g +1 } ]
  } else {
    .c itemconfigure cross -fill blue
  }
  
  if { $g == 100 } {
    set q1 [rshm ankle_dp_torque]
  } elseif { $g == 200 } {
    set q2 [rshm ankle_dp_torque]
  } elseif { $g == 300 } {
    set q3 [rshm ankle_dp_torque]
  } elseif { $g == 400 } {
    set q4 [rshm ankle_dp_torque]
  } elseif { $g == 500 } {
    global grav
    set q5 [rshm ankle_dp_torque]
    set j 2
    set gravity [ expr { ( $q1 + $q2 + $q3 + $q4 + $q5 ) / 5 } ]
    set grav $gravity
    set gravCompStatus 1
    
  }
  if { $bz == 0} {
    if { $stableMode == 0 } {
      # get mouse cursor position
      foreach {x y} [getcurxy .c] break
      # Scale the motion of the curor on the screen to the motion of ankle
      set x $x
      set y $y
      # load ankle parameters from shm.tcl for stable env.
      
      if { $activationMode == 1 } {
        wshm ankle_gravityTorque $gravity
        wshm ankle_stiff_DP 400
        wshm ankle_stiff_IE 200.0
        wshm ankle_damp_DP 1.0
        wshm ankle_damp_IE 1.0
      } elseif { $activationMode == 2 } {
        wshm ankle_gravityTorque $gravity
        wshm ankle_stiff_DP 200
        wshm ankle_stiff_IE 400.0
        wshm ankle_damp_DP 1.0
        wshm ankle_damp_IE 1.0
      } else {
        
        wshm ankle_gravityTorque $gravity
        wshm ankle_stiff_DP 200
        wshm ankle_stiff_IE 200.0
        wshm ankle_damp_DP 1.0
        wshm ankle_damp_IE 1.0
      }
      
    } elseif { $stableMode == 1 } {
      global x
      global y
      global stiff
      global damp
      # get mouse cursor position
      foreach {x y} [getcurxy .c] break
      # load ankle parameters from shm.tcl for unstable env.
      #	set damp [lindex $stablevector $stablevecpos]
      
      
      
      set vel [rshm ankle_ie_fvel]
      set v5 $v4
      set v4 $v3
      set v3 $v2
      set v2 $v1
      set v1 $vel
      
      set timesincestart [ expr { [rshm time_ms_since_start] } ]
      #	set timesincestart [ expr { $timesincestart / 100 }]
      set t5 $t4
      set t4 $t3
      set t3 $t2
      set t2 $t1
      set t1 $timesincestart
      set accel [expr { ($v1 - $v5)*1000 / ($t1 - $t5) } ]
      
      #	set vel [rshm ankle_dp_vel]
      
      #	set accel [rshm ankle_dp_accel]
      
      
      
      set number [lindex $stablevector $stablevecpos]
      if { $number == 1 } {
        set damp -0.25
      } elseif { $number == 2 } {
        set damp [ expr { ( $bh * (-1) ) / (1 + exp( (-1) * $k *$vel * $accel) ) + 0.75 } ]
      } elseif { $number == 3 } {
        set damp 0.75
      }
      
      
      
      if { $activationMode == 1 } {
        wshm ankle_stiff_DP 400.0
        wshm ankle_stiff_IE 0.0
        wshm ankle_damp_DP 1.0
        wshm ankle_damp_IE 1.0
      } elseif { $activationMode == 2 } {
        if { $stiff == 0 } {
        }
        
        set min [ expr { $torquerange * $pi / 180 } ]
        set max [ expr { $torquerange * $pi * -1 / 180 } ]
        set TDP [ expr { $y / $scale } ]
        if { $TDP > [ expr { -15 * $pi / 180 } ] } {
          if { $TDP < [ expr { 15 * $pi / 180 } ] } {
            if { $TDP < $max } {
              wshm ankle_stiff_DP 400
              wshm ankle_gravityTorque [ expr { $max * $stiff + $gravity } ]
              wshm ankle_damp_DP 1.0
              wshm ankle_stiff_DP 0.0
              wshm ankle_damp_IE $damp
            } elseif { $TDP > $min } {
              wshm ankle_stiff_DP 400
              wshm ankle_gravityTorque [ expr { $min * $stiff + $gravity } ]
              wshm ankle_damp_DP 1.0
              wshm ankle_stiff_DP 0.0
              wshm ankle_damp_IE $damp
            } else {
              if { $gravCompStatus == 1 } {
                wshm ankle_gravityTorque $gravity
                wshm ankle_stiff_DP 400.0
                wshm ankle_stiff_IE 00.0
                wshm ankle_damp_DP 1.0
                wshm ankle_damp_IE $damp
              } elseif { $gravCompStatus == 0 } {
                wshm ankle_gravityTorque 0
                wshm ankle_stiff_DP 400.0
                wshm ankle_stiff_IE 00.0
                wshm ankle_damp_DP 1.0
                wshm ankle_damp_IE $damp
              }}
          }}
        #	    wshm ankle_stiff_DP $stiff
        #	    wshm ankle_stiff_IE 400.0
        #	    wshm ankle_damp_DP 0.0
        #	    wshm ankle_damp_IE 1.0
      } else {
        wshm ankle_stiff_DP $stiff
        wshm ankle_stiff_IE $stiff
        wshm ankle_damp_DP 1.0
        wshm ankle_damp_IE 1.0
      }
    } elseif { $stableMode == 2 } {
      # get mouse cursor position
      foreach {x y} [getcurxy .c] break
      # load ankle parameters from shm.tcl for passive env.
      
      if { $activationMode == 1 } {
        wshm ankle_stiff_DP 400.0
        wshm ankle_stiff_IE 0.0
        wshm ankle_damp_DP 0.0
        wshm ankle_damp_IE 0.0
      } elseif { $activationMode == 2 } {
        wshm ankle_stiff_DP 0.0
        wshm ankle_stiff_IE 400.0
        wshm ankle_damp_DP 0.0
        wshm ankle_damp_IE 0.0
      } else {
        wshm ankle_stiff_DP 400.0
        wshm ankle_stiff_IE 0.0
        wshm ankle_damp_DP 0.0
        wshm ankle_damp_IE 0.0
      }
    }
  } else {
    wshm ankle_stiff_DP 400.0
    wshm ankle_stiff_IE 00.0
    wshm ankle_damp_DP 0.0
    wshm ankle_damp_IE 0.0
  }
  
  if { $t < 30 } {
    #        .c coords $::cursor [ballxy $calx $caly [ expr { 0.5 * $pi / 180 * $scale } ]]
    .c create text [ expr { 5 * $pi / 180 * $scale } ] [ expr { -5 * $pi / 180 * $scale } ] -text "GO" -font [list Courier 100] -tags go
    bell
    .c raise $::cursor
    set t [ expr { $t + 1 } ]
  } else {
    if { $activationMode == 2 } {
      global x
      global y
      # move yellow cursor ball to match it.
      set x [rshm ankle_ie_pos]
      set x [expr { $x * $scale }]
      .c coords $::cursor [ballxy $x $caly [ expr { 0.5 * $pi / 180 * $scale } ]]
      .c raise $::cursor
      set distcal [edist $x $caly $calx $caly]
    } elseif { $activationMode == 1 } {
      global x
      global y
      # move yellow cursor ball to match it.
      .c coords $::cursor [ballxy $calx $y [ expr { 0.5 * $pi / 180 * $scale } ]]
      .c raise $::cursor
      set distcal [edist $calx $y $calx $caly]
    } else {
      global x
      global y
      # move yellow cursor ball to match it.
      .c coords $::cursor [ballxy $x $y [ expr { 0.5 * $pi / 180 * $scale } ]]
      .c raise $::cursor
      #	set distcal [edist $x $y $calx $caly]
      set distcal 100
    }
  }
  
  
  if { $x > [ expr { $scale * $safteywall * $pi / 180 } ] } {
    
    wshm ankle_stiff_DP 400.0
    wshm ankle_stiff_IE 0.0
    wshm ankle_damp_DP 1.0
    wshm ankle_damp_IE 10.0
    
  } elseif { $x < -[ expr { $scale * $safteywall * $pi / 180 } ] } {
    
    wshm ankle_stiff_DP 400.0
    wshm ankle_stiff_IE 0.0
    wshm ankle_damp_DP 1.0
    wshm ankle_damp_IE 10.0
    
  } elseif { $y > [ expr { $scale * $safteywall * $pi / 180 } ] } {
    
    wshm ankle_stiff_DP 0.0
    wshm ankle_stiff_IE 400.0
    wshm ankle_damp_DP 20.0
    wshm ankle_damp_IE 1.0
    
  } elseif { $y < -[ expr { $scale * $safteywall * $pi / 180 } ] } {
    
    wshm ankle_stiff_DP 0.0
    wshm ankle_stiff_IE 400.0
    wshm ankle_damp_DP 20.0
    wshm ankle_damp_IE 1.0
    
  }
  
  if { $trialStatus == 1 } {
    set trialtime [ expr { $trialtime + 1 } ]
    if { $trialtime == 1000 } {
      set waittime 1
      set plswait 499
      set perturb 20
      wshm ankle_perturb_DP $perturb
      
      
    }}
  if { $vecpos < 8 } {
    set pause 6
  } else {
    set pause [ expr { 6 + $pauseno * 14 } ]
  }
  
  if {$disttarg < [ expr { 0.5 * $pi / 180 * $scale } ]} {
    set m [expr {$m + 1}]
    .c delete go
    #Inside of the target
    .c itemconfigure target -width 4.0
  } elseif {$disttarg > [ expr { 0.5 * $pi / 180 * $scale } ]} {
    set m 0
    .c itemconfigure target -width 1.0
  }
  
  if { $targactive == 1 } {
    if { $activationMode == 2 } {
      set disttarg [edist $x $caly $targx $targy]
    } elseif { $activationMode == 2 } {
      set y [rshm ankle_dp_pos]
      set y [expr { $y * -1 * $scale } ]
      set disttarg [edist $calx $y $targx $targy]
    }
  }
  if {$disttarg < [ expr { 0.5 * $pi / 180 * $scale } ]} {
    set n [expr {$n + 1}]
    set trialtime [ expr { $trialtime - 1 } ]
  } elseif {$disttarg > [ expr { 0.5 * $pi / 180 * $scale } ]} {
    set n 0
  }
  
  if { $n > $RAND } {
    set perturb 10
    set bz 1
    if { $q < $rest } {
      .c itemconfigure target -fill green
      .c coords target [ballxy $calx $caly [ expr { 1 * $pi / 180 * $scale } ]]
      set targx $calx
      set targy $caly
      set damp 0
      set disttarg [edist $calx $y $calx $caly]
      if {$disttarg < [ expr { 0.5 * $pi / 180 * $scale } ]} {
        set q [expr {$q + 1}]
      } elseif {$disttarg > [ expr { 0.5 * $pi / 180 * $scale } ]} {
        set q 250
      }
    } else {
      #########################################TARGET MOVE##############################################
      set perturb 10
      wshm ankle_perturb_DP $perturb
      set trialno [ expr { $trialno + 1 }]
      if { $vecpos < 40 } {
        set vecpos [expr { $vecpos + 1 }]
      } elseif { $vecpos == 40 } {
        set vecpos 1
        set stablevecpos [ expr { $stablevecpos +1 }]
      }
      puts "Trial $trialno of 121 complete"
      #	puts $vecpos
      #	puts $stablevecpos
      if { $trialno == 61 } {
        puts "Trial $trialno of 121 complete"
        puts "Rest for 5 minutes."
        wshm ankle_stiff_IE 200.0
        wshm ankle_gravityTorque $gravity
        set perturb 0
        wshm ankle_perturb_DP $perturb
        puts "Press ENTER to continue."
        gets stdin in
        set perturb 10
        wshm ankle_perturb_DP $perturb
      }
      if { $trialno == 31 } {
        puts "Trial $trialno of 121 complete"
        puts "Rest for 5 minutes."
        wshm ankle_stiff_IE 200.0
        wshm ankle_gravityTorque $gravity
        set perturb 0
        wshm ankle_perturb_DP $perturb
        puts "Press ENTER to continue."
        gets stdin in
        set perturb 10
        wshm ankle_perturb_DP $perturb
      }
      if { $trialno == 91 } {
        puts "Trial $trialno of 121 complete"
        puts "Rest for 5 minutes."
        wshm ankle_stiff_IE 200.0
        wshm ankle_gravityTorque $gravity
        set perturb 0
        wshm ankle_perturb_DP $perturb
        puts "Press ENTER to continue."
        gets stdin in
        set perturb 10
        wshm ankle_perturb_DP $perturb
      }
      if { $trialno == 121 } {
        set perturb 0
        wshm ankle_perturb_DP $perturb
        puts "End of Trials"
        wshm ankle_stiff_DP 50.0
        wshm ankle_stiff_IE 50.0
        wshm ankle_damp_DP 5.0
        wshm ankle_damp_IE 5.0
        puts "Hit enter to exit."
        gets stdin in
        done
      }
      
      
      set t 1
      
      
      
      if { $activationMode == 2} {
        puts [lindex $rdf $vecpos]
        set randvar [lindex $rdf $vecpos]
        puts $vecpos
        if { [lindex $rdf $vecpos] == 1} {
          .c itemconfigure target -fill green
          .c coords target [ballxy $x1 $caly [ expr { 1 * $pi / 180 * $scale } ]]
          set targx $x1
          set targy $caly
          puts $x1
        } elseif { $randvar == 2} {
          .c itemconfigure target -fill green
          .c coords target [ballxy $x2 $caly [ expr { 1 * $pi / 180 * $scale } ]]
          set targx $x2
          set targy $caly
          puts $x2
        }
      } elseif { $activationMode == 1} {
        if { [lindex $rdf $vecpos] == 1} {
          .c itemconfigure target -fill green
          .c coords target [ballxy $calx $y1 [ expr { 1 * $pi / 180 * $scale } ]]
          set targx $calx
          set targy $y1
        } elseif { [lindex $rdf $vecpos] == 2} {
          .c itemconfigure target -fill green
          .c coords target [ballxy $calx $y2 [ expr { 1 * $pi / 180 * $scale } ]]
          set targx $calx
          set targy $y2
        }
      }
      set targactive 1
      
      wshm ankle_stiff_DP 400.00
      wshm ankle_stiff_IE 00.0
      wshm ankle_damp_DP 1.0
      wshm ankle_damp_IE 0.0
      
      #	.c create oval [ballxy $calx $caly 30] -fill red
      .c itemconfigure target -fill green
      set waittime [ expr { $waittime + 1 } ]
      
      set RAND 100
      set n 0
      set q 1
      set bz 0
      set trialtime 0
      set rest [ expr { 500 + [ irand 1 500 ] } ]
    }
  }
  set ob(ankle_ctl_independent) 30
}

