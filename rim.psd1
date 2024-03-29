<# PowerShell Remote Installation Module for Microsoft Deployment Toolkit

Copyright 2018 Joël Ammann

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

@{
    RootModule = 'rim.psm1'
    ModuleVersion = '0.19'
    GUID = '7f1a5cbd-5ba5-4319-88d8-c3b936d30cd6'
    Author = 'Joël Ammann'
    CompanyName = 'simplywing.ch'
    Copyright = '(c) 2018 Joël Ammann'
    Description = 'PowerShell Remote Installation Module for Microsoft Deployment Toolkit'
    FunctionsToExport = @('Set-MDTDeploymentShare', 'Get-MdtDeploymentShare', 'Get-MdtApplications', 'Install-MdtApplications')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @('gmdta', 'imdta')
    PrivateData = @{
        PSData = @{
            LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri = 'http://simplywing.ch/mdtrim'

        } 

    }
    HelpInfoURI = 'http://simplywing.ch/mdtrim'
}
