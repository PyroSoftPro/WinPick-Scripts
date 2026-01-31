# NAME: Set Sleep Schedule
# DESCRIPTION: Creates scheduled tasks to sleep and wake the computer daily. Use -Clear to remove tasks.
# UNDOABLE: Yes
# UNDO_DESC: Removes the scheduled sleep and wake tasks.
# LINK: https://github.com/jhochwald/PowerShell-collection
#

param (
    [string]$SleepTime,
    [string]$WakeTime,
    [switch]$Clear,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$SleepTaskName = "WinPick-Sleep"
$WakeTaskName = "WinPick-Wake"

# Set up logging
$LogFile = Join-Path $PSScriptRoot "$(Split-Path -Leaf $PSCommandPath).log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Level - $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

function Parse-Time {
    param ([string]$TimeValue)
    if (-not $TimeValue) {
        return $null
    }
    [DateTime]::ParseExact($TimeValue, "HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Remove-TaskIfExists {
    param ([string]$Name)
    if (Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $Name -Confirm:$false
        Write-Log "Removed scheduled task: $Name" "INFO"
    }
}

try {
    if ($Clear) {
        Remove-TaskIfExists -Name $SleepTaskName
        Remove-TaskIfExists -Name $WakeTaskName
        Write-Log "Sleep schedule cleared." "INFO"
        Write-Log "Script completed successfully." "INFO"
        exit 0
    }

    if (-not $SleepTime -or -not $WakeTime) {
        throw "SleepTime and WakeTime are required (format: HH:mm)."
    }

    $sleepAt = Parse-Time -TimeValue $SleepTime
    $wakeAt = Parse-Time -TimeValue $WakeTime

    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType InteractiveToken -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -WakeToRun:$true -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    $sleepAction = New-ScheduledTaskAction -Execute "rundll32.exe" -Argument "powrprof.dll,SetSuspendState 0,1,0"
    $sleepTrigger = New-ScheduledTaskTrigger -Daily -At $sleepAt
    $sleepTask = New-ScheduledTask -Action $sleepAction -Trigger $sleepTrigger -Principal $principal -Settings $settings
    Register-ScheduledTask -TaskName $SleepTaskName -InputObject $sleepTask -Force | Out-Null

    $wakeAction = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c exit"
    $wakeTrigger = New-ScheduledTaskTrigger -Daily -At $wakeAt
    $wakeTask = New-ScheduledTask -Action $wakeAction -Trigger $wakeTrigger -Principal $principal -Settings $settings
    Register-ScheduledTask -TaskName $WakeTaskName -InputObject $wakeTask -Force | Out-Null

    Write-Log "Sleep scheduled at $SleepTime and wake scheduled at $WakeTime." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
