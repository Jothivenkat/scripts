'==========================================================================
'
' NAME: OS_Engineering-HPSA_Install_WSUS_Patches_Step_2_script.vbs
' AUTHORS: Micro Focus Professional Services
' VERSION: 1.0
' CREATION DATE: 20/03/2018
'
'==========================================================================

Option Explicit
On Error Resume Next

Dim objShell, objUpdateSystemInfo, objUpdateSession, objUpdateSearcher, objSearcherResults, downloader, objWshScriptExec, objStdOut, rebootRequired
Dim objUpdate, objUpdateColl, objDownloadColl, objInstaller, objInstallResult, objWindowsUpdate, downloadResult
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
WScript.Echo "OS_Engineering-HPSA_Install_WSUS_Patches_Step_2_script script execution started!"

WScript.Echo vbLf & "Creating WScript shell object..."
Set objShell = CreateObject("wscript.shell")
If Err.Number <> "0" Then
	WScript.Echo "- *** Unable to create WScript shell object!"
	Set intShellFail = 1
Else
	WScript.Echo "- WScript shell object creation is OK!"
	objShell.LogEvent EVENTLOG_SUCCESS, "OS_Engineering-HPSA_Install_WSUS_Patches_Step_2_script script has been started!" &_
	vblf & "SCRIPT NAME: OS_Engineering-HPSA_Install_WSUS_Patches_Step_2_script.vbs"
End If

Set objWshScriptExec = objShell.Exec("C:\Program Files\Opsware\agent_tools\get_cust_attr.bat EPP_REBOOT")
Set objStdOut = objWshScriptExec.StdOut
rebootRequired = objStdOut.ReadLine

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

WScript.Echo vbLf & "Search for missing approved updates..."
Set objUpdateSession = CreateObject("Microsoft.Update.Session")
Set objUpdateSearcher = objUpdateSession.CreateUpdateSearcher
Set objSearcherResults = objUpdateSearcher.Search("IsInstalled=0 and Type='software'")

intCounter = 0
WScript.Echo vbLf & "List of missing approved updates..."
For intIndex = intCounter To objSearcherResults.updates.count - 1
	Set objUpdate = objSearcherResults.updates.item(intIndex)
	WScript.Echo intIndex + 1 & vbtab & objUpdate.title
Next

Set objDownloadColl = CreateObject("Microsoft.Update.UpdateColl")
intCounter = 0
For intIndex = intCounter To objSearcherResults.updates.count - 1
	Set objUpdate = objSearcherResults.updates.item(intIndex)
	If objUpdate.isdownloaded = False Then
		objDownloadColl.Add(objUpdate)
		WScript.Echo vblf & objDownloadColl.Count & " not downloaded"
	End If
Next

If objDownloadColl.Count > 0 Then
	WScript.Echo vblf & "Downloading updates..."
	Set downloader = objUpdateSession.CreateUpdateDownloader()
	downloader.Updates = objDownloadColl 
	Set downloadResult = downloader.Download()
        WScript.Echo "Download Result: " & downloadResult.ResultCode
End If

intCounter = 0
Do While intCounter < 1
	WScript.Echo "- Please be patient..."
	WScript.Sleep 30000
	intCounter = intCounter + 1
Loop
If intIndex = 0 Then
	WScript.Echo "- There are no missing approved updates!"
	If intShellFail <> 1 Then
		objShell.LogEvent EVENTLOG_INFORMATION, "Detected no missing patches!"
	End If
Else
	If intShellFail <> 1 Then
		objShell.LogEvent EVENTLOG_INFORMATION, "Detected " & intIndex &_
		" missing patches!  Check the SYSTEM Log for vendor patch installation status."
	End If
	WScript.Echo vblf & "Updates that will be skipped due to manual intervention requirement..."
	Set objUpdateColl = CreateObject("Microsoft.Update.UpdateColl")
	intCounter = 0
	For intIndex = intCounter To objSearcherResults.updates.count - 1
		Set objUpdate = objSearcherResults.updates.item(intIndex)
		If objUpdate.isdownloaded = True Then
			If objUpdate.eulaaccepted = False Then
				intCounter2 = intCounter2 + 1
				WScript.Echo intCounter2 & vbtab & objUpdate.title &_
				" will be skipped due to unaccepted EULA" & vblf
				If intShellFail <> 1 Then
					objShell.LogEvent EVENTLOG_WARNING, objUpdate.title & " will NOT be" &_
					vbLf & "automatically installed due to unaccepted EULA!"
				End If
			ElseIf objUpdate.installationbehavior.canrequestuserinput = True Then
				intCounter2 = intCounter2 + 1
				WScript.Echo intCounter2 & vbTab & objUpdate.title &_
				"will be skipped due to user input requirement" & vblf
				If intShellFail <> 1 Then
					objShell.LogEvent EVENTLOG_WARNING, objUpdate.title & " will NOT be" &_
					vblf & "automatically installed due to user input required!"
				End If
			Else
				objUpdateColl.Add(objUpdate)
			End If
		Else
			WScript.Echo intindex + 1 & objDownloadColl.Item(intIndex).Title &	" is not downloaded"
		End If	
	Next
	If intCounter2 = 0 Then
		WScript.Echo "- There are no patches that will be skipped!"
	End If
	If objUpdateColl.Count > 0 Then
		WScript.Echo vblf & "Installation of updates..."
		Set objInstaller = objUpdateSession.CreateUpdateInstaller()
		objInstaller.updates = objUpdateColl
		Set objInstallResult = objInstaller.Install()
		intCounter = 0
		For intIndex = intCounter To objUpdateColl.Count - 1
			Select Case objInstallResult.getupdateresult(intIndex).resultcode
				Case 0
					strResultCode = "Not Started"
				Case 1
					strResultCode = "In Progress"
				Case 2
					strResultCode = "Succeeded"
				Case 3
					strResultCode = "Succeeded With Errors"
				Case 4
					strResultCode = "Failed"
				Case 5
					strResultCode = "Aborted"
			End Select
			WScript.Echo intIndex + 1 & vbtab & objUpdateColl.Item(intIndex).title & vbtab & strResultCode
			If intShellFail <> 1 Then
				objShell.LogEvent EVENTLOG_INFORMATION, objUpdateColl.Item(intIndex).Title &_
				" was attempted with a status of " & strResultCode
			End If
		Next
		If StrComp(rebootRequired,"at_end",1) = 0 Then
			WScript.Echo "- System reboot is required!"
			WScript.Echo "- Initiating HPSA reboot command!"
			WScript.Echo "OPSW_REBOOT"
			If intShellFail <> 1 Then
				objShell.LogEvent EVENTLOG_INFORMATION, "HPSA reboot command executed!"
			End If
			WScript.Echo "- HPSA reboot command executed!" & vbLf
		End If
	End If
End If

If intShellFail <> 1 Then
	objShell.LogEvent EVENTLOG_SUCCESS, "OS_Engineering-HPSA_Install_WSUS_Patches_Step_2_script script has completed!" &_
	vblf & "SCRIPT NAME: OS_Engineering-HPSA_Install_WSUS_Patches_Step_2_script.vbs"
End If

WScript.Echo vbLf & "OS_Engineering-HPSA_Install_WSUS_Patches_Step_2_script.vbs script execution completed!"
WScript.Quit(intExitCode)
