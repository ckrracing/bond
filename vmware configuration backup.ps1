<#
    # key is base64 encoded
    # host can be either vcenter appliance or esxi hosts , use comma for multiple esxi hosts eg <siteid>-esx001,<siteid>-esx002 
    # parentPage isn't used.

    {
        "rootDirectory":  "C:\\Bond\\Vmware\\",
        "username":  <read only account>,
        "key":  "N1hHP3BWOTk4bU1WeVBFRQ==",
        "password":  "76492d1116743f0423413b16050a5345MgB8AEwAVgBjAGkAYQBhAHUAQQBxAE0AVQBRAFgARQAzAFgASABBAGcAUgA4AGcAPQA9AHwAMQA3ADIAOABlAGMANQBjAGYAZABlADgAYQAxAGMAOAAyADEAOQAwADMAZgA2AGIAOQAzADcAZAA5ADcANwAyAGEAOABjAGYAMAA5ADcANgBlADgANQBkADcAYgBmADQAYgA2ADgAYgAzADEAYwA1AGEANAA0AGQAOQA2ADMAZgA=",
        "host":  "0515-esx003",
        "parentPage":  "0515 - Esxi",
        "pageTitle":  "0515 - Configuration Backups",
        "fileToUpload":  "vmware_host_config.txt"
    }

#>

Param(

  [switch]$force,

  #job options file is in the current directory
  [string]$job_options_file = "job-options.json" ,

  [string]$site_options_file = "vbw-options.json" 
  
 
)

Function getPassword{

 Param(

    [PSCustomObject] $options
 ) 

 #get the key to unlock pasword 
   $base64Key = [Convert]::FromBase64String($options.key);
   $key = [System.text.Encoding]::ASCII.GetString($base64Key);
   $KeyBytes = [System.text.Encoding]::ASCII.GetBytes($key);
   
   $securePassword = ConvertTo-SecureString -Key $KeyBytes -String $options.password;

   $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securePassword) 
  
   $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
   [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

   # $options | add-member Noteproperty plainTextPassword $result

   return $result

}

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
   # Get-Location | Write-Host 

   #Read in options from the json options file and convert encrypted password to plaintext for use while the program is running

   $o = ConvertFrom-Json $optionsJson

   #Add-Member -InputObject $options -NotePropertyName 'plainTextPassword' -NotePropertyValue (getPassWOrd -options $options)
   #$options.plainTextPassword = getPassword -options $options; 

   $hosts = $o.host.split(',');

   $o | Add-Member hosts $hosts;

   return $o


 }

."C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1" $true

$site_options_file = "C:\Bond\bond_vbi\vbw-options.json" ;

$job_options_file = "C:\Bond\vmware\0515\job-options.json" ;

$options =  readJobOptions -options_file $job_options_file

$pass = (getPassWord -options $options)



ForEach($esxhost in $options.hosts){

    $esxHost = Connect-VIServer -Server $options.host -User $options.username -Password $pass
    Get-VMHost | Get-VMHostFirmware  -BackupConfiguration -DestinationPath $options.rootDirectory
    Disconnect-VIServer -Confirm:$false
    
    }

    
$fileToUpload = $options.rootDirectory + '\' + $options.fileToUpload;

# Get the name of the files uploaded to -DestinationPath 
$configs = Get-ChildItem -Path $options.rootDirectory -Filter "*.tgz" -Name

#backup current $fileToUpload
if(Test-Path -Path $fileToUpload){
  move -Force $fileToUpload ($options.rootDirectory + '\' + $options.fileToUpload + '.bak')
} 

#write the full path of the configuration files to the fileToUpload
ForEach($backup in $configs){

    $options.rootDirectory + '\' + $backup | Out-File -FilePath $fileToUpload -Append

}




## options in job-options.json ##
## rootDirectory
## fileToUpload
## host
## username
## passs
## key 
## pageTitle 
## parentPage

## -write_job_options -username "administrator@vsphere.local" -password " -key "2.S([W9@<{7Bfj#u" -page_title "0812 - esxi" -parent_page_title "0812 - configs" -root_directory "C:\Bond\Veeam" -file "vmware_host_config.txt" -email_to "notifications@my-titan.com"




