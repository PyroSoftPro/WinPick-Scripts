# NAME: Save Download
# DESCRIPTION: Downloads a file from a URL or WebResponse object and saves it using the server filename.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/bastienperez/PowerShell-Toolbox
#

param (
    [Microsoft.PowerShell.Commands.WebResponseObject]$WebResponse,
    [string]$Url,
    [string]$Directory = ".",
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

function Save-Download {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebResponseObject]$Response,
        [string]$TargetDirectory
    )

    if (-not $Response.Headers.ContainsKey("Content-Disposition")) {
        throw "Cannot determine filename for download."
    }

    $content = [System.Net.Mime.ContentDisposition]::new($Response.Headers["Content-Disposition"])
    $fileName = $content.FileName
    if (-not $fileName) {
        throw "Cannot determine filename for download."
    }

    if (-not (Test-Path -Path $TargetDirectory)) {
        New-Item -Path $TargetDirectory -ItemType Directory | Out-Null
    }

    $fullPath = Join-Path -Path $TargetDirectory -ChildPath $fileName
    $file = [System.IO.FileStream]::new($fullPath, [System.IO.FileMode]::Create)
    $file.Write($Response.Content, 0, $Response.RawContentLength)
    $file.Close()

    return $fullPath
}

try {
    if (-not $WebResponse) {
        if (-not $Url) {
            throw "Provide -Url or -WebResponse."
        }
        $WebResponse = Invoke-WebRequest -Uri $Url -UseBasicParsing
    }

    $savedPath = Save-Download -Response $WebResponse -TargetDirectory $Directory
    Write-Log "Saved download to $savedPath" "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
