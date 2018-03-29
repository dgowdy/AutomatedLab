param
(
    [String]
    [ValidateSet('Yes', 'No')]
    $IsAdvancedRDSDeployment,
    
    [Parameter(Mandatory = $false)]
    [String]
    $RDSSHComputerName,

    [Parameter(Mandatory)]
    [String]
    [ValidateSet('Yes', 'No')]
    $IsSessionBasedDesktop,

    [Parameter(Mandatory)]
    [String]
    $LabPath
)

Import-Lab -Path $LabPath

switch ($IsAdvancedRDSDeployment)
{
    'Yes'
    {
        Invoke-LabCommand -ComputerName $RDSSHComputerName -ActivityName 'Installing RSAT-AD-PowerShell' -ScriptBlock {
            Install-WindowsFeature -Name 'RSAT-AD-PowerShell'
        }

        Invoke-LabCommand -ComputerName $RDSSHComputerName -ActivityName "Move Computer to the right OU in AD" -ScriptBlock {
            Import-Module ActiveDirectory
            $dn = (Get-ADDomain).DistinguishedName
            $computerName = $env:COMPUTERNAME
            $pc_path = (Get-ADComputer -Identity $computerName).DistinguishedName
            
            if ($args[0] -eq 'Yes')
            {
                $targetpath = [String]::Concat("OU=RDSBD,OU=RDS,", $dn)
            }
            else
            {
                $targetpath = [String]::Concat("OU=RDSSH,OU=RDS,", $dn)
            }
                        
            $domainName = (Get-ADDomain).DNSRoot
            $domaincontroller = (Get-ADDomainController -DomainName $domainName -Discover).HostName | Select-Object -First 1

            if ($dn -eq $targetpath)
            {
                Write-Output "Computer $computerName is already in the right OU ($targetpath)."
            }
            else
            {
                Write-Output "Moving Computer $computername to the path $targetpath."
                Move-ADObject -Identity $pc_path -TargetPath $targetpath -Server $domaincontroller
            }
        } -ArgumentList $IsSessionBasedDesktop

        $isInstalled_CBRole = (Get-LabWindowsFeature -FeatureName "RDS-RD-Server" -ComputerName $RDSSHComputerName).State

        if ($isInstalled_CBRole -eq "Installed") 
        {
            Write-Output -Message "RDS Session Host Role is already installed."
        }
        else 
        {                    
            Write-Verbose -Message "Installing Feature for RDS Session Host"
                    
            Invoke-LabCommand -ComputerName $RDSSHComputerName -ActivityName "Installing RDS Session Host Role on $RDSSHComputerName" -ScriptBlock {
                Install-WindowsFeature -Name "RDS-RD-Server" -IncludeAllSubFeature -IncludeManagementTools -Restart
            }

            Wait-LabVMRestart -ComputerName $RDSSHComputerName -DoNotUseCredSsp -ProgressIndicator 30 -TimeoutInMinutes 5
        }
    }

    'No'
    {
        Write-Output "It is not an advanced deployment. No action needed."
    }
}