param
(
    [Parameter(Mandatory)]
    [Switch]
    $ConnectionBrokerHighAvailabilty,

    [Parameter(Mandatory)]
    [Switch]
    $RDSStructureName
)

$dn = (Get-ADDomain).DistinguishedName
$dn_rds = [String]::Concat("OU=$RDSStructureName,",$dn)

if(Get-ADOrganizationalUnit -Identity $dn)
{
    Write-Error -Message "OU $RDSStructureName is already there in Path $dn"
}
else 
{
    New-ADOrganizationalUnit -Name "RDS" -Path $dn -Description "Entrypoint for RDS AD Structure"
    New-ADOrganizationalUnit -Name "RDSBD" -Path $dn_rds -Description "Session Based Desktop Servers"
    New-ADOrganizationalUnit -Name "RDSFS" -Path $dn_rds -Description "File Servers"
    New-ADOrganizationalUnit -Name "RDSGW" -Path $dn_rds -Description "Gateway Servers"
    New-ADOrganizationalUnit -Name "RDSWA" -Path $dn_rds -Description "Web Access Server"
    New-ADOrganizationalUnit -Name "RDSSH" -Path $dn_rds -Description "Session Host Servers"
    New-ADOrganizationalUnit -Name "RDSLIC" -Path $dn_rds -Description "Licensing Servers"
    New-ADOrganizationalUnit -Name "RDSGroups" -Path $dn_rds -Description "RDS Permission groups"
    
    if($PSBoundParameters.ContainsKey('ConnectionBrokerHighAvailabilty'))
    {
        New-ADGroup -Name "G_ConnectionBrokerServers" -GroupScope Global -GroupCategory Security -SamAccountName "G_ConnectionBrokerServers" -Path $dn_rds
    }
}