'==========================================================================
'
' NAME: OS_Engineering-HPSA_Install_WSUS_Patches_Step_3_script.vbs
' AUTHORS: Micro Focus Professional Services
' VERSION: 1.0
' CREATION DATE: 20/03/2018
'
'==========================================================================

Option Explicit
On Error Resume Next

Dim objShell, objUpdateSystemInfo, objUpdateSession, objUpdateSearcher, objSearcherResults
Dim objUpdate, objUpdateColl, objInstaller, objInstallResult, objWindowsUpdate, strComputerName, datetime
Dim intShellFail, intIndex, intCounter, intCounter2, intExitCode
Dim strResultCode

Const EVENTLOG_SUCCESS = 0
Const EVENTLOG_ERROR = 1
Const EVENTLOG_WARNING = 2
Const EVENTLOG_INFORMATION = 4
Const EVENTLOG_AUDIT_SUCCESS = 8
Const EVENTLOG_AUDIT_FAILURE = 16

intShellFail = 0
intIndex = 0
intCounter = 0
intCounter2 = 0
intExitCode = 0

Err.Clear
WScript.Echo vbLf & vblf
WScript.Echo "OS_Engineering-HPSA_Install_WSUS_Patches_Step_3_script script execution started!"

WScript.Echo vbLf & "Creating WScript shell object..."
Set objShell = CreateObject("wscript.shell")
If Err.Number <> "0" Then
	WScript.Echo "- *** Unable to create WScript shell object!"
	Set intShellFail = 1
Else
	WScript.Echo "- WScript shell object creation is OK!"
	objShell.LogEvent EVENTLOG_SUCCESS, "OS_Engineering-HPSA_Install_WSUS_Patches_Step_3_script script has been started!" &_
	vblf & "SCRIPT NAME: OS_Engineering-HPSA_Install_WSUS_Patches_Step_3_script.vbs"
End If

WScript.Echo vbLf & "Detecting WSUS updates..."
WScript.Echo "- Initiating DetectNow via WMI request!"

Set objWindowsUpdate = CreateObject("Microsoft.Update.AutoUpdate")
If Err.Number <> "0" Then
	WScript.Echo "- *** Unable to call DetectNow via WMI!"
	WScript.Echo "- Attempting alternative means of detecting updates!"
	WScript.Echo "- Executing wuauclt /detectnow..."
	objShell.Run "wuauclt /detectnow",,True
	If Err.Number = "0" Then
		WScript.Echo "- DetectNow initiated via command shell..."
	End If
Else
objWindowsUpdate.DetectNow
	If Err.Number = "0" Then
		WScript.Echo "- DetectNow initiated via WMI..."
	End If
End If
WScript.Echo "- Detection initiated OK!"

intCounter = 0
Do While intCounter < 1
	WScript.Echo "- Please be patient..."
	WScript.Sleep 30000
	intCounter = intCounter + 1
Loop

WScript.Echo vbLf & "Reporting WSUS patch status..."
WScript.Echo "- Initiating ReportNow request!"
WScript.Echo "- Initiating ReportNow via command shell..."
objShell.Run "wuauclt /reportnow",,True
If Err.Number = "0" Then
	WScript.Echo "- Reporting initiated OK!"
	intCounter = 0
	Do while intCounter < 1
		WScript.Echo "- Please be patient..."
		WScript.Sleep 30000
		intCounter = intCounter + 1
	Loop
End If

wscript.Echo vbLf & "Search for overall completion status..."
Set objUpdateSession = CreateObject("Microsoft.Update.Session")
Set objUpdateSearcher = objUpdateSession.CreateUpdateSearcher
Set objSearcherResults = objUpdateSearcher.search("IsInstalled=0 and Type='software'")
WScript.Echo vbLf & "Overall completion status..."
WScript.Echo "- " & objSearcherResults.Updates.Count & " total approved patches remain to be installed..."
Set objUpdateColl = CreateObject("Microsoft.Update.UpdateColl")
intCounter = 0
intCounter2 = 0
For intIndex = intCounter To objSearcherResults.Updates.Count - 1
	Set objUpdate = objSearcherResults.Updates.Item(intIndex)
	If objUpdate.IsDownloaded = True Then
		If objUpdate.EulaAccepted = False Then
			intCounter2 = intCounter2 + 1
		ElseIf objUpdate.installationbehavior.canrequestuserinput = True Then
			intCounter2 = intCounter2 + 1
		Else
			objUpdateColl.Add(objUpdate)
		End If
	End If
Next
WScript.Echo "- " & intCounter2 & " updates were skipped due to manual intervention requirement..."
WScript.Echo "- " & objUpdateColl.Count & " updates are downloaded and ready to be installed..."
Set objUpdateSystemInfo = CreateObject("Microsoft.Update.SystemInfo")
If objUpdateSystemInfo.RebootRequired = "True" Then
	WScript.Echo vbLf & "A system reboot is needed at this time!"
Else
	WScript.Echo vbLf & "A system reboot is NOT needed at this time!"
End If

If intShellFail <> 1 Then
	objShell.LogEvent EVENTLOG_SUCCESS, "OS_Engineering-HPSA_Install_WSUS_Patches_Step_3_script script has completed!" &_
	vblf & "SCRIPT NAME: OS_Engineering-HPSA_Install_WSUS_Patches_Step_3_script.vbs"
End If

WScript.Echo vbLf & "OS_Engineering-HPSA_Install_WSUS_Patches_Step_3_script script execution completed!"
strComputerName = objShell.ExpandEnvironmentStrings( "%COMPUTERNAME%" )
datetime=Replace(Now,"/","-")
WScript.Echo "Patch Process completed on " & strComputerName & " at [" & datetime & "]"
WScript.Quit(intExitCode)
