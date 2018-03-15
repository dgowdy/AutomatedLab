param
(
    [Parameter(Mandatory)]
    [bool]
    $ConnectionBrokerHighAvailabilty,

    [Parameter(Mandatory)]
    [String]
    $RDSStructureName
)

Import-Module .\RDSAD.psm1 -Force
Import-Module .\Helper.psm1 -Force

switch($ConnectionBrokerHighAvailabilty)
{
    $true
    {
        New-ADStructure -RDSStructureName $RDSStructureName -ConnectionBrokerHighAvailabilty $true
    }

    $false
    {
        New-ADStructure -RDSStructureName $RDSStructureName -ConnectionBrokerHighAvailabilty $false
    }
}
