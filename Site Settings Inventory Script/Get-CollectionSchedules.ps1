<#
.Synopsis
   This script reads Collection Refresh Schedule date/time
.DESCRIPTION


 
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

Function Convert-DayNumbersToDayName
{
    [CmdletBinding()]
    Param(
         [String]$DayNumber
         )
 
    Switch ($DayNumber)
    {
          "1" {$DayName = "Sunday"}
          "2" {$DayName = "Monday"}
          "3" {$DayName = "TuesDay"}
          "4" {$DayName = "WednesDay"}
          "5" {$DayName = "ThursDay"}
          "6" {$DayName = "FriDay"}
          "7" {$DayName = "Saturday"}
 
    }
 
    Return $DayName
}
 
Function Convert-MonthToNumbers
{
    [CmdletBinding()]
    Param(
         [String]$MonthNumber
         )
 
    Switch ($MonthNumber)
    {
          "1" {$MonthName = "January"}
          "2" {$MonthName = "Feburary"}
          "3" {$MonthName = "March"}
          "4" {$MonthName = "April"}
          "5" {$MonthName = "May"}
          "6" {$MonthName = "June"}
          "7" {$MonthName = "July"}
          "8" {$MonthName = "August"}
          "9" {$MonthName = "September"}
          "10" {$MonthName = "October"}
          "11" {$MonthName = "November"} 
          "12" {$MonthName = "December"}
    }
 
    Return $MonthName
}
 
Function Convert-WeekOrderNumber
{
    [CmdletBinding()]
    Param(
         [String]$WeekOrderNumber
         )
 
    Switch ($WeekOrderNumber)
    {
          0 {$WeekOrderName = "Last"}
          1 {$WeekOrderName = "First"}
          2 {$WeekOrderName = "Second"}
          3 {$WeekOrderName = "Third"}
          4 {$WeekOrderName = "Fourth"}
 
    }
 
    Return $WeekOrderName
}



######################################################
#Begin Script
######################################################

$SCCMserver = Read-Host "Input the SCCM server name"
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

$Collections = @()
$RefreshScheduleCollection = @()
$prog = 0
Write-Host "Preparing....." -ForegroundColor Yellow
Get-WmiObject -Namespace "root\sms\site_$SiteCode" -Query "Select * from SMS_Collection where CollectionID like '$SiteCode%'" -ComputerName $SCCMServer | ForEach-Object {$Collections +=[WMI]$_.__PATH}


foreach($item in $Collections)
{
 $prog++
 Write-Progress -Activity "Processing Collections" -Status "Processed: $prog of $($Collections.Count)" -PercentComplete (($prog / $Collections.Count)*100)
 
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "Collection Name" -Value $item.Name
 
    if($item.RefreshType -eq 1){
 
        $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Type" -Value $item.RefreshType
        $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Date" -Value "NO Date"
        $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Time" -Value "NO Time"
        $DObject | Add-Member -MemberType NoteProperty -Name "Limiting Collection Name" -Value $item.LimitToCollectionName
    }
 
    Else{
         switch($item.RefreshSchedule.__CLASS)
         {
            "SMS_ST_RecurWeekly" 
                               {
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Type" -Value $item.RefreshType
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Date" -Value ("Occures every: $($item.RefreshSchedule.ForNumberOfWeeks) weeks on " + (Convert-DayNumbersToDayName -DayNumber $item.RefreshSchedule.Day))
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Time" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($item.RefreshSchedule.StartTime))
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Limiting Collection Name" -Value $item.LimitToCollectionName
                               }
 
           "SMS_ST_RecurInterval"
                               {
 
 
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Type" -Value $item.RefreshType
 
                                    if($item.RefreshSchedule.DaySpan -ne 0){
                                        $text = "Occures every $($item.RefreshSchedule.DaySpan) days"
                                    }
                                    if($item.RefreshSchedule.HourSpan -ne 0){
                                        $text = "Occures every $($item.RefreshSchedule.HourSpan) hours"
                                    }
                                    if($item.RefreshSchedule.MinuteSpan -ne 0){
                                        $text = "Occures every $($item.RefreshSchedule.MinuteSpan) minutes"
                                    }
 
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Date" -Value $text
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Time" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($item.RefreshSchedule.StartTime))
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Limiting Collection Name" -Value $item.LimitToCollectionName
                               }
 
           "SMS_ST_RecurMonthlyByDate"
                               {
 
                                   If($item.RefreshSchedule.MonthDay -eq 0){
 
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Type" -Value $item.RefreshType
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Date" -Value "Occures the last day of every $($item.RefreshSchedule.ForNumberOfMonths) months"
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Time" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($item.RefreshSchedule.StartTime))
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Limiting Collection Name" -Value $item.LimitToCollectionName
                                   }
                                   Else{
 
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Type" -Value $item.RefreshType
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Date" -Value "Occures day $($item.RefreshSchedule.MonthDay) of every $($item.RefreshSchedule.ForNumberOfMonths) months"
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Time" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($item.RefreshSchedule.StartTime))
                                    $DObject | Add-Member -MemberType NoteProperty -Name "Limiting Collection Name" -Value $item.LimitToCollectionName
                                   }
                               }
 
           "SMS_ST_RecurMonthlyByWeekday"    
                               {
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Type" -Value $item.RefreshType
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Date" -Value ("Occures the " + (Convert-WeekOrderNumber -weekordernumber $item.RefreshSchedule.WeekOrder) + " " + (Convert-DayNumbersToDayName -DayNumber $item.RefreshSchedule.Day) + " of every " + (Convert-MonthToNumbers -MonthNumber $item.RefreshSchedule.ForNumberOfMonths))
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Time" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($item.RefreshSchedule.StartTime))
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Limiting Collection Name" -Value $item.LimitToCollectionName
                               }                 
 
           "SMS_ST_NonRecurring"
                                {
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Type" -Value $item.RefreshType
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Date" -Value "No Recurrence. The Scheduled event Occures once at the specific time"
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Refresh Time" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($item.RefreshSchedule.StartTime))
                                   $DObject | Add-Member -MemberType NoteProperty -Name "Limiting Collection Name" -Value $item.LimitToCollectionName
                                }              
         }
    }
    $RefreshScheduleCollection += $DObject
}
 
####################write output###########################
    Try{
        $OutPut = ("C:\SCCMsettings\$($SiteCode)_CollectionRefreshSchedule") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".csv" 
        $RefreshScheduleCollection | Export-Csv $OutPut -NoTypeInformation -ErrorAction Stop
    }
    Catch{
        Write-Host "Failed to export CSV to $OutPut"
    }

    $CurrentDate = Get-Date
 
    #HTML style
    $HeadStyle = "<style>"
    $HeadStyle = $HeadStyle + "BODY{background-color:peachpuff;}"
    $HeadStyle = $HeadStyle + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
    $HeadStyle = $HeadStyle + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:thistle}"
    $HeadStyle = $HeadStyle + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:palegoldenrod}"
    $HeadStyle = $HeadStyle + "</style>"   
 
    Try{
        $OutPut = ("C:\SCCMsettings\$($SiteCode)_CollectionRefreshSchedule") + (Get-Date -UFormat "%Y-%m-%d-%a-%H%M%S") + ".html"
        $RefreshScheduleCollection | ConvertTo-Html -Head $HeadStyle -Body "<h2>Collections Refresh Schedule Date/Time Report: $CurrentDate</h2>" -ErrorAction STOP | Out-File $OutPut
    }
    Catch{
        Write-Host "Failed to export HTML to $OutPut"
    }

Write-Host "Exiting....." -ForegroundColor Yellow