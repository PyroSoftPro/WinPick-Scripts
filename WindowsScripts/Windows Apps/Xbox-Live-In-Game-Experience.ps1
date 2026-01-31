# NAME: Xbox Live In-Game Experience
# DESCRIPTION: Removes Xbox Live In-Game Experience for all users and deprovisions it. Use -Undo to reinstall via WinGet.
# UNDOABLE: Yes
# UNDO_DESC: Reinstalls Xbox Live In-Game Experience using WinGet (Microsoft Store).
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

function Remove-XboxLiveInGameExperience {
    $appxName = "Microsoft.Xbox.TCUI"
    $removeCmd = Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue
    $supportsAllUsers = $false
    if ($removeCmd) {
        $supportsAllUsers = $removeCmd.Parameters.ContainsKey("AllUsers")
    }

    Write-Log "Removing installed Xbox Live In-Game Experience packages..." "INFO"
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

    Write-Log "Removing provisioned Xbox Live In-Game Experience package..." "INFO"
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

function Install-XboxLiveInGameExperience {
    $wingetId = "9NKNC0LD5NN6"
    $appxName = "Microsoft.Xbox.TCUI"

    $existing = Get-AppxPackage -Name $appxName -AllUsers -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "Xbox Live In-Game Experience is already installed. No action taken." "INFO"
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is not available. Install WinGet (App Installer) and retry."
    }

    Write-Log "Installing Xbox Live In-Game Experience via WinGet..." "INFO"
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
    Write-Log "Xbox Live In-Game Experience installed successfully." "INFO"
}

try {
    Ensure-Admin
    if ($Undo) {
        Write-Log "Starting undo operation (reinstall Xbox Live In-Game Experience)..." "INFO"
        Install-XboxLiveInGameExperience
    } else {
        Write-Log "Starting removal operation..." "INFO"
        Remove-XboxLiveInGameExperience
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
