<#
.SYNOPSIS
This script grabs all shared folders in the current server along with their shared path, disk path and permsissions

.DESCRIPTION
Options:

  -help                  - Display the current help menu
  -silent                - Run the script without printing anything
  -url  <string>         - Give a URL to POST script output to
  -file <string>         - Declare a location to save script output to as a csv
  -organization <string> - Declare the name of the organization

.NOTES
This script is largely a modification on grolo's "Audit File Share Perms" script available at http://poshcode.org/3398.
We thank grolo for doing a lot of the heavy lifting for us.

Author: Mark Jacobs
Author: Caleb Albers

.LINK
https://github.com/KeystoneIT/Documentation-Scripts

#>

[cmdletbinding()]

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

    Write-Host "Server:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $currentServer "`n"

    Write-Host "Share Name:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $share "`n"

    Write-Host "Share Path:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $writePath "`n"

    Write-Host "Share Description:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $ShareDescription "`n"

    Write-Host "Disk Path:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $DiskPath "`n"

    Write-Host "Permissions:  `t" -ForegroundColor Gray -NoNewline
    Write-Host "`t `t" $permissions "`n"
}


if($help) {
    Get-Help $MyInvocation.MyCommand.Path
    exit
}

if(($silent) -and !($url -or $file)) {
    Write-Error -Message "ERROR: Using the silent flag requires a URL, FTP server, or location to save results to." `
                -Category InvalidOperation `
}
else {
    if($continuum) {
        $organization = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\SAAZOD").SITENAME
    }

    $computer = $env:COMPUTERNAME
    $results = @()

    $File = gwmi -Class win32_share -ComputerName $computer -Filter "Type=0"
    $shares = $File| select -ExpandProperty Name
    $description =  $File| select -ExpandProperty Description
    $path = $File| select -ExpandProperty Path
    $server= ([regex]::matches($File, "(?<=[\\][\\])[^\\]+"))

    $i=0
    foreach ($share in $shares) {
        if( $share -notlike "print$" -or -notlike "NETLOGON" -or -notlike "MTATempStore$"){
            $acl = $null # or $sharePath[$i]

            $permissions= ""
            Write-Host $share -ForegroundColor Green
            Write-Host $('-' * $share.Length) -ForegroundColor Green
            $currentServer= $server[$i]
            $writePath = "\\$currentServer\$share"



            $file = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$Share'"  -ComputerName $computer
            if($file){
                $obj = @()
                $ACLS = $file.GetSecurityDescriptor().Descriptor.DACL
                foreach($ACL in $ACLS){
                    $User = $ACL.Trustee.Name
                    if(!($user)){$user = $ACL.Trustee.SID} #If there is no username use SID
                    $Domain = $ACL.Trustee.Domain
                    switch($ACL.AccessMask) {
                        2032127 {$Perm = "Full Control"}
                        1245631 {$Perm = "Change"}
                        1179817 {$Perm = "Read"}
                    }
                    $permissions= $permissions + "<p>$Domain\$user $Perm</p>"
                } # End foreach $ACL
                $ShareDescription= $description[$i]
                $DiskPath= $path[$i]

                if(!$silent){writeOutput}

                if($url -or $file) {
                    $PostData = @{
                        "Organization" = "$organization"
                        "Share Name" = "$share"
                        "Share Description" = "$ShareDescription"
                        "Server" = "$currentServer"
                        "Share Path" = "$writePath"
                        "Disk Path" = "$DiskPath"
                        "Permissions" = "$permissions"
                    }
                }
                if($url){
                    Invoke-WebRequest -Uri $url -Method POST -Body $PostData
                }
                if($file) {
                    $SaveData += New-Object PSObject -Property $PostData
                }
            $i++
            }# end if $file
        }# end if(notlike)
    } # end foreach $share
    if($file){
        $SaveData | export-csv -Path $file -NoTypeInformation
    }
}
