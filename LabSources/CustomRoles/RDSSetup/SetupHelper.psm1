#region ServerManager Helper
function Get-ServerListPath
{
    $ServerListPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\ServerManager\ServerList.xml"
    return $ServerListPath
}
function Get-RDSADComputer
{
    $AllRDSComputers = Get-ADComputer -SearchBase 'OU=RDS,DC=dev,DC=local' -Filter * -SearchScope Subtree | Select-Object -ExpandProperty DNSHostName
    return $AllRDSComputers
}
function Close-ServerManager
{
    # Close Servermanager if it is open
    $ServerManagerProcess = Get-Process -Name ServerManager -ErrorAction SilentlyContinue
    if ($ServerManagerProcess)
    {
        Write-Output 'Stopping ServerManager.'
        Stop-Process -Name ServerManager
    }
    else
    {
        Write-Output 'ServerManager is not running. No action needed.'
    }
}
function Test-IfServerListExist
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ServerListPath
    )

    if (Test-Path -Path $ServerListPath)
    {
        return $true
    }
    else
    {
        return $false
    }
}
function Get-ServerListXMLFile
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ServerListFile
    )

    $ServerListContent = [xml](Get-Content -Path $ServerListFile)
    return $ServerListContent
}
function Get-AllServersInServerListFile
{
    $return_ServerListPath = Get-ServerListXMLFile -ServerListFile (Get-ServerListPath)
    $AllXMLServers = $return_ServerListPath.ServerList.ServerInfo.name
    return $AllXMLServers
}
function Find-IfServerIsInServerListFile
{
    param
    (
        [Parameter(Mandatory)]
        [string[]]
        $AllXMLServers,

        [Parameter(Mandatory)]
        [string[]]
        $AllRDSComputers
    )

    $returnarray = New-Object -TypeName System.Collections.ArrayList

    foreach ($XMLServer in $AllXMLServers)
    {
        foreach ($RDSServer in $AllRDSComputers)
        {
            if ($RDSServer -eq $XMLServer)
            {
                $null = $returnarray.Add($true)
            }
            else
            {
                $null = $returnarray.Add($false)
                $null = $returnarray.Add($RDSServer)
            }
        }
    }
    return $returnarray
}
function Add-XMLEntryToServerListFile
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $RDSServer
    )
    
    $ServerListContent = Get-ServerListXMLFile -ServerListFile (Get-ServerListPath)

    $NewServer = @($ServerListContent.ServerList.ServerInfo)[0].Clone()
    $NewServer.Name = "$RDSServer"
    $NewServer.LastUpdateTime = '0001-01-01T00:00:00'
    $NewServer.status = '2'
    
    $null = $ServerListContent.ServerList.AppendChild($NewServer)
    return $ServerListContent
}
function Add-ServerListEntry
{
    # Make a duplicate of the ServerList.xml
    $ServerList_NewPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\ServerManager\ServerList1.xml"
    if (Test-IfServerListExist -ServerListPath $ServerList_NewPath)
    {
        Write-Output 'File already exists. No action needed.'
        $ServerListFile = Get-Item -Path (Get-ServerListPath)
    }
    else
    {
        Copy-Item -Path $ServerListPath -Destination $ServerList_NewPath -Force
        $ServerListFile = Get-Item -Path (Get-ServerListPath)
    }

    # Import the XML File
    #$return_GetServerListXMLFile = Get-ServerListXMLFile -ServerListFile $ServerListFile
    
    $return_AllXMLServers = Get-AllServersInServerListFile
    $return_AllRDSADPCs = Get-RDSADComputer

    # Create a New ServerElement for each RDS Server
    $return_FindIfServerIsInServerListFile = Find-IfServerIsInServerListFile -AllXMLServers $return_AllXMLServers -AllRDSComputers $return_AllRDSADPCs 

    if ($return_FindIfServerIsInServerListFile.Where{$_ -eq $true})
    {
        Write-Output 'Entry is already in ServerList.xml.'
    }
    else
    {
        Write-Output 'Entry is not in ServerList.xml. Adding it.'
        $return_AddXMLEntryToServerListFile = Add-XMLEntryToServerListFile -RDSServer $return_FindIfServerIsInServerListFile[1]
        $null = $return_AddXMLEntryToServerListFile.Save($ServerListFile.FullName)
    }
}
function New-ServerListFile
{
    # Starting ServerManager
    Start-Process -FilePath "$env:windir\System32\ServerManager.exe"
    Start-Sleep -Seconds 5
    
    # Stop ServerManager gracefully to create the xml File
    $null = Get-Process -Name ServerManager | ForEach-Object {$_.CloseMainWindow()}
    Start-Sleep -Seconds 5

    # Make a duplicate of the ServerList.xml
    $ServerList_NewPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\ServerManager\ServerList1.xml"
    if (Test-Path -Path $ServerList_NewPath)
    {
        Write-Output 'File already exists. No action needed.'
    }
    else
    {
        Copy-Item -Path $ServerListPath -Destination $ServerList_NewPath -Force
    }
}
#endregion