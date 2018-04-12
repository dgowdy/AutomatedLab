param
(
    [String]
    [ValidateSet('Yes', 'No')]
    $IsAdvancedRDSDeployment,

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

        Invoke-LabCommand -ComputerName $rootdcname -ActivityName 'Reset ServerManager open at logon' -ScriptBlock {
            Set-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Value "0x01" -Force
        }
    }

    'No'
    {
        Write-Output "It is not an advanced deployment. No action needed."
    }
}