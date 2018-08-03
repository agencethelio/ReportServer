function Publish-RS{
    param(      
        [string]$DestinationUri = 'http://sqlsrv:8080/reports'
        ,[Parameter(Mandatory=$true,HelpMessage="report path")] [string]$SourcePath      
        ,[Parameter(Mandatory=$false,HelpMessage="Define path on the report server. by default the report will go to the root")] [string]$DestinationPath = '/'
        ,[Parameter(Mandatory=$false,HelpMessage="Defining the path on the report server of shared sources")] [string]$DataSourcePath 
    )
    if (Get-Module -ListAvailable -Name ReportingServicesTools) {
        Write-Host "Module ReportingServicesTools exist"
    } else {
        Install-Module -Name ReportingServicesTools
    }
    $listReports = Get-ChildItem "$($SourcePath)*.rdl" -Filter *.rdl 
    $listReports |  Write-RsCatalogItem -ReportServerUri $DestinationUri -Destination $DestinationPath -Verbose 
    $Reports = Get-RsFolderContent -RsFolder $DestinationPath -ReportServerUri $DestinationUri
    if($DataSourcePath){
        foreach($report in $Reports){
            $Sources = Get-RsItemReference -Path "$DestinationPath/$($report.name)" -ReportServerUri $DestinationUri
            write-host $Sources
            foreach($source in $Sources){
                Set-RsDataSourceReference -DataSourceName $source.name -DataSourcePath "$DataSourcePath" -Path "$DestinationPath/$($report.name)" -ReportServerUri $DestinationUri -verbose
            }
        }
    }
}
