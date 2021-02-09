## View.tcl
# Created by James Arnold

package require Tk
source Controller.tcl

# ---------------Study Specifications------------------

# Degrees from the center for the target
# This study uses different, prerandomized target distances for each trial, so not needed
#set targetDistance 7.5

# Time required to meet targets, in ms
set targetTime 2000
# Uncomment this line for testing the study quickly
#set targetTime 200

# No time randomization in this study, but still used for tuning trials
set neutralTimeRange [list 1500 4000]
# Uncomment this line for testing the study quickly
#set neutralTimeRange [list 200 300]

# Radii of the cursor and target in degrees
set cursorRadius 0.75
set targetRadius 2.25

# --------------Initialized Variables-----------------

set studyStarted 0
set visualizeMVC 0 
set targetPositionsInBlock 0
set mvc_time -1
set emgMatrix_TA { }
set emgMatrix_PL { }
set emgMatrix_SL { }
set emgMatrix_MG { }

# -------------------Constants------------------------

# Size of the window in pixels (window is square)
set canvasWidth 980
set canvasHeight $canvasWidth

# Number of degrees to show over the full width and height (ie. -20 to 20 is a degreeRange of 40)
set degreeRange 40

# Spacing in degrees of the background grid
set gridSpacing 1

# Pixels over degrees scaling factor (converts degrees to pixels)
set scale [expr $canvasWidth / $degreeRange ]

# Button names (cannot include spaces)
set buttonList {"EMG" "MVC" "Initialize" "Gravity" "Start"}

# Colors
set black "#000000"
#set backgroundColor1 "#CCF2F2"
#set backgroundColor2 "#7ADDDD"
set backgroundColor1 "#EDDBF4"
set backgroundColor2 "#D09AEB"
set cursorColor "#DF0E39"
set targetColor "#00B0F0"
#set gridColor "#97B2B5"
set gridColor "#A38BB5"
set insideTargetColor "#FFD45C"

set negDampColor "#FF7F32"
set posDampColor "#78BE21"

# -------------------Functions------------------------

# Draw a gradient (used for the background of the canvas)
proc drawGradient {win axis col1Str col2Str} {
  if {[winfo class $win] != "Canvas"} {
    return -code error "$win must be a canvas widget"
  }
  
  $win delete gradient
  
  set width  [winfo width $win]
  set height [winfo height $win]
  switch -- $axis {
    "x" { set max $width; set x 1 }
    "y" { set max $height; set x 0 }
    default {
      return -code error "Invalid axis $axis: must be x or y"
    }
  }
  
  if {[catch {winfo rgb $win $col1Str} color1]} {
    return -code error "Invalid color $col1Str"
  }
  
  if {[catch {winfo rgb $win $col2Str} color2]} {
    return -code error "Invalid color $col2Str"
  }
  
  foreach {r1 g1 b1} $color1 break
  foreach {r2 g2 b2} $color2 break
  set rRange [expr $r2.0 - $r1]
  set gRange [expr $g2.0 - $g1]
  set bRange [expr $b2.0 - $b1]
  
  set rRatio [expr $rRange / $max]
  set gRatio [expr $gRange / $max]
  set bRatio [expr $bRange / $max]
  
  for {set i 0} {$i < $max} {incr i} {
    set nR [expr int( $r1 + ($rRatio * $i) )]
    set nG [expr int( $g1 + ($gRatio * $i) )]
    set nB [expr int( $b1 + ($bRatio * $i) )]
    
    set col [format {%4.4x} $nR]
    append col [format {%4.4x} $nG]
    append col [format {%4.4x} $nB]
    if {$x} {
      $win create line $i 0 $i $height -tags gradient -fill #${col}
    } else {
      $win create line 0 $i $width $i -tags gradient -fill #${col}
    }
  }
  bind $win <Configure> [list drawGradient $win $axis $col1Str $col2Str]
  return $win
}

# Takes degrees as an x position input and outputs the result in pixels
proc transformX {x} {
  global scale
  global canvasWidth
  set xNew [expr { ($x * $scale + $canvasWidth / 2 ) }]
  list $xNew
}

# Takes degrees as a y position input and outputs the result in pixels
proc transformY {y} {
  global scale
  global canvasWidth
  set yNew [expr {-1 * ( $y * $scale - $canvasWidth / 2 ) }]
  list $yNew
}


# Draws a circle of a given radius when degrees as position are input
proc drawCircle {x y radius} {
  global scale
  set x [transformX $x ]
  set y [transformY $y ]
  set radius [expr $radius * $scale ]
  
  set x1 [expr {$x - $radius}]
  set y1 [expr {$y - $radius}]
  set x2 [expr {$x + $radius}]
  set y2 [expr {$y + $radius}]
  
  list $x1 $y1 $x2 $y2
}

# Draws a line when degrees as position are input
proc drawLine {x1 y1 x2 y2} {
  set x1 [transformX $x1 ]
  set y1 [transformY $y1 ]
  set x2 [transformX $x2 ]
  set y2 [transformY $y2 ]
  list $x1 $y1 $x2 $y2
}

# Creates grid lines every number of degrees
proc drawGrid {spacing} {
  global degreeRange
  global gridColor
  for {set i 0} {$i <= [ expr $degreeRange / $spacing ]} {incr i} {
    # Horizontal lines
    .right.view create line [drawLine [expr $degreeRange / -2] [expr -1 * $degreeRange / 2 + $i * $spacing ] [expr $degreeRange / 2] [expr -1 * $degreeRange / 2 + $i * $spacing ]] -fill $gridColor
    # Vertical lines
    .right.view create line [drawLine [expr -1 * $degreeRange / 2 + $i * $spacing ] [expr $degreeRange / -2] [expr -1 * $degreeRange / 2 + $i * $spacing ] [expr $degreeRange / 2]] -fill $gridColor
  }
}

# Functions called for each of the buttons on the left
proc buttonAction {place} {
  global buttonList
  global black
  global trialsPerBlock
  global studyStarted
  global targetRadius
  global targetColor
  global targetPositionsInBlock
  global target
  global visualizeMVC
  
  # Actions when buttons are pressed
  set buttonNumber [lsearch $buttonList $place]
  
  if {$buttonNumber == 1} {
    # After button 0 (MVC) is pressed, log the data
    # Allows you to put on EMG sensors without logging the data
    collectMVC

    # Disable the button after it has been pressed
    .left.[string tolower [lindex $buttonList $buttonNumber]] configure -state disabled

  } elseif {$buttonNumber == 2} {
    # Set the stiffness and damping in preparation for gravity compenstation
    initializeStiffDamp

    # Disable the button after it has been pressed
    .left.[string tolower [lindex $buttonList $buttonNumber]] configure -state disabled

  } elseif {$buttonNumber == 3} {
    # Call gravity compensation function from controller
    gravityComp
    
    # Once the gravity is compensated, make the x axis, y axis, and center visible
    .right.view itemconfigure $::center -fill $black
    .right.view coords $::center [drawCircle 0 0 0.25 ]
    .right.view itemconfigure $::xAxis -fill $black
    .right.view itemconfigure $::yAxis -fill $black
    
    # Disable the button after it has been pressed
    .left.[string tolower [lindex $buttonList $buttonNumber]] configure -state disabled
    
  } elseif {$buttonNumber == 4} {
    # Call startTrials function from controller
    startTrials
    
    set target [.right.view create oval [drawCircle 0 0 $targetRadius ] -fill $targetColor -outline $black -width 0]
    
    # Generate a vector representing the position of the target during each block
    # This function is no longer used since target directions are predefined
    #set targetPositionsInBlock [targetPosition $trialsPerBlock]
    
    # Starts the study within the loop
    set studyStarted 1
    
    # Disable the button after it has been pressed
    .left.[string tolower [lindex $buttonList $buttonNumber]] configure -state disabled
    
  } elseif {$buttonNumber == 0} {

    set visualizeMVC 1

    # Disable the button after it has been pressed
    .left.[string tolower [lindex $buttonList $buttonNumber]] configure -state disabled

  } else {
    puts "Unknown button command"
  }
}

# Predefined paths for 2D data collection trials
# These paths are designed so that they never go outside of an elliptical workspace: 15 DP and 7.5 IE
# Mininum distance between consecutive targets: 5 DP and 2.5 IE
# Maximum distance between consecutive targets: 10 DP and 5 IE
# The total IE distance (21.2) traveled is equal to DP distance traveled times two (42.4)

# Path 1
set path1_X [list 0.0 4.0 -0.1 -4.3 0.4 3.0 -0.6 2.0 -2.7 0.1 4.6 0.0]
set path1_Y [list 0.0 -9.2 -1.4 4.1 12.6 4.0 12.3 4.5 -5.4 -12.3 -3.1 0.0]

# Path 2          
set path2_X [list 0.0 -4.0 0.1 4.3 -0.4 -3.0 0.6 -2.0 2.7 -0.1 -4.6 0.0]
set path2_Y [list 0.0 -9.2 -1.4 4.1 12.6 4.0 12.3 4.5 -5.4 -12.3 -3.1 0.0]

# Path 3      
set path3_X [list 0.0 4.0 -0.1 -4.3 0.4 3.0 -0.6 2.0 -2.7 0.1 4.6 0.0]
set path3_Y [list 0.0 9.2 1.4 -4.1 -12.6 -4.0 -12.3 -4.5 5.4 12.3 3.1 0.0]

# Path 4     
set path4_X [list 0.0 -4.0 0.1 4.3 -0.4 -3.0 0.6 -2.0 2.7 -0.1 -4.6 0.0]
set path4_Y [list 0.0 9.2 1.4 -4.1 -12.6 -4.0 -12.3 -4.5 5.4 12.3 3.1 0.0]

# Target Positions in the tuning blocks
# These are both for the x direction
set targetPositionsInBlock1_IE [list 0.000 7.5 0.000 -7.5 0.000 -7.5 0.000 7.5 0.000 -7.5 0.000 7.5 0.000 -7.5 0.000 7.5 0.000 -7.5 0.000 7.5 0.000]
set targetPositionsInBlock2_IE [list 0.000 -7.5 0.000 7.5 0.000 7.5 0.000 -7.5 0.000 -7.5 0.000 7.5 0.000 7.5 0.000 -7.5 0.000 7.5 0.000 -7.5 0.000]
set targetPositionsInBlock3_IE [list 0.000 -7.5 0.000 7.5 0.000 -7.5 0.000 -7.5 0.000 -7.5 0.000 7.5 0.000 7.5 0.000 7.5 0.000 7.5 0.000 -7.5 0.000]
# These are both for the y direction
set targetPositionsInBlock4_DP [list 0.000 15.0 0.000 -15.0 0.000 -15.0 0.000 -15.0 0.000 15.0 0.000 -15.0 0.000 15.0 0.000 15.0 0.000 -15.0 0.000 15.0 0.000]
set targetPositionsInBlock5_DP [list 0.000 15.0 0.000 -15.0 0.000 15.0 0.000 15.0 0.000 -15.0 0.000 -15.0 0.000 15.0 0.000 -15.0 0.000 -15.0 0.000 15.0 0.000]
set targetPositionsInBlock6_DP [list 0.000 -15.0 0.000 15.0 0.000 15.0 0.000 -15.0 0.000 15.0 0.000 -15.0 0.000 15.0 0.000 15.0 0.000 -15.0 0.000 -15.0 0.000]

# The rest are pairs of x and y vectors cooresponding to the following 3 blocks
# Practice set of 3 pairs (only 10 trials, completely random target placement)
set targetPositionsInBlock7_X $path3_X
set targetPositionsInBlock7_Y $path3_Y

set targetPositionsInBlock8_X $path4_X
set targetPositionsInBlock8_Y $path4_Y

# The rest are pairs of x and y vectors cooresponding to the following blocks for data collection
set targetPositionsInBlock9_X $path1_X
set targetPositionsInBlock9_Y $path1_Y

set targetPositionsInBlock10_X $path2_X
set targetPositionsInBlock10_Y $path2_Y

set targetPositionsInBlock11_X $path3_X
set targetPositionsInBlock11_Y $path3_Y


set targetPositionsInBlock12_X $path1_X
set targetPositionsInBlock12_Y $path1_Y

set targetPositionsInBlock13_X $path2_X
set targetPositionsInBlock13_Y $path2_Y

set targetPositionsInBlock14_X $path3_X
set targetPositionsInBlock14_Y $path3_Y


set targetPositionsInBlock15_X $path1_X
set targetPositionsInBlock15_Y $path1_Y

set targetPositionsInBlock16_X $path2_X
set targetPositionsInBlock16_Y $path2_Y

set targetPositionsInBlock17_X $path3_X
set targetPositionsInBlock17_Y $path3_Y

set targetPositionsInBlock18_X $path4_X
set targetPositionsInBlock18_Y $path4_Y


set targetPositionsInBlock19_X $path1_X
set targetPositionsInBlock19_Y $path1_Y

set targetPositionsInBlock20_X $path2_X
set targetPositionsInBlock20_Y $path2_Y

set targetPositionsInBlock21_X $path3_X
set targetPositionsInBlock21_Y $path3_Y

set targetPositionsInBlock22_X $path4_X
set targetPositionsInBlock22_Y $path4_Y


# Initialize the targets for the first block
set targetPositionsInBlock $targetPositionsInBlock1_IE

# Function that generates a random interger in a range
proc randomInRange {range} {
  set min [lindex $range 0]
  set max [lindex $range 1]
  return [expr int(rand()*($max-$min+1)) + $min]
}

# --------------------Generate GUI--------------------

# Create a canvas with a left and right side
frame .left
frame .right
pack .left .right -side left -expand yes -fill both

# Create the buttons
foreach b $buttonList {
  pack [button .left.[string tolower $b] -text $b -command "buttonAction $b"] -side top
}

# Add an end button
pack [button .left.quit -text "End MVC" -command stopMVC] -side bottom
#pack [button .left.quit -text "End" -command done] -side bottom
pack [canvas .right.view -width $canvasWidth -height $canvasHeight] \
    -side right -expand yes -fill both

# Green background gradient
drawGradient .right.view y $backgroundColor1 $backgroundColor2

# Make the canvas display, then find the size of the canvas
update idletasks
set size [wm geometry .]

# Set limits to the canvas based on the size
regexp {(\d+)x(\d+)} $size all w h
wm aspect . $w $h $w $h
wm minsize . $w $h

# Since it is set to 1, the window cannot be resized
wm maxsize . [expr int($w*1)] [expr int($h*1)]

# Title on the top of the window
wm title . [concat "Variable Impedance with Disturbance Rejection" ]

# Draw a grid with a certain number of degree spacing
drawGrid $gridSpacing

# Draw coordinate axes, not distinguishable from grid until after gravity compensation
set xAxis [.right.view create line [drawLine [expr $degreeRange / -2] 0 [expr $degreeRange / 2] 0] -fill $gridColor]
set yAxis [.right.view create line [drawLine 0 [expr $degreeRange / -2] 0 [expr $degreeRange / 2]] -fill $gridColor]

# Graphics on the page
set cursor [.right.view create oval [drawCircle 0 0 $cursorRadius ] -fill $cursorColor -outline $black -width 0]
#set target [.right.view create oval [drawCircle 10 0 $targetRadius ] -fill $targetColor -outline $black -width 0]
set center [.right.view create oval [drawCircle 0 0 0.1 ] -fill $gridColor -outline $black -width 0]

# Load the file that allows for the creation of a graph in tcl (used for calculation of k)
source /home/imt/imt/robot4/protocols/ankle/VariableDampingStudy/Supporting/Graph.tcl
#emu_graph::emu_graph foo -canvas .right.view -width 600 -height 300 -xref 200 -yref 600

# Uncomment this line to view the plot
# emu_graph::emu_graph responseGraph -canvas .right.view -width 600 -height 300 -xref 200 -yref 600

# Intentionally put the plot off of the page so the subject can't see it (comment this out to view plot)
emu_graph::emu_graph responseGraph -canvas .right.view -width 600 -height 300 -xref 20000 -yref 60000


# ----------------------Loops----------------------

# Loop that constantly updates the cursor position from the controller
# Runs every 1 ms to avoid lag
every 1 {
  global cursorRadius
  set coordinates [getRobotPosition .right.view]
  lassign $coordinates x y
  .right.view coords $::cursor [drawCircle $x $y $cursorRadius ]
  .right.view raise $::cursor
}

# Variables initialized for the main loop
set timeInsideTarget 0
set i 0
set currentTarget 0
set currentTarget_X 0
set currentTarget_Y 0
set previousTarget_X 0
set previousTarget_Y 0

set currentBlock 1
set currentTrial 0

# Skip the tuning and practice trials
if {$suppressTuning == 1 } {
  set currentTrial 80
  set currentBlock 9
}


# The first target is always in the neutral position, so make it based on the random range
set requiredTimeInsideTarget [randomInRange $neutralTimeRange]

# Main loop
every 10 {
  global studyStarted
  global targetRadius
  global cursorRadius
  global insideTargetColor
  global targetColor
  global targetPositionsInBlock
  global targetPositionsInBlock_X
  global targetPositionsInBlock_Y
  global timeInsideTarget
  global requiredTimeInsideTarget
  global neutralTimeRange
  global targetTime
  global targetRadius
  global currentTarget
  global currentTarget_X
  global currentTarget_Y
  global previousTarget_X
  global previousTarget_Y

  global target
  global i
  global targetOrientation
  global innerCursor
  global outerCursor
  global trialsPerBlock
  global currentBlock
  global blocks
  global currentTrial
  global totalTrials
  global pathLine
  
  global innerCursor_DP
  global outerCursor_DP
  global innerCursor_IE
  global outerCursor_IE

  global visualizeMVC
  
  if {$studyStarted == 1} {
    
    ######################################################################################
    # CODE BELOW ONLY USED FOR BLOCKS THAT ARE 2D (old code for 1D included in else clause)
    ######################################################################################
    
    if {$targetOrientation == "2D"} {
      # TODO: New code for target reaching in 2D
      
      # Find the position coordinates of the robot in degrees
      set coordinates [getRobotPosition .right.view]
      lassign $coordinates x y
      
      # Define outer edge of the curse in all four directions
      set innerCursor_DP [ expr $y - $cursorRadius ]
      set outerCursor_DP [ expr $y + $cursorRadius ]
      set innerCursor_IE [ expr $x - $cursorRadius ]
      set outerCursor_IE [ expr $x + $cursorRadius ]
      
      # Called at the start of every block, including block 1
      # Prevents the problem of the first trial of each block starting in the neutral without any waiting
      if {$i == 0 } {
        set requiredTimeInsideTarget 5000
      }
      
      # What happens when the subject/cursor is inside of the target
      if {[ expr $currentTarget_X - $targetRadius ] <= $innerCursor_IE && [ expr $currentTarget_X + $targetRadius ] >= $outerCursor_IE && [ expr $currentTarget_Y - $targetRadius ] <= $innerCursor_DP && [ expr $currentTarget_Y + $targetRadius ] >= $outerCursor_DP } {
        # Visual feedback that user is inside of target
        .right.view itemconfigure $::target -fill $insideTargetColor

        # Delete the previous pathLine when the target is hit
        .right.view delete pathLine
        
        # Start counting how long the user is in the the target in ms
        set timeInsideTarget [expr $timeInsideTarget + 10]
        
        # Once the subject has been in the target the required amount of time
        if {$timeInsideTarget >= $requiredTimeInsideTarget} {
          set i [expr $i + 1]
          
          # Called when all of the trials in the block are completed, not *2 like for 1D because no return to netural
          # Plus 1 to account for end block
          if {$i > [expr $trialsPerBlock + 1]} {
            # Calls the end command from the controller
            endBlock $currentBlock
            
            set currentBlock [expr $currentBlock + 1]
            # Reset the index to 0
            set i 0
          }
          
          # Finds the location of the next target
          # targetPositionsInBlock is technically a nested list, so the 0 cooresponds to the list, then i to the entry within that list
          #set currentTarget [lindex $targetPositionsInBlock 0 $i]
          set currentTarget_X [lindex $targetPositionsInBlock_X $i]
          set currentTarget_Y [lindex $targetPositionsInBlock_Y $i]

          # Previous target (used to draw straight line between the previous and current targets)
          set previousTarget_X [lindex $targetPositionsInBlock_X [expr $i - 1]]
          set previousTarget_Y [lindex $targetPositionsInBlock_Y [expr $i - 1]]
          
          # What happens after a target at a distance is met and new neutral target just appeared
          if {$currentTarget_X == 0 && $currentTarget_Y == 0} {
            # For 2D case, always send a 1 to signify target was shown in log
            sendTargetDistanceSignal $currentTarget_X $currentTarget_Y
            
            # Neutral target, random time range to be met (How long is needed to stay inside the target to meet the target)
            set requiredTimeInsideTarget [randomInRange $neutralTimeRange]
            
            # When i = 0, trial number is output twice: before and after the block
            # Therefore, only dispaly when i > 0
            if {$i > 1} {
              # Display the trial number, which was updated when the target at a distance was met
              #puts "Trial $currentTrial of $totalTrials complete"
              # Called before the return to neutral after the very last trial
              set currentTrial [expr $currentTrial + 1]
              endTrial $currentTrial
              #puts "Top ONE!"
              
              # Delete text that says "Go!"
              .right.view delete goText

              # Delete the previous pathLine
              .right.view delete pathLine
            }
            # What happens when a neutral target is met and a target at a distance has just appeared
          } else {
            # Targets at a distance, constant time range to be met
            set requiredTimeInsideTarget $targetTime
            
            # Where the trial number is being updated, but it is displayed in the if clause of this statement
            #puts $i
            if {$i > 1} {
              set currentTrial [expr $currentTrial + 1]
            }
            
            # Sends a signal to the controller that shows the distance of the target (just send a 1 for 2D)
            sendTargetDistanceSignal $currentTarget_X $currentTarget_Y
            
            # Play an audio file at the start of each trial, using a bash script
            exec bash /home/imt/imt/robot4/protocols/ankle/VariableDampingStudy/Supporting/playSound.sh &
            
            
            # Counts the trials, and deletes the previous Go! text
            if {$i > 1} {
              # Display the trial number, which was updated when the target at a distance was met
              #puts "Trial $currentTrial of $totalTrials complete"
              endTrial $currentTrial
              #puts "Bottom ONE!"
              
              # Delete text that says "Go!"
              .right.view delete goText

              # Delete the previous pathLine
              .right.view delete pathLine
            }
            
            # Show text that says "Go!" next to or above the target, depending on whether the trial is DP or IE
            if {$targetOrientation == "DP"} {
              .right.view create text [transformX 5 ] [transformY $currentTarget ] -text "Go!" -font [list Helvetica 50] -tags goText
            } elseif {$targetOrientation == "IE"} {
              .right.view create text [transformX $currentTarget ] [transformY 5 ] -text "Go!" -font [list Helvetica 50] -tags goText
            } elseif {$targetOrientation == "2D"} {
              # Same as for DP
              .right.view create text [transformX [expr $currentTarget_X + 5] ] [transformY $currentTarget_Y ] -text "Go!" -font [list Helvetica 50] -tags goText
            }
          }
          

          # Draw the new target
          .right.view coords $::target [drawCircle $currentTarget_X $currentTarget_Y $targetRadius ]

          # Draw a line to the target
          if {$i > 0} {
            .right.view create line [drawLine $previousTarget_X $previousTarget_Y $currentTarget_X $currentTarget_Y] -fill $targetColor -tags pathLine -width 3 -dash -
          }

          # Places the target on the correct coordinate axis for DP vs IE studies
          if {$targetOrientation == "DP"} {
            .right.view coords $::target [drawCircle 0 $currentTarget $targetRadius ]
          } elseif {$targetOrientation == "IE"} {
            .right.view coords $::target [drawCircle $currentTarget 0 $targetRadius ]
          } elseif {$targetOrientation == "2D"} {
            .right.view coords $::target [drawCircle $currentTarget_X $currentTarget_Y $targetRadius ]
          }
          
        }
        
        # Outside of the target
      } else {
        # Not inside of the target, so no visual feedback color and no timer
        .right.view itemconfigure $::target -fill $targetColor
        # Reset the timer for how long the user has been inside the target
        set timeInsideTarget 0
      }
      
      ###################################################################################
      # CODE ABOVE ONLY USED FOR BLOCKS THAT ARE 2D (old code for 1D included below)
      ###################################################################################
      
      
      # Moved all of the code from the previous study so that 1D blocks still function the same
      # Within this else clause is the old code from the 1D study
    } else {
      
      # Find the position coordinates of the robot in degrees
      set coordinates [getRobotPosition .right.view]
      lassign $coordinates x y
      
      # Find the correct range of the target position based on the study type
      if {$targetOrientation == "DP"} {
        set innerCursor [ expr $y - $cursorRadius ]
        set outerCursor [ expr $y + $cursorRadius ]
      } elseif {$targetOrientation == "IE"} {
        set innerCursor [ expr $x - $cursorRadius ]
        set outerCursor [ expr $x + $cursorRadius ]
      } else {
        puts "Error: targetOrientation is $targetOrientation but should be DP or IE"
      }
      
      # Called at the start of every block, including block 1
      # Prevents the problem of the first trial of each block starting in the neutral without any waiting
      if {$i == 0 } {
        set requiredTimeInsideTarget 5000
      }
      
      # What happens when the subject/cursor is inside of the target
      if {[ expr $currentTarget - $targetRadius ] <= $innerCursor && [ expr $currentTarget + $targetRadius ] >= $outerCursor} {
        # Visual feedback that user is inside of target
        .right.view itemconfigure $::target -fill $insideTargetColor
        
        # Start counting how long the user is in the the target in ms
        set timeInsideTarget [expr $timeInsideTarget + 10]
        
        # Once the subject has been in the target the required amount of time
        if {$timeInsideTarget >= $requiredTimeInsideTarget} {
          set i [expr $i + 1]
          
          # Called when all of the trials in the block are completed
          if {$i > [expr $trialsPerBlock * 2]} {
            # Calls the end command from the controller
            endBlock $currentBlock
            
            set currentBlock [expr $currentBlock + 1]
            
            
            # Reset the index to 0
            set i 0
          }
          
          # Finds the location of the next target
          # targetPositionsInBlock is technically a nested list, so the 0 cooresponds to the list, then i to the entry within that list
          #set currentTarget [lindex $targetPositionsInBlock 0 $i]
          # By predetermining the target positions, this is no longer a nested list, so the zero is not needed as in previous studies
          set currentTarget [lindex $targetPositionsInBlock $i]
          #puts $targetPositionsInBlock
          #puts "CurrentTarget:"
          #puts $currentTarget
          
          # What happens after a target at a distance is met and new neutral target just appeared
          if {$currentTarget == 0} {
            
            # Sends a signal to the controller that shows the distance of the target, will be 0 in this case
            if {$targetOrientation == "DP"} {
            	sendTargetDistanceSignal 0 $currentTarget
            } elseif {$targetOrientation == "IE"} {
            	sendTargetDistanceSignal $currentTarget 0
            }
            
            # Neutral target, random time range to be met (How long is needed to stay inside the target to meet the target)
            set requiredTimeInsideTarget [randomInRange $neutralTimeRange]
            
            # When i = 0, trial number is output twice: before and after the block
            # Therefore, only dispaly when i > 0
            if {$i > 0} {
              # Display the trial number, which was updated when the target at a distance was met
              #puts "Trial $currentTrial of $totalTrials complete"
              endTrial $currentTrial
              
              # Delete text that says "Go!"
              .right.view delete goText
            }
            
            # What happens when a neutral target is met and a target at a distance has just appeared
          } else {
            # Targets at a distance, constant time range to be met
            set requiredTimeInsideTarget $targetTime
            
            # Where the trial number is being updated, but it is displayed in the if clause of this statement
            set currentTrial [expr $currentTrial + 1]
            
            # Sends a signal to the controller that shows the distance of the target
            if {$targetOrientation == "DP"} {
            	sendTargetDistanceSignal 0 $currentTarget
            } elseif {$targetOrientation == "IE"} {
            	sendTargetDistanceSignal $currentTarget 0
            }
            
            # Play an audio file at the start of each trial, using a bash script
            exec bash /home/imt/imt/robot4/protocols/ankle/VariableDampingStudy/Supporting/playSound.sh &
            
            # Show text that says "Go!" next to or above the target, depending on whether the trial is DP or IE
            if {$targetOrientation == "DP"} {
              .right.view create text [transformX 5 ] [transformY $currentTarget ] -text "Go!" -font [list Helvetica 50] -tags goText
            } elseif {$targetOrientation == "IE"} {
              .right.view create text [transformX $currentTarget ] [transformY 5 ] -text "Go!" -font [list Helvetica 50] -tags goText
            }
          }
          
          # Draw the new target
          .right.view coords $::target [drawCircle $currentTarget 0 $targetRadius ]
          
          # Places the target on the correct coordinate axis for DP vs IE studies
          if {$targetOrientation == "DP"} {
            .right.view coords $::target [drawCircle 0 $currentTarget $targetRadius ]
          } elseif {$targetOrientation == "IE"} {
            .right.view coords $::target [drawCircle $currentTarget 0 $targetRadius ]
          }
        }
        
        # Outside of the target
      } else {
        # Not inside of the target, so no visual feedback color and no timer
        .right.view itemconfigure $::target -fill $targetColor
        # Reset the timer for how long the user has been inside the target
        set timeInsideTarget 0
      }
    }
  }

  if {$visualizeMVC == 1} {

    global emgMatrix_TA
    global emgMatrix_PL
    global emgMatrix_SL
    global emgMatrix_MG

    global mvc_time

    #puts "VISUALIZING MVC"

    #if {$mvc_time > -1 } {
    #  emgGraph destroy
    #}
    if {$mvc_time == -1} {
      # TA Graph
      #.right.view create text 150 80 -text "TA Response" -font [list Helvetica 20] -tags taText
      #emu_graph::emu_graph emgGraphTA -canvas .right.view -width 300 -height 300 -xref 100 -yref 100
      # PL Graph
      #.right.view create text 750 80 -text "PL Response" -font [list Helvetica 20] -tags plText
      #emu_graph::emu_graph emgGraphPL -canvas .right.view -width 300 -height 300 -xref 600 -yref 100

      # All in one (making separate graphs created too much lag)
      emu_graph::emu_graph emgGraph -canvas .right.view -width 600 -height 300 -xref 200 -yref 600
    }

    # If all y data is zero, the graph program crashes
    if {$mvc_time == -1} {
      set emgTA 0.0001
      set emgPL 0.0001
      set emgSL 0.0001
      set emgMG 0.0001
    } else {
      set emgTA [rshm emg1]
      set emgPL [rshm emg2]
      set emgSL [rshm emg3]
      set emgMG [rshm emg4]
    }
    #set emgTA [rshm ankle_ie_pos]

    set mvc_time [expr $mvc_time + 1]
    lappend emgMatrix_TA $mvc_time
    lappend emgMatrix_TA $emgTA

    lappend emgMatrix_PL $mvc_time
    lappend emgMatrix_PL $emgPL

    lappend emgMatrix_SL $mvc_time
    lappend emgMatrix_SL $emgSL

    lappend emgMatrix_MG $mvc_time
    lappend emgMatrix_MG $emgMG

    # Don't let the matricies get larger than 300 timesteps
    set emgMatrix_TA [lrange $emgMatrix_TA end-299 end]
    set emgMatrix_PL [lrange $emgMatrix_PL end-299 end]
    set emgMatrix_SL [lrange $emgMatrix_SL end-299 end]
    set emgMatrix_MG [lrange $emgMatrix_MG end-299 end]

    #puts $emgMatrix_TA

    if {$mvc_time > 5 } {
      emgGraph data d1 -colour blue -points 0 -lines 1 -coords $emgMatrix_TA
      emgGraph data d2 -colour red -points 0 -lines 1 -coords $emgMatrix_PL
      emgGraph data d3 -colour green -points 0 -lines 1 -coords $emgMatrix_SL
      emgGraph data d4 -colour yellow -points 0 -lines 1 -coords $emgMatrix_MG
    }


  }

}