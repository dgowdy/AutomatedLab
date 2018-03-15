param
(
    [Parameter(Mandatory)]
    [String]
    $RDSStructureName,

    [Parameter(Mandatory)]
    [String]
    $ADServer,

    [Parameter(Mandatory)]
    [bool]
    $IsSessionBasedDesktop
)

& $PSScriptRoot\RDSSH.ps1 -RDSStructureName $RDSStructureName -ADServer $ADServer -IsSessionBasedDesktop $IsSessionBasedDesktop