# NAME: Get Installed Apps
# DESCRIPTION: Lists installed desktop apps and optionally Microsoft Store apps.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/jhochwald/PowerShell-collection
#

param (
    [switch]$IncludeStoreApps,
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

function Get-InstalledFromPath {
    param (
        [string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        return @()
    }

    Get-ItemProperty -Path "$Path\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString, PSChildName
}

try {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $apps = foreach ($path in $paths) { Get-InstalledFromPath -Path $path }
    $apps | Sort-Object DisplayName -Unique | ForEach-Object { $_ }

    if ($IncludeStoreApps) {
        Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName, Publisher, InstallLocation |
            Sort-Object Name | ForEach-Object { $_ }
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
