. $(Resolve-Path "$PSScriptRoot/functions.ps1").Path

Set-DotEnv # loads from the local .env file

$global:XU_BASE_URL = $Env:XU_BASE_URL ?? "http://localhost:8065"
$global:RSD_TEMPLATE = $Env:RSD_TEMPLATE ?? "TEMPLATE_JSON.rsd"
$global:RSD_TARGET_FOLDER = $Env:RSD_TARGET_FOLDER ?? "./OUTPUT"
$global:FILTER_DESTINATION_TYPE = $Env:FILTER_DESTINATION_TYPE ?? "HTTPJSON"
$global:DESTINATION_TYPE_PARAMETER = $Env:DESTINATION_TYPE_PARAMETER ?? "http-json"
$global:FORCE_DESTINATION_TYPE = $Env:FORCE_DESTINATION_TYPE ?? $false
$global:DEFAULT_DAYS_SLIDING_WINDOW = $($Env:DEFAULT_DAYS_SLIDING_WINDOW ?? "3") -as [int]
$global:SLIDING_COLUMNS = ConvertFrom-Json $($Env:SLIDING_COLUMNS ?? '["AEDAT", "CPUDT", "CPUDT_MKPF", "AUGDT"]')

#$columns = Get-ColumnList -extractionName "BSEG" -Debug

New-Item -ItemType Directory -Path $RSD_TARGET_FOLDER -Force -ErrorAction Continue

$extractions = Get-Extractions -Debug

foreach ($extraction in $extractions) {
    Build-AllRsds -extraction $extraction -Debug
}
