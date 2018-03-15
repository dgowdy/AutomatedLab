function New-ADStructure
{
    param
    (
        [Parameter()]
        [bool]
        $ConnectionBrokerHighAvailabilty,

        [Parameter(Mandatory)]
        [String]
        $RDSStructureName
    )

    $dn = (Get-ADDomain).DistinguishedName
    $dn_rds = [String]::Concat("OU=$RDSStructureName,",$dn)
    $subfolders = "RDSBD", "RDSFS", "RDSGW", "RDSWA", "RDSSH", "RDSGroups", "RDSCB"

    try
    {
       $null = Get-ADOrganizationalUnit -Identity $dn_rds -ErrorAction SilentlyContinue
       Write-Output -InputObject "OU $RDSStructureName already exists."
       Write-Output -InputObject "Check if subfolders are missing."
       New-OUSubfolderStructure -DN $dn_rds -Folderstructure $subfolders
       if($ConnectionBrokerHighAvailabilty)
       {
           if(Get-ADGroupState -DN $dn_rds)
           {
              Write-Output -InputObject "Global Group G_ConnectionBrokerServers already exists."
           }
           else
           {
              Write-Output -InputObject "Global Group G_ConnectionBrokerServers will be created."
              New-ADGroup -Name "G_ConnectionBrokerServers" -GroupScope Global -GroupCategory Security -SamAccountName "G_ConnectionBrokerServers" -Path $dn_rds       
           }       
       }
    }
    catch 
    {
       Write-Output -InputObject "OU Structure not there Create it"
   
       Write-Output -InputObject "Create A New Folderstructure."
       New-ADOrganizationalUnit -Name "$RDSStructureName" -Path $dn -Description "Entrypoint for RDS AD Structure"
       New-OUSubfolderStructure -DN $dn_rds -Folderstructure $subfolders

       if($ConnectionBrokerHighAvailabilty)
       {
           if(Get-ADGroupState -DN $dn_rds)
           {
              Write-Output -InputObject "Global Group G_ConnectionBrokerServers already exists."
           }
           else
           {
              Write-Output -InputObject "Global Group G_ConnectionBrokerServers will be created."
              New-ADGroup -Name "G_ConnectionBrokerServers" -GroupScope Global -GroupCategory Security -SamAccountName "G_ConnectionBrokerServers" -Path $dn_rds       
           }       
       }
    }
}