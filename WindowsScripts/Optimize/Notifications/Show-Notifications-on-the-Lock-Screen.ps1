# NAME: Show notifications on the lock screen
# DESCRIPTION: Disables lock screen notifications. Use -Undo to enable them.
# UNDOABLE: Yes
# UNDO_DESC: Enables lock screen notifications.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$SettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
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
    if (-not (Test-Path -Path $SettingsPath)) {
        New-Item -Path $SettingsPath -Force | Out-Null
    }
    if (-not (Test-Path -Path $PushPath)) {
        New-Item -Path $PushPath -Force | Out-Null
    }

    if ($Undo) {
        Set-ItemProperty -Path $SettingsPath -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $PushPath -Name "LockScreenToastEnabled" -Value 1 -Type DWord -Force
        Write-Log "Lock screen notifications enabled." "INFO"
    } else {
        Set-ItemProperty -Path $SettingsPath -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $PushPath -Name "LockScreenToastEnabled" -Value 0 -Type DWord -Force
        Write-Log "Lock screen notifications disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
