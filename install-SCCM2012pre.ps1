#*****************************************************
#*   Script configures server for ConfigMan 2012     *
#*              written by Daniel Kucinski           *
#*                  updated 2/4/14                   *
#*       updated for  RTM, SP1 and R2 versions       *
#*****************************************************
# Prereqs for SCCM 2012 server

# Begin by elevating to admin perms
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
# Check to see if we are currently running "as Administrator" and elevates if not
    if ($myWindowsPrincipal.IsInRole($adminRole))
       {
           $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
           $Host.UI.RawUI.BackgroundColor = "DarkBlue"
           clear-host
       }
        else
           {
               $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
               $newProcess.Arguments = $myInvocation.MyCommand.Definition;
               $newProcess.Verb = "runas";
               [System.Diagnostics.Process]::Start($newProcess);
               exit
           }


<# Define function for getting disk drive letters in use
 Displays global PS Drives that use the Filesystem provider   #>
Function Get-FileSystemDrives
    {
        Get-PSDrive -PSProvider FileSystem -scope Global
    }

$erroractionpreference = "Continue" # shows error message, but continue
$error.clear()
# DEBUG MODE : $erroractionpreference = "Inquire"; "`$error = $error[0]"
$myName = $MyInvocation.MyCommand.Name
$now = get-date -format g
"$now # Starting $myName"
netsh advfirewall set domainprofile state off

# create dir and download prereqs from MS
IF (Test-Path "C:\SCCMprereqs")
    {
        Write-Host "prereqs dir already exists, continuing..."
        Sleep 2
    }
        ELSE
        {
            New-Item -type directory -path C:\SCCMprereqs
            Write-Host "created C:\SCCMprereqs - continuing..."
        }

#find SCCM media and download prereqs.
$alldrives = Get-FileSystemDrives | ForEach-Object {$_.name}
foreach ($item in $alldrives) {
    Write-Host "Testing" $item
        IF (Test-Path $item":\SMSSETUP\BIN\X64\setupdl.exe")
	    { 
	        $setuppath = $item + ":\SMSSETUP\BIN\X64\setupdl.exe"
	        Start-Process -FilePath $setuppath -ArgumentList "C:\SCCMprereqs" -Wait
	    }
            ELSE {Write-Host "Not found on" $item}
            }

#find SCCM media and extend AD schema.
foreach ($item in $alldrives) {
    Write-Host "Testing" $item
        IF (Test-Path $item":\SMSSETUP\BIN\X64\extadsch.exe")
	    { 
	        $setuppath = $item + ":\SMSSETUP\BIN\X64\extadsch.exe"
	    }
            ELSE {Write-Host "Not found on" $item}
            }
try {            
    Import-Module -Name ActiveDirectory -ErrorAction Inquire            
    $SchemaPartition = (Get-ADRootDSE -ErrorAction Inquire).NamingContexts | Where-Object {$_ -like "*Schema*"}            
    Get-ADObject "CN=mS-SMS-Version,$SchemaPartition"
    Get-ADObject "CN=mS-SMS-Capabilities,$SchemaPartition"
    Get-ADObject "CN=mS-SMS-Source-Forest,$SchemaPartition"
    } catch
        {            
    Write-Warning -Message "Failed to find SMS v4 new attributes because $($_.Exception.Message)"  
    Write-Warning -Message "Attempting to update schema..."          
    Start-Process -FilePath $setuppath -Wait
        }
	        
#===============================================================================
# Enable Windows Server Feature pre-requisites 
Write-Host -foregroundcolor "green" "Enable Windows Servermanager PowerShell Module, and install prerequisite features"
Import-Module Servermanager
Start-Sleep 1
<# Displayed names from Get-WindowsFeature
[X] Web Server (IIS)                                    Web-Server
    [X] Web Server                                      Web-WebServer
        [X] Common HTTP Features                        Web-Common-Http
            [X] Static Content                          Web-Static-Content
            [X] Default Document                        Web-Default-Doc
            [X] Directory Browsing                      Web-Dir-Browsing
            [X] HTTP Errors                             Web-Http-Errors
            [X] HTTP Redirection                        Web-Http-Redirect
        [X] Application Development                     Web-App-Dev
            [X] ASP.NET                                 Web-Asp-Net
            [X] .NET Extensibility                      Web-Net-Ext
            [X] ASP                                     Web-ASP
            [X] ISAPI Extensions                        Web-ISAPI-Ext
            [X] ISAPI Filters                           Web-ISAPI-Filter
        [X] Health and Diagnostics                      Web-Health
            [X] HTTP Logging                            Web-Http-Logging
            [X] Logging Tools                           Web-Log-Libraries
            [X] Request Monitor                         Web-Request-Monitor
            [X] Tracing                                 Web-Http-Tracing
        [X] Security                                    Web-Security
            [X] Basic Authentication                    Web-Basic-Auth
            [X] Windows Authentication                  Web-Windows-Auth
            [X] URL Authorization                       Web-Url-Auth
            [X] Request Filtering                       Web-Filtering
            [X] IP and Domain Restrictions              Web-IP-Security
        [X] Performance                                 Web-Performance
            [X] Static Content Compression              Web-Stat-Compression
    [X] Management Tools                                Web-Mgmt-Tools
        [X] IIS Management Console                      Web-Mgmt-Console
        [X] IIS Management Scripts and Tools            Web-Scripting-Tools
        [X] Management Service                          Web-Mgmt-Service
        [X] IIS 6 Management Compatibility              Web-Mgmt-Compat
            [X] IIS 6 Metabase Compatibility            Web-Metabase
            [X] IIS 6 WMI Compatibility                 Web-WMI
            [X] IIS 6 Scripting Tools                   Web-Lgcy-Scripting
            [X] IIS 6 Management Console                Web-Lgcy-Mgmt-Console
 [X] File Services                                      File-Services
     [X] File Server                                    FS-FileServer  #>

# Install .NET features and WCF Activation
# use Install-WindowsFeature for PowerShell 3.0 and newer
Get-WindowsFeature NET* | Add-WindowsFeature

# Create array of all pre-requisite features including file services role
$features =@("Web-Server", "Web-WebServer", "Web-Common-Http", "Web-Static-Content", "Web-Default-Doc", "Web-Dir-Browsing", "Web-Http-Errors", "Web-Http-Redirect", "Web-App-Dev", "Web-Asp-Net", "Web-Net-Ext", "Web-ASP", "Web-ISAPI-Ext", "Web-ISAPI-Filter", "Web-Health", "Web-Http-Logging", "Web-Log-Libraries", "Web-Request-Monitor", "Web-Http-Tracing", "Web-Security", "Web-Basic-Auth", "Web-Windows-Auth", "Web-Url-Auth", "Web-Filtering", "Web-IP-Security", "Web-Performance", "Web-Stat-Compression", "Web-Mgmt-Tools", "Web-Mgmt-Console", "Web-Scripting-Tools", "Web-Mgmt-Service", "Web-Mgmt-Compat", "Web-Metabase", "Web-WMI", "Web-Lgcy-Scripting", "Web-Lgcy-Mgmt-Console","File-Services","FS-FileServer","RDC");

#Add-WindowsFeature [-Name] <string[]> [-IncludeAllSubFeature] [-logPath <string>] [-WhatIf] [-Restart] [-Concurrent] [<CommonParameters>]
foreach ($item in $features) {
	Write-Host "Installing $item ...." -ForegroundColor Green
    Add-WindowsFeature -Name $item -logPath Add-WindowsFeature_$item.log
}

#Install .NET 4
#Not needed on Server 2012
$server = [System.Environment]::OSVersion.Version.Minor
IF ($server -eq 1) 
    {
        Write-Host ".Net Framework 4 for Server2008R2 installing..."
        Start-Process -FilePath C:\SCCMprereqs\dotNetFx40_Full_x86_x64.exe -ArgumentList "/showfinalerror /passive /log c:\windows\net4install.log" -Wait
    }
    ELSE 
        {
            Write-Host ".NET Framework 4 installation only needed on Server 2008R2, continuing..."
            Sleep 3
        }   

#Install BITS
Get-WindowsFeature BITS* | Add-WindowsFeature
Write-Host "BITS configured..."

#Install Silverlight 
IF (Test-Path "C:\SCCMprereqs\Silverlight.exe")
    {
        Start-Process -FilePath C:\SCCMprereqs\Silverlight.exe -ArgumentList "/q" -Wait
        Write-Host "Silverlight Installed" -ForegroundColor White
    }
    ELSE
        {
            Write-Warning "Silverlight x64 installation files not found, do you wish to continue?" -WarningAction Inquire
            Sleep 1
        }

#Install SQL Native Client
IF (Test-Path "C:\SCCMprereqs\sqlncli.msi")
    {
        Write-Host "Installing SQL Native Client...."
        msiexec.exe /i C:\SCCMprereqs\sqlncli.msi /qr IACCEPTSQLNCLILICENSETERMS=YES
        Start-Sleep 25
        Write-Host "SQL Native Client installed!" -ForegroundColor White
    }
    ELSE
        {
            Write-Warning "SQL Native Client installation files not found, do you wish to continue?" -WarningAction Inquire
            Sleep 1
        }

#download and install ADK
Try {

    $source = "http://download.microsoft.com/download/6/A/E/6AEA92B0-A412-4622-983E-5B305D2EBE56/adk/adksetup.exe"
    $destination = "C:\SCCMprereqs\adksetup.exe"
    Invoke-WebRequest -Uri $source -OutFile $destination
    Sleep 1
    Write-Host "Launching ADK installer..." -ForegroundColor White
    Start-Process -FilePath "C:\SCCMprereqs\adksetup.exe" -Wait
    } 
        Catch {
            Write-Error "Download and install failed :-(" -ErrorAction Inquire
            Write-Host "Download and install Windows ADK separately"
        }

#Finish
    Sleep 2
    Write-Host "SCCM Prereqs installed"
    Write-Host "This script will now exit."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Exit-PSSession