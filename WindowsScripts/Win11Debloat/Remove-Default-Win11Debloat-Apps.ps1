# NAME: Remove Default Win11Debloat Apps
# DESCRIPTION: Removes the default Win11Debloat app set from Appslist.txt for all users.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$LogFile = Join-Path $PSScriptRoot "$(Split-Path -Leaf $PSCommandPath).log"
$AppsListPath = Join-Path $PSScriptRoot "Appslist.txt"

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
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Get-DefaultAppsList {
    if (-not (Test-Path $AppsListPath)) {
        throw "Appslist.txt not found at $AppsListPath"
    }
    $apps = @()
    foreach ($line in Get-Content -Path $AppsListPath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }
        if ($trimmed.StartsWith("-")) { continue }
        if ($trimmed.StartsWith("----")) { continue }
        if ($trimmed.Contains("#")) {
            $trimmed = $trimmed.Split("#")[0].Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $apps += $trimmed
        }
    }
    return $apps
}

function Remove-AppxPackages {
    param (
        [string[]]$AppxNames
    )
    $removeCmd = Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue
    $supportsAllUsers = $false
    if ($removeCmd) {
        $supportsAllUsers = $removeCmd.Parameters.ContainsKey("AllUsers")
    }

    foreach ($name in $AppxNames) {
        $pattern = if ($name -like "*`**") { $name } else { "*$name*" }

        if ($name -in @("Microsoft.Edge", "Microsoft.OneDrive")) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Log "Attempting WinGet uninstall for $name..." "INFO"
                Start-Process -FilePath "winget" -ArgumentList @("uninstall", "--id", $name, "--accept-source-agreements", "--disable-interactivity") -Wait | Out-Null
            } else {
                Write-Log "WinGet not available; skipping $name." "WARN"
            }
            continue
        }

        $packages = Get-AppxPackage -Name $pattern -AllUsers -ErrorAction SilentlyContinue
        if ($packages) {
            foreach ($pkg in $packages) {
                if ($supportsAllUsers) {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                } else {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                }
            }
        }

        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pattern }
        if ($prov) {
            foreach ($p in $prov) {
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName | Out-Null
            }
        }
    }
}

try {
    Ensure-Admin
    $apps = Get-DefaultAppsList
    if ($apps.Count -eq 0) {
        Write-Log "No default apps found in Appslist.txt." "WARN"
        exit 0
    }
    Write-Log "Removing $($apps.Count) default apps..." "INFO"
    Remove-AppxPackages $apps
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
