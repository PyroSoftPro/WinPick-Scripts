# NAME: Update All PowerShell Modules
# DESCRIPTION: Updates installed PowerShell modules and removes older versions.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/bastienperez/PowerShell-Toolbox
#

param (
    [String[]]$ExcludedModules,
    [String[]]$IncludedModules,
    [switch]$SkipPublisherCheck,
    [switch]$SimulationMode,
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

function Remove-OldVersions {
    param ([string]$ModuleName, [version]$LatestVersion)
    $oldVersions = Get-InstalledModule -Name $ModuleName -AllVersions -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -ne $LatestVersion }

    foreach ($old in $oldVersions) {
        Write-Log "Removing old version $($old.Version) of $ModuleName" "INFO"
        if (-not $SimulationMode) {
            Uninstall-Module -Name $ModuleName -RequiredVersion $old.Version -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $modules = Get-InstalledModule -ErrorAction SilentlyContinue
    if ($IncludedModules) {
        $modules = $modules | Where-Object { $_.Name -like $IncludedModules }
    }

    foreach ($module in $modules) {
        if ($ExcludedModules -contains $module.Name) {
            Write-Log "Skipping excluded module: $($module.Name)" "WARN"
            continue
        }

        $gallery = Find-Module -Name $module.Name -ErrorAction SilentlyContinue
        if (-not $gallery) {
            Write-Log "Module $($module.Name) not found in PSGallery." "WARN"
            continue
        }

        $latest = [version]$gallery.Version
        $current = [version]$module.Version
        if ($latest -gt $current) {
            Write-Log "Updating $($module.Name): $current -> $latest" "INFO"
            if (-not $SimulationMode) {
                if ($SkipPublisherCheck) {
                    Update-Module -Name $module.Name -Force -SkipPublisherCheck -ErrorAction Stop
                } else {
                    Update-Module -Name $module.Name -Force -ErrorAction Stop
                }
                Remove-OldVersions -ModuleName $module.Name -LatestVersion $latest
            }
        } else {
            Write-Log "$($module.Name) is up to date ($current)." "INFO"
        }
    }

    Write-Log "Module update process completed." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
