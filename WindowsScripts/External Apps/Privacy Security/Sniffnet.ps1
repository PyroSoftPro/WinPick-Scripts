# NAME: Sniffnet
# DESCRIPTION: Installs Sniffnet from the official download URL. Use -Undo to uninstall.
# UNDOABLE: Yes
# UNDO_DESC: Uninstalls Sniffnet using the installed uninstall entry.
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$AppName = "Sniffnet"
$DownloadUrls = @{
    "arm64" = "https://github.com/GyulyVGC/sniffnet/releases/latest/download/Sniffnet_Windows_arm64.msi"
    "x64"   = "https://github.com/GyulyVGC/sniffnet/releases/latest/download/Sniffnet_Windows_x64.msi"
    "x86"   = "https://github.com/GyulyVGC/sniffnet/releases/latest/download/Sniffnet_Windows_x86.msi"
}

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

function Get-OsArch {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "ARM64" { return "arm64" }
        "AMD64" { return "x64" }
        "x86" { return "x86" }
        default { return "x64" }
    }
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
    $arch = Get-OsArch
    $downloadUrl = $DownloadUrls[$arch]
    if (-not $downloadUrl) {
        throw "Unsupported architecture: $arch"
    }

    $installerPath = Join-Path $env:TEMP "Sniffnet_$arch.msi"
    Write-Log "Downloading Sniffnet ($arch) from $downloadUrl" "INFO"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

    Write-Log "Installing Sniffnet from $installerPath" "INFO"
    $args = @("/i", $installerPath, "/qn", "/norestart")
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru
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
