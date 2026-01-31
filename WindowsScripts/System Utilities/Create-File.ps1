# NAME: Create File
# DESCRIPTION: Creates a new file at the specified path with optional content. Use -Undo to delete it.
# UNDOABLE: Yes
# UNDO_DESC: Deletes the file created by this script.
# LINK: https://github.com/davidbombal/Powershell
#

param (
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$Content,
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$MarkerFile = Join-Path $PSScriptRoot "$(Split-Path -Leaf $PSCommandPath).created.json"

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
    if ($Undo) {
        if (Test-Path -Path $MarkerFile) {
            $marker = Get-Content -Path $MarkerFile -Raw | ConvertFrom-Json
            if ($marker.Path -and (Test-Path -Path $marker.Path)) {
                Remove-Item -Path $marker.Path -Force
                Write-Log "Removed file: $($marker.Path)" "INFO"
            }
            Remove-Item -Path $MarkerFile -Force -ErrorAction SilentlyContinue
        } else {
            Write-Log "No marker found; nothing to undo." "INFO"
        }

        Write-Log "Script completed successfully." "INFO"
        exit 0
    }

    if (Test-Path -Path $Path) {
        throw "File already exists: $Path"
    }

    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    if ($Content) {
        Set-Content -Path $Path -Value $Content -Force
    } else {
        New-Item -Path $Path -ItemType File -Force | Out-Null
    }

    @{ Path = $Path } | ConvertTo-Json | Set-Content -Path $MarkerFile -Force
    Write-Log "Created file: $Path" "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
