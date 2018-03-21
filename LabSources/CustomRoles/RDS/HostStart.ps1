param
(
    [Parameter(Mandatory)]
    [String]
    [ValidateSet('Yes', 'No')]
    $IsAdvancedRDSDeployment,
    
    [Parameter(Mandatory)]
    [String]
    [ValidateSet('Yes', 'No')]
    $ConnectionBrokerHighAvailabilty,

    [Parameter(Mandatory)]
    [String]
    $RDSStructureName,

    [Parameter()]
    [String]
    [ValidateSet('Yes', 'No')]
    $IsSessionBasedDesktop,

    [Parameter(Mandatory)]
    [String]
    $LabPath,

    [Parameter(Mandatory)]
    [String[]]
    [ValidateSet('RDSAD', 'RDSCB', 'RDSGW', 'RDSLIC', 'RDSSH', 'RDSWA')]
    $Roles
)

Import-Lab -Path $LabPath

switch ($IsAdvancedRDSDeployment) {
    'Yes' {
        switch ($Roles) {
            'RDSAD' {                
                if (Get-Module -Name InstallRDSAD -ErrorAction SilentlyContinue) {
                    Remove-Module InstallRDSAD
                    Import-Module $PSScriptRoot\InstallRDSAD.psm1
                }
                else {
                    Import-Module $PSScriptRoot\InstallRDSAD.psm1
                }
                
                $module = Get-Command -Module InstallRDSAD
                $rootdcname = Get-LabVM -Role RootDC | Select-Object -First 1 -ExpandProperty Name

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Creating RDS ActiveDirectory Structure' -ScriptBlock {
                    New-ADStructure -ConnectionBrokerHighAvailabilty $args[0] -RDSStructureName $args[1]
                } -Function $module -ArgumentList $ConnectionBrokerHighAvailabilty, $RDSStructureName                
            }

            'RDSCB' {
                if (Get-Module -Name InstallRDSAD -ErrorAction SilentlyContinue) {
                    Remove-Module InstallRDSCB
                    Import-Module $PSScriptRoot\InstallRDSCB.psm1
                }
                else {
                    Import-Module $PSScriptRoot\InstallRDSCB.psm1
                }
                
                $module = Get-Command -Module InstallRDSCB
                
                Invoke-LabCommand -ComputerName $RDSCBComputerName -ActivityName 'Installing RSAT-AD-PowerShell' -ScriptBlock {
                    Install-WindowsFeature -Name 'RSAT-AD-PowerShell'
                }

                Invoke-LabCommand -ComputerName
            }

            'RDSGW' {

            }

            'RDSLIC' {

            }

            'RDSSH' {

            }

            'RDSWA' {

            }
        }
    }

    'No' {

    }
}
