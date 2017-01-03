<#

.SYNOPSIS
This script grabs all installed programs/applications and then compares them to a list of known programs of interest.
This is useful for discovering if common applications like QuickBooks or ShadowProtect are present during initial auditing.

.DESCRIPTION
Options:

    -help - Display the current help menu
    -applications <string> - Give an XML file listing all applications of interest
    -silent - Run the script without printing anything
    -url <string> - Give a URL to POST script output to
    -file <string> - Declare a location to save script output to as a csv
    -organization <string> - Declare the name of the organization

.EXAMPLE
./FindApps.ps1 -applications C:/apps.xml
./FindApps.ps1 -app applist.xml -silent -url api.example.com
./FindApps.ps1 -a input.xml -s -file C:/output.csv

.NOTES
Author: Mark Jacobs
Author: Caleb Albers

.LINK
https://github.com/KeystoneIT/Documentation-Scripts

#>


Param (
    [switch]$help = $False,
    [switch]$applications = ""
    [switch]$silent = $False,
    [switch]$continuum = $False,
    [string]$url,
    [string]$file,
    [string]$organization = ""
)

# Get Known Application List
[xml]$Applist = Get-Content $applications

# Print Results
function writeOutput {
    Write-Host "Organization Name:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $organization "`n"

    Write-Host "Application Name:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Name "`n"

    Write-Host "Version:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Version "`n"

    Write-Host "Publisher:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Publisher "`n"

    Write-Host "Install Date:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Installed "`n"

    Write-Host "Category:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Category[$i] "`n"

    Write-Host $('=' * 50)
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


    $i=0

    $app = $Applist.Applications.software| select -ExpandProperty name
    $category = $Applist.Applications.software| select -ExpandProperty category
    $length = $print.Length

    while($i -lt $length){
        ForEach ($inApp in $inApps){
            $Name = $inApp.DisplayName

            if($Name -eq $app[$i]){
                $Version = $inApp.DisplayVersion
                $Publisher = $inApp.Publisher
                $Installed = $inApp.InstallDate

                if(!$silent){writeOutput}

                if($url -or $file -or $ftp) {
                    $PostData= @{
                        organization = $organization; `
                        ApplicationName = $Name; `
                        Version = $Version; `
                        Publisher = $Publisher; `
                        Category = $category[$i];
                    }
                if($url){
                    Invoke-WebRequest -Uri $url -Method POST -Body $PostData
                }
                if($file) {
                    $SaveData += New-Object PSObject -Property $PostData
                }
            }
        } $i++ # Increment counter to check the next application
    }
    if($file){
        $SaveData | export-csv -Path $file -NoTypeInformation
    }
}
