# NAME: Auto Update Microsoft Store Apps
# DESCRIPTION: Disables automatic Microsoft Store app updates. Use -Undo to enable them.
# UNDOABLE: Yes
# UNDO_DESC: Enables automatic Microsoft Store app updates.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$UserPath = "HKCU:\SOFTWARE\Policies\Microsoft\WindowsStore"
$MachinePath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
$ValueName = "AutoDownload"

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
    if (-not (Test-Path -Path $UserPath)) {
        New-Item -Path $UserPath -Force | Out-Null
    }
    if (-not (Test-Path -Path $MachinePath)) {
        New-Item -Path $MachinePath -Force | Out-Null
    }

    if ($Undo) {
        Set-ItemProperty -Path $UserPath -Name $ValueName -Value 4 -Type DWord -Force
        Set-ItemProperty -Path $MachinePath -Name $ValueName -Value 4 -Type DWord -Force
        Write-Log "Microsoft Store app auto-updates enabled." "INFO"
    } else {
        Set-ItemProperty -Path $UserPath -Name $ValueName -Value 2 -Type DWord -Force
        Set-ItemProperty -Path $MachinePath -Name $ValueName -Value 2 -Type DWord -Force
        Write-Log "Microsoft Store app auto-updates disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
