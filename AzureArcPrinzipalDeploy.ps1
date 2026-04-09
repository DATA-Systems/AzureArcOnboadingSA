##########
# Config #
##########
$subscriptionId = 'XXXX'
$ClientName = 'Azure Arc'
$resourceGroupName = 'XXXX'
$Location = 'germanywestcentral'
$ClientSecretLifetimeMonths = 120
$Domain = "XXXX"
$path = "NETLOGON\AzureArc"
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
    if ($content.Count -ge 6) {
        $content[5] = $content[5] -replace 'AzureArcConfig\.json', $configFilePath
        $content | Set-Content -Path $enableSaScript
    }
}

.\DeployGPO.ps1 -DomainFQDN $Domain -ReportServerFQDN $Domain -ArcRemoteShare $path -ServicePrincipalSecret $credential.SecretText -ServicePrincipalClientId $sp.AppId -SubscriptionId $subscriptionId -ResourceGroup $resourceGroupName -Location $Location -TenantId $sp.AppOwnerOrganizationId

Set-Location -Path $dir
exit