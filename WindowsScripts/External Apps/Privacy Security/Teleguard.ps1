# NAME: Teleguard
# DESCRIPTION: Installs Teleguard from the official download URL. Use -Undo to uninstall.
# UNDOABLE: Yes
# UNDO_DESC: Uninstalls Teleguard using the installed uninstall entry.
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$AppName = "Teleguard"
$DownloadUrl = "https://pub.teleguard.com/teleguard-desktop-latest.exe"

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

function Get-UninstallEntry {
    param ([string]$DisplayName)

    $paths = @(
        "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        "HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    )

    foreach ($path in $paths) {
        $entry = Get-ItemProperty "$path\\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$DisplayName*" } |
            Select-Object -First 1
        if ($entry) {
            return $entry
        }
    }

    return $null
}

function Invoke-UninstallEntry {
    param ([string]$DisplayName)

    $entry = Get-UninstallEntry -DisplayName $DisplayName
    if (-not $entry) {
        throw "No uninstall entry found for $DisplayName."
    }

    $cmd = if ($entry.QuietUninstallString) { $entry.QuietUninstallString } else { $entry.UninstallString }
    if (-not $cmd) {
        throw "No uninstall command found for $DisplayName."
    }

    if ($cmd -match "msiexec") {
        $cmd = $cmd -replace "/I", "/X" -replace "/i", "/X"
        if ($cmd -notmatch "/qn|/quiet") {
            $cmd = "$cmd /qn /norestart"
        }
    }

    Write-Log "Running uninstall command: $cmd" "INFO"
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Uninstall command failed with exit code $($process.ExitCode)."
    }
}

function Install-App {
    $installerPath = Join-Path $env:TEMP "teleguard-desktop-latest.exe"
    Write-Log "Downloading Teleguard from $DownloadUrl" "INFO"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $installerPath

    Write-Log "Launching Teleguard installer from $installerPath" "INFO"
    $process = Start-Process -FilePath $installerPath -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Installer failed with exit code $($process.ExitCode)."
    }
}

function Uninstall-App {
    Invoke-UninstallEntry -DisplayName $AppName
}

try {
    if ($Undo) {
        Uninstall-App
    } else {
        Install-App
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
