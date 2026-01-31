# NAME: Test Reboot Pending
# DESCRIPTION: Checks common indicators to determine if a reboot is pending.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/jhochwald/PowerShell-collection
#

param (
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

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

function Test-RegistryKey {
    param ([string]$Path)
    return Test-Path -Path $Path
}

try {
    $reasons = New-Object System.Collections.Generic.List[string]

    if (Test-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $reasons.Add("ComponentBasedServicing")
    }
    if (Test-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reasons.Add("WindowsUpdate")
    }
    if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue)) {
        $reasons.Add("PendingFileRenameOperations")
    }
    if (Test-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce") {
        $reasons.Add("RunOnce")
    }

    $result = [PSCustomObject]@{
        RebootPending = ($reasons.Count -gt 0)
        Reasons       = $reasons
    }

    $result
    Write-Log "Reboot pending: $($result.RebootPending)" "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
