# NAME: Get .NET Versions
# DESCRIPTION: Lists installed .NET Framework and .NET (Core/SDK) versions.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/jhochwald/PowerShell-collection
#

param (
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

function Get-DotNetFrameworkVersions {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\NET Framework Setup\NDP"
    )

    foreach ($path in $paths) {
        if (-not (Test-Path -Path $path)) { continue }
        Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue |
            Get-ItemProperty -ErrorAction SilentlyContinue |
            Where-Object { $_.Version -and $_.PSChildName -match '^v' } |
            Select-Object @{Name="Framework";Expression={$_.PSChildName}}, Version, Release, @{Name="RegistryPath";Expression={$_.PSPath}}
    }
}

function Get-DotNetSdkVersions {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        return @()
    }

    $sdks = & dotnet --list-sdks 2>$null
    $runtimes = & dotnet --list-runtimes 2>$null

    $sdkObjects = $sdks | ForEach-Object {
        if ($_ -match '^(?<version>\S+)\s+\[(?<path>.+)\]$') {
            [PSCustomObject]@{
                Type = ".NET SDK"
                Version = $Matches.version
                Path = $Matches.path
            }
        }
    }

    $runtimeObjects = $runtimes | ForEach-Object {
        if ($_ -match '^(?<name>\S+)\s+(?<version>\S+)\s+\[(?<path>.+)\]$') {
            [PSCustomObject]@{
                Type = $Matches.name
                Version = $Matches.version
                Path = $Matches.path
            }
        }
    }

    $sdkObjects + $runtimeObjects
}

try {
    $frameworks = Get-DotNetFrameworkVersions
    if ($frameworks) {
        $frameworks | ForEach-Object { $_ }
    } else {
        Write-Log ".NET Framework versions not found in registry." "WARN"
    }

    $dotnet = Get-DotNetSdkVersions
    if ($dotnet) {
        $dotnet | ForEach-Object { $_ }
    } else {
        Write-Log "dotnet CLI not found or no SDKs installed." "WARN"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
