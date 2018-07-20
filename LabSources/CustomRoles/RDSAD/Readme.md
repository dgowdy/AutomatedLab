# RDS Domain Structure

# Definition of the parameters
- IsAdvancedRDSDeployment: ('Yes', 'No')
    ConnectionBrokerHighAvailabilty = 'Yes'
    LabPath                         = $labPath

# Defining the role

```` PowerShell
$role_dc = Get-LabPostInstallationActivity -CustomRole RDSAD -Properties @{
    IsAdvancedRDSDeployment         = 'Yes'
    ConnectionBrokerHighAvailabilty = 'Yes'
    LabPath                         = $labPath
}
Add-LabMachineDefinition -Name ALDC -Memory 1GB -Roles RootDC -IpAddress 192.168.0.10 -PostInstallationActivity $role_dc
````