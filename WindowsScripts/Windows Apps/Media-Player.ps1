# NAME: Media Player
# DESCRIPTION: Removes Media Player for all users and deprovisions it. Use -Undo to reinstall via WinGet.
# UNDOABLE: Yes
# UNDO_DESC: Reinstalls Media Player using WinGet (Microsoft Store).
#

param (
    [switch]$Undo,
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

function Remove-MediaPlayer {
    $appxName = "Microsoft.ZuneMusic"
    $removeCmd = Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue
    $supportsAllUsers = $false
    if ($removeCmd) {
        $supportsAllUsers = $removeCmd.Parameters.ContainsKey("AllUsers")
    }

    Write-Log "Removing installed Media Player packages..." "INFO"
    $packages = Get-AppxPackage -Name $appxName -AllUsers -ErrorAction SilentlyContinue
    if ($packages) {
        foreach ($pkg in $packages) {
            if ($supportsAllUsers) {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            } else {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            }
        }
        Write-Log "Installed packages removed." "INFO"
    } else {
        Write-Log "No installed packages found." "INFO"
    }

    Write-Log "Removing provisioned Media Player package..." "INFO"
    $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $appxName }
    if ($prov) {
        foreach ($p in $prov) {
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName | Out-Null
        }
        Write-Log "Provisioned package removed." "INFO"
    } else {
        Write-Log "No provisioned package found." "INFO"
    }
}

function Install-MediaPlayer {
    $wingetId = "9WZDNCRFJ3PT"
    $appxName = "Microsoft.ZuneMusic"

    $existing = Get-AppxPackage -Name $appxName -AllUsers -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "Media Player is already installed. No action taken." "INFO"
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is not available. Install WinGet (App Installer) and retry."
    }

    Write-Log "Installing Media Player via WinGet..." "INFO"
    $args = @(
        "install",
        "--id", $wingetId,
        "--source", "msstore",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "WinGet failed with exit code $($process.ExitCode)."
    }
    Write-Log "Media Player installed successfully." "INFO"
}

try {
    Ensure-Admin
    if ($Undo) {
        Write-Log "Starting undo operation (reinstall Media Player)..." "INFO"
        Install-MediaPlayer
    } else {
        Write-Log "Starting removal operation..." "INFO"
        Remove-MediaPlayer
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
