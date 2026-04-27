# Azure Arc Onboarding

## Setup

### 1. Download

Prinzipal and Deploy: https://github.com/DATA-Systems/AzureArcOnboadingSA/blob/main/AzureArcPrinzipalDeploy.ps1<br>
Enable Software Asurance: https://github.com/DATA-Systems/AzureArcOnboadingSA/blob/main/AzureArcEnableSA.ps1<br>
Azure Connected Maschine Agent: https://gbl.his.arc.azure.com/azcmagent/latest/AzureConnectedMachineAgent.msi<br>
GPO Deploy Script Bundle: https://github.com/Azure/ArcEnabledServersGroupPolicy/releases/latest<br>

### 2. Sysvol
1. Create an folder for AzureArc eg. `C:\Windows\SYSVOL\sysvol\domain.com\scripts\AzureArc` (`\\domain.com\NETLOGON\AzureArc`), which will be the `$LocalPath` in the config.
2. Put the `Enable Software Asurance` Script, the `Azure Connected Maschine Agent` msi and the content of the `GPO Deploy Script Bundle` zip (`ArcGPO`, `AuireArcDeployment.psm1`, `DeplayGPO.ps1`, `EnableAzureArc.ps1`) together in the created folder.

### 3. Config
Adjust the config in the `Prinzipal and Deploy` script.
```
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
```

### 4. Execute the deployment script
1. Open an Powershell as Administrator
2. `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force`
3. Execute the `Prinzipal and Deploy` Script (`.\AzureArcPrinzipalDeploy.ps1`) and login as M365 Administraotor.
The Script will create an Service Prinzipal and handels the permissions, it will create an new Secret with the lifetime from the config (default 120 months = 10 years).
Also it will create an config file in the NETLOGON path and adjust the config path in the `Enable Software Asurance` script.
Lastly it executed the deployment script from microsoft which will create an GPO and opens the editor.

### 5. Adjust the Microsoft GPO for our needs
- Rename the GPO eg. `COMPUTER_AzureArc_AzureConnectedMaschineAgent+EnableSA`
- GPO > Computer Configuration > Preferences > Control Panel Settings > Schedules Tasks > Immediate Task (At least Windows 7): Arc Agent Installation > Actions > New:
    - Program/script: `Powershell.exe`
    - Add Aguments: -ExecutionPolicy Bypass -Command "& \\DOMAIN.COM\NETLOGON\AzureArc\AzureArcEnableSA.ps1"
- GPO > Computer Configuration > Policies > Software Settings > Assigned Applications > add the `Azure Connected Maschine Agent` msi

## Trouble Shooting

### argument transformation
Error: `The argument transformation for the parameter "ObjectId" cannot be processed. The value cannot be converted to the type "System.String".`
Fix: Check for multiple Entra Applications with the samen name.
At the moment the script cannot auto delete applications after unsucesful completion, neither decide between multiple applications.

## Refernece
https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-group-policy-powershell<br>
https://learn.microsoft.com/en-us/azure/azure-arc/servers/windows-server-management-overview?tabs=powershell#enrollment

## License
Shall be used under [GPLv3](https://github.com/DATA-Systems/AzureArcOnboadingSA/blob/main/LICENSE).
