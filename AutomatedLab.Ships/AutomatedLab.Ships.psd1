﻿@{
    RootModule             = 'AutomatedLab.Ships.psm1'
    ModuleVersion          = '1.0'
    GUID                   = 'fc08e0e1-d274-41a3-afdd-09247e497c08'
    Author                 = 'Raimund Andree, Per Pedersen, Jan-Hendrik Peters'    
    CompanyName            = 'AutomatedLab Team'
    Description            = 'The SHiPS module to mount a lab drive containing all lab data'
    PowerShellVersion      = '5.0'    
    DotNetFrameworkVersion = '4.0'    
    CLRVersion             = '4.0'
    RequiredModules        = @('SHiPS')
    ModuleList             = @('AutomatedLab.Ships')
    FileList               = @('AutomatedLab.Ships.psm1', 'AutomatedLab.Ships.psd1')
}
