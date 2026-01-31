# NAME: Start Chrome
# DESCRIPTION: Launches Google Chrome.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/davidbombal/Powershell
#

param (
    [string]$Arguments,
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

function Get-ChromePath {
    $paths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path -Path $path) {
            return $path
        }
    }

    $cmd = Get-Command "chrome.exe" -ErrorAction SilentlyContinue
    return $cmd?.Source
}

try {
    $chromePath = Get-ChromePath
    if (-not $chromePath) {
        throw "Chrome executable not found."
    }

    if ($Arguments) {
        Start-Process -FilePath $chromePath -ArgumentList $Arguments
    } else {
        Start-Process -FilePath $chromePath
    }

    Write-Log "Chrome launched." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
