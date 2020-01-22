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
    if {$i > [expr $trialsPerBlock]} {
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
      
      # Sends a signal to the controller that shows the distance of the target (just send a 1 for 2D)
      sendTargetDistanceSignal 1
      
      # Play an audio file at the start of each trial, using a bash script
      exec bash /home/imt/imt/robot4/protocols/ankle/VariableDampingStudy/Supporting/playSound.sh &
      
      # Show text that says "Go!" next to or above the target, depending on whether the trial is DP or IE
      if {$targetOrientation == "DP"} {
        .right.view create text [transformX 5 ] [transformY $currentTarget ] -text "Go!" -font [list Helvetica 50] -tags goText
      } elseif {$targetOrientation == "IE"} {
        .right.view create text [transformX $currentTarget ] [transformY 5 ] -text "Go!" -font [list Helvetica 50] -tags goText
      } elseif {$targetOrientation == "2D"} {
        # Same as for DP
        .right.view create text [transformX 5 ] [transformY $currentTarget ] -text "Go!" -font [list Helvetica 50] -tags goText
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















