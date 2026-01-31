# NAME: Update PowerShell Resources
# DESCRIPTION: Updates modules and scripts installed via PSResourceGet.
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

function Remove-OldResources {
    param ([string]$Name, [version]$LatestVersion)
    $oldVersions = Get-PSResource -Name $Name -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -ne $LatestVersion }

    foreach ($old in $oldVersions) {
        Write-Log "Removing old version $($old.Version) of $Name" "INFO"
        if (-not $SimulationMode) {
            Uninstall-PSResource -Name $Name -Version $old.Version -ErrorAction SilentlyContinue
        }
    }
}

try {
    if (-not (Get-Command Get-PSResource -ErrorAction SilentlyContinue)) {
        throw "PSResourceGet is not available. Install it and retry."
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $resources = Get-PSResource
    if ($IncludedModules) {
        $resources = $resources | Where-Object { $_.Name -like $IncludedModules }
    }

    foreach ($resource in $resources) {
        if ($ExcludedModules -contains $resource.Name) {
            Write-Log "Skipping excluded resource: $($resource.Name)" "WARN"
            continue
        }

        $gallery = Find-PSResource -Name $resource.Name -ErrorAction SilentlyContinue
        if (-not $gallery) {
            Write-Log "Resource $($resource.Name) not found in PSGallery." "WARN"
            continue
        }

        $latest = [version]$gallery.Version
        $current = [version]$resource.Version

        if ($latest -gt $current) {
            Write-Log "Updating $($resource.Name): $current -> $latest" "INFO"
            if (-not $SimulationMode) {
                if ($SkipPublisherCheck) {
                    Update-PSResource -Name $resource.Name -Force -SkipPublisherCheck -ErrorAction Stop
                } else {
                    Update-PSResource -Name $resource.Name -Force -ErrorAction Stop
                }
                Remove-OldResources -Name $resource.Name -LatestVersion $latest
            }
        } else {
            Write-Log "$($resource.Name) is up to date ($current)." "INFO"
        }
    }

    Write-Log "Resource update process completed." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
