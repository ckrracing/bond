Function getPassword{

 Param(

    [string] $password ,
    [string] $key

 )

 $KeyBytes = [System.text.Encoding]::ASCII.GetBytes($key);

     $securePassword = ConvertTo-SecureString  $password -AsPlainText -Force
     $securePasswordForOptionsFile =  ConvertFrom-SecureString -Key $KeyBytes  -SecureString $securePassword

     #convert Key ($KeyBytes) to base64 for the options file
     $base64KeyString = [Convert]::ToBase64String($KeyBytes)

    $props = @{
       password = $securePasswordForOptionsFile 
       key = $base64KeyString
     }

     $credentialObject = New-Object PSObject -Property $props
     return $credentialObject;

}

Function writeJobOptions2{

Param(
 
  [hashtable] $p

 )
 
 # $opts = New-Object psobject;

  # $args = @{"name" ="Chris";"address"="nowhere"}
  
  $keys = $p.Keys;
  $prop;

  $properties = @{
    
  }
  
  ForEach($key in $keys){

   $prop = $key.Substring(1)
   
   $value = $p.get_item($key) ; 
   $properties.Add($prop , $value);

   
  }

  #Add-Member -InputObject $opts -MemberType Property $properties

  if($p.ContainsKey('-password')){

    if(! $p.ContainsKey('-key')){
      Write-Error "Must have a key switch if supplying a plain text password";
      exit -1; 
    }

    else {
         $opts = New-Object PSObject -Property $properties
         $secureOptions = getPassword -password $opts.password -key $opts.key
         $opts.password = $secureOptions.password;
         $opts.key = $secureOptions.key;
    }
  }
  
  return $opts; 
}

## options in job-options.json ##
## rootDirectory
## fileToUpload
## host
## username
## password
## key 
## pageTitle 
## parentPage

$a = @{ 

"-username" = "root" 
 "-password" = "*0515PorkSword" 
 "-key" = "7XG?pV998mMVyPEE" 
 "-parentPage" = "0515 - Esxi" 
 "-pageTitle" = "0515 - Configuration Backups"
 "-rootDirectory" =  "C:\Bond\Vmware"
 "-fileToUpload" = "vmware_host_config.txt"
 "-host" = "0515-esx003" 
}

$o = writeJobOptions2 -p $a

ConvertTo-Json $o | Out-File -Force "job-options.json" 


