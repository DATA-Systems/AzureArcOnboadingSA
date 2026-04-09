# Test if Softwareassurence already has beean enabled.
if ((Get-ItemProperty -Path "HKLM:\SYSTEM\Software\Microsoft\AzureConnectedMachineAgent" -ErrorAction SilentlyContinue).SoftwareAssurance -eq 1) {
    exit 0
}

$jsonData = Get-Content -Path "AzureArcConfig.json" | ConvertFrom-Json
##########
# Config #
##########
$subscriptionId = $jsonData.subscriptionId
$resourceGroupName = $jsonData.resourceGroupName
$servicePrincipalClientSecret = $jsonData.SecretText
$servicePrincipalID = $jsonData.AppId
$tenantID = $jsonData.TenantId
$location = $jsonData.Location
##########

# Install Az.ConnectedMachine module, connect to Azure, enable SA
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
Set-PSRepository -name PSGallery -InstallationPolicy Trusted | Out-Null
Install-Module Az.ConnectedMachine -AllowClobber -Confirm:$false | Out-Null

$pass = ConvertTo-SecureString $servicePrincipalClientSecret -AsPlainText -Force
$clientSecret = New-Object System.Management.Automation.PSCredential ($servicePrincipalID, $pass)
$account       = Connect-AzAccount -ServicePrincipal -Tenant $tenantID -Credential $clientSecret
$context       = Set-azContext -Subscription $subscriptionId 
$profile       = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile 
$profileClient = [Microsoft.Azure.Commands.ResourceManager.Common.rmProfileClient]::new( $profile ) 
$token         = $profileClient.AcquireAccessToken($context.Subscription.TenantId) 
$header = @{ 
   'Content-Type'='application/json' 
   'Authorization'='Bearer ' + $token.AccessToken 
}

$uri = [System.Uri]::new( "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.HybridCompute/machines/$env:COMPUTERNAME/licenseProfiles/default?api-version=2023-10-03-preview" ) 
$contentType = "application/json"  
$data = @{         
    location = $location; 
    properties = @{ 
        softwareAssurance = @{ 
            softwareAssuranceCustomer= $true; 
        }; 
    }; 
}; 
$json = $data | ConvertTo-Json; 
$response = Invoke-RestMethod -Method PUT -Uri $uri.AbsoluteUri -ContentType $contentType -Headers $header -Body $json | Out-Null

# Verify if SA is enabled and set reg key
if ((Get-AzConnectedMachine -ResourceGroup $resourceGroupName -Name $env:COMPUTERNAME).LicenseProfile.SoftwareAssuranceCustomer -eq $true) {
    # Create reg key if it does not exist
    New-Item -Path "HKLM:\SYSTEM\Software\Microsoft\AzureConnectedMachineAgent" -Force -ErrorAction SilentlyContinue | Out-Null
    # set reg key to 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\Software\Microsoft\AzureConnectedMachineAgent" -Name "SoftwareAssurance" -Value 1 -Type DWord | Out-Null
    exit 0
} else {
    exit 1
}