﻿<#
.Synopsis
   This function will find the Kaseya Machine ID of the computer.  It will find the computer name if there is no kaseya agent installed.
.DESCRIPTION
   This function checks the registry for the Kaseya Machine ID.  It can be used in other scripts to find the name.
.EXAMPLE
  Get-KaseyaMachineID
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-KaseyaMachineID
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
    )
    Begin
    {
    }
    Process
    {
        try
        {
            if($(Get-Process -Name AgentMon -ErrorAction SilentlyContinue).Name)
            { 
                $(Get-ItemProperty -Path "HKLM:\Software\WOW6432Node\Kaseya\Agent\INTTSL74824010499872" -Name MachineID -ErrorAction Stop -ErrorVariable CurrentError).MachineID
            }
            Else
            {
                $env:computername
            }
        }
        Catch
        {
            $env:computername
        }   
    }
    End
    {
    }
}

<#
.Synopsis
   This script emails MSAlarm@integratedit.com.
.DESCRIPTION
   This scipt needs 1 parameter to work.  It requires the subject.  An optional attachment parameter can be used if you wish to attach a file. 
.EXAMPLE
   Email-MSalarm -Body "This is my Email" -Attachment "C:\Foo.txt"
#>
function Email-MSalarm
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true, Position=0)]
        $Body,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=1)]
        $Attachment
    )

    Begin
    {
        try
        {
        $CurrentError = $null
        $ErrorLog = "$env:windir\Temp\EmailMSalarm_IITS.txt"
        $key = Get-Content "C:\IITS_Scripts\Key.key" -ErrorAction Stop -ErrorVariable CurrentError
        $password = Get-Content "C:\IITS_Scripts\passwd.txt" | ConvertTo-SecureString -Key $key -ErrorAction Stop -ErrorVariable CurrentError
        $credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist "forecast@integratedit.com",$password
        }
        Catch
        {
        "$(Get-Date) - Couldn't get a variable.  Error= $CurrentError ." | Out-File -FilePath $ErrorLog -Force -Append
        }
    }
    Process
    {
        if(!$CurrentError)
        {
            if($Attachment)
                {
            Try
                {
                    Send-MailMessage -To MSalarm@integratedit.com -Subject "[$(Get-KaseyaMachineID)] - Emailed form Powershell Script" -body "
                    {Script}
        
                    $Body"  -Credential $credentials -SmtpServer outlook.office365.com -UseSsl -From $From -Attachments $Attachment -ErrorAction Stop -ErrorVariable CurrentError
                }
            Catch
                {
                    "$(Get-Date) - Couldn't email.  Error= $CurrentError ." | Out-File -FilePath $ErrorLog -Force -Append
                }
        }
            Else
                {
            Try
            {
                Send-MailMessage -To MSalarm@integratedit.com -Subject "[$(Get-KaseyaMachineID)] - Emailed form Powershell Script" -body "
                {Script}
        
                $Body"  -Credential $credentials -SmtpServer outlook.office365.com -UseSsl -From forecast@integratedit.com -ErrorAction Stop -ErrorVariable CurrentError
            }
            Catch
            {
                "$(Get-Date) - Couldn't email.  Error= $CurrentError ." | Out-File -FilePath $ErrorLog -Force -Append
            }
        }
        }
        Else
        {
            "$(Get-Date) - Skipped process block due to not having the key file or the password.  Error = $CurrentError" | Out-File -FilePath $ErrorLog -Force -Append
        }
    }
    End
    {
    }
}

<#
.Synopsis
   This function will enable or disable the windows 10 action center.
.DESCRIPTION
   This function checks for the existence of the neccessary registry keys and will create the keys if needed.  Once they are created or verified to be there then it will change the appropriate dword based on user request
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Toggle-ActionCenter
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0
                   )]
        [ValidateSet("Enable","Disable")]
        [String]$Setting
    )

    Begin
    {
        $regpath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
        $namedword = "DisableNotificationCenter"
        $output= "$env:windir\Temp\actioncenter_IITS.txt"
        if($Setting -eq "Enable")
        {
            $Status = 0
        }
        Else
        {
            $Status = 1
        }
    }
    Process
    {
        try
        {
            $machineID  = $(Get-ItemProperty -Path "HKLM:\Software\WOW6432Node\Kaseya\Agent\INTTSL74824010499872" -Name MachineID -ErrorAction Stop -ErrorVariable CurrentError).MachineID
            if (!(Test-Path $regpath))
            {
                "$(Get-Date) - Registry path does not exist." | Out-File -FilePath $output -Force -Append
                New-Item -Path $regpath -Force -ErrorAction Stop -ErrorVariable CurrentError
                "$(Get-Date) - Created new key $regpath." | Out-File -FilePath $output -Force -Append
                New-ItemProperty -Path $regpath -Name $namedword -Value $Status -PropertyType DWORD -Force -ErrorAction Stop -ErrorVariable CurrentError
                "$(Get-Date) - Created new dword $namedword with value of $Setting." | Out-File -FilePath $output -Force -Append
            }
            else
            {
                 "$(Get-Date) - Registry path exists." | Out-File -FilePath $output -Force -Append
                 New-ItemProperty -Path $regpath -Name $namedword -Value $Status -PropertyType DWORD -Force -ErrorAction Stop -ErrorVariable CurrentError
                 "$(Get-Date) - Set new dword $namedword with value of $Setting." | Out-File -FilePath $output -Force -Append
            }
        }
        Catch
        {
            Email-MSalarm -From "Powershell@integratedit.com" -Body $CurrentError -Attachment $output
        }
    }
    End
    {
    }
}

<#
.Synopsis
   This procedure will calculate the total messages sent from all users in Office 365.  It can then email the results along with a .csv file for futher data manipulation
.DESCRIPTION
   There are 3 parts to this procedure.  The first part connects to Office 365 after requesting the credentials.  The credentials that are used will dictate what tenant information is gathered.  
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-MailFlowStats
{
    [CmdletBinding()]
    [Alias()]
     Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Param1,
        [switch]$errorlog
    )

    Begin
    {
        $file_path_csv = "$env:windir\Temp\Email_stats_$(get-date -f yyyyMMdd).csv"
        $shouldemail = Read-Host -Prompt "Do you want to have the results emailed to you along with a CSV attachment? Enter 'Yes' if desired. If no email is required then output is .csv located at $file_path_csv"
        if($shouldemail -like "yes"){
        $office365 = Read-Host -Prompt "Do you want to send through Office 365? Enter Yes or No"
            if($office365 -like "Yes"){
            $smtpServer = "outlook.office365.com"
            }
            Else{
            $smtpServer = Read-Host -Prompt "Please enter the IP address of an accessible Exchange Server."
            }
        $from = read-host -Prompt "Please enter the From address."
        $to = Read-Host -Prompt "Please enter the To address."
        }
        $credential = Get-Credential -Message "Please enter an account that has administrator privleges on the Office 365 tenant."
        Write-Output "Closing open powershell session: $(Get-PSSession)"
        Get-PSSession | Remove-PSSession
        try{
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $credential -Authentication Basic -AllowRedirection -ErrorAction SilentlyContinue -ErrorVariable session_issue
            Import-PSSession $Session -ErrorAction SilentlyContinue -ErrorVariable $session_issue
            cls
            }
        catch{
            Write-Output "There was an issue connecting to Office 365 with the credentials supplied.  Please try again or check the error log."
            $session_issue | Out-File -force "$env:TEMP\Error_log_$(get-date -f yyyyMMdd).txt"
            throw
            }
    }
    Process
    {
        [int]$days_past = -(Read-Host -Prompt 'Enter the number of days in the past to gather reports. Up to a max of 30 days')
        $date = get-date
        $report = @()
        $entry = 1
        $recipients = @()
        Write-Output "Getting recipient list for users with a usermailbox."
        $recipients = Get-Recipient -RecipientTypeDetails UserMailBox -RecipientType UserMailBox
        $start_time = Get-Date
        foreach ($recipient in $recipients)
        {
            Write-Output "Currently working on $recipient.  Number $entry of $(($recipients | measure-object).Count) total. $(($entry/$(($recipients | measure-object).Count))*100 -as [int])% Complete"
            try
            {
                $messages_received = Get-MessageTrace -RecipientAddress $recipient.PrimarySMTPAddress -StartDate $date.AddDays($days_past) -EndDate $date | Measure-Object -ErrorAction Stop -ErrorVariable issue
                $messages_sent = Get-MessageTrace -SenderAddress $recipient.PrimarySMTPAddress -StartDate $date.AddDays($days_past) -EndDate $date | Measure-Object -ErrorAction Stop -ErrorVariable issue
                $Prop=[ordered]@{
                            'Display Name'=$recipient.DisplayName
                            'Start Date'=$date.AddDays($days_past)
                            'End Date'=$date
                            'Messages Received'=$messages_received.Count
                            'Messages Sent'=$messages_sent.Count
                            'Total Messages'=($messages_received.Count + $messages_sent.Count)
                            }
                $report += New-Object -TypeName psobject -Property $Prop
                $entry = ++$entry
            }
            catch
            {
                Write-Output "Error with $recipient.  Check error log for exact issue"
                $issues += $issue
                continue
            }
        }
    }
    End
    {
        if($shouldemail -like "yes")
        {
            $report | Export-Csv -Path $file_path_csv -force
            $subject = "Script finished in $(((get-date).Subtract($start_time)).TotalMinutes -as [int]) minutes!"
                try
                {
                Send-MailMessage -To $to -Subject $subject -BodyAsHtml "$($report | ConvertTo-Html),$($issues | ConvertTo-Html)" -Credential $credential -SmtpServer $smtpServer -UseSsl -From $from -Attachments $file_path_csv -ErrorAction Stop -ErrorVariable email_error
                Remove-Item -Path $file_path_csv -Force
                }
                catch
                {
                Write-Output "Something went wrong while trying to email file.  Defaulting to file output."
                Write-Output "The report has been generated and is located at $file_path_csv"
                break
                }
        }
        Else
        {
                $report | Export-Csv -Path $file_path_csv -Force
                Write-Output "The report has been generated and is located at $file_path_csv"
        }
    Write-Output "Closing powershell sessions: $(Get-PSSession)"
    Get-PSSession | Remove-PSSession       
    }
}

<#
.Synopsis
   This removes a word from outcorrect in anything that uses Microsoft Word. 
.DESCRIPTION
   This cmdlet will connect to the local machine's Microsoft Word installation and then remove a word so that it does not autocorrect to another word.  ehr will no longer autocorrect to her.
.EXAMPLE
   Remove-AutoCorrect -WordToRemove "ehr"
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Remove-AutoCorrect
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$WordToRemove
    )

    Begin
    {
    try
    {
        $ErrorLog= "$env:windir\Temp\disableautocorrectoutput_IITS.txt"
        $found=0
        $word = New-Object -ComObject word.application -ErrorAction Stop -ErrorVariable CurrentError
        $word.visible = $false
    }
    catch
    {
        "$(Get-Date) - Problem starting WORD as a com object.  Error = $CurrentError" | Out-File -FilePath $ErrorLog -Append
    }
    }
    Process
    {
        if(!$CurrentError)
        {
            Try
            {
                $entries = $word.AutoCorrect.entries
                foreach($e in $entries)
                { 
                    if($e.name -eq $WordToRemove)
                    {
                        "$(Get-Date) - Found $WordToRemove in Auto Correct List." | Out-File -FilePath $ErrorLog -Append
                        $found=1
                        $e.delete()
                        "$(Get-Date) - Deleted $WordToRemove in Auto Correct List." | Out-File -FilePath $ErrorLog -Append
                    }
                }
                if($found -eq 0)
                {
                    "$(Get-Date) - Did not find $WordToRemove in Auto Correct List." | Out-File -FilePath $ErrorLog -Append
                }
            }
            Catch
            {
                "$(Get-Date) - Something went wrong while trying to remove the word $WordToRemove" | Out-File -FilePath $ErrorLog -Append
            }
        }
        Else
        {
            Email-MSalarm -From Script_Genie@integratedit.com -Body "Problem starting WORD as a com object.  Error = $CurrentError" -Attachment $ErrorLog
        }
    }
    End
    {
        $word.Quit()
        $word = $null
        [gc]::collect()
        [gc]::WaitForPendingFinalizers()
    }
}

<#
.Synopsis
   Delete a user's 365 account
.DESCRIPTION
   Will prompt for email address of user and disable after you give the 365 credentials
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function disable-365-account
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param ([string]$mailbox=(read-host "Enter user's email address:"))

    #Connect to client's 365
    $LiveCred = Get-Credential
    Import-Module msonline; Connect-MsolService -Credential $livecred
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/?proxymethod=rps -Credential $LiveCred -Authentication Basic -AllowRedirection
    Import-PSSession $Session

    Set-MsolUser -UserPrincipalName $mailbox -BlockCredential $true
    
}

<#
   Get App Version
.DESCRIPTION
   Gives you the exact application version for an app in Windows
.EXAMPLE
   You will be prompted for the full path and application name, ie:  c:\windows\apppp.exe

#>
function get-app-version
{

    Param ([string]$app=(Read-host "FULL path with filename:"))

$VersionString = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($app).Fileversion
$OutputString = "$Machine $QueryString AppVersion $VersionString"


$sep="."
$parts=$VersionString.split($sep)
$parts[0]

}

<#
.Synopsis
   External Push of Kaseya via Powershell
.DESCRIPTION
   If a machine on a network doesn't have powershell OR if it's a machine
   from an acquisistion that we don't have access to yet, this will install
   Kaseya
.EXAMPLE
   After execution, you'll be asked for the path of the Kaseya installer for
   the client

.EXAMPLE
   
#>
function external-kaseya-push
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$kaseyaLink=(read-host "Input the full URL for the Kaseya client to be installed.  Example: https://www.dropbox.com/s/o6q9bbe91jcsoa7/sccit_KcsSetup.exe?dl=1")

    )

    Begin
    {
    $sccit_url = $kaseyaLink 
    $kaseya_path= "$Env:SystemDrive\iits_mgmt" 
    }
    Process
    {
    #Create Kaseya download path if it doesn't already exist 
    if ((Test-Path $kaseya_path) -eq $false) {New-Item -type directory -Path $kaseya_path | out-null} 
    $tableurl
    #Download Kaseya if it's not already there 
    if ((Test-Path "$kaseya_path\sccit_KcsSetup.exe") -eq $false)
        { 
            $kaseya_dload_file = "$kaseya_path\sccit_KcsSetup.exe" 
            $kaseya_dload = new-object System.Net.WebClient 
            $kaseya_dload.DownloadFile($sccit_url,$kaseya_dload_file) 
        } 

    #Run Kaseya and wait for it to exit 
    $kaseya_launch = new-object Diagnostics.ProcessStartInfo 
    $kaseya_launch.FileName = "$kaseya_path\sccit_KcsSetup.exe" 

    #$kaseya_launch.Arguments = $kaseya_switches 

    $kaseya_process = [Diagnostics.Process]::Start($kaseya_launch) 
    $kaseya_process.WaitForExit() 
    }
    End
    {
    }
}

<#
.Synopsis
   Hides a user from the GAL
.DESCRIPTION
   
.EXAMPLE
   
.EXAMPLE
   
#>
function hide-user-from-GAL
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$mailbox=(read-host "Enter user's email address:")

    )

    Begin
    {

    #Connect to client's 365
    $LiveCred = Get-Credential
    Import-Module msonline; Connect-MsolService -Credential $livecred
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/?proxymethod=rps -Credential $LiveCred -Authentication Basic -AllowRedirection
    Import-PSSession $Session

    }
    Process
    {

    Set-Mailbox -Identity $mailbox -HiddenFromAddressListsEnabled $true

    }

    End
    {
    }
}

<#
.Synopsis
   Match an organization and a Windows OS architecture (32 or 64) to download an installer. Only works on a single machine at a time.
.DESCRIPTION
   Determine the root org (groupName) based on a given machine ID (machName). Determine the OS architecture (machOS) of the machine this script is run on (which will be the same machine in machName). Match machOrg and machOS against key EsetKey.csv to get a Dropbox download link to a company-specific ESET Agent installer.
.EXAMPLE
   Get-EsetLink [-machName] my.machine.sccit
.INPUTS
   machName (string)
.OUTPUTS
   URL (string)
.FUNCTIONALITY
   Downloads a URL link to an installer.
#>

function Get-EsetLink
{
    [CmdletBinding(DefaultParameterSetName='Parameter Set 1', 
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  HelpUri = 'http://www.microsoft.com/',
                  ConfirmImpact='Medium')]
    [Alias("Get-ESET")]
    [OutputType([String])]
    Param
    (
        # This is the name of the machine. It will be converted into the name of the org and then checked against a spreadsheet/key.
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false,
                   Position=0,
                   ParameterSetName='Parameter Set 1')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("name","machine")] 
        [String]$machName
    )
    
    Begin
    {
    # Get the OS architecture of the target (Windows) machine.
    (Get-WmiObject Win32_OperatingSystem).OSArchitecture -match '\d+' | Out-Null
    [Int]$machOS=$matches[0]
    
    # RegEx the machine name to extract the group name.
    $machName -match '\w+$' | Out-Null
    [String]$groupName = $matches[0]
    }
    Process
    {
    # Import the key and search for the group and OS architecture. Save the result to a container.
    $orgLink = (Import-Csv "C:\IITS_Scripts\EsetKey.csv" | where{$_.machOrg -eq $groupName} | where{$_.machOS -eq $machOS} | % link)
    }
    End
    {
    # Print the container with the ESET link.
    return $orgLink
    }
}

<#
.Synopsis
   Gets the account used for all services
.DESCRIPTION
   Uses WMI to find the list of services and the accounts they are using to start.  Added description to aid in figuring out what it does.  The Output will be returned to the screen and can then be sent to a file. 
.EXAMPLE
   Get-ServiceAccount -ComputerName Computron -LogFile
#>

function Get-ServiceAccount
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $ComputerName,

        [switch][parameter(mandatory=$false, Position=1)] $LogFile
    )

    Begin
    {
        if(!$ComputerName)
        {
            $ComputerName=$env:COMPUTERNAME
        }
        Else
        {
        }
    }
    Process
    {
        $services = Get-WmiObject win32_service -ComputerName $ComputerName -ErrorAction Stop -ErrorVariable CurrentError
        $services | Select-Object -Property SystemName, Name, StartName, ServiceType, Description | Format-Table
    }
    End
    {
        if($LogFile)
        {
            $ErrorLog = "$env:windir\Temp\ServiceAccount_IITS.txt"
            if(!$CurrentError)
            {
                "$(Get-Date) - Error= NO ERROR." | Out-File -FilePath $ErrorLog -Force -Append
            }
            Else
            {
                "$(Get-Date) - Error= $CurrentError." | Out-File -FilePath $ErrorLog -Force -Append
            }
        }
        Else
        {
        }
    }
}

<#
.Synopsis
   This command will output a list of all of the install programs from the registry.
.DESCRIPTION
   This command will find the installed applications on any computer.  It will output the name and the uninstall string that can be used to remove the application.
.EXAMPLE
   Get-InstalledPrograms -ComputerName
#>
function Get-InstalledPrograms
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # ComuputerName
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $ComputerName,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [switch]
        $ErrorLog
    )

    Begin
    {
        $booboos = @()
        $array = @()
        $RegLocations = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
                        'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        if(!$ComputerName)
        {
            $ComputerName=$env:COMPUTERNAME
        }
        Else
        {
        }
    }
    Process
    {
        try
        {
            $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$ComputerName)
            foreach($RegLocation in $RegLocations)
            {
            $CurrentKey= $reg.opensubkey($RegLocation)
            $subkeys = $CurrentKey.GetSubKeyNames()
            foreach($subkey in $subkeys)
            {
                $Values = $reg.OpenSubKey("$RegLocation$subkey")
                if($Values.GetValue('DisplayName'))
                {
                    $Prop=[ordered]@{
                    'Display_Name'=$Values.GetValue('DisplayName')
                    'Uninstall_Path'=$Values.GetValue('UninstallString')
                    }
                     $array += New-Object -TypeName psobject -Property $Prop -ErrorAction SilentlyContinue -ErrorVariable errors
                } 
            }
        }
            $array | Sort-Object -Property 'Display_Name'
        }
        catch
        {
            $booboos += $error
        }
    }
    End
    {
        if($ErrorLog)
        {
            $LogPath = "$env:windir\Temp\InstalledPrograms_IITS.txt"
            foreach($booboo in $booboos)
            {
                "$(Get-Date) - $booboo ." | Out-File -FilePath $LogPath -Force -Append
            }
        }
    }
}

<#
.Synopsis
   This program will uninstall any application in ADD/Remove that matches the information entered.
.DESCRIPTION
   This program will remove an appliation with MSIEXEC if applicable.  If there is no msiexec uninstall string then it will attempt to use the uninstall path if there is one. There will be an output file located in the windows\temp folder.  
.EXAMPLE
   Remove-Application -UninstallPrograms Kaseya,Microsoft -ErrorLog
#>
function Remove-Application
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [array]$UninstallPrograms,

        [Parameter()]
        [switch]$ErrorLog
    )

    Begin
    {
        [array]$booboos = @()
        [array]$InstalledPrograms = Get-InstalledPrograms
        if(!$UninstallPrograms)
        {
            $UninstallPrograms = Read-Host 'What program(s) would you like to uninstall?'
        }
    }
    Process
    {
        try
        {
            foreach($program in $UninstallPrograms)
            {
                $progs = $InstalledPrograms | Where-Object {($_.Display_Name -match "$program")}
                if($progs)
                {
                    foreach($prog in $progs)
                    {    
                        if($prog.Uninstall_Path)
                        {
                            if($prog.Uninstall_Path -match "msiexec.exe")
                            {
                                $removestring = $prog.Uninstall_Path -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
                                $removestring = $removestring.Trim()
                                $booboos += "$(Get-Date) - Removing $($prog.display_name) using $removestring."
                                start-process "msiexec.exe" -arg "/X $removestring /qn" -Wait -ErrorAction SilentlyContinue
                            }
                            else
                            {
                                $booboos += "$(Get-Date) - Application $($prog.display_name) isn't using MSIEXEC for uninstall."
                                start-process "cmd.exe" -arg "$($prog.Uninstall_Path)" -Wait -ErrorAction SilentlyContinue
                            }
                        }
                        Else
                        {
                            $booboos += "$(Get-Date) - Application $($prog.Display_name) doesn't have an uninstall path."
                        }
                    }
                }
                else
                {
                    $booboos += "$(Get-Date) - Couldn't find application that matched $program."
                }

            }
        }
        catch
        {
            $booboos += $error
        }
    }
    End
    {
        if($ErrorLog)
        {
            $LogPath = "$env:windir\Temp\RemoveApplication_IITS.txt"
            foreach($booboo in $booboos)
            {
                "$booboo" | Out-File -FilePath $LogPath -Force -Append
            }
        }
    }
}

<#
.Synopsis
   VERY simple function to get versions of all installed apps
.DESCRIPTION
   
.EXAMPLE
  Get-All-App-Versions
.EXAMPLE
   Another example of how to use this cmdlet
#>

function Get-All-App-Versions
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
    )
    Begin
    {
    }
    Process
    {
    Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Export-Csv "c:\iits_mgmt\all_app_versions.csv"
    
    }
    End
    {
    }
}

<#
.Synopsis
   Gathers crashplan log files from a computer and zips them up in a folder.
.DESCRIPTION
   Long description
.EXAMPLE
   Get-CrashPlanLogs "C:\IITS_MGMT\CrashPlan.zip" -ErrorLog
#>
function Get-CrashPlanLogs
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Output,
        
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [switch]$Errorlog
    )

    Begin
    {
        $booboos = @()
        $CrashLogPath = "C:\ProgramData\CrashPlan\log"

    }
    Process
    {
        if(Test-Path $CrashLogPath)
        {
            Create-Zip -Source $CrashLogPath -Destination $Output
            return $Output
        }
        else
        {
            $booboos += "$(Get-Date) - CrashPlan log directory $CrashLogPath doesn't exist."
        }
    }
    End
    {
        if($ErrorLog)
        {
            $LogPath = "$env:windir\Temp\GetCrashPlanLogs_IITS.txt"
            foreach($booboo in $booboos)
            {
                "$booboo" | Out-File -FilePath $LogPath -Force -Append
            }
        }
    }
}

<#
.Synopsis
   This command will zip a folder
.DESCRIPTION
   Long description
.EXAMPLE
   Create-Zip -Source "C:\Temp\Logs" -Destination "C:\Temp\Logs.zip" -Overwrite -Errorlog
#>
function Create-Zip
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Source Directory
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Source,

        # Destination for Zip file
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $Destination,

        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [switch]$Overwrite,
        [switch]$Errorlog
    )

    Begin
    {
        $Error = $null
        $booboos = @()
        if(!$Overwrite)
        {
            if(Test-Path $Destination)
                {
                    $Destination = "$($Destination).new"
                    $booboos += "$(Get-Date) - File already exists.  Creation new file $Destination."
                }
        }
        Else
        {
            if(test-path $Destination)
            {
                Remove-Item $Destination
                $booboos += "$(Get-Date) - Removing previous file $Destination."
            }
        }
    }
    Process
    {
        Try
        {
        Add-Type -assembly "system.io.compression.filesystem" -ErrorAction Stop
        [io.compression.zipfile]::CreateFromDirectory($Source, $Destination) 
        }
        Catch
        {
            $booboos += "$(Get-Date) - Couldn't load assembly.  Error = $Error"
        }
    }
    End
    {
         if($ErrorLog)
        {
            $LogPath = "$env:windir\Temp\CreateZip_IITS.txt"
            foreach($booboo in $booboos)
            {
                "$booboo" | Out-File -FilePath $LogPath -Force -Append
            }
        }
    }
}

<#
.Synopsis
   Will request a domain name and see if it's blacklisted
.DESCRIPTION
   Long description
.EXAMPLE
   Michael takes no credit for this code!
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Find-If-Domain-Blacklisted
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
    )

    Begin
    {
    }
    Process
    {
    write-host "Stand by..."
    $wc=New-Object net.webclient
        #$IP =(Invoke-WebRequest ifconfig.me/ip).Content.Trim()
        #$IP = $wc.downloadstring("http://ifconfig.me/ip") -replace "[^\d\.]"
        Try {
            $IP = $wc.downloadstring("http://checkip.dyndns.com") -replace "[^\d\.]"
        }
        Catch {
            $IP = $wc.downloadstring("http://ifconfig.me/ip") -replace "[^\d\.]"
        }
        $IP = Read-Host -prompt "Enter a domain name to see if it's on a blacklist:"
        Write-Host "Testing Public IP: $IP"
        $reversedIP = ($IP -split '\.')[3..0] -join '.'
 
        $blacklistServers = @(
            'b.barracudacentral.org'
            'spam.rbl.msrbl.net'
            'zen.spamhaus.org'
            'bl.deadbeef.com'
            'bl.spamcannibal.org'
            'bl.spamcop.net'
            'blackholes.five-ten-sg.com'
            'bogons.cymru.com'
            'cbl.abuseat.org'
            'combined.rbl.msrbl.net'
            'db.wpbl.info'
            'dnsbl-1.uceprotect.net'
            'dnsbl-2.uceprotect.net'
            'dnsbl-3.uceprotect.net'
            'dnsbl.cyberlogic.net'
            'dnsbl.sorbs.net'
            'duinv.aupads.org'
            'dul.dnsbl.sorbs.net'
            'dyna.spamrats.com'
            'dynip.rothen.com'
            'http.dnsbl.sorbs.net'
            'images.rbl.msrbl.net'
            'ips.backscatterer.org'
            'misc.dnsbl.sorbs.net'
            'noptr.spamrats.com'
            'orvedb.aupads.org'
            'pbl.spamhaus.org'
            'phishing.rbl.msrbl.net'
            'psbl.surriel.com'
            'rbl.interserver.net'
            'relays.nether.net'
            'sbl.spamhaus.org'
            'smtp.dnsbl.sorbs.net'
            'socks.dnsbl.sorbs.net'
            'spam.dnsbl.sorbs.net'
            'spam.spamrats.com'
            't3direct.dnsbl.net.au'
            'tor.ahbl.org'
            'ubl.lashback.com'
            'ubl.unsubscore.com'
            'virus.rbl.msrbl.net'
            'web.dnsbl.sorbs.net'
            'xbl.spamhaus.org'
            'zombie.dnsbl.sorbs.net'
            'hostkarma.junkemailfilter.com'
        )
 
        $blacklistedOn = @()
 
        foreach ($server in $blacklistServers)
        {
            $fqdn = "$reversedIP.$server"
            #Write-Host "Testing Reverse: $fqdn"
            try
            {
              #Write-Host "Trying Blacklist: $server"
                $result = [System.Net.Dns]::GetHostEntry($fqdn)
             foreach ($addr in $result.AddressList) {
              $line = $Addr.IPAddressToString
             } 
            #IPAddress[] $addr = $result.AddressList;
                #$addr[$addr.Length-1].ToString();
            #Write-Host "Blacklist Result: $line"
            if ($line -eq "127.0.0.1") {
                    $blacklistedOn += $server
            }
            }
            catch { }
        }
 
        if ($blacklistedOn.Count -gt 0)
        {
            # The IP was blacklisted on one or more servers; send your email here.  $blacklistedOn is an array of the servers that returned positive results.
            Write-Host "$IP was blacklisted on one or more Lists: $($blacklistedOn -join ', ')"
            Exit 1010
        }
        else
        {
            Write-Host "$IP is not currently blacklisted on any lists checked."
           
        }
 
    }
    End
    {
    }
}

<#
.Synopsis
   Remove's another user's folder/calendar from automap
.DESCRIPTION
   If a user is assigned, or has been, permissions to another user's calendar or mailbox, 365 automatically maps it
   in the user's Outlook.  This will turn off the automap
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Remove-Outlook-Automap
{

    Begin {

        #Connect to client's 365
         $LiveCred = Get-Credential
         Import-Module msonline; Connect-MsolService -Credential $livecred
         $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/?proxymethod=rps -Credential $LiveCred -Authentication Basic -AllowRedirection
         Import-PSSession $Session
           }


    Process {
            $owner=read-host "Enter Owner's email address:"
            $requestor=read-host "Enter email address of person to remove Automapping from:"
            Add-MailboxPermission -Identity $owner -User $requestor -AccessRights FullAccess -AutoMapping:$false
            }
}

<#
.Synopsis
   This cmdlet will return the current filesystem drives as an object
.DESCRIPTION
   This cmdlet gets all of the drives that are marked as filesystem drives and returns them as an ohject
.EXAMPLE
   Get-DriveStatistics -ErrorLog
#>
function Get-DriveStatistics
{
    [CmdletBinding()]
    Param
    (
        [switch]$ErrorLog
    )

    Begin
    {
        $booboos=@()
        $Error = $null
        try
        {
            $volumes = Get-PSDrive | Where-Object {$_.Provider -match 'Filesystem'}
        }
        catch
        {
            $booboos += "$(Get-Date) - Couldn't get drive list."
        }
    }
    Process
    {
        $report=@()
        if(!$booboos)
        {
            foreach($volume in $volumes)
            {
                $Prop=
                [ordered]@{
                'Name'=$volume.Name
                'Drive'=$volume.root
                'UsedSpace'=[System.Math]::Round($($volume.used / 1GB), 2)
                'FreeSpace'=[System.Math]::Round($($volume.free / 1GB) ,2)
                'TotalSpace'=[System.Math]::Round($($volume.used /1gb + $volume.free/1gb), 2)
                }
                $report += New-Object -TypeName psobject -Property $Prop   
            }
        }
        else
        {
            $booboos += "$(Get-Date) - Skipping process block due to not having volumes."
        }
        return $report | Format-Table
    }
    End
    {
        if($ErrorLog)
        {
            $LogPath = "$env:windir\Temp\DriveStatistics_IITS.txt"
            foreach($booboo in $booboos)
            {
                "$booboo" | Out-File -FilePath $LogPath -Force -Append
            }
        }
    }
}