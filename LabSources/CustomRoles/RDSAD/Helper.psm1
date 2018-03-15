function New-OUSubfolderStructure()
{    
    param
    (
        [Parameter(Mandatory)]
        [String]
        $DN,

        [Parameter(Mandatory)]
        [String[]]
        $Folderstructure
    )

    foreach($folder in $Folderstructure)
    {
        $DN_folder = [String]::Concat("OU=$folder,",$DN)
        
        if(Get-OUState -DN $DN_folder)
        {
            Write-Output -InputObject "OU $Folder exists already."
        }
        else
        {
            Write-Output -InputObject "Going to create OU $folder in path $DN"
            New-ADOrganizationalUnit -Name "$folder" -Path $DN -Description "Session Based Desktop Servers"
        }
    }
}

function Get-OUState()
{
    Param
    (
        [Parameter(Mandatory)]
        [String]
        $DN
    )
    
    try
    {
        Get-ADOrganizationalUnit -Identity $DN -ErrorAction SilentlyContinue
        return $true
    }
    catch
    {
        return $false
    }
}

function Get-ADGroupState()
{
    Param
    (
        [Parameter(Mandatory)]
        [String]
        $DN
    )
    
    try
    {
        Get-ADGroup -Identity $DN -ErrorAction SilentlyContinue
        return $true
    }
    catch
    {
        return $false
    }
}