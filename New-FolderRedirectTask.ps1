﻿# Requires -Version 3
<#
    .SYNOPSIS
        Creates a scheduled task to enable folder redirection at user login.
        Enable folder redirection on Windows 10 Azure AD joined PCs.
        Downloads the folder redirection script from a URL locally and creates the schedule task.
#>
[CmdletBinding(ConfirmImpact = 'Low', HelpURI = 'https://stealthpuppy.com/', SupportsPaging = $False,
    SupportsShouldProcess = $False, PositionalBinding = $False)]
Param (
    [Parameter()] $Url = "https://raw.githubusercontent.com/rlewandowski-fl/intune/main/Redirect-Folders.ps1",
    [Parameter()] $Script = "Redirect-Folders.ps1",
    [Parameter()] $ScriptVb = "Redirect-Folders.vbs",
    [Parameter()] $TaskName = "Folder Redirection",
    [Parameter()] $Group = $((Get-LocalGroup -SID S-1-5-32-545).Name),
    [Parameter()] $Execute = "wscript.exe",
    [Parameter()] $Target = "$env:ProgramData\Intune-Scripts",
    [Parameter()] $Arguments = "$Target\$ScriptVb /b /nologo"
)

$VerbosePreference = "Continue"
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\IntuneScriptLogs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# Construct string to output as a VBscript
$vbScript = 'Set objShell=CreateObject("WScript.Shell")' + "`r`n"
$vbScript = $vbScript + 'Set objFSO=CreateObject("Scripting.FileSystemObject")' + "`r`n"
$vbScript = $vbScript + 'strCMD = "powershell -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File ' + "$Target\$Script" + '"' + "`r`n"
$vbScript = $vbScript + 'objShell.Run strCMD,0'

# If local path for script doesn't exist, create it
If (!(Test-Path -Path $Target)) {
    Write-Verbose "Creating $Target."
    New-Item -Path $Target -Type Directory -Force
}

# Download the script from the source repository; output the VBscript
If (Test-Path "$Target\$Script") {
    Write-Verbose "Removing $Target\$Script."
    Remove-Item -Path "$Target\$Script" -Force
}

Write-Verbose "Downloading $Url to $Target\$Script."
Start-BitsTransfer -Source $Url -Destination "$Target\$Script" -Priority Foreground -TransferPolicy Always -ErrorAction SilentlyContinue -ErrorVariable $TransferError
If (Test-Path -Path "$Target\$Script") { Write-Verbose "$Target\$Script downloaded successfully." }

$vbScript | Out-File -FilePath "$Target\$ScriptVb" -Force -Encoding ascii

# Get an existing local task if it exists
If ($Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue ) {

    Write-Verbose "Folder redirection task exists."
    # If the task Action differs from what we have above, update the values and save the task
    If (!( ($Task.Actions[0].Execute -eq $Execute) -and ($Task.Actions[0].Arguments -eq $Arguments) )) {
        Write-Verbose "Updating scheduled task."
        $Task.Actions[0].Execute = $Execute
        $Task.Actions[0].Arguments = $Arguments
        $Task | Set-ScheduledTask -Verbose
    }
    Else {
        Write-Verbose "Existing task action is OK, no change required."
    }
}
Else {
    Write-Verbose "Creating folder redirection scheduled task."
    # Build a new task object
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments
    $trigger = New-ScheduledTaskTrigger -AtLogon -RandomDelay (New-TimeSpan -Minutes 1)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Hidden -DontStopIfGoingOnBatteries -Compatibility Win8
    $principal = New-ScheduledTaskPrincipal -GroupId $Group
    $newTask = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    # No task object exists, so register the new task
    Write-Verbose "Registering new task $TaskName."
    Register-ScheduledTask -InputObject $newTask -TaskName $TaskName -Verbose
}

Stop-Transcript
