<#
.Synopsis
   Use the REST API of FortiOS/Fortigate with powershell
.DESCRIPTION
   This scripts serves as examples on how to work with the REST api of FortiOS/Fortigate. 
   It's been tested with FortiOS 5.2 and 5.4 using powershell v5.
   
   It features examples that uses the excel module for powershell. If you are running Windows PowerShell 5.0, 
   you can use the new Install-Module ImportExcel command. It’ll pull down the module from the gallery. 
   You can also get it from GitHub: dfinke/ImportExcel.

#>
#Requires -RunAsAdministrator
Param
(
    [Parameter(Mandatory=$false)]
    [string]
    $FortiDevice = "10.0.0.1",
    
    [Parameter(Mandatory=$true)]
    [string]
    $Username,

    [Parameter(Mandatory=$true)]
    [string]
    $Password,
 
    [Parameter(Mandatory=$false)]
    [string]
    $Vdom = "root",
    
    [Parameter(Mandatory=$false)]
    [string]
    $output_folder = "c:\temp"       
)

$URL = "https://$($FortiDevice)"
$login_url = $URL + '/logincheck'
$logout_url = $URL + '/logout'
$api_url = $URL + '/api/v2'

##########################################################
# TRUST all SSL certificate
##########################################################
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#############################################
# SUPPORT TLS 1.2 
##############################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

##########################################################
#CONNECT and extract ccsrftoken for future request
##########################################################
Write-Host "Connect and extract ccsrftoken" -ForegroundColor Magenta

$creds = @{
    username=$Username
    secretkey=$Password
}
 
$result = Invoke-WebRequest -Uri $login_url -Method POST -Body $creds -SessionVariable mySession -ErrorAction Stop
Write-Host "status : $($result.statuscode) $($result.statusdescription)"

# extract ccsrftoken from cookies
$result.Headers.'Set-Cookie' -match 'ccsrftoken=\"(.+)\"'
$ccsrftoken = $Matches[1]

# add ccsrftoken info to header of the Session
$mySession.Headers.add('X-CSRFTOKEN',$ccsrftoken)


########################################################
# CHECK port info 
########################################################
Write-Host "Check port info" -ForegroundColor Magenta
$APIURLaction = "$api_url/monitor/system/interface?interface_name=port11"
$port_monitor = Invoke-WebRequest -Uri $APIURLaction -Method GET -WebSession $mySession
$obj_port_monitor = $port_monitor.Content | ConvertFrom-Json

########################################################
# CHECK UTM Rating-----------------
# Activate monitor-all WebFilter Profile on any rules before
########################################################
Write-Host "Check UTM Rating" -ForegroundColor Magenta
$urlToRate = "www.google.com"
$APIURLaction = "$api_url/monitor/utm/rating-lookup?url=" + $urlToRate
$rating = Invoke-WebRequest -Uri $APIURLaction -Method GET -WebSession $mySession
$obj_rating = $rating.Content | ConvertFrom-Json
Write-Host "Status : $($obj_rating.status)"
Write-Host "Category : $($obj_rating.results.category)"
Write-Host "SubCategory : $($obj_rating.results.subcategory)"

########################################################
# ACQUIRE all addresses from $vdom
########################################################
Write-Host "Acquire all addresses" -ForegroundColor Magenta
$APIURLaction = "$api_url/cmdb/firewall/address/?vdom=$vdom&with_meta=1" #with_meta(optionnal) is used to aquire additionnal info such as uuid
$addresses = Invoke-WebRequest -Uri $APIURLaction -Method GET -WebSession $mySession
$obj_addr = $addresses.Content | ConvertFrom-Json
$obj_addr.results | Export-Excel $output_folder\addresses.xlsx

########################################################
#  ACQUIRE all addresses groups
########################################################
Write-Host "Acquire all addresses group" -ForegroundColor Magenta
$APIURLaction = "$api_url/cmdb/firewall/addrgrp/"
$addressesGroup = Invoke-WebRequest -Uri $APIURLaction -Method GET -WebSession $mySession
$obj_addrGroup = $addressesGroup.Content | ConvertFrom-Json
$obj_addrGroup.results | Export-Excel $output_folder\addrGroup.xlsx

########################################################
# ACQUIRE all policies
########################################################
Write-Host "Acquire all policies" -ForegroundColor Magenta
$APIURLaction = "$api_url/cmdb/firewall/policy/"
$policies = Invoke-WebRequest -Uri $APIURLaction -Method GET -WebSession $mySession
$obj_policies = $policies.Content | ConvertFrom-Json
$obj_policies.results | Export-Excel $output_folder\policies.xlsx

########################################################
# CREATE object type address
########################################################
$APIURLaction = "$api_url/cmdb/firewall/address"
$body_content = @{
     name = "Desktop Lois"
     subnet = "10.2.2.2/32"
} | ConvertTo-Json
$create_addresse = Invoke-WebRequest -Uri $APIURLaction -Method POST -Body $body_content -WebSession $mySession

########################################################
# UPDATE object type address
########################################################
$APIURLaction = "$api_url/cmdb/firewall/address/Desktop%20Lois/" # notice the address name should be URL encoded
$body_content = @{
        name = "Desktop Louis"
} | ConvertTo-Json
$update_addresse = Invoke-WebRequest -Uri $APIURLaction -Method PUT -Body $body_content -WebSession $mySession

########################################################
# DELETE object type address using uuid
########################################################
$APIURLaction = "$api_url/cmdb/firewall/address/?uuid=ea8cf64c-ea4a-51e6-5d04-ff4745a421e2"
$delete_addresse = Invoke-WebRequest -Uri $APIURLaction -Method DELETE -WebSession $mySession

########################################################
# DELETE object type address using name
########################################################
$APIURLaction = "$api_url/cmdb/firewall/address/Desktop%20Louis/"
$delete_addresse = Invoke-WebRequest -Uri $APIURLaction -Method DELETE -WebSession $mySession

########################################################
# LOGOUT
########################################################
$result = Invoke-WebRequest -Uri $logout_url -Method GET -SessionVariable mySession