<#

.SYNOPSIS
This script grabs all DHCP servers in a domain and provides their name, status, and scope

.DESCRIPTION
Options:

    -help - Display the current help menu
    -silent - Run the script without printing anything
    -file <string> - Declare a location to save script output to as a csv
    -organization <string> - Declare the name of the organization


.EXAMPLE
./DHCP.ps1 -s -c -url api.example.com
./DHCP.ps1 -FQDN -file C:\adout.csv

.NOTES
Author: Mark Jacobs
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

# Print Results
function writeOutput {
    Write-Host "Organization Name:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $organization "`n"

    Write-Host "DHCP Scope Name:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Name "`n"

    Write-Host "Getting Server Name:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Server "`n"

    Write-Host "Status:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $organization "`n"

    Write-Host "Scope:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $Start " - " $End "`n"
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

    # Get DHCP v4 Scopes
    $DHCPs = Get-DhcpServerv4Scope
    $Server = [System.Net.Dns]::GetHostName()

    ForEach($DHCP in $DHCPs){
        $Start = $DHCP.StartRange
        $End = $DHCP.EndRange
        $Status = $DHCP.State
        $Name = $DHCP.Name

        if(!$silent){writeOutput}

        if($url -or $file -or $ftp) {
            $PostData = @{
                Organization = $organization; `
                Name = $Name; `
                Status = $Status; `
                Scope = "$Start - $End"; `
                Server = $Server;
            }
        }
        if($url){
            Invoke-WebRequest -Uri $url -Method POST -Body $PostData
        }
        if($file) {
            $SaveData += New-Object PSObject -Property $PostData
        }
    }
    if($file) {
        $SaveData | export-csv -Path $file -NoTypeInformation
    }
}
