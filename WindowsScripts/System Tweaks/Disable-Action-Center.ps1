# NAME: Disable Action Center
# DESCRIPTION: Disables the Windows Action Center (notification center). Use -Undo to re-enable.
# UNDOABLE: Yes
# UNDO_DESC: Re-enables the Windows Action Center.
# LINK: https://github.com/WinTweakers/WindowsToolbox
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$PolicyPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
$PushPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"

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

try {
    if (-not (Test-Path -Path $PolicyPath)) {
        New-Item -Path $PolicyPath -Force | Out-Null
    }
    if (-not (Test-Path -Path $PushPath)) {
        New-Item -Path $PushPath -Force | Out-Null
    }

    if ($Undo) {
        Set-ItemProperty -Path $PolicyPath -Name "DisableNotificationCenter" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $PushPath -Name "ToastEnabled" -Value 1 -Type DWord -Force
        Write-Log "Action Center enabled." "INFO"
    } else {
        Set-ItemProperty -Path $PolicyPath -Name "DisableNotificationCenter" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $PushPath -Name "ToastEnabled" -Value 0 -Type DWord -Force
        Write-Log "Action Center disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
