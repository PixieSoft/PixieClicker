#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=PixieClicker.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Comment=PixieClicker - Automated Mouse Clicker for Roblox and other games.
#AutoIt3Wrapper_Res_Description=PixieClicker - Automated Mouse Clicker for Roblox and other games.
#AutoIt3Wrapper_Res_Fileversion=1.1.0.0
#AutoIt3Wrapper_Res_FileVersion_AutoIncrement=n
#AutoIt3Wrapper_Res_ProductVersion=1.1.0.0
#AutoIt3Wrapper_Res_CompanyName=PixieSoft
#AutoIt3Wrapper_Res_LegalCopyright=Copyright © 2025
#AutoIt3Wrapper_Run_AU3Check=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

; Change Log
; 04/02/25 - Initial release.
; 04/24/25 - Warning boxes no longer steal focus and have colored backgrounds.



; =================
; PixieClicker.au3
; =================
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <MsgBoxConstants.au3>
#include <Array.au3>
#include <GuiEdit.au3> ; Required for Edit control scrolling

; Registry key constants
; Application information constants
Global Const $APP_NAME = "PixieClicker"
Global Const $APP_VERSION = "1.1.0"
Global Const $REGISTRY_KEY = "HKEY_CURRENT_USER\Software\" & $APP_NAME

; Initialize variables
Global $aScreenSize = _GetDesktopSize()
Global $hGUI = 0
Global $iTimerCount = 2 ; Start with 2 timers (default)
Global $iRowHeight = 30 ; Height of each timer row
Global $iBaseHeight = 150 ; Base height for GUI with minimum timers

; Structure to store timer data
; Added Label column as index 4
Global $aTimerData[2][5] ; [timer_index][0=X, 1=Y, 2=Minutes, 3=Active, 4=Label]
Global $aTimerMinutesValue[2] ; Direct tracking of minutes value
Global $aTimerInterval[2] ; Store the actual interval in milliseconds

; Initialize with default values
For $i = 0 To 1
    $aTimerData[$i][0] = 0    ; X coordinate
    $aTimerData[$i][1] = 0    ; Y coordinate
    $aTimerData[$i][2] = 10   ; Minutes
    $aTimerData[$i][3] = False ; Active state
    $aTimerData[$i][4] = "Timer " & ($i + 1) ; Default label name
    $aTimerMinutesValue[$i] = 10
    $aTimerInterval[$i] = 10 * 60 * 1000 ; 10 minutes in milliseconds
Next

; Structure to store timer control IDs
; Added label input control as index 8
; [timer_index][0=X input, 1=Y input, 2=Record button, 3=Minutes input, 4=Toggle button, 5=Time remaining, 6=Remove button, 7=Add button, 8=Label input]
Global $aTimerControls[2][9]

; Additional timer state tracking
Global $aTimerLastRun[2] ; Last time the timer was run
Global $aTimerRecording[2] ; Recording state (are we currently recording position for this timer)
For $i = 0 To 1
    $aTimerLastRun[$i] = 0
    $aTimerRecording[$i] = False
Next

; Global controls
Global $idStatusText = 0 ; Changed from $idStatus to $idStatusText to reflect new control type
Global $idCloseButton = 0
Global $idRecentStatusLabel = 0 ; Added label for most recent status message
Global $sStatusHistory = "" ; Added to preserve status history during GUI redraws

; Main application entry point
Func Main()
    ; Load configuration from registry
    LoadConfiguration()
    
    ; Create the initial GUI
    CreateCompleteGUI()
    
    ; Main loop
    While 1
        $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $idCloseButton
                ; Save configuration before exiting
                SaveConfiguration()
                ExitLoop
                
            ; Check for other control interactions
            Case Else
                ; Process timer-specific controls using direct ID matching
                For $i = 0 To $iTimerCount - 1
                    ; Check if record button was clicked
                    If $nMsg = $aTimerControls[$i][2] Then ; Record button
                        $aTimerRecording[$i] = True
                        AddStatusMessage("Click anywhere to record position for " & $aTimerData[$i][4] & "...")
                        ExitLoop
                    EndIf
                    
                    ; Check if toggle button was clicked
                    If $nMsg = $aTimerControls[$i][4] Then ; Toggle button
                        ToggleTimer($i)
                        ExitLoop
                    EndIf
                    
                    ; Check if remove button was clicked
                    If $nMsg = $aTimerControls[$i][6] Then ; Remove button
                        RemoveTimer($i)
                        ExitLoop
                    EndIf
                    
                    ; Check if add button was clicked
                    If $nMsg = $aTimerControls[$i][7] Then ; Add button
                        AddTimer($i)
                        ExitLoop
                    EndIf
                Next
        EndSwitch
        
        ; Handle recording mode if active for any timer
        For $i = 0 To $iTimerCount - 1
            If $aTimerRecording[$i] And _IsPressed("01") Then ; 01 is the hex code for left mouse button
                $aPos = MouseGetPos()
                $aTimerData[$i][0] = $aPos[0] ; X coordinate
                $aTimerData[$i][1] = $aPos[1] ; Y coordinate
                
                ; Update the GUI labels instead of input fields
                GUICtrlSetData($aTimerControls[$i][0], $aPos[0]) ; X label
                GUICtrlSetData($aTimerControls[$i][1], $aPos[1]) ; Y label
                
                ; Get the current label for this timer
                Local $sLabel = GUICtrlRead($aTimerControls[$i][8])
                If $sLabel = "" Then
                    $sLabel = "Timer " & ($i + 1)
                    GUICtrlSetData($aTimerControls[$i][8], $sLabel)
                EndIf
                
                AddStatusMessage("Recorded position for " & $sLabel & ": X=" & $aPos[0] & ", Y=" & $aPos[1], $sLabel)
                $aTimerRecording[$i] = False
                
                ; Update registry with the new position
                RegWrite($REGISTRY_KEY & "\Timer" & $i, "X", "REG_DWORD", $aPos[0])
                RegWrite($REGISTRY_KEY & "\Timer" & $i, "Y", "REG_DWORD", $aPos[1])
                
                Sleep(500) ; To prevent double-clicking issues
            EndIf
        Next
        
        ; Check active timers
        For $i = 0 To $iTimerCount - 1
            If $aTimerData[$i][3] Then ; If timer is active
                ; Always read the current minutes value
                Local $iCurrentMinutes = Number(GUICtrlRead($aTimerControls[$i][3]))
                If $iCurrentMinutes > 0 Then
                    ; Update our stored values if valid
                    $aTimerMinutesValue[$i] = $iCurrentMinutes
                    $aTimerData[$i][2] = $iCurrentMinutes
                    $aTimerInterval[$i] = $iCurrentMinutes * 60 * 1000
                EndIf
                
                ; Get coordinates
                $iX = $aTimerData[$i][0]
                $iY = $aTimerData[$i][1]
                
                ; Read label value
                Local $sLabel = GUICtrlRead($aTimerControls[$i][8])
                If $sLabel = "" Then
                    $sLabel = "Timer " & ($i + 1)
                    GUICtrlSetData($aTimerControls[$i][8], $sLabel)
                EndIf
                $aTimerData[$i][4] = $sLabel
                
                ; Validate parameters before clicking
                If Not ValidateClickParams($iX, $iY, $aTimerMinutesValue[$i], $sLabel) Then
                    $aTimerData[$i][3] = False ; Deactivate timer
                    GUICtrlSetData($aTimerControls[$i][4], "OFF") ; Toggle button
                    GUICtrlSetBkColor($aTimerControls[$i][4], 0xFF0000) ; Red background for OFF
                    
                    ; Update registry to reflect deactivated timer
                    RegWrite($REGISTRY_KEY & "\Timer" & $i, "Active", "REG_DWORD", $aTimerData[$i][3])
                    
                    ContinueLoop
                EndIf
                
                ; Calculate time remaining using the interval
                Local $iTimeDiff = TimerDiff($aTimerLastRun[$i])
                Local $iTimeRemaining = $aTimerInterval[$i] - $iTimeDiff
                
                If $iTimeRemaining <= 0 Then
                    PerformClick($iX, $iY, $sLabel)
                    AddStatusMessage("Clicks completed (interval: " & $aTimerMinutesValue[$i] & " minutes)", $sLabel)
                    $aTimerLastRun[$i] = TimerInit()
                    $iTimeRemaining = $aTimerInterval[$i]
                EndIf
                
                ; Update time remaining display
                Local $iMinRemaining = Floor($iTimeRemaining / (60 * 1000))
                Local $iSecRemaining = Floor(($iTimeRemaining - ($iMinRemaining * 60 * 1000)) / 1000)
                GUICtrlSetData($aTimerControls[$i][5], StringFormat("%02d:%02d", $iMinRemaining, $iSecRemaining))
            Else
                GUICtrlSetData($aTimerControls[$i][5], "--:--") ; Time remaining
            EndIf
        Next
        
        Sleep(100) ; Reduce CPU usage
    WEnd
    
    ; Clean up and exit
    GUIDelete($hGUI)
    Exit
EndFunc

; Save configuration to registry
Func SaveConfiguration()
    ; Create or open the registry key
    RegWrite($REGISTRY_KEY)
    
    ; Save number of timers with the new name
    RegWrite($REGISTRY_KEY, "Timers", "REG_DWORD", $iTimerCount)
    
    ; First, clean up any existing timer keys that may be outdated
    ; This handles the case where we previously had more timers than we do now
    Local $i = 0
    Local $sSubKey = ""
    
    ; Loop through all subkeys
    While 1
        $sSubKey = RegEnumKey($REGISTRY_KEY, $i)
        If @error Then ExitLoop ; No more keys or error
        
        ; If this is a Timer key and its index is beyond our current count, delete it
        If StringRegExp($sSubKey, "^Timer\d+$") And Number(StringReplace($sSubKey, "Timer", "")) >= $iTimerCount Then
            RegDelete($REGISTRY_KEY & "\" & $sSubKey)
        Else
            $i += 1 ; Only increment if we didn't delete a key
        EndIf
    WEnd
    
    ; Save each timer's data
    For $i = 0 To $iTimerCount - 1
        ; Get the current label from the control
        Local $sLabel = GUICtrlRead($aTimerControls[$i][8])
        If $sLabel = "" Then
            $sLabel = "Timer " & ($i + 1)
        EndIf
        $aTimerData[$i][4] = $sLabel
        
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "X", "REG_SZ", String($aTimerData[$i][0]))
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "Y", "REG_SZ", String($aTimerData[$i][1]))
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "Minutes", "REG_DWORD", $aTimerData[$i][2])
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "Active", "REG_DWORD", $aTimerData[$i][3])
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "Label", "REG_SZ", $aTimerData[$i][4])
    Next
    
    AddStatusMessage("Configuration saved successfully to registry!", "System")
    Return True
EndFunc

; Load configuration from registry
Func LoadConfiguration()
    ; Check if main key exists with the new name "Timers"
    If Not RegRead($REGISTRY_KEY, "Timers") Then
        ; Also check the old name for backward compatibility
        If Not RegRead($REGISTRY_KEY, "TimerCount") Then
            AddStatusMessage("No configuration found in registry. Using defaults.")
            Return False
        Else
            ; If found with old name, use it and we'll save with the new name later
            $iTimerCount = Number(RegRead($REGISTRY_KEY, "TimerCount"))
            ; Delete the old key
            RegDelete($REGISTRY_KEY, "TimerCount")
            AddStatusMessage("Migrated from old configuration format.")
        EndIf
    Else
        ; Use the new name
        $iTimerCount = Number(RegRead($REGISTRY_KEY, "Timers"))
    EndIf
    
    If $iTimerCount < 1 Then $iTimerCount = 2 ; Ensure at least one timer
    
    ; Resize arrays
    ReDim $aTimerData[$iTimerCount][5] ; Updated to include label column
    ReDim $aTimerControls[$iTimerCount][9] ; Updated to include label control
    ReDim $aTimerLastRun[$iTimerCount]
    ReDim $aTimerRecording[$iTimerCount]
    ReDim $aTimerMinutesValue[$iTimerCount]
    ReDim $aTimerInterval[$iTimerCount]
    
    ; Read each timer's data
    For $i = 0 To $iTimerCount - 1
        $aTimerData[$i][0] = Number(RegRead($REGISTRY_KEY & "\Timer" & $i, "X"))
        $aTimerData[$i][1] = Number(RegRead($REGISTRY_KEY & "\Timer" & $i, "Y"))
        $aTimerData[$i][2] = Number(RegRead($REGISTRY_KEY & "\Timer" & $i, "Minutes"))
        $aTimerData[$i][3] = Number(RegRead($REGISTRY_KEY & "\Timer" & $i, "Active"))
        
        ; Read label, with fallback to default
        $aTimerData[$i][4] = RegRead($REGISTRY_KEY & "\Timer" & $i, "Label")
        If @error Or $aTimerData[$i][4] = "" Then 
            $aTimerData[$i][4] = "Timer " & ($i + 1)
        EndIf
        
        ; Apply defaults if registry values are missing or invalid
        If @error Or $aTimerData[$i][2] <= 0 Then $aTimerData[$i][2] = 10
        
        $aTimerMinutesValue[$i] = $aTimerData[$i][2]
        $aTimerInterval[$i] = $aTimerData[$i][2] * 60 * 1000
        $aTimerLastRun[$i] = TimerInit()
        $aTimerRecording[$i] = False
    Next
    
    AddStatusMessage("Configuration loaded successfully from registry!", "System")
    Return True
EndFunc

; Creates the complete GUI from scratch
; Creates the complete GUI from scratch
; Creates the complete GUI from scratch
Func CreateCompleteGUI()
    ; If GUI already exists, delete it
    If $hGUI <> 0 Then
        GUIDelete($hGUI)
    EndIf
    
    ; Calculate the height based on number of timers
    Local $iGUIHeight = $iBaseHeight + (($iTimerCount - 2) * $iRowHeight) + 125
    
    ; Create the main GUI with increased width to accommodate wider layout
    ; Use the APP_NAME and APP_VERSION constants in the title
    $hGUI = GUICreate($APP_NAME & " " & $APP_VERSION, 595, $iGUIHeight + 35, Default, Default, Default, $WS_EX_TOPMOST)

    ; Create each timer row
    For $i = 0 To $iTimerCount - 1
        CreateTimerRow($i)
    Next
    
    ; Create Recent Status label in a group box for visual separation
    GUICtrlCreateGroup("Status", 10, ($iTimerCount * $iRowHeight) + 30, 575, 40)
    $idRecentStatusLabel = GUICtrlCreateLabel("Ready", 20, ($iTimerCount * $iRowHeight) + 45, 555, 20)
    GUICtrlSetFont($idRecentStatusLabel, 9, 600) ; Make it bold for better visibility
    
    ; Status display as a scrollable text box - increased height for more lines
    GUICtrlCreateLabel("Status History:", 10, ($iTimerCount * $iRowHeight) + 80, 575, 20)
    $idStatusText = GUICtrlCreateEdit("", 10, ($iTimerCount * $iRowHeight) + 100, 575, 115, BitOR($ES_READONLY, $ES_MULTILINE, $ES_AUTOVSCROLL, $WS_VSCROLL, $ES_WANTRETURN))
    
    ; Set the text box to have a monospace font for better readability
    GUICtrlSetFont($idStatusText, 9, 400, 0, "Consolas")
    
    ; Restore any saved status history
    If $sStatusHistory <> "" Then
        GUICtrlSetData($idStatusText, $sStatusHistory)
    Else
        ; Add initial status message with timestamp
        AddStatusMessage("Ready")
    EndIf
    
    ; Close button - moved up slightly to be closer to the status history
    $idCloseButton = GUICtrlCreateButton("Close", 257, ($iTimerCount * $iRowHeight) + 220, 80, 25)
    
    ; Show the GUI
    GUISetState(@SW_SHOW, $hGUI)
EndFunc

; Creates a single timer row with all controls
; Creates a single timer row with all controls
; Creates a single timer row with all controls
Func CreateTimerRow($iIndex)
    ; Calculate Y position based on index
    Local $iY = ($iIndex * $iRowHeight) + 15 
    
    ; Create label input field - 20% longer
    $aTimerControls[$iIndex][8] = GUICtrlCreateInput($aTimerData[$iIndex][4], 10, $iY, 96, 20)
    
    ; Create a group box for X coordinate (without a title)
    GUICtrlCreateGroup("", 116, $iY - 5, 60, 30)
    ; Create X coordinate label - right-justified within the group
    $aTimerControls[$iIndex][0] = GUICtrlCreateLabel($aTimerData[$iIndex][0], 121, $iY + 2, 45, 20, $SS_RIGHT)
    ; Create X label to the right of the value (outside the group)
    GUICtrlCreateLabel("X", 181, $iY + 2, 10, 20)
    
    ; Create a group box for Y coordinate (without a title)
    GUICtrlCreateGroup("", 196, $iY - 5, 60, 30)
    ; Create Y coordinate label - right-justified within the group
    $aTimerControls[$iIndex][1] = GUICtrlCreateLabel($aTimerData[$iIndex][1], 201, $iY + 2, 45, 20, $SS_RIGHT)
    ; Create Y label to the right of the value (outside the group)
    GUICtrlCreateLabel("Y", 261, $iY + 2, 10, 20)
    
    ; Create Record button - adjusted position
    $aTimerControls[$iIndex][2] = GUICtrlCreateButton("Record", 276, $iY, 60, 20)
    
    ; Create Minutes input (right-justified) followed by label
    $aTimerControls[$iIndex][3] = GUICtrlCreateInput($aTimerData[$iIndex][2], 346, $iY, 40, 20, BitOR($ES_NUMBER, $ES_RIGHT))
    GUICtrlCreateLabel("Min", 391, $iY + 2, 25, 20)
    
    ; Create ON/OFF toggle button
    $aTimerControls[$iIndex][4] = GUICtrlCreateButton("OFF", 426, $iY, 60, 20)
    If $aTimerData[$iIndex][3] Then ; If timer is active
        GUICtrlSetData($aTimerControls[$iIndex][4], "ON")
        GUICtrlSetBkColor($aTimerControls[$iIndex][4], 0x00FF00) ; Green background for ON
    Else
        GUICtrlSetBkColor($aTimerControls[$iIndex][4], 0xFF0000) ; Red background for OFF
    EndIf
    
    ; Create Time remaining label - with more space between it and the +/- buttons
    $aTimerControls[$iIndex][5] = GUICtrlCreateLabel("--:--", 496, $iY + 2, 45, 20)
    
    ; Create Remove button ("-") - moved further right to add space
    $aTimerControls[$iIndex][6] = GUICtrlCreateButton("-", 551, $iY, 15, 20)
    
    ; Create Add button ("+") - moved further right to add space
    $aTimerControls[$iIndex][7] = GUICtrlCreateButton("+", 571, $iY, 15, 20)
EndFunc

; Adds a new timer at a specific position
Func AddTimer($iPosition)
    ; Read current values from the UI before rebuilding
    SaveTimerData()
    
    ; Increment timer count
    $iTimerCount += 1
    
    ; Resize our data arrays
    ReDim $aTimerData[$iTimerCount][5] ; Updated to include label column
    ReDim $aTimerControls[$iTimerCount][9] ; Updated to include label control
    ReDim $aTimerLastRun[$iTimerCount]
    ReDim $aTimerRecording[$iTimerCount]
    ReDim $aTimerMinutesValue[$iTimerCount]
    ReDim $aTimerInterval[$iTimerCount]
    
    ; Adjust insertion position to be AFTER the current row (iPosition + 1)
    $iInsertAt = $iPosition + 1
    
    ; Shift timers down from insertion point
    For $i = $iTimerCount - 1 To $iInsertAt Step -1
        For $j = 0 To 4 ; Updated to include label column
            $aTimerData[$i][$j] = $aTimerData[$i - 1][$j]
        Next
        $aTimerLastRun[$i] = $aTimerLastRun[$i - 1]
        $aTimerRecording[$i] = $aTimerRecording[$i - 1]
        $aTimerMinutesValue[$i] = $aTimerMinutesValue[$i - 1]
        $aTimerInterval[$i] = $aTimerInterval[$i - 1]
    Next
    
    ; Initialize the new timer's data at the insertion point
    $aTimerData[$iInsertAt][0] = 0    ; X coordinate
    $aTimerData[$iInsertAt][1] = 0    ; Y coordinate
    $aTimerData[$iInsertAt][2] = 10   ; Minutes
    $aTimerData[$iInsertAt][3] = False ; Active state
    $aTimerData[$iInsertAt][4] = "Timer " & ($iInsertAt + 1) ; Label
    $aTimerLastRun[$iInsertAt] = 0
    $aTimerRecording[$iInsertAt] = False
    $aTimerMinutesValue[$iInsertAt] = 10
    $aTimerInterval[$iInsertAt] = 10 * 60 * 1000
    
    ; Rebuild the GUI
    CreateCompleteGUI()
    
    ; Update status message
    AddStatusMessage("Added new timer at position " & ($iInsertAt + 1), "System")
    
    ; Save configuration to registry with timer addition
    SaveConfiguration()
EndFunc

; Removes a timer by index
Func RemoveTimer($iIndex)
    ; Don't allow removing all timers - must have at least one
    If $iTimerCount <= 1 Then
        AddStatusMessage("Cannot remove the only timer!")
        Return
    EndIf
    
    ; Read current values from the UI
    SaveTimerData()
    
    ; Shift all data up to remove the specified timer
    For $i = $iIndex To $iTimerCount - 2
        ; Copy data from the next timer
        For $j = 0 To 4 ; Updated to include label column
            $aTimerData[$i][$j] = $aTimerData[$i + 1][$j]
        Next
        $aTimerLastRun[$i] = $aTimerLastRun[$i + 1]
        $aTimerRecording[$i] = $aTimerRecording[$i + 1]
        $aTimerMinutesValue[$i] = $aTimerMinutesValue[$i + 1]
        $aTimerInterval[$i] = $aTimerInterval[$i + 1]
    Next
    
    ; Decrement timer count
    $iTimerCount -= 1
    
    ; Resize our arrays
    ReDim $aTimerData[$iTimerCount][5] ; Updated to include label column
    ReDim $aTimerControls[$iTimerCount][9] ; Updated to include label control
    ReDim $aTimerLastRun[$iTimerCount]
    ReDim $aTimerRecording[$iTimerCount]
    ReDim $aTimerMinutesValue[$iTimerCount]
    ReDim $aTimerInterval[$iTimerCount]
    
    ; Rebuild the GUI
    CreateCompleteGUI()
    
    ; Update status message
    AddStatusMessage("Removed timer " & ($iIndex + 1), "System")
    
    ; Save configuration to registry with timer removal
    SaveConfiguration()
EndFunc

; Saves current timer data from controls - also update registry data for positions and minutes
Func SaveTimerData()
    For $i = 0 To $iTimerCount - 1
        ; X and Y coordinates are no longer inputs, so don't read them from controls
        ; They're updated directly in the recording function
        
        ; Read the label value
        $aTimerData[$i][4] = GUICtrlRead($aTimerControls[$i][8])
        If $aTimerData[$i][4] = "" Then
            $aTimerData[$i][4] = "Timer " & ($i + 1)
            GUICtrlSetData($aTimerControls[$i][8], $aTimerData[$i][4])
        EndIf
        
        ; Store minutes value
        Local $iMinutes = Number(GUICtrlRead($aTimerControls[$i][3]))
        If $iMinutes <= 0 Then
            $iMinutes = 10 ; Default to 10 if invalid
        EndIf
        
        $aTimerData[$i][2] = $iMinutes ; Minutes in the main data structure
        $aTimerMinutesValue[$i] = $iMinutes ; Additional storage of minutes value
        $aTimerInterval[$i] = $iMinutes * 60 * 1000 ; Calculate interval in milliseconds
        
        ; Active state is maintained separately (not read from control)
        
        ; Update registry values for this timer
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "X", "REG_SZ", String($aTimerData[$i][0]))
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "Y", "REG_SZ", String($aTimerData[$i][1]))
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "Minutes", "REG_DWORD", $aTimerData[$i][2])
        RegWrite($REGISTRY_KEY & "\Timer" & $i, "Label", "REG_SZ", $aTimerData[$i][4])
    Next
    
    ; Update timer count in registry
    RegWrite($REGISTRY_KEY, "Timers", "REG_DWORD", $iTimerCount)
    
    ; Debug output
    ConsoleWrite("SaveTimerData() executed" & @CRLF)
    For $i = 0 To $iTimerCount - 1
        ConsoleWrite("Timer " & $i & ": Label=" & $aTimerData[$i][4] & ", X=" & $aTimerData[$i][0] & ", Y=" & $aTimerData[$i][1] & ", Minutes=" & $aTimerData[$i][2] & ", Active=" & $aTimerData[$i][3] & ", MinutesValue=" & $aTimerMinutesValue[$i] & ", Interval=" & $aTimerInterval[$i] & @CRLF)
    Next
EndFunc

; Toggles a timer on or off
Func ToggleTimer($iTimerIndex)
    ; Toggle the active state
    $aTimerData[$iTimerIndex][3] = Not $aTimerData[$iTimerIndex][3]
    
    ; Get the toggle button control ID
    Local $idToggle = $aTimerControls[$iTimerIndex][4]
    
    ; Read label value
    Local $sLabel = GUICtrlRead($aTimerControls[$iTimerIndex][8])
    If $sLabel = "" Then
        $sLabel = "Timer " & ($iTimerIndex + 1)
        GUICtrlSetData($aTimerControls[$iTimerIndex][8], $sLabel)
    EndIf
    $aTimerData[$iTimerIndex][4] = $sLabel
    
    If $aTimerData[$iTimerIndex][3] Then
        ; Read the current minutes value directly from the control
        Local $iCurrentMinutes = Number(GUICtrlRead($aTimerControls[$iTimerIndex][3]))
        If $iCurrentMinutes <= 0 Then
            $iCurrentMinutes = 10 ; Default to 10 if invalid
        EndIf
        
        ; Update both data structures with the latest value
        $aTimerData[$iTimerIndex][2] = $iCurrentMinutes
        $aTimerMinutesValue[$iTimerIndex] = $iCurrentMinutes
        $aTimerInterval[$iTimerIndex] = $iCurrentMinutes * 60 * 1000
        
        ; Debug output
        ConsoleWrite(">>> TIMER " & $iTimerIndex & " (" & $sLabel & ") ACTIVATED <<<" & @CRLF)
        ConsoleWrite("Minutes from control: " & $iCurrentMinutes & @CRLF)
        ConsoleWrite("Minutes in data: " & $aTimerData[$iTimerIndex][2] & @CRLF)
        ConsoleWrite("Minutes value: " & $aTimerMinutesValue[$iTimerIndex] & @CRLF)
        ConsoleWrite("Interval (ms): " & $aTimerInterval[$iTimerIndex] & @CRLF)
        
        ; Get coordinates
        $iX = $aTimerData[$iTimerIndex][0]
        $iY = $aTimerData[$iTimerIndex][1]
        
        ; Validate the parameters
        If Not ValidateClickParams($iX, $iY, $iCurrentMinutes, $sLabel) Then
            $aTimerData[$iTimerIndex][3] = False
            GUICtrlSetData($idToggle, "OFF")
            GUICtrlSetBkColor($idToggle, 0xFF0000) ; Red background for OFF
            
            ; Update registry to reflect deactivated timer
            RegWrite($REGISTRY_KEY & "\Timer" & $iTimerIndex, "Active", "REG_DWORD", $aTimerData[$iTimerIndex][3])
            
            Return
        EndIf
        
        GUICtrlSetData($idToggle, "ON")
        GUICtrlSetBkColor($idToggle, 0x00FF00) ; Green background for ON
        AddStatusMessage("Activated with " & $iCurrentMinutes & " minute interval!", $sLabel)
        
        ; Perform initial click immediately
        PerformClick($iX, $iY, $sLabel)
        
        ; Initialize timer
        $aTimerLastRun[$iTimerIndex] = TimerInit()
    Else
        GUICtrlSetData($idToggle, "OFF")
        GUICtrlSetBkColor($idToggle, 0xFF0000) ; Red background for OFF
        AddStatusMessage("Deactivated!", $sLabel)
    EndIf
    
    ; Save configuration to registry when timer state changes
    RegWrite($REGISTRY_KEY & "\Timer" & $iTimerIndex, "X", "REG_SZ", String($aTimerData[$iTimerIndex][0]))
    RegWrite($REGISTRY_KEY & "\Timer" & $iTimerIndex, "Y", "REG_SZ", String($aTimerData[$iTimerIndex][1]))
    RegWrite($REGISTRY_KEY & "\Timer" & $iTimerIndex, "Minutes", "REG_DWORD", $aTimerData[$iTimerIndex][2])
    RegWrite($REGISTRY_KEY & "\Timer" & $iTimerIndex, "Active", "REG_DWORD", $aTimerData[$iTimerIndex][3])
EndFunc

; Function to perform a sequence of clicks at specified coordinates
; Function to perform a sequence of clicks at specified coordinates
; Function to perform a sequence of clicks at specified coordinates
Func PerformClick($iX, $iY, $sLabel)
    ; Show countdown first
    Local $aScreenSize = _GetDesktopSize()
    Local $iScreenWidth = $aScreenSize[0]
    Local $iScreenHeight = $aScreenSize[1]
    
    ; Create a much smaller GUI for the countdown
    Local $iCountdownWidth = 180
    Local $iCountdownHeight = 80
    
    ; Position in bottom right with 20px margin from edges
    Local $iCountdownX = $iScreenWidth - $iCountdownWidth - 20
    Local $iCountdownY = $iScreenHeight - $iCountdownHeight - 20
    
    ; Use different colors for countdown
    Local $aColors[3] = [0x00FF00, 0xFFFF00, 0xFF0000] ; Green, Yellow, Red
    
    ; Create the countdown windows (one for each color to avoid redraw issues)
    Local $hCountdown[3]
    Local $idInfoLabel[3]
    Local $idCountLabel[3]
    Local $idCancelButton[3]
    
    ; Create three separate windows - one for each color
    For $i = 0 To 2
        $hCountdown[$i] = GUICreate($sLabel, $iCountdownWidth, $iCountdownHeight, $iCountdownX, $iCountdownY, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_NOACTIVATE))
        
        ; Set color-specific background
        GUISetBkColor($aColors[$i], $hCountdown[$i])
        
        ; Create larger label for timer name (increased font size from 9 to 12)
        $idInfoLabel[$i] = GUICtrlCreateLabel($sLabel, 10, 10, 120, 25)
        GUICtrlSetFont($idInfoLabel[$i], 12, 700) ; Larger font and bold
        
        ; Move number closer to right edge (changed X from 90 to 140)
        $idCountLabel[$i] = GUICtrlCreateLabel(3 - $i, 140, 8, 30, 25)
        GUICtrlSetFont($idCountLabel[$i], 16, 700)
        
        $idCancelButton[$i] = GUICtrlCreateButton("Cancel", 50, 40, 80, 25)
    Next
    
    ; Do the countdown - showing one window at a time
    Local $bCancelled = False
    For $i = 0 To 2
        ; Show only the current window, hide others
        DllCall("user32.dll", "int", "ShowWindow", "hwnd", $hCountdown[$i], "int", 4) ; SW_SHOWNOACTIVATE = 4
        
        ; Check for cancel button click or close button click
        Local $iStartTime = TimerInit()
        While TimerDiff($iStartTime) < 1000 ; Check every 100ms for 1 second
            Local $nMsg = GUIGetMsg()
            Switch $nMsg
                Case $GUI_EVENT_CLOSE, $idCancelButton[$i]
                    $bCancelled = True
                    ExitLoop 2 ; Exit both loops
            EndSwitch
            Sleep(100)
        WEnd
        
        ; Hide this window before showing the next
        If $i < 2 Then DllCall("user32.dll", "int", "ShowWindow", "hwnd", $hCountdown[$i], "int", 0) ; SW_HIDE = 0
    Next
    
    ; Close all countdown GUIs
    For $i = 0 To 2
        GUIDelete($hCountdown[$i])
    Next
    
    ; Check if cancelled
    If $bCancelled Then
        AddStatusMessage("Click sequence cancelled by user", $sLabel)
        Return False
    EndIf
    
    ; Save current mouse position before clicking
    Local $aPrevMousePos = MouseGetPos()
    
    ; Save current active window handle
    Local $hPrevWindow = WinGetHandle("[ACTIVE]")
    
    ; First click at specified position
    MouseClick("left", $iX, $iY, 1, 0) ; Move and single-click at specified position
    AddStatusMessage("First click at X=" & $iX & ", Y=" & $iY, $sLabel)
    
    ; Wait 100ms (updated from 250ms)
    Sleep(100)
    
    ; Second click at the same position
    MouseClick("left", $iX, $iY, 1, 0)
    AddStatusMessage("Second click at X=" & $iX & ", Y=" & $iY, $sLabel)
    
    ; Calculate random offset (5-10 pixels in each direction)
    Local $iOffsetX = Random(5, 10, 1)
    Local $iOffsetY = Random(5, 10, 1)
    
    ; Randomly decide if offset should be positive or negative
    If Random(0, 1, 1) Then $iOffsetX = -$iOffsetX
    If Random(0, 1, 1) Then $iOffsetY = -$iOffsetY
    
    ; Calculate new position with offset
    Local $iNewX = $iX + $iOffsetX
    Local $iNewY = $iY + $iOffsetY
    
    ; Wait 300ms (updated from 1000ms)
    AddStatusMessage("Waiting 300ms before offset clicks...", $sLabel)
    Sleep(300)
    
    ; CRITICAL FIX: Use $iNewX and $iNewY when actually clicking
    MouseClick("left", $iNewX, $iNewY, 1, 0)
    AddStatusMessage("First offset click at X=" & $iNewX & ", Y=" & $iNewY, $sLabel)
    
    ; Wait 100ms (updated from 250ms)
    Sleep(100)
    
    ; CRITICAL FIX: Use $iNewX and $iNewY when actually clicking
    MouseClick("left", $iNewX, $iNewY, 1, 0)
    AddStatusMessage("Second offset click at X=" & $iNewX & ", Y=" & $iNewY, $sLabel)
    
    ; Restore previous mouse position
    MouseMove($aPrevMousePos[0], $aPrevMousePos[1], 0)
    
    ; Restore previous active window
    WinActivate($hPrevWindow)
    
    Return True
EndFunc

; Function to get desktop size
Func _GetDesktopSize()
    Local $aSize[2]
    $aSize[0] = @DesktopWidth
    $aSize[1] = @DesktopHeight
    Return $aSize
EndFunc

; Function to validate click parameters
Func ValidateClickParams($iX, $iY, $iTimer, $sLabel)
    ; Check if any values are empty
    If $iX = "" Or $iY = "" Or $iTimer = "" Then
        AddStatusMessage("Empty coordinate or timer values!", $sLabel)
        Return False
    EndIf
    
    ; Check if timer is greater than zero
    If $iTimer <= 0 Then
        AddStatusMessage("Timer must be greater than 0!", $sLabel)
        Return False
    EndIf
    
    Return True
EndFunc

; Function to add a timestamped status message to the status text box
Func AddStatusMessage($sMessage, $sTimerLabel = "")
    ; Get current time in 24-hour format
    Local $sTime = StringFormat("%02d:%02d:%02d", @HOUR, @MIN, @SEC)
    
    ; Format message with timestamp and optional timer label
    Local $sFormattedMessage
    If $sTimerLabel = "" Then
        $sFormattedMessage = $sTime & " [System] - " & $sMessage
    Else
        $sFormattedMessage = $sTime & " [" & $sTimerLabel & "] - " & $sMessage
    EndIf
    
    ; Update the most recent status label (removed "Status: " prefix)
    GUICtrlSetData($idRecentStatusLabel, $sFormattedMessage)
    
    ; Get current text
    Local $sCurrentText = GUICtrlRead($idStatusText)
    
    ; Add new message at the BEGINNING (newest at top)
    If $sCurrentText <> "" Then
        $sCurrentText = $sFormattedMessage & @CRLF & $sCurrentText
    Else
        $sCurrentText = $sFormattedMessage
    EndIf
    
    ; Update the text box
    GUICtrlSetData($idStatusText, $sCurrentText)
    
    ; Save history in our global variable to restore after GUI redraws
    $sStatusHistory = $sCurrentText
    
    ; Auto-scroll to the top (since newest messages are at the top)
    _GUICtrlEdit_Scroll($idStatusText, $SB_TOP)
    
    Return $sFormattedMessage
EndFunc

; Include needed constants for scrolling
Global Const $SB_BOTTOM = 7
Global Const $SB_SCROLLCARET = 4
Global Const $SB_TOP = 6 ; Added for scrolling to top

Func _IsPressed($sHexKey)
    Local $aReturn = DllCall("user32.dll", "int", "GetAsyncKeyState", "int", "0x" & $sHexKey)
    If $aReturn[0] Then
        Return 1
    EndIf
    Return 0
EndFunc   ;==>_IsPressed

; Function to clear all registry settings (for reset)
Func ClearConfiguration()
    ; Delete the entire registry key
    RegDelete($REGISTRY_KEY)
    
    ; Reset to default values
    $iTimerCount = 2
    
    ; Resize arrays
    ReDim $aTimerData[2][5] ; Updated to include label column
    ReDim $aTimerControls[2][9] ; Updated to include label control
    ReDim $aTimerLastRun[2]
    ReDim $aTimerRecording[2]
    ReDim $aTimerMinutesValue[2]
    ReDim $aTimerInterval[2]
    
    ; Initialize with default values
    For $i = 0 To 1
        $aTimerData[$i][0] = 0    ; X coordinate
        $aTimerData[$i][1] = 0    ; Y coordinate
        $aTimerData[$i][2] = 10   ; Minutes
        $aTimerData[$i][3] = False ; Active state
        $aTimerData[$i][4] = "Timer " & ($i + 1) ; Default label name
        $aTimerMinutesValue[$i] = 10
        $aTimerInterval[$i] = 10 * 60 * 1000 ; 10 minutes in milliseconds
        $aTimerLastRun[$i] = 0
        $aTimerRecording[$i] = False
    Next
    
    ; Rebuild the GUI
    CreateCompleteGUI()
    
    AddStatusMessage("Configuration has been reset to defaults.", "System")
EndFunc

; Start the application
Main()
