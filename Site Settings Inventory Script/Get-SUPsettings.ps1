<#
    .Synopsis
        Simple script to export settings about WSUS and SUP Configuration
    .Description

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


#script block
$ScriptBlock = {
 
$WSUS = Get-ItemProperty "HKLM:\Software\Microsoft\Update Services\Server\Setup"
 
    $DObject = New-Object PSObject
        $DObject | Add-Member -MemberType NoteProperty -Name "SqlDatabaseName" -Value $WSUS.SqlDatabaseName
        $DObject | Add-Member -MemberType NoteProperty -Name "SqlServerName" -Value $WSUS.SqlServerName
        $DObject | Add-Member -MemberType NoteProperty -Name "ContentDir" -Value $WSUS.ContentDir
        $DObject | Add-Member -MemberType NoteProperty -Name "UsingSSL" -Value $WSUS.UsingSSL
        $DObject | Add-Member -MemberType NoteProperty -Name "PortNumber" -Value $WSUS.PortNumber
        $DObject | Add-Member -MemberType NoteProperty -Name "VersionString" -Value $WSUS.VersionString
        $DObject | Add-Member -MemberType NoteProperty -Name "TargetDir" -Value $WSUS.TargetDir
        $DObject | Add-Member -MemberType NoteProperty -Name "ServicePackLevel" -Value $WSUS.ServicePackLevel
        $DObject | Add-Member -MemberType NoteProperty -Name "OperatingSystem" -Value (Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
    $DObject
}
 

    $Servers = Get-CMSoftwareUpdatePoint | Get-CMSoftwareUpdatePointComponent
    $EmptyArray = @()
    
    foreach($item in $Servers)
    {
    $EmptyArray2 = @()
        Try{
            Write-host "Processing $($item.Name) Server" -ForegroundColor Green
            $Command = Invoke-Command -ScriptBlock $ScriptBlock -ComputerName $item.Name -ErrorAction STOP
            $EmptyArray += $Command 
        }
        Catch{
            Write-host "Failed to Connect or WSUS not installed : $($item.Name)" -ForegroundColor RED
        }
        $EmptyArray2 = Get-CMSoftwareUpdatePoint -SiteSystemServerName $item.Name -SiteCode $SiteCode
        $OutPut = ("C:\SCCMsettings\$($item.Name)_SUPconfig") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".csv" 
        $EmptyArray2.Props | Export-Csv $OutPut -NoTypeInformation
    }
 
    $OutPut = ("C:\SCCMsettings\$($SiteCode)_WSUS_Config") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".csv"   #"$ENV:USERPROFILE\Desktop\WSUS_Configuration.CSV"
    $EmptyArray | Export-Csv $OutPut -NoTypeInformation
    

#Export selected products and classifications
$test = Get-WmiObject -Namespace Root\sms\Site_$SiteCode -Query "Select * from SMS_UpdateCategoryInstance" -computerName $SCCMServer
$OutPut = ("C:\SCCMsettings\$($SiteCode)_ProductsAndClassifications") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".csv"   #"$ENV:USERPROFILE\Desktop\WSUS_Configuration.CSV"
$test | Export-Csv $OutPut -NoTypeInformation