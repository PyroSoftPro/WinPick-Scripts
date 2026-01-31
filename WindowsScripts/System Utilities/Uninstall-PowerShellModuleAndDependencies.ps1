# NAME: Uninstall PowerShell Module and Dependencies
# DESCRIPTION: Uninstalls a PowerShell module and its dependencies from PSGallery.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/bastienperez/PowerShell-Toolbox
#

param (
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
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

function Get-RecursiveDependencies {
    param (
        [string]$Module
    )

    $target = Find-Module -Name $Module -ErrorAction Stop
    if ($target.Dependencies.Count -eq 0) {
        return @($target.Name)
    }

    $deps = New-Object System.Collections.Generic.List[string]
    foreach ($dep in $target.Dependencies) {
        $deps.Add($dep.Name)
        $deps.AddRange((Get-RecursiveDependencies -Module $dep.Name))
    }
    $deps + $target.Name
}

try {
    $modules = Get-RecursiveDependencies -Module $ModuleName | Select-Object -Unique
    foreach ($mod in $modules) {
        Write-Log "Uninstalling module: $mod" "INFO"
        try {
            Uninstall-Module -Name $mod -Force -ErrorAction Stop
        } catch {
            Write-Log "Failed to uninstall $mod: $($_.Exception.Message)" "WARN"
        }
    }

    Write-Log "Module uninstall process completed." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
