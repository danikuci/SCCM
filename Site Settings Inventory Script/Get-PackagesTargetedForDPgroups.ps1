<#
    .Synopsis
        Simple script to export where content is distributed to
    .Description
ContentServerType = 1 means assigned to DP, 2 means assigned to DP Group
ObjectTypeID = 42 means info has been collected from SMS_DistributionPointInfo, 43 means it’s from SMS_DistributionPointGroup
PackageType

0 Regular software distribution package. 
3 Driver package. 
4 Task sequence package. 
5 Software update package. 
6 Content package. 
8 Device setting package. 
257 Image package. 
258 Boot image package. 
259 Operating system install package. 
512 Application package.
#>


##################check for x86 powershell and relaunch if need be##############
if ($env:Processor_Architecture -ne "x86")   
{ Write-Warning 'Launching x86 PowerShell'
&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $myinvocation.Mycommand.path -executionpolicy bypass
exit
}
$env:Processor_Architecture
[IntPtr]::Size


################### Elevate to admin perms if need be #######################
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
    if ($myWindowsPrincipal.IsInRole($adminRole))
       {
           # We are running "as Administrator" - so change the title and background color to indicate this
           $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
           $Host.UI.RawUI.BackgroundColor = "DarkBlue"
           clear-host
       }
        else
           {
               # We are not running "as Administrator" - so relaunch as administrator   
               $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
               $newProcess.Arguments = $myInvocation.MyCommand.Definition;
               $newProcess.Verb = "runas";
               [System.Diagnostics.Process]::Start($newProcess);
               exit
           }
############################Functions#####################################

Function Get-SiteCode
{
    $wqlQuery = “SELECT * FROM SMS_ProviderLocation”
    $a = Get-WmiObject -Query $wqlQuery -Namespace “root\sms” -ComputerName $SCCMserver
    $a | ForEach-Object {
        if($_.ProviderForLocalSite)
            {
                $script:SiteCode = $_.SiteCode
            }
    }
return $SiteCode
}


######################################################
#Begin Script
######################################################

$SCCMserver = Read-Host "Input the SCCM server name"
#$SiteCode = Read-Host "Input the site code:"
$SiteCode = Get-SiteCode

# create dir for export
IF (Test-Path "C:\SCCMsettings")
    {
        Write-Host "export dir already exists, continuing..."
    }
        ELSE
        {
            New-Item -type directory -path C:\SCCMsettings
            Write-Host "created dir - continuing..."
        }

#Import the CM12 Powershell cmdlets
    if (-not (Test-Path -Path $SiteCode))
        {
            Import-Module ($env:SMS_ADMIN_UI_PATH.Substring(0,$env:SMS_ADMIN_UI_PATH.Length – 5) + '\ConfigurationManager.psd1') | Out-Null
        }
    Set-Location $SiteCode":"  

[array]$AssignedToDPGroup = @()
[array]$AssignedToDP = @()
[array]$OutputArray = @()
$i = $null
$AllContent = $null
$UniqueContent = $null
$prog = 0

$AllContent = Get-WmiObject -Class SMS_PackageContentServerInfo -Namespace Root\SMS\Site_$SiteCode -ComputerName $SCCMserver
$UniqueContent = $AllContent | Where-Object {$_.DPType -eq 3}# | select -Unique -Property ObjectID,PackageType,Name,DPType<PackageType

    foreach ($i in $UniqueContent)
        {
            Switch($i.PackageType)
                {
                "0" {$FriendlyType = "Package"}
                "3" {$FriendlyType = "Driver Package"}
                "4" {$FriendlyType = "Task Sequence Package"}
                "5" {$FriendlyType = "Software Updates"}
                "6" {$FriendlyType = "Content Package"}
                "8" {$FriendlyType = "Device Settings"}
                "257" {$FriendlyType = "OS Image"}
                "258" {$FriendlyType = "Boot Image"}
                "259" {$FriendlyType = "OS Install"}
                "512" {$FriendlyType = "Application"}
                }
            
            $prog++
            Write-Progress -Activity "Processing Packages" -Status "Processed: $prog of $($UniqueContent.Count)" -PercentComplete (($prog / $UniqueContent.Count)*100)

            $FriendlyPackageName = $null
            $FriendlyPackageName = (Get-WmiObject -Class SMS_ObjectName -Namespace root\SMS\Site_$SiteCode -ComputerName $SCCMserver -Filter "ObjectKey = '$($i.ObjectID)'" | Where-Object {$_.ObjectTypeID -ne 9} ).Name
            
            if ($FriendlyPackageName.GetType().IsArray){       #$ff -eq "True") {
                $FriendlyLongName = Get-CMApplication | Where-Object {$_.PackageID -eq $i.PackageID} # | select -Property LocalizedDisplayName | Out-Null   
                $FriendlyPackageName = $FriendlyLongName.LocalizedDisplayName
            }
            
            $DObject = New-Object PSObject
                $DObject | Add-Member -MemberType NoteProperty -Name "Package Name" -Value $FriendlyPackageName
                $DObject | Add-Member -MemberType NoteProperty -Name "Package ID" -Value ($i.PackageID)
                $DObject | Add-Member -MemberType NoteProperty -Name "DP Group Name" -Value ($i.Name)
                $DObject | Add-Member -MemberType NoteProperty -Name "Package Type" -Value $FriendlyType
                #$DObject | Add-Member -MemberType NoteProperty -Name "Package Name" -Value $FriendlyPackageName
            $OutputArray += $DObject
            $FriendlyPackageName
        }
    $OutputFilename = "$($SiteCode)_PackageDistributionToDPgroups" + (Get-Date -UFormat "%Y-%M-%d-%a") + (Get-Random -Maximum 99) + ".csv"
    $OutputArray | Export-Csv C:\SCCMsettings\$OutputFilename  -NoTypeInformation


