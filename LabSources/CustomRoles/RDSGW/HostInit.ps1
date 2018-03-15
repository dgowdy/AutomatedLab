param
(
    [Parameter(Mandatory)]
    [String]
    $RDSStructureName,

    [Parameter(Mandatory)]
    [String]
    $ADServer
)

& $PSScriptRoot\RDSGW.ps1 -RDSStructureName $RDSStructureName -ADServer $ADServer