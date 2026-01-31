# NAME: Create System Restore Point
# DESCRIPTION: Creates a system restore point before making changes.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [string]$Description = "WinPick Restore Point",
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

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
            if ($Description) { $argList += @("-Description", "`"$Description`"") }
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Ensure-SystemRestoreEnabled {
    param (
        [string]$Drive
    )
    try {
        Enable-ComputerRestore -Drive $Drive | Out-Null
    } catch {
        Write-Log "Enable-ComputerRestore failed or is already enabled." "WARN"
    }
}

try {
    Ensure-Admin
    $systemDrive = "$($env:SystemDrive)\"
    Ensure-SystemRestoreEnabled -Drive $systemDrive
    Write-Log "Creating restore point: $Description" "INFO"
    Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" | Out-Null
    Write-Log "System restore point created successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
