

###Outlook Anywhere
OA is RPC over HTTP 

Verify RPC/HTTP proxy is installed using Svr Mgr / Features. 

Get-WindowsFeature *rpc* 

Create an *A* record to point to CAS servers. eg mail.domain.com 192.168.0.1, 192.168.0.2

Setup OA EAC visit each cas server role / OA enter A record above.

PowerShell
Get-OutlookAnywhere | Set-OutlookAnywhere -InternalHostname mail.litwareinc.com -InternalClientsRequireSsl $true -ExternalHostname mail.litwareinc.com -ExternalClientsRequireSsl $true -ExternalClientAuthenticationMethod Basic
*Each CAS Server* has to present the same certificate to avoid cert errors, or provide a SAN certificate for CAS to present to the client.

Verify 
Use remote Connectivity Analyzer

####How does the autodiscover service retrieve Outlook Anywhere settings ? 

* (Internally) Outlook consults SCP (Active Directory) and generates an insite and out of site list of CAS servers 
* tries to connect to the autodiscover url discovered from above list (randomized) insite first then out of site. 
* if no SCP (think external clients) tries predefined Autodiscover URL https://autodiscover.domain.com/autodiscover/autodiscover.xml 
* if no response then Http redirect 
* if no response SRV records in DNS 

#####What does autodiscover server provide ? 
takes users email address and provides the following to Outlook. 

*Users display name
* Separate connection settings for internal and external access 
* location of users mailbox server
* URLs for outlook services including free/busy UM OAB and Outlook Anywhere Server Settings

Autodiscover reconfigures user's outlook profile if changes are detected.

Every CAS server install generates an SCP in AD , contains authoritative list autodiscover URLS for the entire forest. 

