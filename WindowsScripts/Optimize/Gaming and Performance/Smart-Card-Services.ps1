# NAME: Smart Card Services
# DESCRIPTION: Disables smart card services. Use -Undo to set them to Automatic.
# UNDOABLE: Yes
# UNDO_DESC: Sets smart card services to Automatic.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$ServicePaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\SCardSvr",
    "HKLM:\SYSTEM\CurrentControlSet\Services\ScDeviceEnum",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SCPolicySvc"
)
$ValueName = "Start"

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
    foreach ($path in $ServicePaths) {
        if (-not (Test-Path -Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
    }

    if ($Undo) {
        foreach ($path in $ServicePaths) {
            Set-ItemProperty -Path $path -Name $ValueName -Value 2 -Type DWord -Force
        }
        Write-Log "Smart card services set to Automatic." "INFO"
    } else {
        foreach ($path in $ServicePaths) {
            Set-ItemProperty -Path $path -Name $ValueName -Value 4 -Type DWord -Force
        }
        Write-Log "Smart card services disabled." "INFO"
    }

    Write-Log "A restart may be required for changes to take effect." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
