## Controller.tcl
# Created by James Arnold

package require Tk
source /home/imt/imt/robot4/crob_ASU/shm.tcl
global ob
bind . <Key-q> done

# ---------------Study Specifications------------------

# Either DP or IE
set studyType "DP"

# Damping environments and the number of blocks for each (place in order)
set dampingEnvironments [list {zero 1} {tuning 2} {variable 1} {negative 1} {positive 1}]
# Number of trials in a block, should be even in order to ensure equal number of trials in both directions
set trialsPerBlock 4
# Damping values
set negativeDamping -1.0
set positiveDamping 2.0
set variableDampingRange [list $negativeDamping $positiveDamping]

# Initialized list of every damping enviorment in order
set everyBlockEnvironment {}

# Creates a list of every damping enviorment in order
foreach x $dampingEnvironments {
    set blockType [lindex $x 0 ]
    set numberOfBlocks [lindex $x 1 ]

    for {set index 1} {$index <= $numberOfBlocks} {incr index} {
        lappend everyBlockEnvironment $blockType
    }
}

# Number of groupings of trials with breaks in-between
set blocks [llength $everyBlockEnvironment]

# Calculate the total number of trials
set totalTrials [expr $blocks*$trialsPerBlock]

# -------------------Constants------------------------

set pi [expr {atan(1) * 4.}]

# --------------Initialized Variables-----------------

set logNumber 0
set subjectName "name"
set calculatingK 0
set enablingVariableDamping 0

# -------------------Functions------------------------

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

# Gets the current position of the ankle in degrees from neutral position
proc getRobotPosition {w} {
    global pi
    set x [rshm ankle_ie_pos]
    set y [rshm ankle_dp_pos]
    set x [expr {$x * 180 / $pi }]
    set y [expr {$y * 180 / $pi }]
    return [list $x $y]
}

# Ends all procedures (binded to "q")
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
  puts "Unloading robot kernel module..."
  stop_lkm
  stop_rtl
  puts "Exit"
  exit
}

set ::donevar 0

# Defines file name and location for logged data
proc logSetup {name type} {
  	global ob
  	global logNumber
  
  	set curtime [clock seconds]
  	set datestamp [clock format $curtime -format "%Y%m%d"]
  
  	#newlog
  	#The log number appends on the name for when you have multiple log files
  	set logNumber [expr {$logNumber + 1 }]
  	set fn $name$logNumber$type.dat

  	#Removes all spaces
  	set fn [string map {" " ""} $fn]
	 puts $fn

 	# Directory where the logs are to be saved
  	set baselogdir /home/imt/logs/Hyunglae/AnkleReflexStudy
  	set logdir [file join $baselogdir $datestamp]
  	file mkdir $logdir
  	set ob(logf) [file join $logdir $fn]
}

# Do every ms milliseconds
proc every {ms body} {
  eval $body 
  after $ms [info level 0]
}

# -------------------Robot Setup------------------------

if {[info exists env(CROB_HOME)]} {
  set ob(crobhome) $env(CROB_HOME)
} else {
  set ob(crobhome) /home/imt/crob_ASU
}

source $ob(crobhome)/shm.tcl
cd $ob(crobhome)/tools 

# Columns in the .dat file (found in an_ulog.c)
set ob(nlog) 24

# Specifies the controller being used
set ob(ankle_pt_ctl) 15
set ob(ankle_ctl_independent) 30

# Calibrate the robot
puts "Loading robot kernel module..."
exec /home/imt/imt/robot4/crob_ASU/tools/acenter
after 200
set ob(calibrated) yes

# Start the robot
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

# Load ankle parameters from shm.tcl (this might not be needed)
wshm ankle_stiff 300.0
wshm ankle_damp 2.0
wshm stiff 0.0
wshm damp 0.0

# Set the stiffness and damping in preparation for gravity compensation
wshm ankle_stiff_DP 200
wshm ankle_stiff_IE 400.0
wshm ankle_damp_DP 0.0
wshm ankle_damp_IE 1.0

# Measurement rate
set Hz 1000

wshm restart_Hz $Hz
wshm Hz $Hz
wshm restart_go 1

puts "Please enter subject name"
gets stdin subjectName

puts "Hit enter to move ankle to neutral..."
gets stdin in

# Find the current position of the ankle
set x [rshm ankle_ie_pos]
set y [rshm ankle_dp_pos]

# Without the following line, none of the stiffness values are set
movebox 0 $ob(ankle_ctl_independent) {0 $Hz 1} {$x $y 0 0} {0 0 0 0}
after 100

# -------------------Other Functions------------------------
# Gravity compensation
proc gravityComp {} {
  global gravity

  # How many data points to collect for gravity compensation
  set numberOfGravityMeasurements 5

  # Create a list of all of the gravity measurements
  for {set index 1} {$index <= $numberOfGravityMeasurements} {incr index} {
    lappend gravity [rshm ankle_dp_torque]
    after 100
  }

  # Calculate the average gravity
  proc lavg L {expr ([join $L +])/[llength $L].}
  set avgGravity [lavg $gravity]

  # Control the robot to adjust for the force of gravity
  wshm ankle_gravityTorque $avgGravity
  puts "Gravity compensation complete"
}

# Used at the start of the trials to limit the subjects motion to the plane of interest
proc applyStiffness {} {
	global studyType
  	if {$studyType == "DP"} {
  		wshm ankle_stiff_DP 0.0
  		wshm ankle_stiff_IE 400.0
      puts "Stiffness applied"
  	} elseif {$studyType == "IE"} {
  		wshm ankle_stiff_DP 400.0
  		wshm ankle_stiff_IE 0.0
      puts "Stiffness applied"
	}
}

# Start trials
proc startTrials {} {
	global subjectName
	global ob
	global everyBlockEnvironment

  puts "Start of trials"
  applyStiffness
  setDampingEnvironment 1

  # Creates a log file with a name in the form: name_damping.dat
  logSetup $subjectName [join [list "_" [lindex $everyBlockEnvironment 0]]]
	start_log $ob(logf) $ob(nlog)
}

# Apply the correct amount of damping based on the block number
proc endBlock {currentBlock} {
  global blocks
	global studyType
	global subjectName
	global everyBlockEnvironment
	global ob
  global calculatingK
  global enablingVariableDamping
  global kMatrix
  global selectedK

	puts "End of block $currentBlock"

  if {$calculatingK == 1} {
    # Calculate the average gravity
    proc lavg L {expr ([join $L +])/[llength $L].}
    set selectedK [lavg $kMatrix]
    puts "Here is the selected K from the previous block:"
    puts $selectedK
    #Reset kMatrix for next average
    set kMatrix { }

  }

	 stop_log
   puts "Log Stopped"

    # Stop the clauses in the control loop that are calculating K and performing variable damping, if enabled
    set calculatingK 0
    set enablingVariableDamping 0

	# Called after the last block is completed
    if {$currentBlock == $blocks} {
    	endTrials
    } else {
		puts "Take a 1 minute break"

    # Prevent the subject from moving from the neutral position during the break
		if {$studyType == "DP"} {
      wshm ankle_stiff_DP 200.0
    } elseif {$studyType == "IE"} {
      wshm ankle_stiff_IE 200.0
    }

    # Pause the study until enter is pressed
    puts "Press ENTER to continue"
    gets stdin in
    	
    # Remove the appropriate stiffness to continue the trials
    applyStiffness

    # Apply the appropriate damping based on the current block
    setDampingEnvironment [expr $currentBlock + 1]
    puts $currentBlock

    logSetup $subjectName [join [list "_" [lindex $everyBlockEnvironment $currentBlock]]]
		start_log $ob(logf) $ob(nlog)
    }
}

proc endTrial {currentTrial} {
  global totalTrials
  global everyBlockEnvironment
  global currentBlock
  global calculatingK
  global graphMatrix
  global maxMinPoints
  global maxVal
  global b_LB
  global b_UB
  global kMatrix
  global va_max
  global variableDampingRange

  # Find the current damping enviornment
  set currentDampingEnvironment [lindex $everyBlockEnvironment [expr $currentBlock - 1]]

  # Output the current trial and its damping enviornment
  puts "Trial $currentTrial of $totalTrials complete ($currentDampingEnvironment damping)" 

  # Determine whether or not k needs to be calculated
  if {$calculatingK == 1} {
    puts "Calculating K from the previous trial"
    # Graph the extrema values as red points on the graph
    foo data d1 -colour red -points 1 -lines 0 -coords $maxMinPoints
    # Graph the velocity times acceleration data as a line on the graph
    foo data d2 -colour blue -points 0 -lines 1 -coords $graphMatrix

    # Finds the parameters for finding k
    set r 0.95
    set va_max $maxVal
    set b_UB [lindex $variableDampingRange 1]
    set b_LB [lindex $variableDampingRange 0]

    # Calculation of k
    set new_k [expr {-log((1-$r)*$b_LB/ ($r*$b_LB - $b_UB)) / $va_max}]
    
    # Create a matrix of all of k values for the block
    lappend kMatrix $new_k
    puts "Here is the new k matrix:"
    puts $kMatrix
  }
}

proc setDampingEnvironment {currentBlock} {
	global everyBlockEnvironment
  global positiveDamping
  global negativeDamping
  global calculatingK
  global enablingVariableDamping

	puts "Start of block $currentBlock"

  # Since everyBlockEnvironment is 0 indexed, need to subtract 1
	set currentDampingEnvironment [lindex $everyBlockEnvironment [expr $currentBlock - 1]]
  puts "Damping environment: $currentDampingEnvironment damping"

  # Apply the appropriate damping based on the current damping environment
  if {$currentDampingEnvironment == "zero"} {
    applyDamping 0
    set calculatingK 1

  } elseif {$currentDampingEnvironment == "tuning"} {
    set calculatingK 1
    set enablingVariableDamping 1

  } elseif {$currentDampingEnvironment == "variable"} {
    set enablingVariableDamping 1

  } elseif {$currentDampingEnvironment == "negative"} {
    applyDamping $negativeDamping

  } elseif {$currentDampingEnvironment == "positive"} {
    applyDamping $positiveDamping

  } else {
    puts "Error: $currentDampingEnvironment is not a known damping environment."
  }

}

proc applyDamping {damping} {
  global studyType
  #puts "Damping of $damping Nms/rad"
  if {$studyType == "DP"} {
    # Apply the input constant damping
    wshm ankle_damp_DP $damping
    # Apply positive daming to the direction opposite of movement
    wshm ankle_damp_IE 1.0
  } elseif {$studyType == "IE"} {
    # Apply positive daming to the direction opposite of movement
    wshm ankle_damp_DP 1.0
    # Apply the input constant damping
    wshm ankle_damp_IE $damping
  }
}

# End of trials
proc endTrials {} {
	puts "End of trials"
    wshm ankle_stiff_DP 50.0
    wshm ankle_stiff_IE 50.0
    wshm ankle_damp_DP 5.0
    wshm ankle_damp_IE 5.0
    puts "Press ENTER to exit"
    gets stdin in
    done
}

# Return to neutral
proc neutralReturn {} {
  global ob
  global Hz
  puts "Return to neutral"
  # Find the current position of the ankle
  set x [rshm ankle_ie_pos]
  set y [rshm ankle_dp_pos]

  # Move the ankle to the neutral position
  movebox 0 $ob(ankle_ctl_independent) {0 $Hz 1} {$x $y 0 0} {0 0 0 0}
  puts "Start move"
  after 1000
  puts "Complete"
}

# Send a signal to the log file that represents the start of a trial (target at a distance has appeared)
proc sendTargetDistanceSignal {targetDistance} {
  wshm ankle_target_Distance $targetDistance
}


# ----------------------Loop----------------------

# Variables initialized for the variable damping tuning
set maxVal -999999899 
set minVal 999999899 
set maxTime 0
set minTime 0

# Main loop used for calculating k and for applying variable damping
every 10 {
  global calculatingK
  global enablingVariableDamping
  global variableDampingRange
  global studyType
  global xtime
  global graphMatrix
  global vtimesaMatrix
  global maxVal
  global minVal
  global maxTime
  global minTime
  global new_k
  global kMatrix
  global avg_k
  global maxMinPoints
  global b_UB
  global b_LB
  global selectedK

  # When k is being calculated OR variable damping is enabled, need to find vel and accel
  if {$calculatingK == 1 || $enablingVariableDamping == 1} {
    #puts "calculating vel and accel"
    # Find the current filtered velocity and acceleration
    if {$studyType == "DP"} {
      set vel [rshm ankle_dp_fvel]
      set accel [rshm ankle_dp_faccel]
    } elseif {$studyType == "IE"} {
      set vel [rshm ankle_ie_fvel]
      set accel [rshm ankle_ie_faccel]
    }
  }

  # Runs during blocks when it is desired that K be calculated
  if {$calculatingK == 1} {
    # If the target is set at the neutral position, do not need to collect data to calculate k
    # Data not being used for calculation of K
    if {[rshm ankle_target_Distance] == 0 } {
      #puts "Current data not being used for calculation of k"

      # Calculate the extrema values of filtered velocity times filtered acceleration
      #puts "Here is the max v*a value:"
      #puts $maxVal
      #puts "Here is the min v*a value:"
      #puts $minVal

      # Reset variables for the variable damping tuning for new calulation of k
      set xtime -1
      set graphMatrix { }
      set vtimesaMatrix { }
      set maxVal -999999899 
      set minVal 999999899 
      set maxTime 0

    # If the target is set at a distance, this is the data being used to calculat k
    # Data is being used for calculation of K
    } else {
      #puts "k is being calculated from the current data"

      # Each time step, calculate filtered velocity times filtered acceleration
      set vtimesa [ expr {$vel * $accel} ]
      #puts $vtimesa

      set xtime [ expr {$xtime + 1} ]
      lappend graphMatrix $xtime
      lappend graphMatrix $vtimesa
      lappend vtimesaMatrix $vtimesa

      # Finding the max v times a
      if { $maxVal < $vtimesa } {
        set maxVal $vtimesa
        set maxTime $xtime
      }

      # Finding the min v times a
      if { $minVal > $vtimesa } {
        set minVal $vtimesa
        set minTime $xtime
      }

      # Maximum and minimum points to show on the graph
      set maxMinPoints [ list $maxTime $maxVal $minTime $minVal]

    }
  }

  # Runs during blocks when it is desired that variable damping be applied
  if {$enablingVariableDamping == 1} {
    #puts "Variable damping is being applied"
    # Find the damping range
    set b_UB [lindex $variableDampingRange 1]
    set b_LB [lindex $variableDampingRange 0]

    #puts "vel: $vel rad/s"
    #puts "accel: $accel rad^2/s"
    #puts "constantK: $constantK"

    # Send the selected variable damping k to the log
    wshm ankle_varDamp_K $selectedK
    set damping [ expr { ( $b_UB - $b_LB ) * (-1) / (1 + exp( (-1) * $selectedK *$vel * $accel) ) + $b_UB } ]
    applyDamping $damping
  }
}