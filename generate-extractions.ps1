# Import necessary modules
Add-Type -AssemblyName 'System.Xml.Linq'

function Read-DotEnv {
    param (
        [string]$FilePath = ".env"
    )

    if (Test-Path $FilePath) {
        $envContent = Get-Content -Path $FilePath -Raw
        $envContent -split "`n" | ForEach-Object {
            $_ = $_.Trim()
            if (-not $_.StartsWith("#") -and $_.Contains("=")) {
                $splitIndex = $_.IndexOf("=")
                $key = $_.Substring(0, $splitIndex).Trim()
                $value = $_.Substring($splitIndex + 1).Trim().Trim('"')
                [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
            }
        }
    }
    else {
        Write-Host "File '$FilePath' not found."
    }
}

# Usage Example
Read-DotEnv -FilePath ".env"

# Load environment variables
$XU_BASE_URL = [Environment]::GetEnvironmentVariable("XU_BASE_URL", [System.EnvironmentVariableTarget]::Process)
if (-not $XU_BASE_URL) { $XU_BASE_URL = "http://localhost:8065" }

$RSD_TEMPLATE = [Environment]::GetEnvironmentVariable("RSD_TEMPLATE", [System.EnvironmentVariableTarget]::Process)
if (-not $RSD_TEMPLATE) { $RSD_TEMPLATE = "TEMPLATE_JSON.rsd" }

$RSD_TARGET_FOLDER = [Environment]::GetEnvironmentVariable("RSD_TARGET_FOLDER", [System.EnvironmentVariableTarget]::Process)
if (-not $RSD_TARGET_FOLDER) { $RSD_TARGET_FOLDER = "./OUTPUT" }

$FILTER_DESTINATION_TYPE = [Environment]::GetEnvironmentVariable("FILTER_DESTINATION_TYPE", [System.EnvironmentVariableTarget]::Process)
if (-not $FILTER_DESTINATION_TYPE) { $FILTER_DESTINATION_TYPE = "HTTPJSON" }

$DESTINATION_TYPE_PARAMETER = [Environment]::GetEnvironmentVariable("DESTINATION_TYPE_PARAMETER", [System.EnvironmentVariableTarget]::Process)
if (-not $DESTINATION_TYPE_PARAMETER) { $DESTINATION_TYPE_PARAMETER = "http-json" }

$FORCE_DESTINATION_TYPE = [Environment]::GetEnvironmentVariable("FORCE_DESTINATION_TYPE", [System.EnvironmentVariableTarget]::Process)
if (-not $FORCE_DESTINATION_TYPE) { $FORCE_DESTINATION_TYPE = $false }
else { $FORCE_DESTINATION_TYPE = $FORCE_DESTINATION_TYPE.ToLower() -in "true", "1" }

$DEFAULT_DAYS_SLIDING_WINDOW = [Environment]::GetEnvironmentVariable("DEFAULT_DAYS_SLIDING_WINDOW", [System.EnvironmentVariableTarget]::Process)
if (-not $DEFAULT_DAYS_SLIDING_WINDOW) { $DEFAULT_DAYS_SLIDING_WINDOW = 3 }
else { $DEFAULT_DAYS_SLIDING_WINDOW = [int]$DEFAULT_DAYS_SLIDING_WINDOW }

$tmpSLIDING_COLUMNS = [Environment]::GetEnvironmentVariable("SLIDING_COLUMNS", [System.EnvironmentVariableTarget]::Process)
if (-not $tmpSLIDING_COLUMNS) { $SLIDING_COLUMNS = @("AEDAT") }
else { $SLIDING_COLUMNS = ConvertFrom-Json $tmpSLIDING_COLUMNS | ConvertFrom-Json }


# Define mapping of data types as a PowerShell hash table
$TYPE_MAPPING = @{
    "Byte"                   = "int"
    "Short"                  = "int"
    "Int"                    = "int"
    "Long"                   = "int"
    "Double"                 = "double"
    "Decimal"                = "decimal"
    "NumericString"          = "string"
    "StringLengthMax"        = "string"
    "StringLengthUnknown"    = "string"
    "ByteArrayLengthExact"   = "string"
    "ByteArrayLengthMax"     = "string"
    "ByteArrayLengthUnknown" = "string"
    "Date"                   = "datetime"
    "ConvertedDate"          = "datetime"
    "Time"                   = "datetime"
}

# Define the list of destination types available in Xtract Universal as a PowerShell array
$DESTINATION_TYPES = @(
    "Unknown",
    "Alteryx",
    "AlteryxConnect",
    "AzureDWH",
    "AzureBlob",
    "CSV",
    "DB2",
    "EXASOL",
    "FileCSV",
    "FileJSON",
    "GoodData",
    "GoogleCloudStorage",
    "HANA",
    "HTTPJSON",
    "MicroStrategy",
    "MySQL",
    "ODataAtom",
    "Oracle",
    "Parquet",
    "PostgreSQL",
    "PowerBI",
    "PowerBIConnector",
    "Qlik",
    "Redshift",
    "S3Destination",
    "Salesforce",
    "SharePoint",
    "Snowflake",
    "SQLServer",
    "SqlServerReportingServices",
    "Tableau",
    "Teradata",
    "Vertica"
)



function Get-Extractions {
    param (
        [string]$FilterDestinationType = $FILTER_DESTINATION_TYPE
    )

    $MetaUrl = $XU_BASE_URL

    $Params = @{}
    if ($null -ne $FilterDestinationType -and $DESTINATION_TYPES -contains $FilterDestinationType) {
        $Params['destinationType'] = $FilterDestinationType
    }

    # Log URL to debug file
    Write-Host "meta_url=$MetaUrl"

    try {
        # Sending the GET request
        $Response = Invoke-RestMethod -Uri $MetaUrl -Method Get -ContentType "application/json" -Body $Params
        $Extractions = $Response.extractions

        # Log extractions to debug file
        Write-Host "extractions=$Extractions"

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

function Get-ColumnList {
    param (
        [string]$ExtractionName
    )

    # Construct the URL for fetching column information
    $MetaUrl = "$XU_BASE_URL/config/extractions/$ExtractionName/result-columns"

    # Log the URL
    Write-Host "meta_url=$MetaUrl"

    try {
        # Sending the GET request
        $Response = Invoke-RestMethod -Uri $MetaUrl -Method Get -ContentType "application/json"
        $Content = $Response | ConvertTo-Json -Depth 100

        # Log raw columns
        Write-Host "Raw columns of extraction '$ExtractionName'"
        Write-Host "content=$Content"

        # Parse the columns from the response
        $Columns = $Response.columns

        # Log decoded columns
        Write-Host "Decoded columns of extraction '$ExtractionName'"
        Write-Host "columns=$Columns"
    }
    catch {
        Write-Host "Failed to retrieve columns for extraction '$ExtractionName': $_"
        return $null
    }

    return $Columns
}

function Get-Parameters {
    param (
        [string]$ExtractionName
    )

    # Construct the URL for fetching parameters
    $MetaUrl = "$XU_BASE_URL/config/extractions/$ExtractionName/parameters"

    # Log the URL
    Write-Host "meta_url=$MetaUrl"

    try {
        # Sending the GET request
        $Response = Invoke-RestMethod -Uri $MetaUrl -Method Get -ContentType "application/json"
        $Content = $Response | ConvertTo-Json -Depth 100

        # Log raw content
        Write-Host "Raw parameters of extraction '$ExtractionName'"
        Write-Host "content=$Content"

        # Parse the parameters from the response
        $Parameters = $Response.custom

        # Log decoded parameters
        Write-Host "Decoded parameters of extraction '$ExtractionName'"
        Write-Host "parameters=$Parameters"
    }
    catch {
        Write-Host "Failed to retrieve parameters for extraction '$ExtractionName': $_"
        return $null
    }

    return $Parameters
}

function New-RSD {
    param (
        [PSCustomObject]$Extraction,
        [string]$Filename,
        [string]$ExtractionUrl,
        [bool]$ForceDestinationType = $FORCE_DESTINATION_TYPE -eq "true"
    )

    $ExtractionName = $Extraction.name
    $Columns = Get-ColumnList -ExtractionName $ExtractionName

    # Load the template RSD XML
    [xml]$TemplateTree = [xml](Get-Content -Path $RSD_TEMPLATE)

    [System.Xml.XmlNamespaceManager] $nsm = new-object System.Xml.XmlNamespaceManager $TemplateTree.NameTable
    $nsm.AddNamespace("api", "http://apiscript.com/ns?v1")
    $nsm.AddNamespace("xs", "http://www.w3.org/2001/XMLSchema")

    # Set extraction URL
    $SetElement = $TemplateTree.SelectSingleNode("//api:set[@attr='URI']", $nsm)
    $SetElement.value = $ExtractionUrl

    # Prepare field section
    $FieldSection = $TemplateTree.SelectSingleNode("//api:info", $nsm)
    $FieldSection.RemoveAll()
    $FieldSection.SetAttribute("title", $ExtractionName)
    $FieldSection.SetAttribute("desc", "Type: $($Extraction.type), Source: $($Extraction.source)")
    $FieldSection.SetAttribute("xmlns:other", "http://apiscript.com/ns?v1")

    foreach ($Column in $Columns) {
        $Attributes = @{
            "name"        = $Column.name
            "xs:type"     = $TYPE_MAPPING[$Column.type] -or "unknown"
            "key"         = if ($Column.isPrimaryKey) { "true" } else { "false" }
            "other:xPath" = "/json/$($Column.name)"
            "readonly"    = "true"
        }

        if ($Column.PSObject.Properties.Name -contains "length") {
            $Attributes["columnsize"] = if ($Column.type -eq "ByteArrayLengthExact") { [string]$($Column.length * 2) } else { [string]$Column.length }
        }

        if ($Column.PSObject.Properties.Name -contains "decimalsCount") {
            $Attributes["decimaldigits"] = [string]$Column.decimalsCount
        }

        if ($Column.PSObject.Properties.Name -contains "description") {
            $Attributes["description"] = $Column.description
        }

        Write-Host "Column: $Column"
        Write-Host "Attributes: $Attributes"

        $AttrElement = $TemplateTree.CreateElement("attr")
        foreach ($Attribute in $Attributes.GetEnumerator()) {
            $AttrElement.SetAttribute($Attribute.Key, $Attribute.Value)
        }
        $FieldSection.AppendChild($AttrElement)
    }

    # Restore xs namespace due to malformed XML structure of RSD format
    $TemplateTree.DocumentElement.SetAttribute("xmlns:xs", $nsm.LookupNamespace("xs"))

    # Ensure the target directory exists
    $TargetDir = [System.IO.Path]::GetDirectoryName($Filename)
    if (-not (Test-Path -Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force
    }

    # Save the updated XML to the specified file
    $TemplateTree.Save($Filename)
}


function New-RSDs {
    param (
        [PSCustomObject]$Extraction,
        [bool]$ForceDestinationType = $FORCE_DESTINATION_TYPE -eq "true",
        [int]$SlidingDays = [int]$DEFAULT_DAYS_SLIDING_WINDOW
    )

    $ExtractionName = $Extraction.name
    $Columns = Get-ColumnList -ExtractionName $ExtractionName

    $ExtractionBaseUrl = "$XU_BASE_URL/run/$ExtractionName/"
    if ($ForceDestinationType) {
        $ExtractionBaseUrl += "?destination=$DESTINATION_TYPE_PARAMETER"
    }

    $ExtractionUrls = @{
        (Join-Path $RSD_TARGET_FOLDER "$ExtractionName.rsd") = $ExtractionBaseUrl
    }

    foreach ($Column in $Columns) {
        $ColumnName = $Column.name
        if ($SLIDING_COLUMNS -contains $ColumnName) {
            $SlidingUrl = $ExtractionBaseUrl + $(If ($string -contains '?') { "&" }  Else { "?" } ) + "where=$ColumnName%20%3E=%20%27" +
                ((Get-Date).AddDays(-$SlidingDays).ToString("yyyyMMdd")) + "%27"
            $ExtractionUrls[(Join-Path $RSD_TARGET_FOLDER "$($ExtractionName)_sliding_$($ColumnName)_$($SlidingDays)days.rsd")] = $SlidingUrl
        }
    }

    # Increment global counter
    $script:RUN_EXTRACTIONS += 1
    $SlidingCounter = 0

    foreach ($Key in $ExtractionUrls.Keys) {
        $Filename = $Key
        $ExtractionUrl = $ExtractionUrls[$Key]

        # Print log to console
        Write-Host "($script:RUN_EXTRACTIONS" + "_" + "$SlidingCounter/$script:TOTAL_EXTRACTIONS) `tGenerating RSD for: $ExtractionName"
        $SlidingCounter += 1

        New-RSD -Extraction $Extraction -Filename $Filename -ExtractionUrl $ExtractionUrl -ForceDestinationType $ForceDestinationType
    }
}


$Extractions = Get-Extractions

foreach ($Extraction in $Extractions) {
    New-RSDs -Extraction $Extraction
}