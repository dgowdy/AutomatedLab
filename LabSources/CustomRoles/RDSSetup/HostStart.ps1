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
    $LabPath,

    [Parameter(Mandatory)]
    [String]
    [ValidateSet('DoNotUse', 'Custom', 'Automatic')]
    $GatewayMode,

    [Parameter(Mandatory = $false)]
    [String]
    [ValidateSet('Password', 'AllowUserToSelectDuringConnection', 'Smartcard')]
    $LogOnMethod,

    [Parameter(Mandatory = $false)]
    [String]
    [ValidateSet('Yes', 'No')]
    $ByPassLocal,

    [Parameter(Mandatory = $false)]
    [String]
    [ValidateSet('Yes', 'No')]
    $UseCachedCredentials,

    [Parameter(Mandatory)]
    [String]
    [ValidateSet('PerDevice', 'PerUser', 'NotConfigured')]
    $LicensingMode
)

Import-Lab -Path $LabPath -NoValidation
$UserName = (Get-Lab).DefaultInstallationCredential.UserName

switch ($IsAdvancedRDSDeployment)
{
    'Yes'
    {
        #region Import SetupHelper Module
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
        #endregion Import SetupHelper Module

        $rootdcname = Get-LabVM -Role RootDC | Select-Object -First 1 -ExpandProperty Name

        #region ServerManager Magic
        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Open Server Manger at Startup' -ScriptBlock {
            Set-ItemProperty -Path 'HKCU:\Software\Microsoft\ServerManager' -Name DoNotOpenServerManagerAtLogon -Value "0x0" -Force
        }

        Restart-LabVM -ComputerName $rootdcname -Wait
        Wait-LabADReady -ComputerName $rootdcname
                
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
        #endregion ServerManager Magic

        # Install RSAT-Tools For the RDS Deployment
        Install-LabWindowsFeature -ComputerName $rootdcname -FeatureName "RSAT-RDS-Tools" -IncludeAllSubFeature -IncludeManagementTools

        #region WA and CB Server Retrival
        $AllWAServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Get All Web Applications Servers.' -ScriptBlock {
            Get-RDSADComputer -OUName "RDSGW"
        } -Function $module -PassThru -NoDisplay

        $AllCBServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Get All Connection Broker Servers.' -ScriptBlock {
            Get-RDSADComputer -OUName "RDSCB"
        } -Function $module -PassThru -NoDisplay
        #endregion WA and CB Server Retrival

        #region DNS Configuration
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

        } -Function $module -ArgumentList $RDSDNSName, $allGatewayServers
        #endregion DNS Configuration

        #region HostsFile
        Write-ScreenInfo -Message 'Adding the DNS Domain of the RDS deployment to the hosts file.'
        
        if (-not(Get-HostEntry -Section (Get-Lab).Name -HostName $RDSDNSName))
        {
            $FirstGW = $allGatewayServers | Select-Object -First 1

            $IP = $FirstGW.IPAddress
            $null = Add-HostEntry -Section (Get-Lab).Name -IpAddress $IP -HostName $RDSDNSName
        }
        #endregion HostsFile

        #region Check for active Deployment
        $activeRDSDeployment = $false
        
        foreach ($CBServer in $AllCBServers)
        {
            $CBServerName = $CBServer.ComputerName

            $result_rdsdeployment = Invoke-LabCommand -ComputerName $CBServerName -ActivityName "Check on Connection Broker $CBServer if we have a RDSDeployment" -ScriptBlock {
                Get-RDSDeployment
            } -Function $module -PassThru -NoDisplay

            if ($result_rdsdeployment)
            {
                $activeRDSDeployment = $true
            }
        }
        #endregion Check for active Deployment

        if ($activeRDSDeployment)
        {
            Write-ScreenInfo -Message "We already have a RDS Deployment."
        }
        else
        {
            #region Server Information
            $allGatewayServers = @()
            $allGatewayServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all Gateway Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSGW"
            } -PassThru -NoDisplay -Function $module

            $allSessionHostServers = @()
            $allSessionHostServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all Session Host Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSSH"
            } -PassThru -NoDisplay -Function $module

            $allSessionBasedDesktopServers = @()
            $allSessionBasedDesktopServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all Session Based Desktop Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSBD"
            } -PassThru -NoDisplay -Function $module

            $allLicenseServers = @()
            $allLicenseServers = Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Getting all License Servers from {0}' -f $rootdcname) -ScriptBlock {
                Get-RDSADComputer -OUName "RDSLIC"
            } -PassThru -NoDisplay -Function $module

            $AllSessionHostServersForDeployment = @()

            foreach ($SessionHostServer in $allSessionHostServers)
            {
                $AllSessionHostServersForDeployment += $SessionHostServer
            }

            foreach ($SessionBasedDesktopServer in $allSessionBasedDesktopServers)
            {
                $AllSessionHostServersForDeployment += $SessionBasedDesktopServer
            }

            $firstwa = $AllWAServers | Select-Object -First 1
            $firstcb = $AllCBServers | Select-Object -First 1
            #endregion Server Information

            #region Create RDS Deployment
            Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Create New RDS Deployment' -ScriptBlock {
                New-RDSessionDeployment -ConnectionBroker $args[2].DNSHostName -WebAccessServer $args[1].DNSHostName -SessionHost $args[0].DNSHostName 
            } -ArgumentList $AllSessionHostServersForDeployment, $firstwa, $firstcb
            #endregion Create RDS Deployment

            #region Configure Web Access Servers
            foreach ($WAServer in $AllWAServers)
            {
                $WebAccessServerName = $WAServer.ComputerName
                Invoke-LabCommand -ComputerName $WebAccessServerName -ActivityName ('Add the external DNSName to the Pages Web Site of Server {0}.' -f $WebAccessServerName) -ScriptBlock {
                    Import-Module WebAdministration

                    $param = @{
                        PSPath = 'MACHINE/WEBROOT/APPHOST/Default Web Site/RDWeb/Pages' 
                        Filter = "appSettings/add[@key='DefaultTSGateway']" 
                        Name   = 'value' 
                        Value  = $args[0]
                    }

                    Set-WebConfigurationProperty @param
                    iisreset
                } -NoDisplay -ArgumentList $RDSDNSName
            }
            #endregion Configure Web Access Servers

            #region Register and Configure GatewayServers
            if ($UseCachedCredentials -eq 'Yes')
            {
                $UseCachedCredentials = $true 
            } 
            else
            {
                $UseCachedCredentials = $false
            }

            if ($ByPassLocal -eq 'Yes')
            {
                $ByPassLocal = $true
            }
            else
            {
                $ByPassLocal = $false             
            }            

            foreach ($GatewayServer in $allGatewayServers)
            {
                $GatewayServerName = $GatewayServer.ComputerName

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Adding {0} as Gateway Server.' -f $GatewayServer.DNSHostName) -ScriptBlock {
                    $param = @{
                        Server              = $args[0].DNSHostName 
                        Role                = 'RDS-GATEWAY' 
                        ConnectionBroker    = $args[1].DNSHostName 
                        GatewayExternalFqdn = $args[2] 
                        ErrorAction         = 'SilentlyContinue'
                    }
                    
                    Add-RDServer @param
                } -ArgumentList $GatewayServer, $firstcb, $RDSDNSName

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Configuring the Gateway Server {0}.' -f $GatewayServer.DNSHostName) -ScriptBlock {
                    $param = @{
                        GatewayMode          = $args[2] 
                        LogonMethod          = $args[1] 
                        UseCachedCredentials = $args[3] 
                        BypassLocal          = $args[4]
                        GatewayExternalFqdn  = $args[5] 
                        ConnectionBroker     = $args[0].DNSHostName
                        Force                = $true
                    }
                    
                    Set-RDDeploymentGatewayConfiguration @param
                } -ArgumentList $firstcb, $LogOnMethod, $GatewayMode, $UseCachedCredentials, $ByPassLocal, $RDSDNSName

                Invoke-LabCommand -ComputerName $GatewayServerName -ActivityName ('Adding {0} to the GatewayFarm' -f $GatewayServerName) -ScriptBlock {
                    Import-Module RemoteDesktopServices
                    Set-Location RDS:\GatewayServer\GatewayFarm\Servers\
                    New-Item -Name $($args[0].DNSHostName)
                } -ArgumentList $GatewayServer
            }
            #endregion Register and Configure GatewayServers

            #region Register and Configure LicenseServers
            foreach ($LicenseServer in $allLicenseServers)
            {
                Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Adding {0} as License Server.' -f $LicenseServer.DNSHostName) -ScriptBlock {
                    Add-RDServer -Server $args[0].DNSHostName -Role 'RDS-LICENSING' -ConnectionBroker $args[1].DNSHostName -ErrorAction SilentlyContinue
                } -ArgumentList $LicenseServer, $firstcb

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName ('Configure License Mode to {0}' -f $LicensingMode) -ScriptBlock {
                    Set-RDLicenseConfiguration -Mode $args[0] -Force -ConnectionBroker $args[1].DNSHostName
                } -ArgumentList $LicensingMode, $firstcb
            }
            #endregion Register and Configure LicenseServers

            #region Certificates
            $RootCA = Get-LabIssuingCA | Select-Object -First 1

            If ($RootCA)
            {
                $param = @{
                    Subject      = "CN=$RDSDNSName" 
                    SAN          = $RDSDNSName 
                    OnlineCA     = $RootCA 
                    TemplateName = "WebServer" 
                    ComputerName = $rootdcname 
                    PassThru     = $true
                }

                $cert = Request-LabCertificate @param
                $mypwd = ConvertTo-SecureString -String "Passw0rd!" -Force -AsPlainText

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Export the certificate to C:\Tools' -ScriptBlock {                    
                    Get-ChildItem -Path Cert:\LocalMachine\My\$($args[0].Thumbprint) | Export-PfxCertificate -FilePath C:\Tools\RDS.pfx -Password $args[1]
                } -ArgumentList $cert, $mypwd

                # Add Certificates to each RDS Role
                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Adding the exported certificate to the RDGateway Role' -ScriptBlock {
                    Set-RDCertificate -Role RDGateway -ImportPath C:\Tools\RDS.pfx -Password $args[0] -ConnectionBroker $args[1].DNSHostName -Force
                } -ArgumentList $mypwd, $firstcb

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Adding the exported certificate to the RDWebAccess Role' -ScriptBlock {
                    Set-RDCertificate -Role RDWebAccess -ImportPath C:\Tools\RDS.pfx -Password $args[0] -ConnectionBroker $args[1].DNSHostName -Force
                } -ArgumentList $mypwd, $firstcb

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Adding the exported certificate to the RDRedirector Role' -ScriptBlock {
                    Set-RDCertificate -Role RDRedirector -ImportPath C:\Tools\RDS.pfx -Password $args[0] -ConnectionBroker $args[1].DNSHostName -Force
                } -ArgumentList $mypwd, $firstcb

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Adding the exported certificate to the RDPublishing Role' -ScriptBlock {
                    Set-RDCertificate -Role RDPublishing -ImportPath C:\Tools\RDS.pfx -Password $args[0] -ConnectionBroker $args[1].DNSHostName -Force
                } -ArgumentList $mypwd, $firstcb

                Write-ScreenInfo -Message "Adding RootCA Certificate to local Computer."
                $ALCertFolder = Join-Path -Path $LabPath -ChildPath 'Certificates'
                $ALCertName = Join-Path -Path $ALCertFolder -ChildPath "$($RootCA.Name).crt"
                Import-Certificate -FilePath $ALCertName -CertStoreLocation Cert:\LocalMachine\Root
            }
            else
            {
                Write-ScreenInfo -Message 'No Lab RootCA found. No certificate will be used for the RDS Deployment.'
            } 
            #endregion Certificates

            #region Create Domain Local Group for all RDS users and add all groups to DL_RDSUsers
            Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Create Domain Local Group for all RDS Users" -ScriptBlock {
                Import-Module ActiveDirectory
                $DomainInfo = Get-DomainInformation
                $DomainDN = $DomainInfo.distinguishedName
                $OuNameDN = [String]::Concat("OU=RDSGroups,", "OU=RDS,", $DomainDN)
                New-ADGroup -Name "DL_RDSUsers" -SamAccountName "DL_RDSUsers" -GroupCategory Security -GroupScope DomainLocal -DisplayName "DL_RDSUsers" -Path $OuNameDN
            } -Function $module -NoDisplay

            Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Create Global Group where to put the users in." -ScriptBlock {
                Import-Module ActiveDirectory
                $DomainInfo = Get-DomainInformation
                $DomainDN = $DomainInfo.distinguishedName
                $OuNameDN = [String]::Concat("OU=RDSGroups,", "OU=RDS,", $DomainDN)
                New-ADGroup -Name "G_ALUsers" -SamAccountName "G_ALUsers" -GroupCategory Security -GroupScope Global -DisplayName "G_ALUsers" -Path $OuNameDN
            } -Function $module -NoDisplay

            Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Add DefaultUser to G_ALUsers." -ScriptBlock {
                Import-Module ActiveDirectory
                Add-ADGroupMember -Members $args[0] -Identity 'G_ALUsers'
            } -ArgumentList $UserName -NoDisplay

            Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Add G_ALUsers to DL_RDSUsers." -ScriptBlock {
                Import-Module ActiveDirectory
                Add-ADGroupMember -Members 'G_ALUsers' -Identity 'DL_RDSUsers'
            } -NoDisplay

            Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Add DL_SBD to DL_RDSUsers." -ScriptBlock {
                Import-Module ActiveDirectory
                Add-ADGroupMember -Members 'DL_SBD' -Identity 'DL_RDSUsers'
            } -NoDisplay
            #endregion Create Domain Local Group for all RDS users and add all groups to DL_RDSUsers

            #region Add DL_RDSUsers to the Connection Authorization Policy
            foreach ($GatewayServer in $allGatewayServers)
            {
                $GatewayServerName = $GatewayServer.ComputerName

                Invoke-LabCommand -ComputerName $GatewayServerName -ActivityName "Adding the group DL_RDSUsers to the Connection Authorization Policy." -ScriptBlock {
                    Import-Module RemoteDesktopServices
                    Import-Module ActiveDirectory
                    $DomainName = (Get-ADDomain).Name
                    Set-Location -Path RDS:\GatewayServer\CAP\RDG_CAP_AllUsers
                    New-Item -Name "DL_RDSUsers@$DomainName" -Path .\UserGroups
                    Set-Location -Path RDS:\GatewayServer\CAP\RDG_CAP_AllUsers\UserGroups
                    Remove-Item "Domain Users@$DomainName" -Force
                }
            }
            #endregion Add DL_RDSUsers to the Connection Authorization Policy

            #region Clean Resource Authorization Policies. Create a Own. Add the Group to the newly created Policy. Network Resource -> Allow users to connect to any network resource
            foreach ($GatewayServer in $allGatewayServers)
            {
                $GatewayServerName = $GatewayServer.ComputerName

                Invoke-LabCommand -ComputerName $GatewayServerName -ActivityName "Remove all the Resource Authorization Policies that exists." -ScriptBlock {
                    Import-Module RemoteDesktopServices
                    Set-Location -Path RDS:\GatewayServer\RAP
                    $AllRAP = Get-ChildItem
                    Remove-Item $AllRAP.Name -Force -Recurse
                }
            }

            foreach ($GatewayServer in $allGatewayServers)
            {
                $GatewayServerName = $GatewayServer.ComputerName

                Invoke-LabCommand -ComputerName $GatewayServerName -ActivityName "Add Resource Authorization Policy." -ScriptBlock {
                    Import-Module RemoteDesktopServices
                    Import-Module ActiveDirectory
                    $DomainName = (Get-ADDomain).Name
                    Set-Location -Path RDS:\GatewayServer\RAP
                    New-Item -Name RDG_AL -UserGroups "DL_RDSUsers@$DomainName" -ComputerGroupType 2
                }
            }
            #endregion Clean Resource Authorization Policies. Create a Own. Add the Group to the newly created Policy. Network Resource -> Allow users to connect to any network resource

            #region TODO
            <#if ($ConnectionBrokerHighAvailabilty -eq 'Yes')
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

                    Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Adding $i additional Connection Broker Server." -ScriptBlock {
                        Add-RDServer -Server $args[0] -Role 'RDS-CONNECTION-BROKER' -ConnectionBroker $args[1]
                    } -ArgumentList $CBServer, $firstcb
                }

                #TODO: Configure HA for Connection Broker
            }#>
            #endregion TODO            
        }     

        #region Remove ServerManager from Autostart
        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Delete Scheduled Task KillServerManager' -ScriptBlock {
            Unregister-ScheduledTask -TaskName 'KillServerManager' -Confirm:$false
        }

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Reset ServerManager open at logon' -ScriptBlock {
            Set-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Value "0x01" -Force
        }
        #endregion Remove ServerManager from Autostart
    }

    'No'
    {
        Write-Output "It is not an advanced deployment. No action needed."
    }
}