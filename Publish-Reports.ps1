Function Publish-Report{
    param(
        [string]$DestinationUri = 'http://<SERVER_NAME>:<SERVER_PORT>/reports'
        ,[Parameter(Mandatory=$true,HelpMessage="Source definition : URL ou FILE")][ValidateSet('URL','FILE')]$TypePath 
        ,[Parameter(Mandatory=$true,HelpMessage="report path" )] [string]$SourcePath 
        ,[Parameter(Mandatory=$false,HelpMessage="Define the path on the report server. by default the report will go to the root")] [string]$DestinationPath ='/'
        ,[Parameter(Mandatory=$false,HelpMessage="Setting the source report server URL")] [string]$SourceUri 
    )
    
    
    $CatalogItemUri = $DestinationUri + "/api/v2.0/CatalogItems"
    
    if($TypePath -eq 'URL' -and !$SourceUri){ throw'Parameter is need'}
    
    #internal function
    Function Get-FromCatalog{
        param(
            [string]$ReportServerUri = 'http://<SERVER_NAME>:<SERVER_PORT>/reports'
            ,[Parameter(Mandatory=$true)] [string]$Name 
            ,[Parameter(Mandatory=$false)] [string]$ReportPath ='/'
            ,[switch]$Full
        )
        
        $QueryOData = "$DestinationUri/api/v2.0/CatalogItems?%24filter=path eq '$ReportPath$Name'"
    
        $json =(Invoke-WebRequest -Method Get -UseDefaultCredentials -Uri $QueryOData).Content | ConvertFrom-Json
        if($Full) {
            return $json
        }else{
            return $json.value.Id
        }
    }
    
    
    if($TypePath -eq 'URL'){
        $SourceUri = "$SourceUri/api/v2.0/CatalogItems"
        $item = (Get-FromCatalog -Name $SourcePath -ReportServerUri $SourceUri -Full).value
    
        if($item.Name -eq '/' -or $item.Type -eq 'Folder')
        {
            return 
        }
    
        switch($item.Type){
            "PowerBIReport" {$extension = "pbix"}
            "Report" {$extension = "rdl"}
            "DataSource" {$extension = "rsds" }
            "DataSet" {$extension = "rsd"}
            default {$extension =""}
        }
    
        $Id = $item.Id
        $Name = $DestinationPath.Substring($DestinationPath.LastIndexOf("/")+1)
        $DestinationPath = "/" + $DestinationPath.Substring(0,$DestinationPath.LastIndexOf("/"))
        $bytes = (Invoke-webrequest -URI "$SourceUri($Id)/Content/%24value" -UseDefaultCredentials).Content
    }
    else {
        $fileName = [IO.Path]::GetFileName($SourcePath).Split('.')
        $Name = $fileName[0]
        $extension = $fileName[1]

        $bytes = Get-Content $SourcePath -Raw -Encoding Byte 
    }
    
    switch($extension)
    {
        "pbix" {$oDataType = "#Model.PowerBIReport";$Type = "PowerBIReport" }
        "rdl" {$oDataType = "#Model.Report";$Type = "Report" }
        "rsds" {$oDataType = "#Model.DataSource";$Type = "DataSource" }
        "rsd" {$oDataType = "#Model.DataSet";$Type = "DataSet" }
    }
    
    
    $bodyJson = @{
        "@odata.type" = $oDataType;
        "Name" = $Name;
        "Description" = "";
        "Path" = $DestinationPath;
        "Type" = $Type;
        "Content" = [System.Convert]::ToBase64String($bytes);
        "ContentType" = "";
    }| ConvertTo-Json
    
    if($DestinationPath.Substring($DestinationPath.Length-1) -ne '/') {
        $DestinationPath = "$DestinationPath/" 
    }
    
    $id = Get-FromCatalog -Name $Name -ReportPath $DestinationPath
    
    if($null -ne $id)
    {
        Invoke-RestMethod -Uri "$CatalogItemUri($id)" -Method Delete -UseDefaultCredentials #| Out-Null
    }
    else {
        Invoke-RestMethod -Uri $CatalogItemUri -Method Post -ContentType "application/json" -Body $bodyJson -UseDefaultCredentials | Out-Null
    }
}
    
    
Function Publish-ReportsWithConfigFile{ 
    param([Parameter(Mandatory=$true,HelpMessage="Path of the configuration file")][string]$configPath)

    $jsonConfig = ConvertFrom-Json "$(get-content "$configPath")"
    
    $DestinationUri =$jsonConfig.destination
    $SourceUri = $jsonConfig.source

    foreach($item in $jsonConfig.reports)
    { 
        # $TypePath = $item[0]
        # $SourcePath = $item[1]
        # $DestinationPath = $item[2]
        Publish-Report -DestinationUri $DestinationUri -SourceUri $SourceUri -TypePath $item[0] -SourcePath $item[1] -DestinationPath $item[2]
    }
}
