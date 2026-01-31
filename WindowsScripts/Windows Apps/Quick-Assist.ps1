# NAME: Quick Assist
# DESCRIPTION: Removes Quick Assist for all users and deprovisions it. Use -Undo to reinstall via WinGet.
# UNDOABLE: Yes
# UNDO_DESC: Reinstalls Quick Assist using WinGet (Microsoft Store).
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

function Remove-QuickAssist {
    $appxName = "MicrosoftCorporationII.QuickAssist"
    $removeCmd = Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue
    $supportsAllUsers = $false
    if ($removeCmd) {
        $supportsAllUsers = $removeCmd.Parameters.ContainsKey("AllUsers")
    }

    Write-Log "Removing installed Quick Assist packages..." "INFO"
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

    Write-Log "Removing provisioned Quick Assist package..." "INFO"
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

function Install-QuickAssist {
    $wingetId = "9P7BP5VNWKX5"
    $appxName = "MicrosoftCorporationII.QuickAssist"

    $existing = Get-AppxPackage -Name $appxName -AllUsers -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "Quick Assist is already installed. No action taken." "INFO"
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is not available. Install WinGet (App Installer) and retry."
    }

    Write-Log "Installing Quick Assist via WinGet..." "INFO"
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
    Write-Log "Quick Assist installed successfully." "INFO"
}

try {
    Ensure-Admin
    if ($Undo) {
        Write-Log "Starting undo operation (reinstall Quick Assist)..." "INFO"
        Install-QuickAssist
    } else {
        Write-Log "Starting removal operation..." "INFO"
        Remove-QuickAssist
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
