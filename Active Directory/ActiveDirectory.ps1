<#

.SYNOPSIS
This script grabs all domains in the current forest along with servers hosting all FSMO roles for each domain

.DESCRIPTION
Options:

  -help                  - Display the current help menu
  -silent                - Run the script without printing anything
  -url  <string>         - Give a URL to POST script output to
  -file <string>         - Declare a location to save script output to as a csv
  -organization <string> - Declare the name of the organization

.EXAMPLE
./ActiveDirectory.ps1 -s -c -url api.example.com
./ActiveDirectory.ps1 -file C:\adout.csv

.NOTES
Author: Caleb Albers

.LINK
https://github.com/KeystoneIT/Documentation-Scripts

#>


Param (
    [switch]$help = $False,
    [switch]$silent = $False,
    [switch]$continuum = $False,
    [string]$url,
    [string]$file,
    [string]$organization = ""
)

import-module ActiveDirectory

# Print results
function writeOutput {
    Write-Host "Organization Name...  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $organization "`n"

    Write-Host "Forest Name...  `t   `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $ADForestName "`n"

    Write-Host "Getting AD Functional Level..." -ForegroundColor Gray -NoNewline
    Write-Host "`t" $ADFunctionalLevel "`n"

    Write-Host "Getting AD Full Name...  " -ForegroundColor Green -NoNewline
    Write-Host "`t `t" $Domain "`n"

    Write-Host "Getting AD Short Name... `t" -ForegroundColor Green -NoNewline
    Write-Host "`t" $ADShortName "`n"

    Write-Host "Getting FSMO Roles..." -ForegroundColor Green

    Write-Host "`t Schema Master:         `t " -ForegroundColor Yellow -NoNewline
    Write-Host $SchemaMaster

    Write-Host "`t Domain Naming Master:   `t " -ForegroundColor Yellow -NoNewline
    Write-Host $DomainNamingMaster

    Write-Host "`t Relative ID (RID) Master:   " -ForegroundColor Yellow -NoNewline
    Write-Host $RIDMaster

    Write-Host "`t PDC Emulator:           `t " -ForegroundColor Yellow -NoNewline
    Write-Host $PDCEmulator

    Write-Host "`t Infrastructure Master: `t " -ForegroundColor Yellow -NoNewline
    Write-Host $InfrastructureMaster "`n"

    Write-Host "Getting Global Catalog Servers (Domain Controllers)..." -ForegroundColor Green
    $GlobalCatalogs
}

if($help) {
    Get-Help $MyInvocation.MyCommand.Path
    exit
}

if(($silent) -and !($url -or $file -or $ftp)) {
    Write-Error -Message "ERROR: Using the silent flag requires a URL, FTP server, or location to save results to." `
                -Category InvalidOperation `
}
else {
    if($continuum) {
        $organization = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\SAAZOD").SITENAME
    }

    # Get forest info
    $ADForestName = (Get-ADForest).Name
    $SchemaMaster = (Get-ADForest).SchemaMaster
    $DomainNamingMaster = (Get-ADForest).DomainNamingMaster
    $ADFunctionalLevel = (Get-ADForest).ForestMode

    # Get Global Catalog Servers (Domain Controllers)
    $GlobalCatalogs = (Get-ADForest).GlobalCatalogs

    # Get domain info
    $Domains = (Get-ADForest).domains

    foreach($Domain in $Domains) {
        $ADShortName = (Get-ADDomain).Name

        # Get FSMO Roles
        $RIDMaster = (Get-ADDomain).RIDMaster
        $PDCEmulator = (Get-ADDOmain).PDCEmulator
        $InfrastructureMaster = (Get-ADDomain).INfrastructureMaster

        if(!$silent){writeOutput}
        if($url -or $file -or $ftp) {
                $PostData= @{organization = $organization; `
                             ForestName =$ADForestName; `
                             FunctionalLevel = $ADFunctionalLevel; `
                             DomainName= $Domain; `
                             DomainShortName= $ADShortName; `
                             SchemaMaster= $SchemaMaster; `
                             DomainNamingMaster = $DomainNamingMaster; `
                             RIDMaster = $RIDMaster; `
                             PDCEmulator = $PDCEmulator; `
                             InfrastructureMaster = $InfrastructureMaster; `
                             GlobalCatalogServers = $GlobalCatalogs;
                             }
        }
        if($url){
            Invoke-WebRequest -Uri $url -Method POST -Body $PostData
        }
        if($file) {
            $SaveData += New-Object PSObject -Property $PostData
        }

    }
    if($file){
        $SaveData | export-csv -Path $file -NoTypeInformation
    }
}
