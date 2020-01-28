## View2D.tcl
# Created by James Arnold

package require Tk
source Controller2D.tcl

# ---------------Study Specifications------------------

# Degrees from the center for the target
# This study uses different, prerandomized target distances for each trial, so not needed
#set targetDistance 7.5

# Time required to meet targets, in ms
set targetTime 2000
# No time randomization in this study, but still used for tuning trials
set neutralTimeRange [list 1500 4000]

# Radii of the cursor and target in degrees
set cursorRadius 1
set targetRadius 2

# --------------Initialized Variables-----------------

set studyStarted 0
set targetPositionsInBlock 0

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
set buttonList {"Gravity" "Start"}

# Colors
set black "#000000"
set backgroundColor1 "#CCF2F2"
set backgroundColor2 "#7ADDDD"
set cursorColor "#DF0E39"
set targetColor "#00B0F0"
set gridColor "#97B2B5"
set insideTargetColor "#FFD45C"

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
  
  # Actions when buttons are pressed
  set buttonNumber [lsearch $buttonList $place]
  
  if {$buttonNumber == 0} {
    # Call gravity compensation function from controller
    gravityComp
    
    # Once the gravity is compensated, make the x axis, y axis, and center visible
    .right.view itemconfigure $::center -fill $black
    .right.view coords $::center [drawCircle 0 0 0.25 ]
    .right.view itemconfigure $::xAxis -fill $black
    .right.view itemconfigure $::yAxis -fill $black
    
    # Disable the button after it has been pressed
    .left.[string tolower [lindex $buttonList $buttonNumber]] configure -state disabled
    
  } elseif {$buttonNumber == 1} {
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
    
  } elseif {$buttonNumber == 2} {
    #neutralReturn
  } else {
    puts "Unknown button command"
  }
}

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
# Practice set of 3 pairs
set targetPositionsInBlock7_X [list 0.000 -5.595 1.985 -3.323 6.863 -5.136 4.504 -1.174 4.383 -6.964 6.510 0.000]
set targetPositionsInBlock7_Y [list 0.000 12.401 -12.074 1.406 13.947 -0.439 -10.743 12.472 4.672 10.474 5.362 0.000]

set targetPositionsInBlock8_X [list 0.000 6.889 -5.261 6.439 -4.551 -0.401 4.962 0.746 -3.212 1.017 -6.691 0.000]
set targetPositionsInBlock8_Y [list 0.000 -10.841 10.222 -4.500 3.481 -4.450 2.558 12.516 -3.587 -12.724 0.924 0.000]

set targetPositionsInBlock9_X [list 0.000 -4.772 5.539 0.748 5.295 -2.236 -6.360 -1.241 6.672 -0.161 4.204 0.000]
set targetPositionsInBlock9_Y [list 0.000 -7.086 2.391 -10.651 3.662 -2.946 -11.300 12.081 -0.274 12.002 -11.664 0.000]

# The rest are pairs of x and y vectors cooresponding to the following 15 blocks for data collection
# First set of three pairs
set targetPositionsInBlock10_X [list 0.000 3.806 -6.691 4.188 -5.551 -0.459 4.414 0.428 -3.555 4.887 0.575 6.928 -6.233 -3.602 -1.029 -3.543 0.000]
set targetPositionsInBlock10_Y [list 0.000 -12.724 0.924 13.020 2.065 -14.643 -5.664 3.059 -12.485 12.400 -12.655 8.247 -3.007 9.002 -9.545 11.079 0.000]

set targetPositionsInBlock11_X [list 0.000 -5.326 1.831 -6.360 -1.241 6.672 -0.161 4.204 -1.654 -6.053 6.631 1.128 -3.978 4.818 -6.855 3.476 0.000]
set targetPositionsInBlock11_Y [list 0.000 10.591 -4.471 -11.300 12.081 -0.274 12.002 -11.664 -2.883 -11.041 13.684 -13.207 -4.405 -14.538 4.473 -1.472 0.000]

set targetPositionsInBlock12_X [list 0.000 -4.644 2.171 -4.636 1.343 -3.143 7.240 3.454 6.095 -3.589 1.415 -1.121 -5.078 1.478 -6.996 0.463 0.000]
set targetPositionsInBlock12_Y [list 0.000 14.449 -3.712 -11.382 -3.461 3.513 9.731 -4.684 -11.767 9.533 -14.325 -5.618 -12.173 -0.872 5.997 -5.412 0.000]

# Next set of three pairs
set targetPositionsInBlock13_X [list 0.000 -6.546 1.918 7.091 -5.417 0.455 5.417 0.301 -5.250 3.824 -3.858 2.817 -1.579 -7.206 -4.544 -1.051 0.000]
set targetPositionsInBlock13_Y [list 0.000 7.905 12.986 -9.239 5.888 0.762 7.238 -4.569 2.583 -13.666 -1.728 7.090 -1.731 -6.892 9.652 -3.265 0.000]

set targetPositionsInBlock14_X [list 0.000 4.628 -1.839 4.356 -2.587 4.033 0.216 5.764 -5.179 -1.396 4.884 0.511 -5.824 -0.072 -6.675 0.908 0.000]
set targetPositionsInBlock14_Y [list 0.000 7.652 -8.519 13.479 5.138 -9.982 14.696 2.641 -9.004 7.461 -5.444 -12.301 5.360 -9.309 10.521 2.484 0.000]

set targetPositionsInBlock15_X [list 0.000 -5.927 4.266 1.553 -1.013 3.871 6.506 -4.688 -0.186 -3.406 2.599 -0.724 -6.609 4.091 -5.620 -1.153 0.000]
set targetPositionsInBlock15_Y [list 0.000 -11.631 -6.253 13.933 5.843 -2.021 -11.707 8.935 -3.120 -13.883 -2.113 3.296 -5.526 5.893 -11.095 4.667 0.000]

# Final set of three pairs
set targetPositionsInBlock16_X [list 0.000 -5.868 -2.738 5.894 0.836 -4.320 3.101 -2.799 1.837 -4.944 -1.548 2.761 7.243 -5.184 5.567 -2.238 0.000]
set targetPositionsInBlock16_Y [list 0.000 -11.205 -5.507 6.097 -9.467 12.414 1.734 -10.014 14.638 -7.266 -12.780 -2.928 3.620 -3.560 7.743 -6.176 0.000]

set targetPositionsInBlock17_X [list 0.000 3.513 6.861 -4.143 -6.824 3.348 -7.175 4.508 1.759 -3.771 -0.725 7.292 0.535 7.337 2.758 5.985 0.000]
set targetPositionsInBlock17_Y [list 0.000 -9.694 12.737 -3.793 4.203 -4.577 12.317 -3.501 2.265 -6.748 9.133 -14.100 9.063 -12.992 8.512 -10.864 0.000]

set targetPositionsInBlock18_X [list 0.000 -6.873 1.747 -2.183 7.265 2.650 -2.450 0.418 3.758 -6.261 7.442 -0.680 4.243 -6.860 -1.827 3.443 0.000]
set targetPositionsInBlock18_Y [list 0.000 -11.792 13.190 -2.681 13.367 8.005 -7.675 5.405 0.355 6.587 -4.364 -11.230 6.783 -14.706 6.130 -8.272 0.000]


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
pack [button .left.quit -text "End" -command done] -side bottom
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
wm title . [concat "Variable Damping Study - 2D" ]

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
emu_graph::emu_graph responseGraph -canvas .right.view -width 600 -height 300 -xref 200 -yref 600


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
set currentBlock 1
# Added for faster testing YOYOYOYO
#set currentBlock 4
set currentTrial 0
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
  
  global innerCursor_DP
  global outerCursor_DP
  global innerCursor_IE
  global outerCursor_IE
  
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
          
          # What happens after a target at a distance is met and new neutral target just appeared
          if {$currentTarget_X == 0 && $currentTarget_Y == 0} {
            # For 2D case, always send a 1 to signify target was shown in log
            sendTargetDistanceSignal 1
            
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
            sendTargetDistanceSignal 1
            
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
            sendTargetDistanceSignal $currentTarget
            
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
            sendTargetDistanceSignal $currentTarget
            
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
}