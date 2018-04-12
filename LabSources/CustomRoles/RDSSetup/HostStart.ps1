param
(
    [String]
    [ValidateSet('Yes', 'No')]
    $IsAdvancedRDSDeployment,

    [String]
    [ValidateSet('Yes', 'No')]
    $ConnectionBrokerHighAvailabilty,

    [Parameter(Mandatory)]
    [String]
    $LabPath
)

Import-Lab -Path $LabPath

switch ($IsAdvancedRDSDeployment)
{
    'Yes'
    {
        if (Get-Module -Name SetupHelper -ErrorAction SilentlyContinue)
        {
            Remove-Module SetupHelper
            Import-Module $PSScriptRoot\SetupHelper.psm1
        }
        else
        {
            Import-Module $PSScriptRoot\SetupHelper.psm1
        }
                
        $module = Get-Command -Module SetupHelper

        $rootdcname = Get-LabVM -Role RootDC | Select-Object -First 1 -ExpandProperty Name

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Open Server Manger at Startup' -ScriptBlock {
            Set-ItemProperty -Path 'HKCU:\Software\Microsoft\ServerManager' -Name DoNotOpenServerManagerAtLogon -Value "0x0" -Force
        }

        Restart-LabVM -ComputerName $rootdcname -Wait -NoNewLine

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Add All RDS Servers To Server Manager' -ScriptBlock {
            $return_ServerListPath = Get-ServerListPath
            Close-ServerManager

            # Test if ServerList.xml exists
            if (Test-IfServerListExist -ServerListPath $return_ServerListPath)
            {
                Add-ServerListEntry
            }
            else
            {
                New-ServerListFile
                Add-ServerListEntry
            }
        } -Function $module

        $AllCBServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Get All Connection Broker Servers.' -ScriptBlock {
            Get-RDSADComputer -OUName "RDSCB"
        } -Function $module

        $activeRDSDeployment = $false
        
        foreach ($CBServer in $AllCBServers)
        {
            $result_rdsdeployment = Invoke-LabCommand -ComputerName $CBServer -ActivityName "Check on Connection Broker $CBServer if we have a RDSDeployment" -ScriptBlock {
                Get-RDSDeployment
            }

            if ($result_rdsdeployment)
            {
                $activeRDSDeployment = $true
            }
        }
        
        if ($activeRDSDeployment)
        {
            Write-ScreenInfo -Message "We already have a RDS Deployment." -NoNewLine
        }
        else
        {
            $allGatewayServers = @()
            $allGatewayServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all Gateway Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSGW"
            }

            $allSessionHostServers = @()
            $allSessionHostServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all Session Host Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSSH"
            }

            $allSessionBasedDesktopServers = @()
            $allSessionBasedDesktopServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all Session Based Desktop Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSSBD"
            }

            $allWebAccessServers = @()
            $allWebAccessServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all Web Access Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSSWA"
            }

            $AllSessionHostServers = @()

            foreach ($SessionHostServer in $allSessionHostServers)
            {
                $AllSessionHostServers += $SessionHostServer
            }

            foreach ($SessionBasedDesktopServer in $allSessionBasedDesktopServers)
            {
                $AllSessionHostServers += $SessionBasedDesktopServer
            }

            #$va_SessionHostServers = Get-Variable -Name allSessionHostServers
            $va_SessionBasedHostServers = Get-Variable -Name AllSessionHostServers
            $va_WebAccessServers = Get-Variable -Name allWebAccessServers
            $va_ConnectionBrokerServers = Get-Variable -Name AllCBServers

            #TODO: ConnectionBroker Problem. Only One Server can be deployed as connection Broker in the first Step
            Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Create New RDS Deployment' -ScriptBlock {
                New-RDSessionDeployment -ConnectionBroker $args[2] -WebAccessServer $args[1] -SessionHost $args[0] 
            } -Variable $va_SessionBasedHostServers, $va_WebAccessServers, $va_ConnectionBrokerServers

            if ($ConnectionBrokerHighAvailabilty -eq 'Yes')
            {
                #TODO: Is SQL Server in Lab Deployment

                #TODO: Add The DNS Name for the roundrobin
                
                #TODO: Change ComputerName, Count Variable whitch Connection Broker is added
                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Adding 2nd Connection Broker Server.' -ScriptBlock {
                    Add-RDServer -Server CB -Role 'RDS-CONNECTION-BROKER' -ConnectionBroker CBName
                }

                #TODO: Configure HA for Connection Broker
            }

            foreach ($GatewayServer in $allGatewayServers)
            {
                Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Adding {0} as Gateway Server.' -f $GatewayServer) -ScriptBlock {
                    Add-RDServer -Server CB -Role 'RDS-GATEWAY' -ConnectionBroker CBName -GatewayExternalFqdn FQDN
                }
            }
        }        

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Reset ServerManager open at logon' -ScriptBlock {
            Set-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Value "0x01" -Force
        }
    }

    'No'
    {
        Write-Output "It is not an advanced deployment. No action needed."
    }
}