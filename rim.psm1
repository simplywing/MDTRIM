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

[single]$Version = 0.19

#useful Aliases
Set-Alias -Name gmdta -Value Get-MdtApplications
Set-Alias -Name imdta -Value Install-MdtApplications

function log
{
    Param
    (
        #Text which should be logged
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=0)]
        [string]$msg,
        [switch]$err,
        [switch]$warning,
        [switch]$info,
        [switch]$success,
        [switch]$verb
    )
    $time = Get-Date -Format HH:mm:ss
    if($success)
    {
        Write-Host "[+"$time"] "$msg -ForegroundColor Green
    }
    elseif($warning)
    {
        Write-Host "[+"$time"] "$msg -ForegroundColor Yellow
    }
    elseif($info)
    {
        Write-Host "[+"$time"] "$msg -ForegroundColor Cyan
    }
    elseif($err)
    {
        Write-Host "[-"$time"] "$msg -ForegroundColor Red
    }
    elseif($verb) 
    {
        if($env:verbose){Write-Host "[+"$time"] "$msg}
    }
    else
    {
        Write-Host "[+"$time"] "$msg
    }
}

<#
.Synopsis
   Defines the default DeploymentShare for the current user.
.DESCRIPTION
   The configuration will be stored under %appdata%\mdtps\ds.conf
.EXAMPLE
   Set-MdtDeploymentShare \\VWDS.lab.local\MDT_DEPLOY$
.EXAMPLE
   Set-MdtDeploymentShare -DeploymentShare "\\VWDS.lab.local\MDT DEPLOY$"
#>
function Set-MdtDeploymentShare
{
    [CmdletBinding()]
    [Alias()]    
    Param
    (
        # Deployment Share
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$DeploymentShare
    )

    #update
    try{$uj = Get-Job -Name "MDTRIM-Update" -ErrorAction Stop; if($uj.state -eq "Completed"){Receive-Job $uj; Remove-Job $uj}}catch{}    
    
    $configurationFile = $env:APPDATA + "\mdtps\ds.conf"

    if(Test-Path $configurationFile)
    {
        $prevSetting = Get-Content $configurationFile
        log "Configuration File already exists, overwriting..."
        try
        {
            Set-Content -Value $DeploymentShare -Path $configurationFile -Force -Encoding String -ErrorAction Stop | log -verb
            log "Configuration updated." -success
        }
        catch
        {   
            log "Error while accessing the configuration file" -err
            log $_.Exception.Message -err
        }
    }
    else
    {
        try
        {
            New-Item -Value $DeploymentShare -Path $configurationFile -Force -ItemType File -ErrorAction Stop | log -verb
            log "Configuration set." -success
        }
        catch
        {
            log "Error while creating the configuration file" -err
            log $_.Exception.Message -err
        }
    }  
}

<#
.Synopsis
   Returns the default DeploymentShare for the current user.
.DESCRIPTION
   The configuration is taken from %appdata%\mdtps\ds.ini
.EXAMPLE
   Get-MdtDeploymentShare | Test-Path
#>
function Get-MdtDeploymentShare
{
    [CmdletBinding()]
    [Alias()]
    $configurationFile = $env:APPDATA + "\mdtps\ds.conf"

    #update
    try{$uj = Get-Job -Name "MDTRIM-Update" -ErrorAction Stop; if($uj.state -eq "Completed"){Receive-Job $uj; Remove-Job $uj}}catch{}

    
    if(Test-Path $configurationFile)
    {
        return Get-Content $configurationFile
    }
    else
    {
        log "Configuration file missing. Use Set-MdtDeploymentShare to define the default Deployment Share" -err
        break
    }  
}

<#
.Synopsis
   Returns available applications from a Deployment Share
.DESCRIPTION
   Returns all available applications which are imported into MDT. By default, the Deployment Share configured with Set-MdtDeploymentShare is taken to harvest application information
.EXAMPLE
   Get-MdtApplications
.EXAMPLE
   Get-MdtApplications | Sort-Object ApplicationName | ft
.EXAMPLE
   Get-MdtApplications -DeploymentShare \\vwds.lab.local\MDT_DEPLOY$
#>
function Get-MdtApplications
{
    [CmdletBinding()]
    Param
    (
        # Deployment Share UNC path
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$DeploymentShare
    )

    #update
    try{$uj = Get-Job -Name "MDTRIM-Update" -ErrorAction Stop; if($uj.state -eq "Completed"){Receive-Job $uj; Remove-Job $uj}}catch{}

    if(!$DeploymentShare){
        $DeploymentShare = Get-MdtDeploymentShare
        if(!$DeploymentShare) 
        {
            return $false
        }
    }
    
    try
    {
        [xml]$applicationXml = Get-Content -Path "$deploymentShare\Control\Applications.xml" -ErrorAction Stop
    }
    catch
    {
        log "Error while accessing the Deployment Share." -err
        log $_.Exception.Message -err
    }
    
    $output = new-object system.collections.arraylist
    $i = 0;
    foreach($item in $applicationXml.applications.application)
    {
        if(!$item.WorkingDirectory)
        {
            #application Bundle
            $installerSource = ""
        }
        elseif($item.WorkingDirectory.Substring(0,1) -like ".")
        {
            #Installer resides on deployment Share
            $installerSource = $deploymentShare+$item.WorkingDirectory.Remove(0,1)
        }
        else
        {
            #Installer is elsewhere on the Network
            $installerSource = $item.WorkingDirectory
        }

        $t = New-Object psobject -Property ([ordered]@{
            Index           = $i
            ApplicationName = $item.Name
            Publisher       = $item.Publisher
            Version         = $item.Version
            Source          = $installerSource
            CommandLine     = $item.CommandLine
            guid            = $item.guid
            Dependency      = $item.Dependency
        })
        $output.Add($t) | Out-Null
        $i++
    }
    return $output
}

<#
.Synopsis
   Installs Applications from MDT on remote computers.
.DESCRIPTION
   Installs Applications from MDT on a remote computer. PSRemoting, and C$ administrative share must be available. Install-MdtApplications follows application dependencies.
.EXAMPLE
   Install-MdtApplications -ComputerName PC1 -Applications 2
.EXAMPLE
   Install-MdtApplications PC1, PC2 5, 6
.EXAMPLE
   Install-MdtApplications PC1, PC2 2, 5, 6 -Concurrent
.EXAMPLE
   Install-MdtApplications PC1, PC2 2, 5, 6 -Concurrent -Shutdown
.EXAMPLE
   ,(Get-ADComputer -Filter * | Select @{label='ComputerName';expression={$_.DNSHostName}}) | Install-MdtApplications -Applications 2, 5, 6 -Concurrent -Shutdown
#>
function Install-MdtApplications
{
    [CmdletBinding()]
    Param
    (
        # Target computer names
        [alias('TargetComputers')]
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    Position=0)]
        [string[]]$ComputerName,

        # list of application indexes to install (Get-MdtApplications)
        [Parameter(Mandatory=$true,
                    Position=1)]
        [int[]]$Applications,

        # specify a different deployment share
        [Parameter(Mandatory=$false,
                    Position=2)]
        [string]$DeploymentShare,

        # specify if computers should be processed concurrently
        [Parameter(Mandatory=$false,
                    Position=3)]
        [switch]$Concurrent,

        # reboot target computer after installation has finished
        [Parameter(Mandatory=$false,
                   Position=4)]
        [switch]$Reboot,

        # shutdown target computers after installation has finished
        [Parameter(Mandatory=$false,
                   Position=5)]
        [switch]$Shutdown
    )

    #update
    try{$uj = Get-Job -Name "MDTRIM-Update" -ErrorAction Stop; if($uj.state -eq "Completed"){Receive-Job $uj; Remove-Job $uj}}catch{}
    
    $func = {
        #re-include log function because dot-referencing inside scriptblocks does not work
        function log
        {
            Param
            (
                #Text which should be logged
                [Parameter(Mandatory=$true,
                            ValueFromPipeline=$true,
                            Position=0)]
                [string]$msg,
                [switch]$err,
                [switch]$warning,
                [switch]$info,
                [switch]$success,
                [switch]$verb
            )
            $time = Get-Date -Format HH:mm:ss
            if($success)
            {
                Write-Host "[+"$time"] "$msg -ForegroundColor Green
            }
            elseif($warning)
            {
                Write-Host "[+"$time"] "$msg -ForegroundColor Yellow
            }
            elseif($info)
            {
                Write-Host "[+"$time"] "$msg -ForegroundColor Cyan
            }
            elseif($err)
            {
                Write-Host "[-"$time"] "$msg -ForegroundColor Red
            }
            elseif($verb) 
            {
                if($env:verbose){Write-Host "[+"$time"] "$msg}
            }
            else
            {
                Write-Host "[+"$time"] "$msg
            }
        }

        function doInstall
        {
            Param
            (
                [Parameter(Mandatory=$true,
                           ValueFromPipeline=$true,
                           Position=0)]
                [string]$applicationName,

                [Parameter(Mandatory=$true,
                           Position=1)]
                [string]$installerSource,

                [Parameter(Mandatory=$true,
                           Position=2)]
                [string]$computer,

                [Parameter(Mandatory=$true,
                           Position=3)]
                [string]$applicationCommandLine
            )

            #Remove unsupportet Chars from Application Name to create working directory
            $escapedApplicationName = $applicationName -replace '[\s:\\\./<>*?|\"]', "_"
            $workingDirectory       = "C:\users\public\downloads\rim\$escapedApplicationName\"
            $installerDestination   = "\\$computer\c$\users\public\downloads\rim\$escapedApplicationName"

            log "Uploading files for $applicationName..."
            log "Source: $installerSource" -verb 
            log "Dest: $installerDestination" -verb
            $roboLog = Robocopy.exe $installerSource $installerDestination /MIR | out-null
            switch ($LASTEXITCODE)
            {
                0  {log "No errors occurred, and no copying was done. The source and destination directory trees are completely synchronized."; break}
                1  {log "One or more files were copied successfully (that is, new files have arrived)."; break}
                2  {log "Some Extra files or directories were detected. No files were copied"; break}
                3  {log "Some files were copied. Additional files were present. No failure was encountered."; break}
                4  {log "Some Mismatched files or directories were detected."; break}
                5  {log "Some files were copied. Some files were mismatched. No failure was encountered."; break}
                6  {log "Additional files and mismatched files exist. No files were copied and no failures were encountered. This means that the files already exist in the destination directory"; break}
                7  {log "Files were copied, a file mismatch was present, and additional files were present."; break}
                8  {log "Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded)." -err; break}
                16 {log "Serious error. Robocopy did not copy any files. Either a usage error or an error due to insufficient access privileges on the source or destination directories." -err; break}
            }

            if(!(Test-Path $installerDestination)){
                break
            }

            ### Installing Application ###
            try
            {
                log "Working Directory: $workingDirectory" -verb
                log "Executing: $applicationCommandLine"
                if($env:verbose)
                {
                    Invoke-Command -ComputerName $computer `
                    -ScriptBlock {$a = $args[0]; $b = $args[1]; Set-Location -Path "$a"; cmd /c "$b"; return "Exit-Code: "+$LastExitCode} `
                    -ArgumentList $workingDirectory, $applicationCommandLine  -ErrorAction Stop
                }
                else
                {
                    $returnCode = Invoke-Command -ComputerName $computer `
                    -ScriptBlock {$a = $args[0]; $b = $args[1]; Set-Location -Path "$a"; cmd /c "$b" | Out-Null; return $LastExitCode} `
                    -ArgumentList $workingDirectory, $applicationCommandLine  -ErrorAction Stop

                    $validExitCodes = 0, 1641, 3010
                    log "Valid Exit-Codes are: $validExitCodes" -verb
                    if(!$validExitCodes.contains($returnCode))
                    {
                        log "Execution likely has failed, exit-code was: $returnCode" -warning
                    }
                    else
                    {
                        log "$applicationName exit-code: $returnCode"
                    }
                }
            }
            catch
            {
                log "$applicationName could not complete on $computer." -err
                log $_.Exception.Message -err
            }
        }

        function installDependency
        {
            Param
            (
                [Parameter(Mandatory=$true,
                           ValueFromPipeline=$true,
                           Position=0)]
                [string]$guid,

                [Parameter(Mandatory=$true,
                           ValueFromPipeline=$true,
                           Position=1)]
                [string]$computer
            )

            #find matching guid
            foreach($item in $applicationXml.applications.application)
            {
                if($item.guid -like $guid)
                {
                    $applicationName                = $item.Name
                    $applicationWorkingDirectory    = $item.WorkingDirectory
                    $applicationCommandLine         = $item.CommandLine
                    break
                }            
            }

            if($applicationWorkingDirectory.Substring(0,1) -like ".")
            {
                #Installer resides on deployment Share
                $installerSource = $deploymentShare+$applicationWorkingDirectory.Remove(0,1)
            }
            else
            {
                #Installer is elsewhere on the Network
                $installerSource = $applicationWorkingDirectory
            }   

            #install the dependency
            doInstall -applicationName $applicationName `
            -installerSource $installerSource `
            -computer $computer `
            -applicationCommandLine $applicationCommandLine
        }
    }
    . $func

    #Verify Parameters
    if(!$ComputerName -or ($Applications -eq $null))
    {
        log "Mandatory parameter missing, cannot execute." -err
        break
    }

    #If no argument for the deployment share was passed, the configuration from the user profile will be taken
    if(!$DeploymentShare)
    {
        $DeploymentShare = Get-MdtDeploymentShare
    }

    #load application.xml
    try
    {
        [xml]$applicationXml = Get-Content -Path "$DeploymentShare\Control\Applications.xml" -ErrorAction Stop
    }
    catch
    {
        log "Error while accessing $DeploymentShare." -err
        log $_.Exception.Message -err
        break
    }

    if($concurrent)
    {
        log "Starting concurrent execution using jobs" -info
    }

    #process all given computers
    foreach($computer in $ComputerName)
    {
        $computerScript = {
            #Determine if running inside a Job and set variables accordingly
            if($args[0])
            {
                $applicationXml     = $args[0]
                $computer           = $args[1]
                $Applications       = $args[2]
                $deploymentShare    = $args[3]
                $reboot             = $args[4]
                $shutdown           = $args[5]
            }

            log "Starting execution on $computer"
            #Connectivity checks
            try
            {
                $res = Resolve-DnsName $computer -ErrorAction Stop
                $add = $res[0].Address
                log "$computer resolved to $add" -verb
            }
            catch
            {
                log "DNS could not resolve $computer" -err
                log $_.Exception.Message -err
                continue

            }
            if(!(Test-Path "\\$computer\c$"))
            {
                log "Error while trying to access the administrative share c$ on target $computer" -err
                continue
            }
            else
            {
                log "Successfully checked access to administrative share c$" -verb
            }
            try
            {
                #pseudo PS-Session to check availability
                Invoke-Command -ComputerName $computer -ScriptBlock {} -ErrorAction Stop
                log "Successfully checked PSRemote access" -verb
            }
            catch
            {
                log "Error while trying to access $computer with PSRemote" -err
                log $_.Exception.Message -err
                continue
            }

            #process all applications
            foreach($appId in $Applications)
            {
                $applicationInfo                = $applicationXml.applications.application[$appId]
                $applicationName                = $applicationInfo.Name
                $applicationCommandLine         = $applicationInfo.CommandLine
                $applicationWorkingDirectory    = $applicationInfo.WorkingDirectory
                $applicationDependency          = $applicationInfo.Dependency
            
                if(!$applicationWorkingDirectory -and $applicationDependency)
                {
                    #If Application is a Application Bundle
                    log "$applicationName is a dependency bundle. Executing dependencies now" -info
                    foreach($item in $applicationDependency)
                    {
                        installDependency -guid $item -computer $computer
                    }
                    log "$applicationName bundle execution on $computer has finished" -success
                }

                if($applicationDependency -and $applicationWorkingDirectory)
                {
                    #If dependencies are configured
                    $numDep = $applicationDependency.Count
                    if($numDep -like 1)
                    {
                        log "$applicationName has $numDep dependency. Executing dependencies now" -info
                    }
                    else
                    {
                        log "$applicationName has $numDep dependencies. Executing dependencies now" -info
                    }
                    
                    foreach($item in $applicationDependency)
                    {
                        installDependency -guid $item -computer $computer
                    }
                    log "Dependency execution finished, continuing..." -info
                }

                if($applicationWorkingDirectory)
                {
                    #Regular or Application with dependencies
                    if($applicationWorkingDirectory.Substring(0,1) -like ".")
                    {
                        #Installer resides on deployment Share
                        $installerSource = $deploymentShare+$applicationWorkingDirectory.Remove(0,1)
                    }
                    else
                    {
                        #Installer is elsewhere on the Network
                        $installerSource = $applicationWorkingDirectory
                    }

                    doInstall -applicationName $applicationName -installerSource $installerSource -computer $computer -applicationCommandLine $applicationCommandLine

                    log "$applicationName execution on $computer has finished" -success
                }
            }

            #Post execution cleanup
            $cleanupPath = "C:\users\public\downloads\rim\"
            try
            {
                log "Starting post execution cleanup..."
                #Invoke-Command -ComputerName $computer -ScriptBlock {$a = $args[0]; Get-ChildItem $a -Recurse -ErrorAction Stop | Remove-Item -Force -Recurse -Confirm:$false} -ArgumentList $cleanupPath -ErrorAction Stop
                #New-Item -Path "\\$computer\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\rim-clean.bat" -Value "RD /S /Q $cleanupPath & Del %0" -Force | Out-Null
                Invoke-Command -ComputerName $computer `
                -ScriptBlock {$a = $args[0]; $b = "$env:temp\dummy"; New-Item $b -ItemType Directory -Force | Out-Null; robocopy $b $a /MIR | Out-Null} `
                -ArgumentList $cleanupPath -ErrorAction Stop

                log "Post execution cleanup complete"
            }
            catch
            {
                log "Post execution cleanup failed" -warning
            }
            
            if($reboot)
            {
                log "Execution procedure on $computer completed. Rebooting now."
                try
                {
                    log "Executing reboot command..." -verb
                    Invoke-Command -ComputerName $computer -ScriptBlock {shutdown -r -t 0} -ErrorAction Stop
                    log "Rebooting..." -verb
                }
                catch
                {
                    log "Reboot failed" -warning
                }
            }
            elseif($shutdown)
            {
                log "Execution procedure on $computer completed. Shutting down now."
                try
                {
                    log "Executing shutdown command..." -verb
                    Invoke-Command -ComputerName $computer -ScriptBlock {shutdown -s -t 0} -ErrorAction Stop
                    log "Shutting down..." -verb
                }
                catch
                {
                    log "Shutdown failed" -warning
                }
            }
        }

        if($concurrent)
        {
            log "Running job on $computer..."
            Start-Job -Name $computer `
            -InitializationScript $func `
            -ScriptBlock $computerScript `
            -ArgumentList $applicationXml, $computer, $Applications, $deploymentShare, $reboot, $shutdown | out-null
        }
        else
        {
            . $computerScript
        }
    }

    if($concurrent)
    {
        while(Get-Job -State Running)
        {
            $j = Get-Job -State Completed
            $j | Receive-Job
            $j | Remove-Job
            Start-Sleep 2
        }
        $j = Get-Job
        $j | Receive-Job
        $j | Remove-Job
        log "all jobs finished" -success
    }
}

#Check if Update is available
$updateJob = {
    $Version = $args[0]
    try
    {
        $r = [System.Net.WebRequest]::CreateHttp("http://simplywing.ch/mdtrim/update.json"); $r.Timeout = 1000;
        $reqstream = ($r.GetResponse()).GetResponseStream()
        $versionJson = ((new-object System.IO.StreamReader $reqstream).ReadToEnd()) | ConvertFrom-Json
        $v = $versionJson.version; $u = $versionJson.downloadUrl
        if([single]$v -gt [single]$Version)
        {
            Write-Host "MDT-RIM Update available! Download the latest version of MDT-RIM ($v) at $u" -ForegroundColor Cyan
        }
    }
    catch
    {
        #could not search for updates
    }
}
Start-Job -Name "MDTRIM-Update" -ScriptBlock $updateJob -ArgumentList $Version