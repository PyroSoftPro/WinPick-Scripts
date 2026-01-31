# NAME: Remove Docker Trash
# DESCRIPTION: Prunes unused Docker containers, images, and optionally volumes.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/stevencohn/WindowsPowerShell
#

param (
    [switch]$Volumes,
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

try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker CLI not found. Install Docker Desktop and retry."
    }

    $args = @("system", "prune", "-f")
    if ($Volumes) {
        $args += "--volumes"
    }

    Write-Log "Running docker $($args -join ' ')." "INFO"
    $process = Start-Process -FilePath "docker" -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Docker prune failed with exit code $($process.ExitCode)."
    }

    Write-Log "Docker cleanup completed." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
