<#
    .Synopsis
        short help
    .Description
        long help
#>


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
##############################################################################
#begin script
#############################################################################
$SiteCode = Read-Host "Input SCCM Site Code"
$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Definition
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

Set-Location "$($SiteCode):" | Out-Null
$AllBGs = Get-CMBoundaryGroup
$EmptyArray = @()
$prog = 0

foreach ($BG in $AllBGs) {

    $prog++
    Write-Progress -Activity "Processing Boundaries and Groups" -Status "Processed: $prog of $($AllBGs.Count)" -PercentComplete (($prog / $AllBGs.Count)*100)

    $Members = Get-CMBoundary -BoundaryGroupID $BG.GroupID
    
    foreach ($Member in $Members) {

        Switch($Member.BoundaryType)
            {
 
            "0" {$FriendlyType = "IP Subnet"}
            "1" {$FriendlyType = "Active Directory Site"}
            "2" {$FriendlyType = "IPv6"}
            "3" {$FriendlyType = "IP Address Range"}
 
             }

        $DObject = New-Object PSObject
            $DObject | Add-Member -MemberType NoteProperty -Name "Boundary Group Name" -Value $BG.Name
            $DObject | Add-Member -MemberType NoteProperty -Name "Boundary Type" -Value $FriendlyType
            $DObject | Add-Member -MemberType NoteProperty -Name "Created By" -Value $Member.CreatedBy
                $defaultsitecode = [string]($BG.DefaultSiteCode)
            $DObject | Add-Member -MemberType NoteProperty -Name "Site Code" -Value $defaultsitecode
            $DObject | Add-Member -MemberType NoteProperty -Name "Boundary Name" -Value $Member.DisplayName
                $SiteSystems = [string]($Member.SiteSystems)
            $DObject | Add-Member -MemberType NoteProperty -Name "Site Systems" -Value $SiteSystems
            $DObject | Add-Member -MemberType NoteProperty -Name "Value" -Value $Member.Value
        $EmptyArray += $DObject

}}

#save files as HTML and CSV
$OutPut = ("C:\SCCMsettings\$($SCCMServer)_BoundariesandGroups") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".html" 
$EmptyArray | ConvertTo-Html -As table -Title "Boundaries" | Out-File $OutPut
$OutPut = ("C:\SCCMsettings\$($SCCMServer)_BoundariesandGroups") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".csv"
$EmptyArray | Export-Csv $OutPut -NoTypeInformation
