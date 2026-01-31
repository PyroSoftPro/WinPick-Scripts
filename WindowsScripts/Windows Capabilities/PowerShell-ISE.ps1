# NAME: PowerShell ISE
# DESCRIPTION: Removes Windows Capability "Microsoft.Windows.PowerShell.ISE". Use -Undo to reinstall.
# UNDOABLE: Yes
# UNDO_DESC: Reinstalls Windows Capability "Microsoft.Windows.PowerShell.ISE".
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$CapabilityName = "Microsoft.Windows.PowerShell.ISE"

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

function Remove-Capability {
    Write-Log "Removing capability: $CapabilityName" "INFO"
    Remove-WindowsCapability -Online -Name $CapabilityName -ErrorAction Stop | Out-Null
}

function Add-Capability {
    Write-Log "Installing capability: $CapabilityName" "INFO"
    Add-WindowsCapability -Online -Name $CapabilityName -ErrorAction Stop | Out-Null
}

try {
    Ensure-Admin
    if ($Undo) {
        Add-Capability
    } else {
        Remove-Capability
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
