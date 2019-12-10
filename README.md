# MDTRIM
Powershell <b>R</b>emote <b>I</b>nstallation <b>M</b>odule for Microsoft Deployment Toolkit (MDTRIM)

Powershell RIM extends the functionality of Microsoft Deployment Toolkit and allows remote installation of Windows applications to Windows clients. The applications are maintained in MDT and can be used for installation in MDT as well as for remote installation with Powershell RIM.

Powershell RIM is based on WinRM for remote execution. To work around the Kerberos double-hop problem, all files needed for the installation are copied to the client. This is done via the administrative share C$

After remote execution, the previously copied files are automatically deleted.
Installation
To install Powershell RIM, download both the Manifest (rim.psd1) and the Module File (rim.psm1). 

## Installation
Download .psd1 & .psm1 files to your Powershell-Modules directory and run
`Import-Module rim.psd1`
to import the module into Powershell.

## Usage
`Set-MdtDeploymentShare -DeploymentShare "\\\DEPLOYMENTSERVER\DEPLOYMENTSHARE$"`
to define your default Deployment Share.

Powershell RIM integrates into MDT (Microsoft Deployment Toolkit) and uses a common application database. The Get-MdtApplications Cmdlet can be used to list all exising applications inside a Deployment Share. For more information about this Cmdlet, use:
`Get-Help Get-MdtApplications`

For a nice overview of all your applications, use:
`Get-MdtApplications | Sort-Object ApplicationName | Format-Table`

Use the Install-MdtApplications Cmdlet to install one or many applications to one or multiple Windows Clients. For more information about this Cmdlet, use:
`Get-Help Install-MdtApplications`

Use the -Concurrent switch to install applications on multiple devices simultaniously.

## Improvements
If you found a bug or have an idea to improve Powershell RIM, I am happy to hear from you: joel@simplywing.ch
