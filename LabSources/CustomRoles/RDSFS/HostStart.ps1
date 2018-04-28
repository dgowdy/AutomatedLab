param
(
    [String]
    [ValidateSet('Yes', 'No')]
    $IsAdvancedRDSDeployment,
    
    [Parameter(Mandatory)]
    [String]
    $LabPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'RoamingProfile')]
    [ValidateSet('Yes', 'No')]
    [String]
    $UseRoamingProfiles,

    [Parameter(Mandatory = $false, ParameterSetName = 'RoamingProfile')]
    [String]
    $RoamingProfilePath,

    [Parameter(Mandatory = $false, ParameterSetName = 'UserProfileDisks')]
    [ValidateSet('Yes', 'No')]
    [String]
    $UseUserProfileDisks,

    [Parameter(Mandatory = $false, ParameterSetName = 'UserProfileDisks')]
    [String]
    $UserProfileDiskPath
)

Import-Lab -Path $LabPath
$FileserverName = Get-LabVM -Role FileServer

switch ($IsAdvancedRDSDeployment)
{
    'Yes'
    {
        Invoke-LabCommand -ComputerName $FileserverName -ActivityName 'Installing RSAT-AD-PowerShell' -ScriptBlock {
            Install-WindowsFeature -Name 'RSAT-AD-PowerShell'
        }

        Invoke-LabCommand -ComputerName $FileserverName -ActivityName "Move Computer to the right OU in AD" -ScriptBlock {
            Import-Module ActiveDirectory
            $dn = (Get-ADDomain).DistinguishedName
            $computerName = $env:COMPUTERNAME
            $pc_path = (Get-ADComputer -Identity $computerName).DistinguishedName
            
            $targetpath_partone = ("OU=RDSFS,OU=RDS,")
            $targetpath = [String]::Concat("$targetpath_partone", $dn)

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
        }

        if ($UseRoamingProfiles -eq 'Yes')
        {
            if ($PSBoundParameters.ContainsKey('RoamingProfilePath'))
            {
                Invoke-LabCommand -ComputerName $FileserverName -ActivityName 'Create Roaming Profile Path' -ScriptBlock {
                    New-Item -Path $args[0] -ItemType Directory -Force
                } -ArgumentList $RoamingProfilePath
                
                Invoke-LabCommand -ComputerName $FileserverName -ActivityName 'Share Roaming Profile Path to everyone' -ScriptBlock {
                    New-SmbShare -Path $args[0] -Name "RoamingProfiles$" -FullAccess Everyone -Description 'Roaming Profile Path for RDS deployment.'
                } -ArgumentList $RoamingProfilePath
            }
        }
        
        if ($UseUserProfileDisks -eq 'Yes')
        {
            if ($PSBoundParameters.ContainsKey('UserProfileDiskPath'))
            {
                Invoke-LabCommand -ComputerName $FileserverName -ActivityName 'Create User Profile Disk Path' -ScriptBlock {
                    New-Item -Path $args[0] -ItemType Directory -Force
                } -ArgumentList $UserProfileDiskPath
                
                Invoke-LabCommand -ComputerName $FileserverName -ActivityName 'Share User Profile Disk Path to everyone' -ScriptBlock {
                    New-SmbShare -Path $args[0] -Name "UserProfileDisks$" -FullAccess Everyone -Description 'User Profile Disk Path for RDS deployment.'
                } -ArgumentList $UserProfileDiskPath
            }
        }

        if (($UseRoamingProfiles -eq 'No') -and ($UseUserProfileDisks -eq 'No'))
        {
            Write-Error -Message 'No Profile method selected. Select UseRoamingProfiles or UseUserProfileDisks and specify the appropiate path.'
        }
    }

    'No'
    {
        Write-Output "It is not an advanced deployment. No action needed."
    }
}