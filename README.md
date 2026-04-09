# Azure Arc Onboarding

## Setup

### 1. Download

Prinzipal and Deploy: `https://cooming.soon/`<br>
Enable Software Asurance: `https://cooming.soon/`<br>
Azure Connected Maschine Agent: `https://gbl.his.arc.azure.com/azcmagent/latest/AzureConnectedMachineAgent.msiv`<br>
GPO Deploy Script Bundle: `https://github.com/Azure/ArcEnabledServersGroupPolicy/releases/latest`<br>

### 2. Sysvol
1. Create an folder for AzureArc eg. `C:\Windows\SYSVOL\sysvol\XXXX\scripts\AzureArc` (`\\domain.com\NETLOGON\AzureArc`)
2. Put the `Enable Software Asurance` Script, the `Azure Connected Maschine Agent` msi and the content of the `GPO Deploy Script Bundle` zip (`ArcFPO`, `AuireArcDeployment.psm1`, `DeplayGPO.ps1`, `EnableAzureArc.ps1`) in the created folder.

### 3. Config
Adjust the config in the `Prinzipal and Deploy` script.
```
##########
# Config #
##########
$subscriptionId = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
$ClientName = 'Azure Arc'
$resourceGroupName = 'XXXXX'
$Location = 'XXXXX'
$ClientSecretLifetimeMonths = 120
$Domain = "domain.com"
$path = "NETLOGON\AzureArc"
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
- GPO > Computer Configuration > Policies > Software Settings > Assigned Applications > add the `Azure Connected Maschine Agent` MSI

## Refernece
https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-group-policy-powershell<br>
https://learn.microsoft.com/en-us/azure/azure-arc/servers/windows-server-management-overview?tabs=powershell#enrollment

## License
Shall be used under [GPLv3](https://github.com/DATA-Systems/AzureArcOnboadingSA/blob/main/LICENSE).
