## View.tcl
# Created by James Arnold

package require Tk
#package provide snack 2.2 (doesn't work yet)
source newController.tcl

# ---------------Study Specifications------------------

# Degrees from the center for the target
set targetDistance 7.5

# Time required to meet targets, in ms
set targetTime 2000
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
set degreeRange 24

# Spacing in degrees of the background grid
set gridSpacing 1

# Pixels over degrees scaling factor (converts degrees to pixels)
set scale [expr $canvasWidth / $degreeRange ]

# Button names (cannot include spaces)
set buttonList {"Gravity" "Start"}

# Colors
set black "#000000"
set backgroundColor1 "#B3DB8E"
set backgroundColor2 "#F3FFE0"
set cursorColor "#DF0E39"
set targetColor "#00B0F0"
set gridColor "#A0B58B"
set insideTargetColor "#FFD45C"

# -------------------Functions------------------------

# Play a .wav audio file (does't work yet)
#proc playwav myWavFile { 
#    snack::sound s -file $myWavFile
#    s play -block 1
#}

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
        set targetPositionsInBlock [targetPosition $trialsPerBlock]

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

# Function that generates the postion of the target for each trial

set direction rand()
proc targetPosition {trials} {
    global targetDistance
    global targetPositionsInBlock
    global trialsPerBlock
    global blocks
    global direction
   

    set directionList [list -1 1 -1 -1 -1 1 1 -1 1 1]
    set direction 0
    set listLength [llength $directionList]

    # Each trial after the intial neutral is either {1, 0} or {-1, 0} for going to the target and returning
    for {set i 0} {$i <= [ expr {$trials - 1}]} {incr i} {

        
        if {$direction < 0.5} {

            lappend targetPositionsInBlock [expr {int([lindex $directionList 0] * $targetDistance)} ]
            set directionList [lreplace $directionList 0 0]
            set listLength [llength $directionList]
        } else {

            lappend targetPositionsInBlock [expr {int([lindex $directionList [expr {int($listLength - 1)}]] * $targetDistance)}]
            set directionList [lreplace $directionList [expr {$listLength - 1}] [expr {$listLength - 1}]]
            set listLength [llength $directionList]
        }

        lappend targetPositionsInBlock 0 
        set direction rand()
    }
    list $targetPositionsInBlock
}

    # Ouputs the final vector in the form of {0, 1, 0, -1, 0, 1...}*targetDistance
    

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
wm title . [concat "Variable Damping Study - " $studyType ]

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
    global studyType
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
        if {$studyType == "DP"} {
            set innerCursor [ expr $y - $cursorRadius ]
            set outerCursor [ expr $y + $cursorRadius ]
        } elseif {$studyType == "IE"} {
            set innerCursor [ expr $x - $cursorRadius ]
            set outerCursor [ expr $x + $cursorRadius ]
        } else {
            puts "Error: studyType is $studyType but should be DP or IE"
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
                set currentTarget [lindex $targetPositionsInBlock 0 $i]

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
      				if {$studyType == "DP"} {
                    	.right.view create text [transformX 5 ] [transformY $currentTarget ] -text "Go!" -font [list Helvetica 50] -tags goText
                	} elseif {$studyType == "IE"} {
                    	.right.view create text [transformX $currentTarget ] [transformY 5 ] -text "Go!" -font [list Helvetica 50] -tags goText
               		 }
                }

                # Draw the new target
                .right.view coords $::target [drawCircle $currentTarget 0 $targetRadius ]

        		# Places the target on the correct coordinate axis for DP vs IE studies
                if {$studyType == "DP"} {
                    .right.view coords $::target [drawCircle 0 $currentTarget $targetRadius ]
                } elseif {$studyType == "IE"} {
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