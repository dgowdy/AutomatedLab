param
(
    [String]
    [ValidateSet('Yes', 'No')]
    $IsAdvancedRDSDeployment,
    
    [Parameter(Mandatory)]
    [String]
    [ValidateSet('Yes', 'No')]
    $ConnectionBrokerHighAvailabilty,

    [Parameter(Mandatory)]
    [String]
    $RDSStructureName,

    [Parameter(Mandatory = $false)]
    [String]
    [ValidateSet('Yes', 'No')]
    $IsSessionBasedDesktop,

    [Parameter(Mandatory = $false)]
    [String]
    $RDSCBComputerName,

    [Parameter(Mandatory)]
    [String]
    $LabPath,

    [Parameter(Mandatory)]
    [String[]]
    [ValidateSet('RDSAD', 'RDSCB', 'RDSGW', 'RDSLIC', 'RDSSH', 'RDSWA')]
    $Roles
)

Import-Lab -Path $LabPath

switch ($IsAdvancedRDSDeployment)
{
    'Yes'
    {
        switch ($Roles)
        {
            'RDSAD'
            {                
                if (Get-Module -Name InstallRDSAD -ErrorAction SilentlyContinue)
                {
                    Remove-Module InstallRDSAD
                    Import-Module $PSScriptRoot\InstallRDSAD.psm1
                }
                else
                {
                    Import-Module $PSScriptRoot\InstallRDSAD.psm1
                }
                
                $module = Get-Command -Module InstallRDSAD
                $rootdcname = Get-LabVM -Role RootDC | Select-Object -First 1 -ExpandProperty Name

                Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Creating RDS ActiveDirectory Structure' -ScriptBlock {
                    New-ADStructure -ConnectionBrokerHighAvailabilty $args[0] -RDSStructureName $args[1]
                } -Function $module -ArgumentList $ConnectionBrokerHighAvailabilty, $RDSStructureName                
            }

            'RDSCB'
            {   
                switch ($ConnectionBrokerHighAvailabilty)
                {
                    'Yes'
                    {
                        Invoke-LabCommand -ComputerName $RDSCBComputerName -ActivityName 'Installing RSAT-AD-PowerShell' -ScriptBlock {
                            Install-WindowsFeature -Name 'RSAT-AD-PowerShell'
                        }

                        $rootdcname = Get-LabVM -Role RootDC | Select-Object -First 1 -ExpandProperty Name

                        Invoke-LabCommand -ComputerName $RDSCBComputerName -ActivityName "Move Computer to the right OU in AD" -ScriptBlock {
                            Import-Module ActiveDirectory
                            $dn = (Get-ADDomain).DistinguishedName
                            $computerName = $env:COMPUTERNAME
                            $pc_path = (Get-ADComputer -Identity $computerName).DistinguishedName
                            $targetpath_partone = ("OU=RDSCB,OU={0}," -f $args[0])
                            $targetpath = [String]::Concat("$targetpath_partone", $dn)

                            if ($pc_path.Contains($args[0]))
                            {
                                Write-Output "Computer $computerName is already in the right OU ($targetpath)."
                            }
                            else
                            {
                                Write-Output "Moving Computer $computername to the path $targetpath."
                                Move-ADObject -Identity $pc_path -TargetPath $targetpath -Server $args[1]
                            }
                        } -Variable $RDSStructureName, $rootdcname

                        $isInstalled_CBRole = (Get-LabWindowsFeature -FeatureName "RDS-Connection-Broker" -ComputerName $RDSCBComputerName).State

                        if ($isInstalled_CBRole -eq "Installed") 
                        {
                            Write-ScreenInfo -Message "RDS Connection Broker Role is already installed."
                        }
                        else 
                        {                    
                            Write-Verbose -Message "Installing Feature for RDS Connection Broker"
                    
                            Invoke-LabCommand -ComputerName $RDSCBComputerName -ActivityName "Installing Connection Broker Role on $RDSCBComputerName" -ScriptBlock {
                                Install-WindowsFeature -Name "RDS-Connection-Broker" -IncludeAllSubFeature -IncludeManagementTools
                            }
                        }

                        Invoke-LabCommand -ComputerName $rootdcname -ActivityName "Add ConnectionBroker $RDSCBComputerName to group G_ConnectionBrokerServers" -ScriptBlock {
                            Import-Module ActiveDirectory
                            Add-ADGroupMember -Identity "G_ConnectionBrokerServers" -Members $RDSCBComputerName
                        }
                    }
                    
                    'No'
                    {
                        Invoke-LabCommand -ComputerName $RDSCBComputerName -ActivityName 'Installing RSAT-AD-PowerShell' -ScriptBlock {
                            Install-WindowsFeature -Name 'RSAT-AD-PowerShell'
                        }

                        $rootdcname = Get-LabVM -Role RootDC | Select-Object -First 1 -ExpandProperty Name

                        Invoke-LabCommand -ComputerName $RDSCBComputerName -ActivityName "Move Computer to the right OU in AD" -ScriptBlock {
                            Import-Module ActiveDirectory
                            $dn = (Get-ADDomain).DistinguishedName
                            $computerName = $env:COMPUTERNAME
                            $pc_path = (Get-ADComputer -Identity $computerName).DistinguishedName
                            $targetpath_partone = ("OU=RDSCB,OU={0}," -f $args[0])
                            $targetpath = [String]::Concat("$targetpath_partone", $dn)

                            if ($pc_path.Contains($args[0]))
                            {
                                Write-Output "Computer $computerName is already in the right OU ($targetpath)."
                            }
                            else
                            {
                                Write-Output "Moving Computer $computername to the path $targetpath."
                                Move-ADObject -Identity $pc_path -TargetPath $targetpath -Server $args[1]
                            }
                        } -Variable $RDSStructureName, $rootdcname

                        $isInstalled_CBRole = (Get-LabWindowsFeature -FeatureName "RDS-Connection-Broker" -ComputerName $RDSCBComputerName).State

                        if ($isInstalled_CBRole -eq "Installed") 
                        {
                            Write-ScreenInfo -Message "RDS Connection Broker Role is already installed."
                        }
                        else 
                        {                    
                            Write-Verbose -Message "Installing Feature for RDS Connection Broker"
                    
                            Invoke-LabCommand -ComputerName $RDSCBComputerName -ActivityName "Installing Connection Broker Role on $RDSCBComputerName" -ScriptBlock {
                                Install-WindowsFeature -Name "RDS-Connection-Broker" -IncludeAllSubFeature -IncludeManagementTools
                            }
                        }
                    }
                }
                
            }

            'RDSGW'
            {

            }

            'RDSLIC'
            {

            }

            'RDSSH'
            {

            }

            'RDSWA'
            {

            }
        }
    }

    'No'
    {

    }
}
