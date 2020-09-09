## Controller2D.tcl
# Created by James Arnold

package require Tk
source /home/imt/imt/robot4/crob_ASU/shm.tcl
global ob
bind . <Key-q> done

# ---------------Study Specifications------------------

# Used for testing purposes
set suppressTuning 1

# Either DP, IE, or 2D
# Initially set to IE since block 1 is set to be a tuning trial in the IE direction
set targetOrientation "IE"

if {$suppressTuning == 1} {
  global selectedK_pos_IE
  global selectedK_neg_IE
  global selectedK_pos_DP
  global selectedK_neg_DP

  # Everything that needs to be set to skip all tuning trials (meaning no variable damping trials)
  set targetOrientation "2D"
  set currentTarget_X 0.0
  set currentTarget_Y 0.0
  set previousTarget_X 0.0
  set previousTarget_Y 0.0
  set path1_X [list 0.0 3.9 -2.4 2.4 -6.7 4.2 0.1 5.3 -0.8 -5.7 -1.6 0.0]
  set path1_Y [list 0.0 -7.5 13.8 5.8 -2.2 -9.4 -0.6 7.2 -3.1 5.9 -14.1 0.0]
  set targetPositionsInBlock9_X $path1_X
  set targetPositionsInBlock9_Y $path1_Y
  set targetPositionsInBlock_X $targetPositionsInBlock9_X
  set targetPositionsInBlock_Y $targetPositionsInBlock9_Y

  # Using k values calculated for James in an old experiment
  set selectedK_pos_IE 0.5709778943261873
  set selectedK_neg_IE 0.3290692829920402
  set selectedK_pos_DP 0.2823221240681159
  set selectedK_neg_DP 0.16154477810533047
}

# Damping environments and the number of blocks for each (place in order)
#set dampingEnvironments [list {zero_IE 1} {tuning_IE 2} {zero_DP 1} {tuning_DP 2} {practice_positive 1} {practice_negative 1} {practice_variable 1} {positive 3} {negative 3} {variable 3}]

###############################################################
# TWO DIFFERENT PATTERNS FOR THE STRUCTURE OF THE STUDY BELOW #
###############################################################

# Pattern 1: PPP VVV PPPP VVVV
#set dampingEnvironments [list {zero_IE 1} {tuning_IE 2} {zero_DP 1} {tuning_DP 2} {practice_positive 1} {practice_variable 1} {positive 3} {variable 3} {positive 4} {variable 4} ]
#puts "Block Pattern 1"

# Pattern 2: VVV PPP VVVV PPPP
set dampingEnvironments [list {zero_IE 1} {tuning_IE 2} {zero_DP 1} {tuning_DP 2} {practice_variable 1} {practice_positive 1} {variable 3} {positive 3} {variable 4} {positive 4} ]
#puts "Block Pattern 2"

if {$suppressTuning == 1 } {
  #set dampingEnvironments [list {zero_IE 1} {tuning_IE 2} {zero_DP 1} {tuning_DP 2} {practice_variable 1} {practice_positive 1} {zero 3} {zero 3} {zero 4} {zero 4} ]
  set dampingEnvironments [list {zero_IE 1} {tuning_IE 2} {zero_DP 1} {tuning_DP 2} {practice_variable 1} {practice_positive 1} {variable 3} {variable 3} {variable 4} {variable 4} ]
  puts "No variable damping, tuning is suppressed"
}


###############################################################
# TWO DIFFERENT PATTERNS FOR THE STRUCTURE OF THE STUDY ABOVE #
###############################################################

# Number of trials in a block, should be even in order to ensure equal number of trials in both directions for 1D trials
set trialsPerBlock 10
#set extraTrialsForDataCollection 0 # Unlike the last study, we still have 10 trials per block

# Damping values
set negativeDamping_IE -0.5
set positiveDamping_IE 1.5
set variableDampingRange_IE [list $negativeDamping_IE $positiveDamping_IE]
set negativeDamping_DP -1
set positiveDamping_DP 3
set variableDampingRange_DP [list $negativeDamping_DP $positiveDamping_DP]

# Stiffness values
set overallStiffness 50
#set overallStiffness 0
puts "2D stiffness will be set to $overallStiffness Nm/rad"

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
#set totalTrials [expr $blocks*$trialsPerBlock]
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
  
  # To see the name of the .dat file that is being created
  #puts $fn
  
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
set ob(nlog) 25

# Specifies the controller being used
set ob(ankle_pt_ctl) 15
# Controller is defined in /crobASU/an_uslot.c
# The controller number is set in /crobASU/pl_uslot.c
set ob(ankle_stiff_ctl) 31

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

# Specificies which C log function to use (id defined in pl_ulog.c and function defined in an_ulog.c)
# 23 is the new one for 2D, 22 was the old one for 1D, had to also set ob(nlog) to 25 above since 25 col now
wshm logfnid 23

# Load ankle parameters from shm.tcl (this might not be needed)
wshm ankle_stiff 300.0
wshm ankle_damp 2.0
wshm stiff 0.0
wshm damp 0.0

# Set the stiffness and damping in preparation for gravity compensation
wshm ankle_stiff_DP 200
wshm ankle_stiff_IE 400.0
wshm ankle_stiff_k12 0.0
wshm ankle_stiff_k21 0.0
wshm ankle_dp_stiff_center 0.0
wshm ankle_ie_stiff_center 0.0
wshm ankle_damp_DP 0.0
wshm ankle_damp_IE 1.0

# Measurement rate
set Hz 1000

wshm restart_Hz $Hz
wshm Hz $Hz
wshm restart_go 1
wshm butcutoff 1

puts "Please enter subject name"
gets stdin subjectName

puts "Hit enter to move ankle to neutral..."
gets stdin in

# Find the current position of the ankle
set x [rshm ankle_ie_pos]
set y [rshm ankle_dp_pos]

# Without the following line, none of the stiffness values are set
movebox 0 $ob(ankle_stiff_ctl) {0 $Hz 1} {$x $y 0 0} {0 0 0 0}
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
  global targetOrientation
  if {$targetOrientation == "DP"} {
    wshm ankle_stiff_DP 0.0
    wshm ankle_stiff_IE 200.0
    wshm ankle_stiff_k12 0.0
    wshm ankle_stiff_k21 0.0
    wshm ankle_dp_stiff_center 0.0
    wshm ankle_ie_stiff_center 0.0
    puts "Stiffness applied"
  } elseif {$targetOrientation == "IE"} {
    wshm ankle_stiff_DP 400.0
    wshm ankle_stiff_IE 0.0
    wshm ankle_stiff_k12 0.0
    wshm ankle_stiff_k21 0.0
    wshm ankle_dp_stiff_center 0.0
    wshm ankle_ie_stiff_center 0.0
    puts "Stiffness applied"
  } elseif {$targetOrientation == "2D"} {
    wshm ankle_stiff_DP 0.0
    wshm ankle_stiff_IE 0.0
    wshm ankle_stiff_k12 0.0
    wshm ankle_stiff_k21 0.0
    wshm ankle_dp_stiff_center 0.0
    wshm ankle_ie_stiff_center 0.0
    puts "2D Stiffness applied"
  }
}


# Start trials
proc startTrials {} {
  global subjectName
  global ob
  global everyBlockEnvironment
  global suppressTuning
  global currentBlock
  
  puts "Start of trials"
  applyStiffness
  #setDampingEnvironment 1

  if {$suppressTuning ==  1} {
    setDampingEnvironment $currentBlock
  } else {
    setDampingEnvironment 1
  }
  
  # Creates a log file with a name in the form: name_damping.dat
  logSetup $subjectName [join [list "_" [lindex $everyBlockEnvironment 0]]]
  start_log $ob(logf) $ob(nlog)
}

# Apply the correct amount of damping based on the block number
proc endBlock {currentBlock} {
  global blocks
  global targetOrientation
  global subjectName
  global everyBlockEnvironment
  global ob
  global calculatingK
  global enablingVariableDamping
  global kMatrixPos
  global kMatrixNeg
  
  global selectedK_pos
  global selectedK_neg
  global selectedK_pos_IE
  global selectedK_neg_IE
  global selectedK_pos_DP
  global selectedK_neg_DP
  
  global targetPositionsInBlock
  global targetPositionsInBlock_X
  global targetPositionsInBlock_Y
  
  global targetPositionsInBlock2_IE
  global targetPositionsInBlock3_IE
  global targetPositionsInBlock4_DP
  global targetPositionsInBlock5_DP
  global targetPositionsInBlock6_DP
  global targetPositionsInBlock7_X
  global targetPositionsInBlock7_Y
  global targetPositionsInBlock8_X
  global targetPositionsInBlock8_Y
  global targetPositionsInBlock9_X
  global targetPositionsInBlock9_Y
  global targetPositionsInBlock10_X
  global targetPositionsInBlock10_Y
  global targetPositionsInBlock11_X
  global targetPositionsInBlock11_Y
  global targetPositionsInBlock12_X
  global targetPositionsInBlock12_Y
  global targetPositionsInBlock13_X
  global targetPositionsInBlock13_Y
  global targetPositionsInBlock14_X
  global targetPositionsInBlock14_Y
  global targetPositionsInBlock15_X
  global targetPositionsInBlock15_Y
  global targetPositionsInBlock16_X
  global targetPositionsInBlock16_Y
  global targetPositionsInBlock17_X
  global targetPositionsInBlock17_Y
  global targetPositionsInBlock18_X
  global targetPositionsInBlock18_Y
  global targetPositionsInBlock19_X
  global targetPositionsInBlock19_Y
  global targetPositionsInBlock20_X
  global targetPositionsInBlock20_Y
  global targetPositionsInBlock21_X
  global targetPositionsInBlock21_Y
  global targetPositionsInBlock22_X
  global targetPositionsInBlock22_Y

  global trialsPerBlock

  
  puts "End of block $currentBlock"
  
  if {$calculatingK == 1} {
    # Calculate the average gravity
    proc lavg L {expr ([join $L +])/[llength $L].}
    set selectedK_pos [lavg $kMatrixPos]
    set selectedK_neg [lavg $kMatrixNeg]
    #puts "Here is the selected K from the previous block, for positive intent:"
    #puts $selectedK_pos
    #puts "Here is the selected K from the previous block, for negative intent:"
    #puts $selectedK_neg
    #Reset kMatrix for next average
    set kMatrixPos { }
    set kMatrixNeg { }
    
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
    if {$targetOrientation == "DP"} {
      wshm ankle_stiff_DP 200.0
      wshm ankle_stiff_k12 0.0
      wshm ankle_stiff_k21 0.0
      wshm ankle_dp_stiff_center 0.0
      wshm ankle_ie_stiff_center 0.0
    } elseif {$targetOrientation == "IE"} {
      wshm ankle_stiff_IE 200.0
      wshm ankle_stiff_k12 0.0
      wshm ankle_stiff_k21 0.0
      wshm ankle_dp_stiff_center 0.0
      wshm ankle_ie_stiff_center 0.0
    } elseif {$targetOrientation == "2D"} {
      wshm ankle_stiff_DP 200.0
      wshm ankle_stiff_IE 200.0
      wshm ankle_stiff_k12 0.0
      wshm ankle_stiff_k21 0.0
      wshm ankle_dp_stiff_center 0.0
      wshm ankle_ie_stiff_center 0.0
    }
    
    # Pause the study until enter is pressed
    puts "Press ENTER to continue"
    gets stdin in
    
    ############################# IE TUNING #############################
    #Specifications for each block after 1
    # Block 2
    if {[expr $currentBlock + 1] == 2} {
      # Not needed
      set targetOrientation "IE"
      set targetPositionsInBlock $targetPositionsInBlock2_IE
      #puts "IE NEW TARGET LOCATIONS 2"
    }
    # Block 3
    if {[expr $currentBlock + 1] == 3} {
      # Not needed
      set targetOrientation "IE"
      set targetPositionsInBlock $targetPositionsInBlock3_IE
      #puts "IE NEW TARGET LOCATIONS 3"
    }

    ############################# DP TUNING #############################
    # Block 4
    if {[expr $currentBlock + 1] == 4} {
      # Save the selected K values before switching to the DP direction
      set selectedK_pos_IE $selectedK_pos
      set selectedK_neg_IE $selectedK_neg
      puts "Here is the selected K from the previous block, for positive intent, IE direction:"
      puts $selectedK_pos_IE
      puts "Here is the selected K from the previous block, for negative intent, IE direction:"
      puts $selectedK_neg_IE
      
      set targetOrientation "DP"
      set targetPositionsInBlock $targetPositionsInBlock4_DP
      #puts "DP NEW TARGET LOCATIONS 4"
    }
    # Block 5
    if {[expr $currentBlock + 1] == 5} {
      set targetOrientation "DP"
      set targetPositionsInBlock $targetPositionsInBlock5_DP
      #puts "DP NEW TARGET LOCATIONS 5"
    }
    # Block 6
    if {[expr $currentBlock + 1] == 6} {
      set targetOrientation "DP"
      set targetPositionsInBlock $targetPositionsInBlock6_DP
      #puts "DP NEW TARGET LOCATIONS 6"
    }

    ############################# PRACTICE BLOCKS #############################
    # Block 7
    if {[expr $currentBlock + 1] == 7} {
      # Save the selected K values before switching to the 2D direction
      set selectedK_pos_DP $selectedK_pos
      set selectedK_neg_DP $selectedK_neg
      puts "Here is the selected K from the previous block, for positive intent, DP direction:"
      puts $selectedK_pos_DP
      puts "Here is the selected K from the previous block, for negative intent, DP direction:"
      puts $selectedK_neg_DP

      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock7_X
      set targetPositionsInBlock_Y $targetPositionsInBlock7_Y
      #puts "2D NEW TARGET LOCATIONS 7 (PRACTICE)"
    }
    # Block 8
    if {[expr $currentBlock + 1] == 8} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock8_X
      set targetPositionsInBlock_Y $targetPositionsInBlock8_Y
      #puts "2D NEW TARGET LOCATIONS 8 (PRACTICE)"
    }
    ############################# DATA COLLECTION BLOCKS #############################
    # Block 9
    if {[expr $currentBlock + 1] == 9} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock9_X
      set targetPositionsInBlock_Y $targetPositionsInBlock9_Y
      #puts "2D NEW TARGET LOCATIONS 9"
    }
    # Block 10
    if {[expr $currentBlock + 1] == 10} {
      set targetOrientation "2D"
      # There are now 15 trials per block (NOT FOR THIS STUDY!)
      set trialsPerBlock 10
      set targetPositionsInBlock_X $targetPositionsInBlock10_X
      set targetPositionsInBlock_Y $targetPositionsInBlock10_Y
      #puts "2D NEW TARGET LOCATIONS 10"
    }
    # Block 11
    if {[expr $currentBlock + 1] == 11} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock11_X
      set targetPositionsInBlock_Y $targetPositionsInBlock11_Y
      #puts "2D NEW TARGET LOCATIONS 11"
    }
    # Block 12
    if {[expr $currentBlock + 1] == 12} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock12_X
      set targetPositionsInBlock_Y $targetPositionsInBlock12_Y
      #puts "2D NEW TARGET LOCATIONS 12"
    }
    # Block 13
    if {[expr $currentBlock + 1] == 13} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock13_X
      set targetPositionsInBlock_Y $targetPositionsInBlock13_Y
      #puts "2D NEW TARGET LOCATIONS 13"
    }
    # Block 14
    if {[expr $currentBlock + 1] == 14} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock14_X
      set targetPositionsInBlock_Y $targetPositionsInBlock14_Y
      #puts "2D NEW TARGET LOCATIONS 14"
    }
    # Block 15
    if {[expr $currentBlock + 1] == 15} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock15_X
      set targetPositionsInBlock_Y $targetPositionsInBlock15_Y
      #puts "2D NEW TARGET LOCATIONS 15"
    }
    # Block 16
    if {[expr $currentBlock + 1] == 16} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock16_X
      set targetPositionsInBlock_Y $targetPositionsInBlock16_Y
      #puts "2D NEW TARGET LOCATIONS 16"
    }
    # Block 17
    if {[expr $currentBlock + 1] == 17} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock17_X
      set targetPositionsInBlock_Y $targetPositionsInBlock17_Y
      #puts "2D NEW TARGET LOCATIONS 17"
    }
    # Block 18
    if {[expr $currentBlock + 1] == 18} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock18_X
      set targetPositionsInBlock_Y $targetPositionsInBlock18_Y
      #puts "2D NEW TARGET LOCATIONS 18"
    }
    # Block 19
    if {[expr $currentBlock + 1] == 19} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock19_X
      set targetPositionsInBlock_Y $targetPositionsInBlock19_Y
      #puts "2D NEW TARGET LOCATIONS 19"
    }
    # Block 20
    if {[expr $currentBlock + 1] == 20} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock20_X
      set targetPositionsInBlock_Y $targetPositionsInBlock20_Y
      #puts "2D NEW TARGET LOCATIONS 20"
    }
    # Block 21
    if {[expr $currentBlock + 1] == 21} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock21_X
      set targetPositionsInBlock_Y $targetPositionsInBlock21_Y
      #puts "2D NEW TARGET LOCATIONS 21"
    }
    # Block 22
    if {[expr $currentBlock + 1] == 22} {
      set targetOrientation "2D"
      set targetPositionsInBlock_X $targetPositionsInBlock22_X
      set targetPositionsInBlock_Y $targetPositionsInBlock22_Y
      #puts "2D NEW TARGET LOCATIONS 22"
    }
    
    # Remove the appropriate stiffness to continue the trials
    applyStiffness
    
    # Apply the appropriate damping based on the current block
    setDampingEnvironment [expr $currentBlock + 1]
    #puts "Here is the current block:"
    #puts [expr $currentBlock + 1]
    
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
  global minVal
  global b_LB
  global b_UB
  global kMatrixPos
  global kMatrixNeg
  global va_max
  global va_min
  global variableDampingRange
  global variableDampingRange_IE
  global variableDampingRange_DP
  global targetOrientation
  
  
  # Find the current damping enviornment
  set currentDampingEnvironment [lindex $everyBlockEnvironment [expr $currentBlock - 1]]
  
  # Output the current trial and its damping enviornment
  #puts "Trial $currentTrial of $totalTrials complete ($currentDampingEnvironment damping)"
  puts "Trial $currentTrial of $totalTrials complete"
  
  
  # Determine whether or not k needs to be calculated
  if {$calculatingK == 1} {
    #puts "Calculating K from the previous trial"
    # Graph the extrema values as red points on the graph
    #foo data d1 -colour red -points 1 -lines 0 -coords $maxMinPoints
    responseGraph data d1 -colour red -points 1 -lines 0 -coords $maxMinPoints
    # Graph the velocity times acceleration data as a line on the graph
    #foo data d2 -colour blue -points 0 -lines 1 -coords $graphMatrix
    responseGraph data d2 -colour blue -points 0 -lines 1 -coords $graphMatrix
    
    # Finds the parameters for finding k
    set r 0.95
    
    set va_max $maxVal
    set va_min $minVal
    
    # Need to assign the appropriate variable damping range based on the target orientation
    # Not needed in previous studies because there was only one range
    if {$targetOrientation == "IE"} {
      set variableDampingRange $variableDampingRange_IE
    } elseif {$targetOrientation == "DP"} {
      set variableDampingRange $variableDampingRange_DP
    }
    
    set b_UB [lindex $variableDampingRange 1]
    set b_LB [lindex $variableDampingRange 0]
    
    # Calculation of k (one for positive intent, one for negative intent)
    set new_k_pos [expr {-log((1-$r)/(1+$r)) / $va_max}]
    set new_k_neg [expr {-log((1+$r)/(1-$r)) / $va_min}]
    
    # Create a matrix of all of k values for the block
    lappend kMatrixPos $new_k_pos
    lappend kMatrixNeg $new_k_neg
    #puts "Here is the new k matrix for positive intent:"
    #puts $kMatrixPos
    #puts "Here is the new k matrix for negative intent:"
    #puts $kMatrixNeg
  } else {
    # Delete the response graph once K is not being calculated
    responseGraph destroy
  }
}

proc setDampingEnvironment {currentBlock} {
  global everyBlockEnvironment
  global positiveDamping
  global negativeDamping
  global positiveDamping_IE
  global positiveDamping_DP
  global negativeDamping_IE
  global negativeDamping_DP
  global calculatingK
  global enablingVariableDamping
  global suppressTuning
  
  puts "Start of block $currentBlock"
  
  # Since everyBlockEnvironment is 0 indexed, need to subtract 1
  set currentDampingEnvironment [lindex $everyBlockEnvironment [expr $currentBlock - 1]]
  
 # To see information about the current damping enviornment of the block
  #puts "Damping environment: $currentDampingEnvironment damping"
  
  # Apply the appropriate damping based on the current damping environment
  if {$currentDampingEnvironment == "zero" || $currentDampingEnvironment == "zero_IE" || $currentDampingEnvironment == "zero_DP" } {
    # Apply zero damping
    applyDamping 0 0

    if {$suppressTuning == 0 } {
      set calculatingK 1
    }
    
  } elseif {$currentDampingEnvironment == "tuning" || $currentDampingEnvironment == "tuning_IE" || $currentDampingEnvironment == "tuning_DP" } {
    set calculatingK 1
    # Tuning uses 1D variable damping
    set enablingVariableDamping 1
    
  } elseif {$currentDampingEnvironment == "variable" || $currentDampingEnvironment == "practice_variable" } {
    # Variable damping trials use 2D variable damping
    set enablingVariableDamping 2
    
  } elseif {$currentDampingEnvironment == "negative" || $currentDampingEnvironment == "practice_negative" } {
    applyDamping $negativeDamping_IE $negativeDamping_DP
    
  } elseif {$currentDampingEnvironment == "positive" || $currentDampingEnvironment == "practice_positive" } {
    applyDamping $positiveDamping_IE $positiveDamping_DP
    
  } else {
    puts "Error: $currentDampingEnvironment is not a known damping environment."
  }
  
}

# Unlike in the previous studies, this function takes two inputs for the different ankle directions
# If only applying for 1 direction (ie. tuning DP constant) you can send the same value for IE and DP
# and the function will automattically limit the damping to the correct direction
proc applyDamping {damping_IE damping_DP} {
  global targetOrientation
  #puts "Damping of $damping Nms/rad"
  if {$targetOrientation == "DP"} {
    # Apply the input constant damping
    wshm ankle_damp_DP $damping_DP
    # Apply positive daming to the direction opposite of movement
    wshm ankle_damp_IE 1.0
    
  } elseif {$targetOrientation == "IE"} {
    # Apply positive daming to the direction opposite of movement
    wshm ankle_damp_DP 1.0
    # Apply the input constant damping
    wshm ankle_damp_IE $damping_IE
    
  } elseif {$targetOrientation == "2D"} {
    wshm ankle_damp_DP $damping_DP
    wshm ankle_damp_IE $damping_IE
  }
}

proc linFit points {
    # linear regression y=ax+b for {{x0 y0} {x1 y1}...}
    # returns {a b r}, where r: correlation coefficient
    foreach i {N Sx Sy Sxy Sx2 Sy2} {set $i 0.0}
    foreach point $points {
        foreach {x y} $point break
        set Sx  [expr {$Sx  + $x}]
        set Sy  [expr {$Sy  + $y}]
        set Sx2 [expr {$Sx2 + $x*$x}]
        set Sy2 [expr {$Sy2 + $y*$y}]
        set Sxy [expr {$Sxy + $x*$y}]
        incr N
    }
    set t1 [expr {$N*$Sxy - $Sx*$Sy}]
    set t2 [expr {$N*$Sx2 - $Sx*$Sx}]
    set a [expr {double($t1)/$t2}]
    set b [expr {double($Sy-$a*$Sx)/$N}]
    set r [expr {$t1/(sqrt($t2)*sqrt($N*$Sy2-$Sy*$Sy))}]
    list $a $b $r
}

# linearReg
#    Determine the coefficients for a linear regression between
#    two series of data (the model: Y = A + B*X)
#
# Arguments:
#    xdata        Series of independent (X) data
#    ydata        Series of dependent (Y) data

# Result:
#    List of the following items:
#    - (Estimate of) Intercept A
#    - (Estimate of) Slope B

proc linearReg { xdata ydata } {

   set sumx  0.0
   set sumy  0.0
   set sumx2 0.0
   set sumy2 0.0
   set sumxy 0.0
   set df    0
   foreach x $xdata y $ydata {
      if { $x != "" && $y != "" } {
         set sumx  [expr {$sumx+$x}]
         set sumy  [expr {$sumy+$y}]
         set sumx2 [expr {$sumx2+$x*$x}]
         set sumy2 [expr {$sumy2+$y*$y}]
         set sumxy [expr {$sumxy+$x*$y}]
         incr df
      }
   }

   # Calculate the intermediate quantities
   set sx  [expr {$sumx2-$sumx*$sumx/$df}]
   set sy  [expr {$sumy2-$sumy*$sumy/$df}]
   set sxy [expr {$sumxy-$sumx*$sumy/$df}]

   # Calculate the coefficients
   set B [expr {$sxy/$sx}]
   set A [expr {($sumy-$B*$sumx)/$df}]

   # Return the list of parameters
   return [list $A $B ]
}

# stiff is 0 or 1 depending on if it's on or off
# startX, startY, endX, endY coorespond to points on the line of direction intent
proc applyVariableStiffness {stiff startX startY endX endY} {
  global currentTarget_X
  global currentTarget_Y
  global previousTarget_X
  global previousTarget_Y
  global pi
  global overallStiffness
  global gridColor

  #puts $currentTarget_X
  #puts $currentTarget_Y
  #puts $previousTarget_X
  #puts $previousTarget_Y

  if {$stiff == 0} {
    wshm ankle_stiff_DP 0.0
    wshm ankle_stiff_IE 0.0
    wshm ankle_stiff_k12 0.0
    wshm ankle_stiff_k21 0.0
  
  } else {

    # Find the position coordinates of the robot in degrees
    set coordinates [getRobotPosition .right.view]
    lassign $coordinates x y

    # A vector
    set a1 [ expr -$x*($endX-$startX) - $y*($endY-$startY) ]
    set a2 [ expr -$startY*($endX-$startX) + $startX*($endY-$startY) ]

    # B matrix
    set b11 [ expr $endX - $startX ]
    set b12 [ expr $endY - $startY ]
    set b21 [ expr $startY - $endY ]
    set b22 [ expr $endX - $startX ]

    # Calculate projection
    set projx [ expr  -((($a1*$b22)/($b11*$b22-$b12*$b21))-(($a2*$b12)/($b11*$b22-$b12*$b21))) ]
    set projy [ expr  -((($a2*$b11)/($b11*$b22-$b12*$b21))-(($a1*$b21)/($b11*$b22-$b12*$b21))) ]

    # Projection point
    #puts "Projection point:"
    #puts $projx
    #puts $projy 

    # Convert degrees to radians
    set projx_rad [ expr  $projx * ( $pi / 180) ]
    set projy_rad [ expr  $projy * ( $pi / 180) ]

    # Calculate the rotation angle
    #set xdist [ expr $endX - $startX ]
    #set ydist [ expr $endY - $startY ]

    # Calculate the angle of rotation of stiffness ellipse
    #set angle [ expr atan2($ydist, $xdist) ]
    #puts "Angle:"
    #puts $angle

    # Everything that needs to written to shared memory
    wshm ankle_stiff_DP $overallStiffness
    wshm ankle_stiff_IE $overallStiffness
    wshm ankle_stiff_k12 0.0
    wshm ankle_stiff_k21 0.0
    # Where the stiffness equilibrium should be placed in radians
    wshm ankle_dp_stiff_center $projy_rad
    wshm ankle_ie_stiff_center $projx_rad

    # Check these in the shm to see what the issue is
    set xSHM [rshm ankle_ie_pos]
    set ySHM [rshm ankle_dp_pos]
    #puts "ankle_ie_pos and ankle_dp_pos"
    #puts $xSHM
    #puts $ySHM

    set xref_posSHM [rshm ankle_ie_ref_pos]
    set yref_posSHM [rshm ankle_dp_ref_pos]
    #puts "ankle_ie_ref_pos and ankle_dp_ref_pos"
    #puts $xref_posSHM
    #puts $yref_posSHM

    set xstiff_centerSHM [rshm ankle_ie_stiff_center]
    set ystiff_centerSHM [rshm ankle_dp_stiff_center]
    #puts "ankle_ie_stiff_center and ankle_dp_stiff_center"
    #puts $xstiff_centerSHM
    #puts $ystiff_centerSHM

    # For some reason, this can't be accessed from the shared memory
    #set torque_IE [rshm ob->ankle_ie_torque]
    #set torque_DP [rshm ob->ankle_dp_torque]
    #puts "ob->ankle_ie_torque and ankle_dp_torque"
    #puts $torque_IE
    #puts $torque_DP

    #puts "Variable Stiffness applied"
  }

}

# End of trials
proc endTrials {} {
  global selectedK_pos_IE
  global selectedK_neg_IE
  global selectedK_pos_DP
  global selectedK_neg_DP

  # Print out the K values to remind 
  puts "SAVE TERMINAL WINDOW FOR K VALUES: Shift+Ctrl+A to select all, then Edit>Copy, and paste in text file."
  puts "selectedK_pos_IE = $selectedK_pos_IE"
  puts "selectedK_neg_IE = $selectedK_neg_IE"
  puts "selectedK_pos_DP = $selectedK_pos_DP"
  puts "selectedK_neg_DP = $selectedK_neg_DP"

  puts "End of trials"
  wshm ankle_stiff_DP 50.0
  wshm ankle_stiff_IE 50.0
  wshm ankle_stiff_k12 0.0
  wshm ankle_stiff_k21 0.0
  wshm ankle_dp_stiff_center 0.0
  wshm ankle_ie_stiff_center 0.0
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
  movebox 0 $ob(ankle_stiff_ctl) {0 $Hz 1} {$x $y 0 0} {0 0 0 0}
  puts "Start move"
  after 1000
  puts "Complete"
}

# Send a signal to the log file that represents the start of a trial (target at a distance has appeared)
proc sendTargetDistanceSignal {targetDistance_IE targetDistance_DP} {
  wshm ankle_target_Distance_IE $targetDistance_IE
  wshm ankle_target_Distance_DP $targetDistance_DP
}


# ----------------------Loop----------------------

# Variables initialized for the variable damping tuning
set maxVal -999999899
set minVal 999999899
set maxTime 0
set minTime 0
set previous_vtimesa_IE 0
set previous_vtimesa_DP 0
set enablingCalcStiffEquil 0
set xPositions { }
set yPositions { }

# Main loop used for calculating k and for applying variable damping
every 10 {
  global calculatingK
  global enablingVariableDamping
  global variableDampingRange
  global variableDampingRange_IE
  global variableDampingRange_DP
  global targetOrientation
  global xtime
  global graphMatrix
  global vtimesaMatrix
  global maxVal
  global minVal
  global maxTime
  global minTime
  global maxMinPoints
  global b_UB
  global b_LB
  global b_UB_IE
  global b_LB_IE
  global b_UB_DP
  global b_LB_DP
  global selectedK_pos
  global selectedK_neg
  global selectedK_pos_IE
  global selectedK_neg_IE
  global selectedK_pos_DP
  global selectedK_neg_DP
  global currentTarget
  global previous_vtimesa_IE
  global previous_vtimesa_DP
  global enablingCalcStiffEquil
  global xPositions
  global yPositions

  #if {$targetOrientation == "2D"} {
  #  applyVariableStiffness
  #}
  
  # When k is being calculated OR variable damping (1D or 2D) is enabled, need to find vel and accel
  if {$calculatingK == 1 || $enablingVariableDamping == 1 || $enablingVariableDamping == 2} {
    #puts "calculating vel and accel"
    # Find the current filtered velocity and acceleration
    if {$targetOrientation == "DP"} {
      set vel [rshm ankle_dp_fvel]
      set accel [rshm ankle_dp_faccel]
    } elseif {$targetOrientation == "IE"} {
      set vel [rshm ankle_ie_fvel]
      set accel [rshm ankle_ie_faccel]
    } elseif {$targetOrientation == "2D"} {
      # Need the velocity and acceleration in all directions
      set vel_IE [rshm ankle_ie_fvel]
      set accel_IE [rshm ankle_ie_faccel]
      set vel_DP [rshm ankle_dp_fvel]
      set accel_DP [rshm ankle_dp_faccel]
    }
  }
  
  # Runs during blocks when it is desired that K be calculated
  if {$calculatingK == 1} {
    # If the target is set at the neutral position, do not need to collect data to calculate k
    # Data not being used for calculation of K
    # No longer reads the log file to see, instead calls global variable from View2D.tcl
    if {$currentTarget == 0 } {
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
      set minTime 0
      
      # If the target is set at a distance, this is the data being used to calculate k
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
  
  # Runs during blocks when it is desired that variable damping be applied for just 1D (either DP or IE)
  if {$enablingVariableDamping == 1} {
    #puts "Variable damping is being applied"
    
    # Need to assign the appropriate variable damping range based on the target orientation
    # Not needed in previous studies because there was only one range
    if {$targetOrientation == "IE"} {
      set variableDampingRange $variableDampingRange_IE
    } elseif {$targetOrientation == "DP"} {
      set variableDampingRange $variableDampingRange_DP
    }
    
    # Find the damping range
    set b_UB [lindex $variableDampingRange 1]
    set b_LB [lindex $variableDampingRange 0]
    
    #puts "vel: $vel rad/s"
    #puts "accel: $accel rad^2/s"
    #puts "constantK: $constantK"
    
    # Each time step, calculate filtered velocity times filtered acceleration
    set vtimesa [ expr {$vel * $accel} ]
    
    # Damping for positive intent
    if { $vtimesa >= 0 } {
      # Send the selected variable damping k to the log
      wshm ankle_varDamp_K $selectedK_pos
      set damping [ expr { ( 2 * $b_LB ) / (1 + exp( (-1) * $selectedK_pos * $vel * $accel) ) - $b_LB } ]
      # Only the appropriate damping will be set (look at function, the other direction will be set to 1)
      applyDamping $damping $damping
      
      # Damping for negative intent
    } else {
      # Send the selected variable damping k to the log
      wshm ankle_varDamp_K $selectedK_neg
      set damping [ expr { (-1) * ( ( 2 * $b_UB ) / (1 + exp( (-1) * $selectedK_neg * $vel * $accel) ) - $b_UB ) } ]
      # Only the appropriate damping will be set (look at function, the other direction will be set to 1)
      applyDamping $damping $damping
    }
  }
  
  
  # Runs during blocks when it is desired that variable damping be applied for 2D (both DP and IE)
  if {$enablingVariableDamping == 2} {
    #puts "2D Variable damping is being applied"
    
    # Find the damping range
    set b_UB_IE [lindex $variableDampingRange_IE 1]
    set b_LB_IE [lindex $variableDampingRange_IE 0]
    set b_UB_DP [lindex $variableDampingRange_DP 1]
    set b_LB_DP [lindex $variableDampingRange_DP 0]
    
    #puts "vel: $vel rad/s"
    #puts "accel: $accel rad^2/s"
    #puts "constantK: $constantK"
    
    # Each time step, calculate filtered velocity times filtered acceleration
    set vtimesa_IE [ expr {$vel_IE * $accel_IE} ]
    set vtimesa_DP [ expr {$vel_DP * $accel_DP} ]
    
    # IE direction intent
    if { $vtimesa_IE >= 0 } {
      # Positive
      set damping_IE [ expr { ( 2 * $b_LB_IE ) / (1 + exp( (-1) * $selectedK_pos_IE * $vel_IE * $accel_IE) ) - $b_LB_IE } ]
    } else {
      # Negative
      set damping_IE [ expr { (-1) * ( ( 2 * $b_UB_IE ) / (1 + exp( (-1) * $selectedK_neg_IE * $vel_IE * $accel_IE) ) - $b_UB_IE ) } ]
    }
    
    # DP direction intent
    if { $vtimesa_DP >= 0 } {
      # Positive
      set damping_DP [ expr { ( 2 * $b_LB_DP ) / (1 + exp( (-1) * $selectedK_pos_DP * $vel_DP * $accel_DP) ) - $b_LB_DP } ]
    } else {
      # Negative
      set damping_DP [ expr { (-1) * ( ( 2 * $b_UB_DP ) / (1 + exp( (-1) * $selectedK_neg_DP * $vel_DP * $accel_DP) ) - $b_UB_DP ) } ]
    }

    # Calculate the overal user intent
    set previous_vtimesa_sum [ expr $previous_vtimesa_IE + $previous_vtimesa_DP]
    set vtimesa_sum [ expr $vtimesa_IE + $vtimesa_DP]


    # Draw a path with the color represending the current user intent
    set coordinates [getRobotPosition .right.view]
    lassign $coordinates x y
    if { $vtimesa_sum >= 0 } {
      set pathPoint [.right.view create oval [drawCircle $x $y 0.05 ] -fill $negDampColor -outline $black -width 0]
    } else {
      set pathPoint [.right.view create oval [drawCircle $x $y 0.05 ] -fill $posDampColor -outline $black -width 0]
    }


    # If the intent as just passed 0.1
    #puts $previous_vtimesa_sum
    #puts $vtimesa_sum

    # 0.1 is the horizontal line on the vtimesa plot that is used as the threshold of when to start calculating intent
    if { $previous_vtimesa_sum < 0.01 && $vtimesa_sum >= 0.01 } {
      #puts "CALCULATE NEW STIFFNESS EQUILIBRUIM"
      set xPositions { }
      set yPositions { }
      .right.view delete interpPoint
      set enablingCalcStiffEquil 1
    }

    # Set zero stiffness when intent is negative
    if { $vtimesa_sum <= 0.01 } {
      applyVariableStiffness 0 0 0 0 0
    }

    set previous_vtimesa_IE $vtimesa_IE 
    set previous_vtimesa_DP $vtimesa_DP
    
    # Now that the correct IE, DP, +, and - damping has been found for this time step, set the damping
    applyDamping $damping_IE $damping_DP

  }

  # Runs if the intent changed from negative to positive, which often cooresponds to a change in direction
  if {$enablingCalcStiffEquil == 1} {
    # Find the position coordinates of the robot in degrees
    set coordinates [getRobotPosition .right.view]
    lassign $coordinates x y

    lappend xPositions $x
    lappend yPositions $y

    set interpPoint [.right.view create oval [drawCircle $x $y 0.1 ] -fill $targetColor -outline $black -width 0]

    #puts $xPositions


    # Once the length of the list is a certain length (ie. enought time has ellapsed to make a calculation)
    if { [llength $xPositions] >= 10} {
      global gridColor
      
      # Perform linear regression on points where the confidence in the correct direction is high
    # Currently, data of the actual target locations is being used (the ideal case)
    # Eventually, many data points will be used over a short window for this calculation
      set result [linearReg $xPositions $yPositions]
    #puts $result
    lassign $result intercept slope

    # Draw a line representing the equilibrium line where the stiffness is being applied
    .right.view delete stiffLine
    

    .right.view create line [drawLine -100 [ expr $slope * -100 + $intercept] 100 [ expr $slope * 100 + $intercept] ] -fill $gridColor -tags stiffLine -width 3 -dash -
    
    applyVariableStiffness 1 -100 [ expr $slope * -100 + $intercept] 100 [ expr $slope * 100 + $intercept]

    #puts "Clear list"
      set xPositions { }
      set yPositions { }
      set enablingCalcStiffEquil 0
      .right.view delete interpPoint

    }

    # Projection point
    #puts "Current Poisition:"
    #puts $x
    #puts $y

    # Perform linear regression on points where the confidence in the correct direction is high
    # Currently, data of the actual target locations is being used (the ideal case)
    # Eventually, many data points will be used over a short window for this calculation
  }



}
