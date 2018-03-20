param
(
    [Parameter(Mandatory)]
    [String]
    $RDSStructureName,

    [Parameter(Mandatory)]
    [String]
    $ADServer
)

& $PSScriptRoot\RDSCB.ps1 -RDSStructureName $RDSStructureName -ADServer $ADServer