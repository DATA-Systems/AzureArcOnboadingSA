##########
# Config #
##########
$subscriptionId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'    # Azure Subscription ID, where the Service Principal will be created and Arc Servers will be onboarded.
                                                            # Check: https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2
$ClientName = 'Azure Arc SPN'                               # DisplayName of the new Azure AD Service Principal.
                                                            # You can choose any name, but it makes sense to choose a meaningful one, especially if you plan to use the same subscription for other purposes as well.
$resourceGroupName = 'EXAMPLE_ARC_Servers'                  # Resource Group where Arc Servers will be onboarded. Your Azure Resource Group needs to exist before running the script.
                                                            # Check: https://portal.azure.com/#servicemenu/Microsoft_Azure_Resources/ResourceManager/resourcegroups
$Location = 'germanywestcentral'                            # Azure Region, where Arc Servers will be onboarded.
                                                            # Check: https://learn.microsoft.com/en-us/azure/reliability/regions-list?tabs=all
                                                            # Pick "Programmatic name" from the table.
$ClientSecretLifetimeMonths = 120
$Domain = "EXAMPLE.LOCAL"                                   # Your local Active Directory Domain (FQDN)
$path = "NETLOGON\AzureArc"                                 # Path in your SYSVOL, where this script is stored. The script will be deployed via GPO, so it needs to be in the SYSVOL (or other deployment share).
                                                            # You can choose any path, but it makes sense to choose a meaningful one and to keep it short because of potential path length issues.
                                                            # Also, this need to be readable by SYSTEM account of the servers, so it needs to be in a share that is accessible by the servers during startup.
                                                            # The NETLOGON share is a good choice, because it is replicated to all Domain Controllers and accessible by all machines in the domain.
$LocalPath = "C:\Windows\SYSVOL\sysvol\${Domain}\scripts\AzureArc"
##########
$dir = Get-Location

# Install Az.ConnectedMachine module, connect to Azure, enable SA
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
Set-PSRepository -name PSGallery -InstallationPolicy Trusted | Out-Null
Install-Module Az.ConnectedMachine -AllowClobber -Confirm:$false | Out-Null

# Create Service Principal
Connect-AzAccount | out-null
if ($subscriptionId -eq '') {
    $subscriptionId = (Get-AzSubscription).Id
    $useNewId = Read-Host "Do you want to use the retrieved subscription ID '$subscriptionId'? (y/n)"
    if ($useNewId -ne 'y') {
        Write-Host "Please put the subscription ID in the config and run again."
        exit
    }
    Set-AzContext -Subscription $subscriptionId | Out-Null
}

$sp = New-AzADServicePrincipal -DisplayName $ClientName -Role "Azure Connected Machine Onboarding"
New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Azure Connected Machine Resource Administrator" -Scope "/subscriptions/$subscriptionId/" | Out-Null
$app = Get-AzADApplication -DisplayName $ClientName
Remove-AzADAppCredential -ObjectId $app.Id -KeyId $app.PasswordCredentials.KeyId | Out-Null
$credential = New-AzADAppCredential -ObjectId $app.Id -EndDate (Get-Date).AddMonths($ClientSecretLifetimeMonths)

cd $LocalPath

$jsonData = @{
    subscriptionId = $subscriptionId
    ClientName = $ClientName
    resourceGroupName = $resourceGroupName
    SecretText = $credential.SecretText
    AppId = $sp.AppId
    TenantId = $sp.AppOwnerOrganizationId
    Location = 'germanywestcentral'
}
$jsonData | ConvertTo-Json | Out-File -FilePath "AzureArcConfig.json"

$enableSaScript = Join-Path -Path $LocalPath -ChildPath 'AzureArcEnableSA.ps1'
if (Test-Path -Path $enableSaScript) {
    $configFilePath = "\\$Domain\$path\AzureArcConfig.json"
    $content = Get-Content -Path $enableSaScript
        if ($content[5] -match ($configFilePath -replace '\\', '\\')) { # first string of "\\"" needs escaping because if regex, secound is just the string put there so it seems like it the same. 
        Write-Host "AzureArcConfig.json path is already correct in AzureArcEnableSA.ps1."
    }
    else {
        $content[5] = $content[5] -replace 'AzureArcConfig\.json', $configFilePath
        $content | Set-Content -Path $enableSaScript
    }
}

.\DeployGPO.ps1 -DomainFQDN $Domain -ReportServerFQDN $Domain -ArcRemoteShare $path -ServicePrincipalSecret $credential.SecretText -ServicePrincipalClientId $sp.AppId -SubscriptionId $subscriptionId -ResourceGroup $resourceGroupName -Location $Location -TenantId $sp.AppOwnerOrganizationId

Set-Location -Path $dir
exit
