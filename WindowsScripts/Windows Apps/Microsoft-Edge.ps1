# NAME: Microsoft Edge
# DESCRIPTION: Removes Microsoft Edge (Chromium and legacy Appx packages). Use -Undo to reinstall via WinGet.
# UNDOABLE: Yes
# UNDO_DESC: Reinstalls Microsoft Edge using WinGet.
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

function Stop-EdgeProcesses {
    $processNames = @(
        "msedge",
        "msedgewebview2",
        "MicrosoftEdgeUpdate",
        "Widgets",
        "WidgetService",
        "CrossDeviceResume",
        "Resume"
    )
    foreach ($name in $processNames) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

function Remove-EdgeShortcuts {
    Write-Log "Removing Edge shortcuts..." "INFO"
    $shortcutPaths = @()
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-Path -Path (Join-Path $_.FullName "NTUSER.DAT")
    }
    foreach ($profile in $userProfiles) {
        $shortcutPaths += @(
            "$($profile.FullName)\Desktop\Microsoft Edge.lnk",
            "$($profile.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$($profile.FullName)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$($profile.FullName)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$($profile.FullName)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk"
        )
    }
    $shortcutPaths += "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"
    foreach ($path in $shortcutPaths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Uninstall-EdgeFromRegistry {
    Write-Log "Running Edge uninstall entries from registry..." "INFO"
    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($key in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            $props = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -like "*Microsoft Edge*") {
                $uninstallString = $props.UninstallString
                if ([string]::IsNullOrWhiteSpace($uninstallString)) { continue }
                if ($uninstallString -like "*msiexec*") {
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString /qn" -Wait -WindowStyle Hidden
                } else {
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString --force-uninstall --system-level --verbose-logging --silent" -Wait -WindowStyle Hidden
                }
            }
        }
    }
}

function Uninstall-EdgeSetup {
    Write-Log "Attempting Edge setup.exe uninstall..." "INFO"
    $edgeRoots = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application",
        "${env:ProgramFiles}\Microsoft\Edge\Application"
    )
    foreach ($root in $edgeRoots) {
        if (-not (Test-Path $root)) { continue }
        $setup = Get-ChildItem -Path $root -Recurse -Filter "setup.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like "*\Installer\setup.exe" } |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($setup) {
            Start-Process -FilePath $setup.FullName -ArgumentList "--uninstall --system-level --force-uninstall --verbose-logging --silent" -Wait -WindowStyle Hidden
        }
    }
}

function Remove-EdgeAppxPackages {
    Write-Log "Removing Edge Appx packages..." "INFO"
    Get-AppxPackage -AllUsers Microsoft.MicrosoftEdge | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
    Get-AppxPackage -AllUsers Microsoft.MicrosoftEdge.Stable | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in @("Microsoft.MicrosoftEdge", "Microsoft.MicrosoftEdge.Stable") } |
        ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null }
}

function Remove-EdgeFolders {
    $paths = @(
        "${env:ProgramFiles}\Microsoft\Edge",
        "${env:ProgramFiles(x86)}\Microsoft\Edge",
        "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-MicrosoftEdge {
    $wingetId = "XPFFTQ037JWMHS"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is not available. Install WinGet (App Installer) and retry."
    }
    Write-Log "Installing Microsoft Edge via WinGet..." "INFO"
    $args = @(
        "install",
        "--id", $wingetId,
        "--source", "winget",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "WinGet failed with exit code $($process.ExitCode)."
    }
    Write-Log "Microsoft Edge installed successfully." "INFO"
}

try {
    Ensure-Admin
    if ($Undo) {
        Write-Log "Starting undo operation (reinstall Microsoft Edge)..." "INFO"
        Install-MicrosoftEdge
    } else {
        Write-Log "Starting removal operation..." "INFO"
        Stop-EdgeProcesses
        Uninstall-EdgeFromRegistry
        Uninstall-EdgeSetup
        Remove-EdgeAppxPackages
        Remove-EdgeShortcuts
        Remove-EdgeFolders
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
