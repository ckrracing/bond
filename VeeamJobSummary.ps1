Param(

  [switch]$force,

  #job options file is in the current directory
  [string]$options_file = "C:\Bond\TEST\Veeam\job-options.json" ,

  [string]$site_options_file = "C:\Bond\TEST\vbw-options.json" 
  
 
)

#."C:\Users\Public\Documents\PS2EXE-v0.5.0.0\vc\bond\functions.ps1"

## latest file ## 

Function readJobOptions {

 Param(
       [string] $options_file 
       )
   
   Try {

        $optionsJson = Get-Content  $options_file -Raw -ErrorAction Stop

   }

   Catch{

        $errorMsg = "Unable to find job-options.json file , Unable to continue" 

        # Note when an error was encountered during Write-EventLog , the script does not stop even when you specifiy -ErrorAction Stop it breaks out of the Catch block and then continues.
        Try{
            Write-EventLog -LogName Application -EventId 2663 -Message $errorMsg -Source "Bond VBI" -ErrorAction Stop
           }
            Catch{
            }

        Write-Error $errorMsg;
        exit;

   }

   # Show current working directory 
   Get-Location | Write-Host 

   #Read in options from the json options file and convert encrypted password to plaintext for use while the program is running

   $options = ConvertFrom-Json $optionsJson

    return $options

 }



Function Get-VeeamVersion {	
	# Location of Veeam executable (Veeam.Backup.Shell.exe)
	$veeamExePath = "C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Shell.exe"
	$veeamExe = Get-Item $veeamExePath
	$VeeamVersion = $veeamExe.VersionInfo.ProductVersion
	Return $VeeamVersion
} 



Clear-Host

$options = readJobOptions -options_file $options_file ;
$rootDir = $options.rootDirectory;


# Add Veeam snap-in if required
If ((Get-PSSnapin -Name VeeamPSSnapin -ErrorAction SilentlyContinue) -eq $null) {add-pssnapin VeeamPSSnapin}

Get-Location | Write-Host


$scheduleType = $null; 
$scheduleTime = $null; 
$job = $null ; 

$path = $rootDir  + "\Veeam_Backup_Summary_latest" + ".txt" 

$version = Get-VeeamVersion ; 

"Veeam Version : $version" | Out-File $path ;

## Get each job in Veeam and collect details output to $rootDir\Veeam_Backup_Summary_latest.txt ##

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
} | Out-File $path -Append

$currentSummaryFile = $rootDir + "\Veeam_Backup_Summary" + ".txt"

$currentSummary = $null;
$currentSummary = Get-ChildItem -Path $currentSummaryFile -ErrorAction SilentlyContinue

#Assume there has been change in the difference between the two files, either there is no existing file or there has been a change in the backup jobs
$changedFlag = $true;

#diff the two files, will return null if the files are the same.
if($currentSummary -ne $null){
  if( (diff -ReferenceObject (Get-Content -Path $currentSummary) -DifferenceObject (Get-Content -Path $path)) -eq $null) {
    $changedFlag = $false;
  }
}

$force = $true;
# If the -force switch is true set changedFlag to true regardless
if($force -eq $true){
    $changedFlag = $true
    
  }

# if changed update the current summary file and upload to bwiki
if($changedFlag){

   Move-Item -Path $path -Destination $currentSummaryFile -Force
   Get-Location | Write-Host

   $upload_file = $currentSummaryFile
   $parent_page = $options.parentPage
   
 #  sendToBwiki -options_file $site_options_file -job_options_file $options_file
   #Note the space after the exe is significant don't ask me why I don't know it just is :( 
   # Call bond_vbi_x64.exe to upload the file specified in options 
   # $options is the fully qualified path of the vbw-options.json file which has been passed to this script as a parameter.

        
        Write-Host 
       
        &"C:\bond\bond_vbi_x64.exe "  -site_options $site_options_file -job_options $options_file 
    
   

}
 ################### SEND EMAIL ######################################

    ###########Define Variables########
<#
$fromaddress = "veeamJobSummary@<customer>.com"
$toaddress = "notifications@<customer>.com"
#$bccaddress = ""
#$CCaddress = ""
$Subject = "Action Required - Update Bwiki for SITE ID: $SITEID - The veeam backup configuration has changed"
$body = get-content $currentSummaryPath
$attachment = $path
$smtpserver = "$SITEID-MSX001"
#>

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


