# NAME: Invoke Concatenate CSV
# DESCRIPTION: Concatenates CSV files from a directory into a single CSV file.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/bastienperez/PowerShell-Toolbox
#

param (
    [string]$InputDirectory = ".",
    [string]$OutputFile = "Concatenated.csv",
    [string]$Delimiter = ";",
    [switch]$AddSourceFile,
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
    [System.Collections.Generic.List[Object]]$allData = @()
    $files = Get-ChildItem -Path $InputDirectory -Filter "*.csv"

    if ($files.Count -eq 0) {
        Write-Log "No CSV files found in directory: $InputDirectory" "WARN"
        exit 0
    }

    foreach ($file in $files) {
        Write-Verbose "Processing file: $($file.Name)"
        $csvContent = Import-Csv -Path $file.FullName -Delimiter $Delimiter

        foreach ($row in $csvContent) {
            if ($AddSourceFile) {
                $row.PSObject.Properties.Add("SourceFile", $file.Name)
            }

            $newRow = @{}
            foreach ($property in $row.PSObject.Properties) {
                $newRow[$property.Name] = $property.Value
            }
            $allData.Add([PSCustomObject]$newRow)
        }
    }

    if ($allData.Count -gt 0) {
        $allData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Log "Concatenated $($files.Count) file(s) into $OutputFile." "INFO"
        Write-Log "Total rows: $($allData.Count)" "INFO"
    } else {
        Write-Log "No data collected from CSV files." "WARN"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
