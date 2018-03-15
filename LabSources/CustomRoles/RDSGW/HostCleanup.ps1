$null = Remove-WindowsFeature -Name "RSAT-AD-PowerShell"
Write-Output -InputObject "RSAT-AD-PowerShell was uninstalled sucessfully."