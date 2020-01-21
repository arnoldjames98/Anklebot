## View.tcl
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
set targetRadius 1.5

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
    	puts "drawGradient"
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
set targetPositionsInBlock1_IE [list 0.000 2.908 0.000 -6.122 0.000 -2.903 0.000 5.172 0.000 -7.490 0.000 6.866 0.000 -5.535 0.000 4.507 0.000 -5.440 0.000 4.283 0.000]
set targetPositionsInBlock2_IE [list 0.000 -5.939 0.000 5.330 0.000 3.508 0.000 -5.096 0.000 -4.852 0.000 2.801 0.000 7.195 0.000 -2.609 0.000 5.918 0.000 -2.840 0.000]
# These are both for the y direction
set targetPositionsInBlock3_DP [list 0.000 7.013 0.000 -10.296 0.000 -5.578 0.000 -7.589 0.000 6.240 0.000 -14.088 0.000 6.001 0.000 5.397 0.000 -10.520 0.000 12.875 0.000]
set targetPositionsInBlock4_DP [list 0.000 6.076 0.000 -8.349 0.000 7.239 0.000 10.420 0.000 -10.900 0.000 -14.830 0.000 7.944 0.000 -13.296 0.000 -7.408 0.000 7.746 0.000]

# The rest are pairs of x and y vectors cooresponding to the following 15 blocks
# First set of 5 pairs
set targetPositionsInBlock5_X [list 0.000 6.953 2.507 -7.211 2.270 -4.031 5.762 -6.789 -2.364 4.420 -6.678 0.000]
set targetPositionsInBlock5_Y [list 0.000 -13.731 2.593 -4.169 14.244 -2.895 -12.172 -3.029 7.079 1.347 11.809 0.000]

set targetPositionsInBlock6_X [list 0.000 2.504 6.506 -0.232 7.077 -0.679 -3.800 5.743 1.483 5.996 -4.415 0.000]
set targetPositionsInBlock6_Y [list 0.000 -12.838 9.329 -2.489 14.639 -3.333 8.533 1.749 -10.534 -1.488 11.990 0.000]

set targetPositionsInBlock7_X [list 0.000 -3.807 3.335 -6.593 -2.637 -7.325 1.967 5.390 1.063 -6.434 5.816 0.000]
set targetPositionsInBlock7_Y [list 0.000 13.527 -2.998 -10.970 -5.948 1.197 -10.605 14.227 1.606 -5.080 -13.061 0.000]

set targetPositionsInBlock8_X [list 0.000 2.906 -5.860 -1.651 -6.745 5.013 0.003 2.567 -6.660 -0.972 1.761 0.000]
set targetPositionsInBlock8_Y [list 0.000 13.356 6.167 -1.219 -8.139 -14.531 -8.460 2.988 -13.310 9.967 0.604 0.000]

set targetPositionsInBlock9_X [list 0.000 -7.002 -2.671 -6.769 0.791 -3.877 6.535 -4.863 2.994 -0.914 3.923 0.000]
set targetPositionsInBlock9_Y [list 0.000 6.495 -4.904 1.457 -6.756 13.692 6.848 -4.189 -14.964 1.292 7.872 0.000]

# Next set of 5 pairs
set targetPositionsInBlock10_X [list 0.000 -6.118 2.584 -7.354 0.484 6.097 -7.127 5.058 -6.646 1.237 -1.892 0.000]
set targetPositionsInBlock10_Y [list 0.000 -11.303 -2.055 -7.296 13.387 -3.219 5.143 14.145 -1.490 5.599 -11.516 0.000]

set targetPositionsInBlock11_X [list 0.000 6.860 -6.145 6.166 1.141 -1.442 -6.150 0.171 3.385 0.440 5.381 0.000]
set targetPositionsInBlock11_Y [list 0.000 -9.822 10.757 -8.103 9.319 14.653 -5.372 -13.182 1.697 9.899 -5.465 0.000]

set targetPositionsInBlock12_X [list 0.000 3.524 0.642 -2.833 -7.360 2.141 -7.044 -0.676 3.406 -0.952 -6.756 0.000]
set targetPositionsInBlock12_Y [list 0.000 13.623 1.203 -12.863 12.451 -14.957 -8.746 -14.741 -4.377 -13.524 2.821 0.000]

set targetPositionsInBlock13_X [list 0.000 4.785 -0.036 3.827 -0.640 5.026 1.241 5.324 -6.954 3.692 -5.341 0.000]
set targetPositionsInBlock13_Y [list 0.000 7.157 -12.983 7.272 -10.305 12.966 2.476 -13.954 -2.768 -10.355 3.179 0.000]

set targetPositionsInBlock14_X [list 0.000 4.221 -5.556 6.412 1.390 -4.987 7.490 -4.295 6.542 2.748 -0.930 0.000]
set targetPositionsInBlock14_Y [list 0.000 7.346 -7.722 -13.461 10.152 0.066 -13.588 -3.065 -8.112 13.863 -14.825 0.000]

# Final set of 5 pairs
set targetPositionsInBlock15_X [list 0.000 -4.005 3.949 -4.148 4.949 -3.143 5.431 2.638 -3.766 4.508 -2.182 0.000]
set targetPositionsInBlock15_Y [list 0.000 12.974 2.204 -5.129 2.536 -2.923 3.442 -8.889 -0.726 -11.848 10.233 0.000]

set targetPositionsInBlock16_X [list 0.000 -5.873 1.771 6.929 2.438 -3.602 0.603 -6.615 5.851 -4.054 2.280 0.000]
set targetPositionsInBlock16_Y [list 0.000 -13.917 2.014 7.383 0.699 13.860 -14.092 0.591 -5.094 -11.582 -6.545 0.000]

set targetPositionsInBlock17_X [list 0.000 3.839 -5.791 5.229 -0.507 -6.969 -1.384 4.581 -6.717 -4.205 6.878 0.000]
set targetPositionsInBlock17_Y [list 0.000 8.498 14.357 -13.481 -5.230 0.414 -11.759 -1.474 11.167 -1.211 8.701 0.000]

set targetPositionsInBlock18_X [list 0.000 7.095 -5.686 5.962 -0.005 -7.060 4.907 1.222 -6.783 1.479 -5.790 0.000]
set targetPositionsInBlock18_Y [list 0.000 -5.726 12.473 -5.036 3.459 -14.038 -4.800 13.130 -13.381 5.444 -12.894 0.000]

set targetPositionsInBlock19_X [list 0.000 6.575 0.497 -3.484 6.415 -3.009 4.476 -3.999 5.068 -0.027 7.113 0.000]
set targetPositionsInBlock19_Y [list 0.000 -7.337 13.643 -7.497 -12.943 2.748 8.879 3.025 12.624 -6.672 12.519 0.000]

# Initialize the targets for the first block
set targetPositionsInBlock $targetPositionsInBlock1_IE

# Function that generates a random interger in a range
proc randomInRange {range} {
    set min [lindex $range 0]
    set max [lindex $range 1]
    puts "Random in range"
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
puts "max size"
wm maxsize . [expr int($w*1)] [expr int($h*1)]

# Title on the top of the window
wm title . [concat "Variable Damping Study - " $targetOrientation ]

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
emu_graph::emu_graph foo -canvas .right.view -width 600 -height 300 -xref 200 -yref 600


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
set currentBlock 1
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
    global timeInsideTarget
    global requiredTimeInsideTarget
    global neutralTimeRange
    global targetTime
    global targetRadius
    global currentTarget
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

    if {$studyStarted == 1} {
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
                puts "trialsPerBlock"
                if {$i > [expr $trialsPerBlock * 2]} {
                	puts "trialsPerBlockINSIDE"
                    # Calls the end command from the controller
                    endBlock $currentBlock

                    set currentBlock [expr $currentBlock + 1]
                    # Reset the index to 0
                    set i 0
                }

                # Finds the location of the next target
                # targetPositionsInBlock is technically a nested list, so the 0 cooresponds to the list, then i to the entry within that list
                #set currentTarget [lindex $targetPositionsInBlock 0 $i]
				set currentTarget [lindex $targetPositionsInBlock $i]
                puts $targetPositionsInBlock

                puts "CurrentTarget:"
                puts $currentTarget

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