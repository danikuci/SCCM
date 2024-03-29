
##################check for x86 powershell and relaunch if need be##############
if ($env:Processor_Architecture -ne "x86")   
{ Write-Warning 'Launching x86 PowerShell'
&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $myinvocation.Mycommand.path -executionpolicy bypass
exit
}
"Always running in 32bit PowerShell at this point."
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

#############################Functions##############################
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


##############################################################################
#begin script
########################################################################
$SCCMServer = Read-Host "Input SCCM Primary Site Server name"
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

<#param ok for running from command line   
Param(
    [parameter(mandatory = $true,position=0)]
    [string]$SCCMServer,      #SCCM Primary Site Server
    [parameter(mandatory = $true)]
    [string]$SiteCode       #SCCM site code
)  #>

$PackagesQuery = Get-WmiObject -Namespace Root\sms\Site_$SiteCode -Query "select Pkgsourcepath,PackageID,Name from SMS_Package where sourcesite='$SiteCode' order by Pkgsourcepath" -computerName $SCCMServer
$EmptyArray = @()
$Location = "C:\SCCMSettings"  #Get-Location | Select-Object -ExpandProperty Path
$i = 0

Foreach($item in $PackagesQuery)
{
    $i++
    Write-Progress -Activity "Processing Package sources" -Status "Added: $i of $($PackagesQuery.count) " -PercentComplete (($i / $PackagesQuery.Count)*100)
    
        $DObject = New-Object PSObject
               $DObject |Add-Member -MemberType NoteProperty -Name "Package" -Value $($item.PackageID)
               $DObject |Add-Member -MemberType NoteProperty -Name "Source" -Value $($item.pkgsourcepath)
               $DObject |Add-Member -MemberType NoteProperty -Name "Name" -Value $($item.Name)
        $EmptyArray += $DObject
}
$EmptyArray | Export-Csv "$Location\PackageSources.csv" -NoTypeInformation  

$Sources = Import-Csv "$Location\PackageSources.csv"
$EmptyArray = @()
$d = 0
Set-Location C:

Foreach($source in $Sources)
{
    $d++
    Write-Progress -Activity "Processing Package source sizes" -Status "Processed: $d of $($Sources.Count)" -PercentComplete (($d / $Sources.Count)*100)
    
    $SourceSizeQuery = Get-ChildItem $source.Source -Recurse| Measure-Object -property length -sum |Select-Object -ExpandProperty SUM
    $DObject = New-Object PSObject
        $DObject |Add-Member -MemberType NoteProperty -Name "Package" -Value $($source.Package)
        $DObject |Add-Member -MemberType NoteProperty -Name "Name" -Value ($Source.Name)
        $DObject |Add-Member -MemberType NoteProperty -Name "Size" -Value ($SourceSizeQuery/1MB)
        $DObject |Add-Member -MemberType NoteProperty -Name "Source" -Value $($source.Source)
    $EmptyArray += $DObject
}

$OutPut = ("C:\SCCMsettings\$($SiteCode)_PackageSourceWithSizes") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".csv"
$EmptyArray | Export-Csv $OutPut -NoTypeInformation
Remove-Item "$Location\PackageSources.csv"