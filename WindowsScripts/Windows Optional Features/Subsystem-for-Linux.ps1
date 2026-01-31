# NAME: Subsystem for Linux
# DESCRIPTION: Disables Windows Optional Feature "Microsoft-Windows-Subsystem-Linux". Use -Undo to enable.
# UNDOABLE: Yes
# UNDO_DESC: Enables Windows Optional Feature "Microsoft-Windows-Subsystem-Linux".
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$FeatureName = "Microsoft-Windows-Subsystem-Linux"

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
        try {
            $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
            if ($Undo) { $argList += "-Undo" }
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Disable-Feature {
    Write-Log "Disabling optional feature: $FeatureName" "INFO"
    Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -ErrorAction Stop | Out-Null
}

function Enable-Feature {
    Write-Log "Enabling optional feature: $FeatureName" "INFO"
    Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart -ErrorAction Stop | Out-Null
}

try {
    Ensure-Admin
    if ($Undo) {
        Enable-Feature
    } else {
        Disable-Feature
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
