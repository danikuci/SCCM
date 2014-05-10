<#
Simple script for exporting SCCM client settings

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
#Begin Script  
##########################################################################

$SCCMServer = Read-Host "Input SCCM Site Code"
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
if (-not (Test-Path -Path $SCCMServer))
    {
        Import-Module ($env:SMS_ADMIN_UI_PATH.Substring(0,$env:SMS_ADMIN_UI_PATH.Length – 5) + '\ConfigurationManager.psd1') | Out-Null
    }
Set-Location $SCCMServer":"

#First export default policies
$DefaultPolicyName = "Default Client Agent Settings"
$IndividualSettings = [Enum]::GetNames([Microsoft.ConfigurationManagement.Cmdlets.ClientSettings.Commands.SettingType])
$OutPut = ("C:\SCCMsettings\$($SCCMServer)_ClientPolicies") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".txt" 
$DefaultPolicyName | Out-File -FilePath $OutPut -Append

    foreach ($setting in $IndividualSettings) 
        {
            Get-CMClientSetting -Setting $setting -Name $DefaultPolicyName | Out-File -FilePath $OutPut -Append
            Write-Host "Exporting $setting of $DefaultPolicyName... Please wait..." -ForegroundColor Yellow
        }


#Then export custom policies
$AllCustomSettingPolicies = Get-CMClientSetting | select Name | Where-Object {$_.Name -ne "Default Client Agent Settings"}
    foreach ($policy in $AllCustomSettingPolicies) 
        {
        $IndividualSettings = Get-CMClientSetting -Name $policy.name
        $IndividualSettings.Name | Out-File -FilePath $OutPut -Append
         
        foreach ($setting in $IndividualSettings.AgentConfigurations) 
            {
                $setting | Out-File -FilePath $OutPut -Append
                Write-Host "Exporting $IndividualSettings.Name... Please wait..." -ForegroundColor Yellow
            }
        }