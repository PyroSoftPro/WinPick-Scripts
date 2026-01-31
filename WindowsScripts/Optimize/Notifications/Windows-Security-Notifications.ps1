# NAME: Windows Security Notifications
# DESCRIPTION: Enables Windows Security notifications. Use -Undo to disable them.
# UNDOABLE: Yes
# UNDO_DESC: Disables Windows Security notifications.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$Paths = @(
    "HKLM:\Software\Microsoft\Windows Defender Security Center\Notifications",
    "HKCU:\Software\Policies\Microsoft\Windows Defender Security Center\Notifications",
    "HKLM:\Software\Policies\Microsoft\Windows Defender Security Center\Notifications"
)

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

function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Re-launching with administrator privileges..." "INFO"
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($Undo) { $argList += "-Undo" }
        if ($Verbose) { $argList += "-Verbose" }
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
}

try {
    Ensure-Admin
    foreach ($path in $Paths) {
        if (-not (Test-Path -Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
    }

    if ($Undo) {
        foreach ($path in $Paths) {
            Set-ItemProperty -Path $path -Name "DisableNotifications" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path -Name "DisableEnhancedNotifications" -Value 1 -Type DWord -Force
        }
        Write-Log "Windows Security notifications disabled." "INFO"
    } else {
        foreach ($path in $Paths) {
            Set-ItemProperty -Path $path -Name "DisableNotifications" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name "DisableEnhancedNotifications" -Value 0 -Type DWord -Force
        }
        Write-Log "Windows Security notifications enabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
