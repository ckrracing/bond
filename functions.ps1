Function writeOptions {


Param(


[string] $username ,


[string] $password  ,


[string]$siteId,


[string]$spaceKey ,


[string]$mx ,


[string]$key 



)
 
 #check to see if we have all information to create a site options file

   if($username -ne "" -and $password -ne ""   -and $siteId -ne ""  -and $spaceKey -ne "" -and $mx -ne ""    -and $key -ne ""  ){
     
     # Write options file 
     Write-Host "Creating File >>> ";
     
     #
     
     #Convert Password to an encrypted string that can be saved 
     # see http://stackoverflow.com/questions/7468389/powershell-decode-system-security-securestring-to-readable-password
    
     $KeyBytes = [System.text.Encoding]::ASCII.GetBytes($key);

     $securePassword = ConvertTo-SecureString  $password -AsPlainText -Force
     $securePasswordForOptionsFile =  ConvertFrom-SecureString -Key $KeyBytes  $securePassword

     #convert Key ($KeyBytes) to base64 for the options file
     $base64KeyString = [Convert]::ToBase64String($KeyBytes)

    $props = @{
       password = $securePasswordForOptionsFile
       userName = $username
       siteId = $siteId
       spaceKey = $spaceKey
       mx = $mx 
       key = $base64KeyString
     }

     $options = New-Object PSObject -Property $props

     Try{
        ConvertTo-Json $options | Out-File "vbw-options.json" -ErrorAction Stop
     }
     Catch{
          Write-Error "Error creating options file "
          exit; 
     }
   }
   else {
     Write-Error "Unable to create options file , all options except parentPage must be specified"; 
     exit;
   }
 #}
 
 }
 
Function parseArgs {
    Param(
        [string[]] $args2pass
    )

    $hashArgs = @{}
    $key = ""; 

    $args2pass | foreach {
        if($_.startsWith('-')){
            $key = $_;
            #"Key is $key"
        }
        else{
            $hashArgs[$key] = $_
            #"Value is $_" 
        }
     }

     return $hashArgs;
}

Function writeJobOptions{
    Param(

#Page Title is the title in bwiki needs to be unique within the space as that is the initial search term. 
# spaces will be replaced with + sign so it can be used in the URI
[string]$page_title ,


[string]$file ,


[string[]]$email_to ,

[string]$root_directory,

[string]$parent_page_title = ""
)


if( $email_to -eq "" -or $page_title -eq "" -or $file -eq "" -or $root_directory -eq "" ){
        Write-Host " All parameters except parent_page_title must be specified ";
        Write-Host " use -help to see options for -write_job_options"
        exit -5 ; 
}

$a = 5;
$props = @{

       fileToUpload = $file
       emailNotifications = $email_to
       pageTitle = $page_title
       parentPage=$parent_page_title
       rootDirectory=$root_directory
      
     }

     $options = New-Object PSObject -Property $props

     Try{
        ConvertTo-Json $options | Out-File "job-options.json" -ErrorAction Stop
     }
     Catch{
          Write-Error "Error creating options file "
          exit; 
     }



}
Function callWriteOptions {

    Param(
        [string[]] $args2pass
    )
    
     
        $hashArgs = parseArgs -args2pass $args2pass;

    
        writeOptions -username $hashArgs.Get_Item('-username') -password $hashArgs.Get_Item('-password') -mx $hashArgs.Get_Item('-mx')   -siteId $hashArgs.Get_Item('-siteId') -spaceKey $hashArgs.Get_Item('-spaceKey') -key $hashArgs.Get_Item('-key')

}



Function callWriteJobOptions{
   Param(
        [string[]] $args2pass
    )
    $hashArgs = parseArgs -args2pass $args2pass;
    writeJobOptions -page_title $hashArgs.get_item('-page_title') -file $hashArgs.Get_Item('-file') -email_to $hashArgs.get_item('-email_to') -parent_page_title $hashArgs.get_item('-parent_page_title') -root_directory $hashArgs.get_item('-root_directory')
}

Function readSiteOptions {

 Param(
       [string] $options_file 
       )
   
   Try {

        $optionsJson = Get-Content  $options_file -Raw -ErrorAction Stop

   }

   Catch{

        $errorMsg = "Unable to find vbw-options.json file , Unable to continue" 

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

   #get the key to unlock pasword 
   $base64Key = [Convert]::FromBase64String($options.key);
   $key = [System.text.Encoding]::ASCII.GetString($base64Key);
   $KeyBytes = [System.text.Encoding]::ASCII.GetBytes($key);
   
   $securePassword = ConvertTo-SecureString -Key $KeyBytes -String $options.password;

   $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securePassword) 
  
   $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
   [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

   $options | add-member Noteproperty plainTextPassword $result

   return $options

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
   Get-Location | Write-Host 

   #Read in options from the json options file and convert encrypted password to plaintext for use while the program is running

   $options = ConvertFrom-Json $optionsJson

    return $options

 }

Function sendToBwiki {

  Param(
        [string]$options_file = "vbw-options.json" ,
        [string] $job_options_file 
  )

  
$vbw_options = readSiteOptions -options_file $options_file
$job_options  = readJobOptions -options_file $job_options_file

$testOptions = $true;

$upload_file = $job_options.rootDirectory + '\' +  $job_options.fileToUpload

if($upload_file -ne "") {
  $testOptions = Test-Path $upload_file;
}

if($testOptions -ne $true) {
  Write-Error "Unable to find the file $upload_file"
  exit;
  }


Write-Host "PassLen is" + $vbw_options.plainTextPassword.Length  ;

$pageTitleParam = $job_options.pageTitle
$getPageTitleParam = $pageTitleParam.replace(' ',"+")

$parentPageTitleParam = $job_options.parentPage.replace(' ',"+")

$spaceKeyParam = $vbw_options.spaceKey

if($upload_file -ne ""  ){
    $fileToUploadPath = $upload_file
}
else{
    $fileToUploadPath = $vbw_options.fileToUpload
  }

#set up basic auth
$pcred = $vbw_options.userName + ":" + $vbw_options.plainTextPassword;

$pBytes = [System.text.Encoding]::ASCII.GetBytes($pcred)
$p64 = [Convert]::ToBase64String($pBytes) 

$headers = @{'Authorization' = "Basic " + $p64} 

# get parent page if one is specified 
$parentPageJsonParam = ""

if($parentPageTitleParam -ne "") {

 $parentPageURI = "https://bwiki.bondtm.com/rest/api/content?type=page&title=" + $parentPageTitleParam + "&space=" + $spaceKeyParam + "&expand=version"

 Try{
    $parentPageResult = Invoke-RestMethod -Uri $parentPageURI -Method Get  -Headers $headers -ContentType "application/json" 
    }
    Catch{
      $_.Exception.Response;
      Write-Error " There has been an error received for the request" 
      Write-Host $_.Exception.Response;
      exit; 
    }

 if($parentPageResult.size -ne 0){
    $parentId = $parentPageResult.results[0].id;
    $parentPageJsonParam = '"ancenstors":' + '[{"id":' + $parentId + '}],'
 }
}

#invoke the request to get the page id if it exists

##Note that some elements can be requested as expandable (verbose) this needs to be done for the version to be returned 
##using the expand param.

$getURI = "https://bwiki.bondtm.com/rest/api/content?type=page&title=" + $getPageTitleParam + "&space=" + $spaceKeyParam + "&expand=version" 
 Try{
    $result = Invoke-RestMethod -Uri $getURI -Method Get  -Headers $headers 
    }
    Catch{
      $_.Exception.Response;
      Write-Error " There has been an error received for the request" 
      Write-Host $_.Exception.Response;
      exit; 
    }



#Get the page ID and build ID param otherwise set to empty string "" ie  it won't apear in the URI
#Same for $versionParam , it will only be a non empty string if there is a result ie document already exists. 

  $idParam = 0;
  $version = $null;
  $versionParam = ""; 

  $HTTP_METHOD = "POST";

if($result.size -ne 0) {
  $id = $result.results[0].id
  $version = $result.results[0].version.number;
   
  if($version -gt 0 ){
     $version = $version + 1;
  }

  # "version":{"number":2}
  $versionParam = ',"version":' + '{"number":' +$version + '}';
  $HTTP_METHOD = "PUT" 

  }
  else {
  $id = 0;
  }

  

  if($id -ne 0) {
    #$idParam = '"id:"' + $id + ','
   $idParam = '"id":' + $id + ','
   
  }
  else{ 
    $idParam = "";
   }

 # "**** Outputting ID $id and idParam $idParam"; 
  
# Read in the file to upload
# $Page = Get-ChildItem -Path "C:\Users\chrisk\AppData\Local\Temp\Veeam_Backup_Summary.txt";

#$Page = Get-ChildItem -Path ($fileToUploadPath.Replace('\\','\'))
$Page = Get-ChildItem -Path $fileToUploadPath

$inMemString = ""

#create a tempPage and account for \\ in the text to ensure it won't get mangled by bwiki  
Try{
     Get-Content $Page -ErrorAction Stop | ForEach {

    # $inMemString = $inMemString + $_;
    $inMemString = $inMemString + "\n" + ($_ -replace '\\','\\')
    }
}
Catch{
     Write-Error "Unable to get content of file $Page"
     exit
    }

#$inMemString | Out-File 'C:\Users\chrisk\AppData\Local\Temp\inMemString.txt';



#update the page


if($id -gt 0) {
  $uri = "https://bwiki.bondtm.com/rest/api/content/$id";
  }
  else {
    $uri = "https://bwiki.bondtm.com/rest/api/content";
  }

$body = "{" + $idParam + ' "type":"page","title":"' + $pageTitleParam + '",' + $parentPageJsonParam + '"space":{"key":"' + $spaceKeyParam + '"},"body":{"storage":{"value":"<ac:structured-macro ac:name=\"noformat\"><ac:parameter ac:name=\"nopanel\">true</ac:parameter><ac:plain-text-body><![CDATA[Name                      : 0515-UTL002\n' + $inMemString + ']]></ac:plain-text-body></ac:structured-macro>","representation":"storage"}}' + $versionParam + '}'
$body | Out-File "$env:Temp\bwikiOutput.txt"

 Try{
    $updateResult = Invoke-RestMethod -Uri $uri -Method $HTTP_METHOD -Body $body -ContentType 'application/json' -Headers $headers 
    }
    Catch{
      $_.Exception.Response;
      Write-Error " There has been an error received for the request" 
      Write-Host $_.Exception.Response;
      exit; 
    }

}


#Testing
#sendToBwiki -options_file "C:\Users\Public\Documents\PS2EXE-v0.5.0.0\vc\bond\vbw-options.json" -upload_file "C:\Users\Public\Documents\PS2EXE-v0.5.0.0\vc\bond\Veeam_Backup_Summary.txt" 
#exit;
#end Testing

$args = [Environment]::GetCommandLineArgs();

#Show the current directory 
Get-Location | Write-Host 

# Check to see if any arguments have been passed in fromt he command line 
if($args.count -gt 1){
 #Help with Troubleshooting
 Write-Host  "Args are $args"
#If help
  if($args[1] -eq "-help"){
    
    Write-Host " -username [string]"
    Write-HOst " -password [string]" 
    Write-HOst " -siteId [string]"
    Write-Host " -spaceKey [string]"
    Write-Host " -siteId [string]"
    Write-Host " -mx [string]"
    Write-Host " -key [string]" 
   
    
    Write-Host " To create a site options file use -write_job_options as the first parameter and ensure you have included all (except any optional) the parameters below after specifying -write_job_options"
    Write-Host " -page_title [string] "
    Write-Host " -file (to send to Bwiki) [string] make sure that this is a fully qualified string"
    Write-Host " -email_to (make sure it is in format first@Email,second@Email with no spaces between the addresses and comma)" 
    Write-Host " -root_directory [string] "
    Write-Host " -parent_page_title (Optional)" 

    Write-Host " To specify a different vbw-options.(json|csv) file than the default current directory "
    Write-Host " Use the -read_options switch to specify the fully qualified path to the options file to be used. (ensure it is quoted)" 
   
    exit; 
  }
  #if Write
  elseif($args[1] -eq "-write_options" -and $args.Count -gt 2 ){
    callWriteOptions $args[2..$args.Count]
  }

  #if Read
  elseif($args[1] -eq "-read_options" -and $args.Count -gt 2) {
    Write-Host "Read Options are " + $args
    sendToBwiki -options_file $args[2]; 
  }
  elseif($args[1] -eq "-write_job_options"){
    callWriteJobOptions $args[2..$args.Count]

  }

  elseif($args[1] -eq "-site_options" ){
  
    $hashArgs = parseArgs $args[2..$args.Count]
    write-host $hashArgs
    pause 
    sendToBwiki -options_file $hashArgs.get_item('-site_options') -job_options_file $hashArgs.get_item('-job_options')
  }
  
  
  #it's an error 
  else {
    Write-Error "First argument must be either -write_options OR -read_options. Please use -help to see the required input" 
 }
 }  

 # If no options are specified just run with defaults 
 else {
        sendToBwiki 
 }   



