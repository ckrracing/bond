$SITEID = '0514';

Clear-Host
# Add Veeam snap-in if required
If ((Get-PSSnapin -Name VeeamPSSnapin -ErrorAction SilentlyContinue) -eq $null) {add-pssnapin VeeamPSSnapin}

$scheduleType = $null; 
$scheduleTime = $null; 
$job = $null ; 
#$path = $env:TEMP + "_" + (Get-Date -uformat %m-%d-%Y_%I-%M-%S) + ".txt"
$path = $env:TEMP + "\Veeam_Backup_Summary_latest" + ".txt" 

 Get-VBRJob | ForEach  {

 $job = $_; 

if($_.ScheduleOptions.OptionsDaily.Enabled -eq $true){

  $scheduleType = 'DAILY';
  
  if($_.ScheduleOptions.OptionsDaily.Kind -eq 'SelectedDays'){
    $scheduleType = 'ON THESE DAYS ' +  $_.ScheduleOptions.OptionsDaily.DaysSrv ;
  }

  $scheduleTime = $_.ScheduleOptions.OptionsDaily.timeLocal;
  }
elseif($_.ScheduleOptions.OptionsMonthly.Enabled -eq $true) {
  $scheduleType = 'MONTHLY'
  $scheduleTime = $_.ScheduleOptions.OptionsMonthly.timeLocal;
  }
elseif($_.ScheduleOptions.OptionsPeriodically.Enabled -eq $true ){ 
  $scheduleType = 'PERIODICALLY'
  $scheduleTime = $_.ScheduleOptions.OptionsPeriodically.Schedule;
  }
  elseif($_.isContinuous -eq $true ){
  $scheduleType  = 'CONTINUOUS';
  $scheduleTime = 'N/A'
  }

  else {
  $scheduleType = 'N/A'
  }

$restorePointCount  = $job.Options.GenerationPolicy.SimpleRetentionRestorePoints
$repo = (Get-VBRBackupRepository | ?{$_.HostId -eq $job.TargetHostId -and $_.Path -eq $job.TargetDir})
$repoName  = $repo.name ;
$repoCreds =  Get-VBRCredentials |  ?{$_.Id -eq $repo.ShareCredsId } | Select -ExpandProperty name

$guestWindowsCreds = "N/A";
if($_.vssOptions.AreWinCredsSet -eq $true ) {
	$guestWindowsCreds =   Get-VBRCredentials | ?{ $_.Id -eq ((Get-VBRJobVSSOptions -Job $job ).WinCredsId) }  | select -Expandproperty name 
}

$guestLinuxCreds = "N/A";	
if($_.vssOptions.AreLinCredsSet -eq $true) {
	$guestLinuxCreds = Get-VBRCredentials | ?{ $_.Id -eq ((Get-VBRJobVSSOptions -Job $job).LinCredsId) } | select -expandProperty name 
}

$linkedJobsProp =  $_.linkedJobs
$linkedJobs = @();
$ljobName = $null;
$ljobId = $null;

ForEach($lj in $linkedJobsProp) {
  $ljobId = $lj.info.linkedjobId;
  $ljobName = (Get-VbrJob | ?{$_.id -eq $ljobId}).name;
  $linkedJobs += $ljobName;
  $ljobName = "";

  $ljobId = 0;  
  }

 

$_ | Select -property name , @{n="Job Id";e={$_.Id}} , @{n="Type";e={$_.JobType}} ,@{n="Enabled";e={$_.isScheduleEnabled}},  @{n="Schedule Type"; e={$scheduleType}},@{n="Schedule Time";e={$scheduleTime}},
@{n="Target Type";e={$_.JobTargetType}} , @{n="Target Directory";e={$_.TargetDir}} , @{n="Backup File";e={$_.TargetFile}} , @{n="Restore Points";e={$restorePointCount}} ,
@{n="Linked Jobs";e={$linkedJobs}} ,
@{n="Windows Guest Credentials";e={$guestWindowsCreds}} , @{n="Linux Guest Credentials";e={$guestLinuxCreds}} | FL 

 $generationPolicy = $job.options.GenerationPolicy;


if($generationPolicy.RetentionPolicyType -eq 'GFS') {

   Write-Output "Retention Policy`n";
   $generationPolicy | FT -AutoSize @{e={$_.SimpleRetentionRestorePoints};Label = "Restore Points";width=16 } , @{e={$_.GFSWeeklyBackups};Label = "Weekly Backups";width=16} ,@{e={$_.GFSMonthlyBackups};Label = "Monthly Backups";width=16} , @{e={$_.GFSQuarterlyBackups};Label = "Quarterly Backups"} , @{e={$_.GFSYearlyBackups};Label = "Yearly Backups";width=16}  ; 
  
}
$generationPolicy = $null;

$_ | Get-VBRJobObject | Select -Property Name, jobId , approxSizeString , VSSOptions | Sort JobId |
 Format-Table @{Expression={$_.Name};Label="Virtual Machine";width=25} ,@{Expression={$_.approxSizeString};Label="Size(GB)";width=16},@{Expression={$_.vssOptions.enabled };Label="VSS Enabled";width=16}
} | Out-File $path 

$currentSummaryPath = $env:TEMP + "\Veeam_Backup_Summary" + ".txt"
$currentSummary = $null;
$currentSummary = Get-ChildItem -Path $currentSummaryPath -ErrorAction SilentlyContinue

#Assume there has been change in the file either there is no existing file or it has changed
$changedFlag = $true;

#diff will return null if the files are the same.
if($currentSummary -ne $null){
  if( (diff -ReferenceObject (Get-Content -Path $currentSummary) -DifferenceObject (Get-Content -Path $path)) -eq $null) {
    $changedFlag = $false;
  }
}



if($changedFlag){

Move-Item -Path $path -Destination $currentSummaryPath -Force 


 ################### SEND EMAIL ######################################

    ###########Define Variables########

$fromaddress = "veeamJobSummary@<customer>.com"
$toaddress = "notifications@<customer>.com"
#$bccaddress = ""
#$CCaddress = ""
$Subject = "ACtion Required - Update Bwiki - The veeam backup configuration has changed"
$body = get-content $currentSummaryPath
$attachment = $path
$smtpserver = "$SITEID-MSX001"

####################################

#$message = new-object System.Net.Mail.MailMessage
#$message.From = $fromaddress
#$message.To.Add($toaddress)
#$message.CC.Add($CCaddress)
#$message.Bcc.Add($bccaddress)
#$message.IsBodyHtml = $false
#$message.Subject = $Subject
#$attach = new-object Net.Mail.Attachment($attachment)
#$message.Attachments.Add($attach)
#$message.body = $body
#$smtp = new-object Net.Mail.SmtpClient($smtpserver)
#$smtp.Send($message)

#################################################################################
}
