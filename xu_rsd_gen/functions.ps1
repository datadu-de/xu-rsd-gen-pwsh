$global:TYPE_MAPPING = @{
    Byte                   = "int";
    Short                  = "int";
    Int                    = "int";
    Long                   = "int";
    Double                 = "double";
    Decimal                = "double";
    NumericString          = "string";
    StringLengthMax        = "string";
    StringLengthUnknown    = "string";
    ByteArrayLengthExact   = "string";
    ByteArrayLengthMax     = "string";
    ByteArrayLengthUnknown = "string";
    Date                   = "datetime";
    ConvertedDate          = "datetime";
    Time                   = "datetime";
}


$global:DESTINATION_TYPES = @(
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


function Set-DotEnv {
    [CmdletBinding()]
    param(
        [string[]]$Path = '.env'
    )

    $dotfile = Get-Content $Path
    
    foreach ($line in $dotfile) {
        $line = $line.Trim()

        if ($line -eq '' -or $line -like '#*') {
            continue
        }

        $key, $value = ($line -split '=', 2).Trim()

        if ($value -like '"*"') {
            # expand \n to `n for double quoted values
            $value = $value -replace '^"|"$', '' -replace '(?<!\\)(\\n)', "`n"
        }
        elseif ($value -like "'*'") {
            $value = $value -replace "^'|'$", ''
        }

        [System.Environment]::SetEnvironmentVariable($key, $value)

    }
}


function Get-Extractions {
    [CmdletBinding()]
    param(
        [string[]]$filterDestionationType = $Env:FILTER_DESTINATION_TYPE
    )

    $meta_url = "$XU_BASE_URL/config/extractions/"

    if ($filterDestionationType -in $DESTINATION_TYPES) {
        $params = @{"destinationType" = ($filterDestionationType -as [string]) }
    }

    Write-Debug $meta_url
    Write-Debug $params

    $response = Invoke-RestMethod `
        -Method Get `
        -Uri $meta_url `
        -Body ($params ?? @{})

    #Write-Debug $response.extractions
    
    return $response.extractions
}


function Get-ColumnList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$extractionName
    )

    $meta_url = "$XU_BASE_URL/config/extractions/$extractionName/result-columns"

    Write-Debug $meta_url
    
    $response = Invoke-RestMethod `
        -Method Get `
        -Uri $meta_url
    
    foreach ($column in $response.columns) {
        Write-Debug $column
    }
    
    return $response.columns
}

function Get-Parameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$extractionName
    )

    $meta_url = "$XU_BASE_URL/config/extractions/$extractionName/parameters"

    Write-Debug $meta_url
    
    $response = Invoke-RestMethod `
        -Method Get `
        -Uri $meta_url
    
    foreach ($column in $response.custom) {
        Write-Debug $column
    }
    
    return $response.custom
}


function Build-Rsd {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        $extraction,
        
        [Parameter(Mandatory = $true)]
        $filename,
        
        [Parameter(Mandatory = $true)]
        $extraction_url,

        [Parameter(Mandatory = $false)]
        $forceDestinationType = $FORCE_DESTINATION_TYPE
    )

    Write-Debug $extraction
    Write-Debug $filename
    Write-Debug $extraction_url
    Write-Debug $forceDestinationType

    $extractionName = $extraction.Name
    $columns = Get-ColumnList $extractionName

    Write-Debug $extractionName

    [xml]$templateTree = Get-Content $RSD_TEMPLATE
    
    $templateTree
}

function Build-AllRsds {
    [CmdletBinding()]
    
    param(
        [Parameter(Mandatory = $true)]
        $extraction,
        
        [Parameter(Mandatory = $false)]
        $forceDestinationType = $FORCE_DESTINATION_TYPE,
        
        [Parameter(Mandatory = $false)]
        $slidingDays = $DEFAULT_DAYS_SLIDING_WINDOW
    )

    Write-Debug $extraction
    Write-Debug $forceDestinationType
    Write-Debug $slidingDays


    $extractionName = $extraction.Name
    
    Write-Debug $extractionName
    
    $columns = Get-ColumnList $extractionName


    $extractionBaseUrl = "$XU_BASE_URL/?name=$extractionName" + ($null -ne $forceDestinationType ? "&destination=$DESTINATION_TYPE_PARAMETER" : "")

    $ExtractionUrls = @{
        (Join-Path $RSD_TARGET_FOLDER ("$extractionName.rsd")) = $extractionBaseUrl;
    }

    foreach ($column in $columns) {
        $columnName = $column.Name

        if ($columnName -in $SLIDING_COLUMNS) {
            $ExtractionUrls.Add(
                (Join-Path $RSD_TARGET_FOLDER ("$($extractionName)_sliding_$($columnName)_$($slidingDays)days.rsd")) ,
                $extractionBaseUrl + (
                    @(
                        "&where=$($columnName)%20%3E=%20%27",
                        ((Get-Date).AddDays(-$slidingDays).ToString("yyyyMMdd"),
                        "%27"
                    ) | Join-String
                    )
                )
            )
        }
    }


    Write-Debug ($ExtractionUrls | ConvertTo-Json)

    foreach ($key in $ExtractionUrls.Keys) {
        Build-Rsd -extraction $extraction -filename $key -extraction_url $ExtractionUrls.$key -forceDestinationType $forceDestinationType
    }

}