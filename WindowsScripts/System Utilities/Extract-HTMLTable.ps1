# NAME: Extract HTML Table
# DESCRIPTION: Extracts HTML tables from a URL or local file into objects and optionally CSV.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/bastienperez/PowerShell-Toolbox
#

param (
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [int]$TableNumber,
    [switch]$AllTables,
    [switch]$LocalFile,
    [string]$OutputPath,
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

function Extract-HTMLTable {
    param (
        [string]$Source,
        [int]$TableNumber,
        [switch]$AllTables,
        [switch]$LocalFile
    )

    [System.Collections.Generic.List[PSObject]]$tablesArray = @()

    if ($LocalFile) {
        $html = New-Object -ComObject "HTMLFile"
        $source = Get-Content -Path $Source -Raw
        $html.IHTMLDocument2_write($source)
        $tables = @($html.getElementsByTagName("TABLE"))
    } else {
        $webRequest = Invoke-WebRequest -Uri $Source -UseBasicParsing
        $tables = @($webRequest.ParsedHtml.getElementsByTagName("TABLE"))
    }

    if ($TableNumber -and -not $AllTables) {
        $tables = @($tables[$TableNumber])
    }

    $currentTable = 0
    foreach ($table in $tables) {
        $titles = @()
        $rows = @($table.Rows)
        $currentTable++

        foreach ($row in $rows) {
            $cells = @($row.Cells)

            if ($cells.Count -eq 0) { continue }
            if ($cells[0].tagName -eq "TH") {
                $titles = @($cells | ForEach-Object { ("" + $_.InnerText).Trim() })
                continue
            }

            if (-not $titles) {
                $titles = @(1..($cells.Count + 1) | ForEach-Object { "P$_" })
            }

            $resultObject = [Ordered]@{ TableNumber = $currentTable }
            for ($counter = 0; $counter -lt $cells.Count; $counter++) {
                $title = $titles[$counter]
                if (-not $title) { continue }
                $resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()
            }

            $tablesArray.Add([PSCustomObject]$resultObject)
        }
    }

    return $tablesArray
}

try {
    $results = Extract-HTMLTable -Source $Url -TableNumber $TableNumber -AllTables:$AllTables -LocalFile:$LocalFile
    if ($OutputPath) {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Log "Saved output to $OutputPath" "INFO"
    } else {
        $results | ForEach-Object { $_ }
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
