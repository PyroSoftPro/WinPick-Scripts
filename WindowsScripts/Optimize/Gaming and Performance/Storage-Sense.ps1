# NAME: Storage Sense
# DESCRIPTION: Disables Storage Sense automatic cleanup. Use -Undo to enable it.
# UNDOABLE: Yes
# UNDO_DESC: Enables Storage Sense automatic cleanup.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$UserPolicyPath = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"
$MachinePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"
$ValueName = "AllowStorageSenseGlobal"

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
    if (-not (Test-Path -Path $UserPolicyPath)) {
        New-Item -Path $UserPolicyPath -Force | Out-Null
    }
    if (-not (Test-Path -Path $MachinePolicyPath)) {
        New-Item -Path $MachinePolicyPath -Force | Out-Null
    }

    if ($Undo) {
        Set-ItemProperty -Path $UserPolicyPath -Name $ValueName -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $MachinePolicyPath -Name $ValueName -Value 1 -Type DWord -Force
        Write-Log "Storage Sense is now enabled." "INFO"
    } else {
        Set-ItemProperty -Path $UserPolicyPath -Name $ValueName -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $MachinePolicyPath -Name $ValueName -Value 0 -Type DWord -Force
        Write-Log "Storage Sense is now disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
