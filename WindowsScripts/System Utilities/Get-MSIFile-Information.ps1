# NAME: Get MSI File Information
# DESCRIPTION: Reads metadata from MSI files (product, version, language, etc.).
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/bastienperez/PowerShell-Toolbox
#

param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [System.IO.FileInfo[]]$Path,
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

function Get-MSIFileInformation {
    param (
        [System.IO.FileInfo]$FilePath
    )

    $msiOpenDatabaseModeReadOnly = 0
    $productLanguageHashTable = @{
        "1025" = "Arabic"
        "1026" = "Bulgarian"
        "1027" = "Catalan"
        "1028" = "Chinese - Traditional"
        "1029" = "Czech"
        "1030" = "Danish"
        "1031" = "German"
        "1032" = "Greek"
        "1033" = "English"
        "1034" = "Spanish"
        "1035" = "Finnish"
        "1036" = "French"
        "1037" = "Hebrew"
        "1038" = "Hungarian"
        "1040" = "Italian"
        "1041" = "Japanese"
        "1042" = "Korean"
        "1043" = "Dutch"
        "1044" = "Norwegian"
        "1045" = "Polish"
        "1046" = "Brazilian"
        "1048" = "Romanian"
        "1049" = "Russian"
        "1050" = "Croatian"
        "1051" = "Slovak"
        "1053" = "Swedish"
        "1054" = "Thai"
        "1055" = "Turkish"
        "1058" = "Ukrainian"
        "1060" = "Slovenian"
        "1061" = "Estonian"
        "1062" = "Latvian"
        "1063" = "Lithuanian"
        "1081" = "Hindi"
        "1087" = "Kazakh"
        "2052" = "Chinese - Simplified"
        "2070" = "Portuguese"
        "2074" = "Serbian"
    }

    $summaryInfoHashTable = @{
        1  = "Codepage"
        2  = "Title"
        3  = "Subject"
        4  = "Author"
        5  = "Keywords"
        6  = "Comment"
        7  = "Template"
        8  = "LastAuthor"
        9  = "RevisionNumber"
        10 = "EditTime"
        11 = "LastPrinted"
        12 = "CreationDate"
        13 = "LastSaved"
        14 = "PageCount"
        15 = "WordCount"
        16 = "CharacterCount"
        18 = "ApplicationName"
        19 = "Security"
    }

    $properties = @("ProductVersion", "ProductCode", "ProductName", "Manufacturer", "ProductLanguage", "UpgradeCode")

    $file = Get-ChildItem $FilePath -ErrorAction Stop
    $object = [PSCustomObject][ordered]@{
        FileName   = $file.Name
        FilePath   = $file.FullName
        LengthMB   = [math]::Round(($file.Length / 1MB), 2)
    }

    $windowsInstallerObject = New-Object -ComObject WindowsInstaller.Installer
    $msiDatabase = $windowsInstallerObject.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $windowsInstallerObject, @($file.FullName, $msiOpenDatabaseModeReadOnly))

    foreach ($property in $properties) {
        $query = "SELECT Value FROM Property WHERE Property = '$property'"
        $view = $msiDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $msiDatabase, $query)
        $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
        $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)

        try {
            $value = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
        } catch {
            $value = ""
        }

        if ($property -eq "ProductLanguage") {
            $value = "$value ($($productLanguageHashTable[$value]))"
        }

        $object | Add-Member -MemberType NoteProperty -Name $property -Value $value
        $view.GetType().InvokeMember("Close", "InvokeMethod", $null, $view, $null)
    }

    $summaryInfo = $msiDatabase.GetType().InvokeMember("SummaryInformation", "GetProperty", $null, $msiDatabase, $null)
    $summaryInfoPropertiesCount = $summaryInfo.GetType().InvokeMember("PropertyCount", "GetProperty", $null, $summaryInfo, $null)

    (1..$summaryInfoPropertiesCount) | ForEach-Object {
        $value = $summaryInfo.GetType().InvokeMember("Property", "GetProperty", $null, $summaryInfo, $_)
        if ($null -eq $value) { $value = "" }
        $object | Add-Member -MemberType NoteProperty -Name $summaryInfoHashTable[$_] -Value $value
    }

    $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($windowsInstallerObject)
    [System.GC]::Collect()

    return $object
}

try {
    foreach ($file in $Path) {
        Get-MSIFileInformation -FilePath $file
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
