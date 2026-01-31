# NAME: Remove Custom Win11Debloat Apps
# DESCRIPTION: Removes a custom selection of apps from Appslist.txt for all users.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [string[]]$Apps,
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
            if ($Apps) { $argList += @("-Apps", ($Apps -join ",")) }
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Get-AllAppsList {
    if (-not (Test-Path $AppsListPath)) {
        throw "Appslist.txt not found at $AppsListPath"
    }
    $apps = @()
    foreach ($line in Get-Content -Path $AppsListPath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) {
            $trimmed = $trimmed.TrimStart("#").Trim()
        }
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("-")) { continue }
        if ($trimmed.StartsWith("The apps below")) { continue }
        if ($trimmed.StartsWith("----")) { continue }
        if ($trimmed.Contains("#")) {
            $trimmed = $trimmed.Split("#")[0].Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $apps += $trimmed
        }
    }
    return $apps | Sort-Object -Unique
}

function Prompt-ForApps {
    param (
        [string[]]$AvailableApps
    )
    Write-Host ""
    Write-Host "Select apps to remove by number (comma-separated), or type 'all' to remove all listed apps."
    Write-Host ""
    for ($i = 0; $i -lt $AvailableApps.Count; $i++) {
        Write-Host ("{0,3}. {1}" -f ($i + 1), $AvailableApps[$i])
    }
    Write-Host ""
    $selection = Read-Host "Enter selection"
    if ($selection -eq "all") {
        return $AvailableApps
    }
    $indices = $selection -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" } | ForEach-Object { [int]$_ }
    $selected = @()
    foreach ($index in $indices) {
        if ($index -ge 1 -and $index -le $AvailableApps.Count) {
            $selected += $AvailableApps[$index - 1]
        }
    }
    return $selected | Sort-Object -Unique
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
    $availableApps = Get-AllAppsList
    if ($availableApps.Count -eq 0) {
        Write-Log "No apps found in Appslist.txt." "WARN"
        exit 0
    }

    if (-not $Apps -or $Apps.Count -eq 0) {
        $Apps = Prompt-ForApps -AvailableApps $availableApps
    } else {
        $Apps = $Apps -join "," -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    if (-not $Apps -or $Apps.Count -eq 0) {
        Write-Log "No apps selected. Exiting." "WARN"
        exit 0
    }

    Write-Log "Removing $($Apps.Count) selected apps..." "INFO"
    Remove-AppxPackages $Apps
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
