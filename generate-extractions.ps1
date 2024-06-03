# Import necessary modules
Import-Module -Name 'Environment'
Add-Type -AssemblyName 'System.Xml.Linq'

# Configure logging
$LogPath = "debug.log"
if (Test-Path $LogPath) {
    Remove-Item $LogPath
}
Function Log-Debug {
    Param([string]$message)
    Add-Content -Path $LogPath -Value $message
}

# Load environment variables
$XU_BASE_URL = [Environment]::GetEnvironmentVariable("XU_BASE_URL", "User")
if (-not $XU_BASE_URL) { $XU_BASE_URL = "http://localhost:8065" }

$RSD_TEMPLATE = [Environment]::GetEnvironmentVariable("RSD_TEMPLATE", "User")
if (-not $RSD_TEMPLATE) { $RSD_TEMPLATE = "TEMPLATE_JSON.rsd" }

$RSD_TARGET_FOLDER = [Environment]::GetEnvironmentVariable("RSD_TARGET_FOLDER", "User")
if (-not $RSD_TARGET_FOLDER) { $RSD_TARGET_FOLDER = "./OUTPUT" }

$FILTER_DESTINATION_TYPE = [Environment]::GetEnvironmentVariable("FILTER_DESTINATION_TYPE", "User")
if (-not $FILTER_DESTINATION_TYPE) { $FILTER_DESTINATION_TYPE = "HTTPJSON" }

$DESTINATION_TYPE_PARAMETER = [Environment]::GetEnvironmentVariable("DESTINATION_TYPE_PARAMETER", "User")
if (-not $DESTINATION_TYPE_PARAMETER) { $DESTINATION_TYPE_PARAMETER = "http-json" }

$FORCE_DESTINATION_TYPE = [Environment]::GetEnvironmentVariable("FORCE_DESTINATION_TYPE", "User")
if (-not $FORCE_DESTINATION_TYPE) { $FORCE_DESTINATION_TYPE = $false }
else { $FORCE_DESTINATION_TYPE = $FORCE_DESTINATION_TYPE.ToLower() -in "true", "1" }

$DEFAULT_DAYS_SLIDING_WINDOW = [Environment]::GetEnvironmentVariable("DEFAULT_DAYS_SLIDING_WINDOW", "User")
if (-not $DEFAULT_DAYS_SLIDING_WINDOW) { $DEFAULT_DAYS_SLIDING_WINDOW = 3 }
else { $DEFAULT_DAYS_SLIDING_WINDOW = [int]$DEFAULT_DAYS_SLIDING_WINDOW }

function Get-Extractions {
    param (
        [string]$FilterDestinationType = $FILTER_DESTINATION_TYPE
    )

    $MetaUrl = $env:XU_BASE_URL

    $Params = @{}
    if ($null -ne $FilterDestinationType -and $DESTINATION_TYPES -contains $FilterDestinationType) {
        $Params['destinationType'] = $FilterDestinationType
    }

    # Log URL to debug file
    Log-Debug "meta_url=$MetaUrl"

    try {
        # Sending the GET request
        $Response = Invoke-RestMethod -Uri $MetaUrl -Method Get -ContentType "application/json" -Query $Params
        $Extractions = $Response.extractions

        # Log extractions to debug file
        Log-Debug "extractions=$Extractions"

        # Log the number of extractions found
        $TotalExtractions = $Extractions.Count
        Write-Host "Extractions Found: $TotalExtractions"
    }
    catch {
        Write-Host "Failed to retrieve extractions: $_"
        return $null
    }

    return $Extractions
}

