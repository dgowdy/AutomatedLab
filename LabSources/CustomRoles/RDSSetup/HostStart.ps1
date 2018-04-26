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
    $RDSDNSName,

    [Parameter(Mandatory)]
    [String]
    $LabPath
)

Import-Lab -Path $LabPath -NoValidation

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

        Restart-LabVM -ComputerName $rootdcname -Wait
        Wait-LabADReady -ComputerName $rootdcname
                
        
        # Create Scheduled Task to Close ServerManager
        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Create Scheduled Task to gracefully close ServerManager' -ScriptBlock {
            $UserName = $Env:USERNAME
            $Domain = $env:USERDNSDOMAIN
            
            $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-ExecutionPolicy Bypass -Command ""Get-Process -Name ServerManager | Foreach-Object {`$_.CloseMainWindow()}"""
            $Principal = New-ScheduledTaskPrincipal -RunLevel Highest -UserId "$Domain\$UserName"
            $Task = New-ScheduledTask -Action $Action -Principal $Principal
            Register-ScheduledTask -TaskName "KillServerManager" -InputObject $task
        }

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Run Scheduled Task To gracefully close ServerManager' -ScriptBlock {
            Start-ScheduledTask -TaskName 'KillServerManager'
        }

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Add All RDS Servers To Server Manager' -ScriptBlock {
            $return_ServerListPath = Get-ServerListPath

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

        $AllWAServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Get All Connection Broker Servers.' -ScriptBlock {
            Get-RDSADComputer -OUName "RDSWA"
        } -Function $module -PassThru -NoDisplay

        # Add Dns Zone and IP Adresses of all Connection Broker Servers to it. (Round Robin)
        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Creating DNS Zone for RDS deployment' -ScriptBlock {
            
            # Calculate Zone Name
            $dnsZone = $args[0].Substring($args[0].IndexOf('.') + 1)
            $dnsname = $args[0].Substring(0, $args[0].IndexOf('.'))
            
            # Check if DNS Zone exist
            if (Get-DnsServerZone | Where-Object {$_.ZoneName -eq ('{0}' -f $dnsZone)})
            {                
                if (-not (Get-DnsServerResourceRecord -Name $dnsname -ZoneName $dnsZone -ErrorAction SilentlyContinue))
                {
                    for ($i = 0; $i -lt $args[1].Count; $i++)
                    {
                        $IP = $args[1][$i].IPAddress
                        Add-DnsServerResourceRecord -ZoneName $dnsZone -IPv4Address $IP  -A -Name $dnsname
                    } 
                }              
            }
            else
            {
                Add-DnsServerPrimaryZone -Name $dnsZone -ReplicationScope Forest
                
                for ($i = 0; $i -lt $args[1].Count; $i++)
                {
                    $IP = $args[1][$i].IPAddress
                    Add-DnsServerResourceRecord -ZoneName $dnsZone -IPv4Address $IP -A -Name $dnsname
                }
            }

        } -Function $module -ArgumentList $RDSDNSName, $AllWAServers

        Write-ScreenInfo -Message 'Adding the DNS Domain of the RDS deployment to the hosts file.'
        
        if (-not(Get-HostEntry -Section (Get-Lab).Name -HostName $RDSDNSName))
        {
            foreach ($WAServer in $AllWAServers)
            {
                $IP = $WAServer.IPAddress
                $null = Add-HostEntry -Section (Get-Lab).Name -IpAddress $IP -HostName $RDSDNSName
            }
        }
        
        <#$activeRDSDeployment = $false
        
        foreach ($CBServer in $AllCBServers)
        {
            $result_rdsdeployment = Invoke-LabCommand -ComputerName $CBServer -ActivityName "Check on Connection Broker $CBServer if we have a RDSDeployment" -ScriptBlock {
                Get-RDSDeployment
            } -Function $module

            if ($result_rdsdeployment)
            {
                $activeRDSDeployment = $true
            }
        }
        
        if ($activeRDSDeployment)
        {
            Write-ScreenInfo -Message "We already have a RDS Deployment."
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

            $firstwa = $allWebAccessServers | Select-Object -First 1
            $firstcb = $AllCBServers | Select-Object -First 1

            #TODO: ConnectionBroker Problem. Only One Server can be deployed as connection Broker in the first Step
            Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Create New RDS Deployment' -ScriptBlock {
                New-RDSessionDeployment -ConnectionBroker $args[2] -WebAccessServer $args[1] -SessionHost $args[0] 
            } -ArgumentList $AllSessionHostServers, $firstwa, $firstcb

            if ($ConnectionBrokerHighAvailabilty -eq 'Yes')
            {
                #Is SQL Server in Lab Deployment ?
                $ISQLServer = Get-LabVM | Where-Object {$_.Roles -like "SQLServer*"}

                if (-not ($ISQLServer))
                {
                    throw "No SQL Server found in Lab. Please add one."
                }
                else
                {
                    Write-ScreenInfo -Message 'SQL Server Machine was found in Lab Deployment. Continue with deployment.'
                }

                $restcb = $AllCBServers | Select-Object -Skip 1
                $firstcb = $AllCBServers | Select-Object -First 1

                foreach ($CBServer in $restcb)
                {                    
                    $i = 1

                    #TODO: Change ComputerName, Count Variable whitch Connection Broker is added
                    Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Adding $i additional Connection Broker Server." -ScriptBlock {
                        Add-RDServer -Server $args[0] -Role 'RDS-CONNECTION-BROKER' -ConnectionBroker $args[1]
                    } -ArgumentList $CBServer, $firstcb
                }

                #TODO: Configure HA for Connection Broker
            }

            foreach ($GatewayServer in $allGatewayServers)
            {
                Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Adding {0} as Gateway Server.' -f $GatewayServer) -ScriptBlock {
                    Add-RDServer -Server CB -Role 'RDS-GATEWAY' -ConnectionBroker CBName -GatewayExternalFqdn FQDN
                }
            }
        }  #>     

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Delete Scheduled Task KillServerManager' -ScriptBlock {
            Unregister-ScheduledTask -TaskName 'KillServerManager' -Confirm:$false
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