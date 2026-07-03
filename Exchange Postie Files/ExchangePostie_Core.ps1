<#
.SYNOPSIS
Sends a simple Microsoft 365 mail flow connector test message.

.DESCRIPTION
Tests SMTP delivery through a Microsoft 365 MX host or authenticated SMTP
submission. The script can be run with parameters for repeatable tests or
without parameters for a guided prompt flow.

.EXAMPLE
.\ExchangePostie_Core.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com

.EXAMPLE
.\ExchangePostie_Core.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com -UseCredentials
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Alias('Host')]
    [ValidateNotNullOrEmpty()]
    [string]$SmtpHost,

    [Alias('Sender')]
    [ValidateNotNullOrEmpty()]
    [string]$From,

    [Alias('Recipient')]
    [ValidateNotNullOrEmpty()]
    [string]$To,

    [switch]$UseCredentials,

    [System.Management.Automation.PSCredential]$Credential,

    [ValidateScript({
        if ($_ -eq 25 -or $_ -eq 587) {
            return $true
        }

        throw 'Port must be 25 or 587.'
    })]
    [int]$Port,

    [switch]$DisableTls
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$authSubmissionHost = 'smtp.office365.com'
$subject = 'M365 Mail Flow Connector Test from the Exchange Postie'

function Write-Logo {
    $logo = @'
  ______          _                              ____           _   _
 |  ____|        | |                            |  _ \         | | (_)
 | |__  __  ___  | |__   __ _ _ __   __ _  ___ | |_) |__  ___ | |_ _  ___
 |  __| \ \/ / | | '_ \ / _` | '_ \ / _` |/ _ \|  __/ _ \/ __|| __| |/ _ \
 | |____ >  <| |_| | | | (_| | | | | (_| |  __/| | | (_) \__ \| |_| |  __/
 |______/_/\_\__,_| |_|\__,_|_| |_|\__, |\___||_|  \___/|___/ \__|_|\___|
                                      __/ |
                                     |___/
'@

    Write-Host ''
    foreach ($line in ($logo -split "`r?`n")) {
        Write-Host $line -ForegroundColor Cyan
    }

    Write-Host '  M365 Mail Flow Connector Tester' -ForegroundColor White
    Write-Host '  Clean SMTP path checks for Microsoft 365' -ForegroundColor DarkGray
    Write-Host ''
}

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

function Write-InfoLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Write-Host ('  {0,-17}' -f "${Label}:") -ForegroundColor DarkCyan -NoNewline
    Write-Host $Value
}

function Write-StatusLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [System.ConsoleColor]$Color
    )

    Write-Host ('[{0}] ' -f $Status) -ForegroundColor $Color -NoNewline
    Write-Host $Message
}

function Read-RequiredText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [string]$CurrentValue
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue.Trim()
    }

    while ($true) {
        $value = Read-Host -Prompt $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host 'A value is required.' -ForegroundColor Yellow
    }
}

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $true)]
        [bool]$Default
    )

    $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }

    while ($true) {
        $answer = Read-Host -Prompt "$Prompt $suffix"

        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $Default
        }

        switch -Regex ($answer.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$' { return $false }
            default { Write-Host 'Please answer y or n.' -ForegroundColor Yellow }
        }
    }
}

function Read-SmtpPort {
    param(
        [Parameter(Mandatory = $true)]
        [int]$DefaultPort
    )

    while ($true) {
        $answer = Read-Host -Prompt "Port (25 or 587) [$DefaultPort]"

        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultPort
        }

        $parsedPort = 0
        if ([int]::TryParse($answer.Trim(), [ref]$parsedPort) -and ($parsedPort -eq 25 -or $parsedPort -eq 587)) {
            return $parsedPort
        }

        Write-Host 'Port must be 25 or 587.' -ForegroundColor Yellow
    }
}

function New-MailAddress {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    try {
        return New-Object System.Net.Mail.MailAddress -ArgumentList $Address
    }
    catch {
        throw "$Label address '$Address' is not valid. $($_.Exception.Message)"
    }
}

function Get-ExceptionSummary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception,

        [System.Management.Automation.PSCredential]$CredentialToProtect
    )

    $messages = New-Object System.Collections.Generic.List[string]
    $currentException = $Exception

    while ($null -ne $currentException) {
        if (-not [string]::IsNullOrWhiteSpace($currentException.Message)) {
            $messages.Add($currentException.Message)
        }

        $currentException = $currentException.InnerException
    }

    $summary = $messages -join ' | '

    if ($null -ne $CredentialToProtect) {
        $networkCredential = $CredentialToProtect.GetNetworkCredential()
        if (-not [string]::IsNullOrEmpty($networkCredential.Password)) {
            $summary = $summary.Replace($networkCredential.Password, '[redacted]')
        }
    }

    return $summary
}

function Write-TestSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetHost,

        [Parameter(Mandatory = $true)]
        [int]$TargetPort,

        [Parameter(Mandatory = $true)]
        [bool]$TlsEnabled,

        [Parameter(Mandatory = $true)]
        [bool]$Authenticated,

        [Parameter(Mandatory = $true)]
        [string]$Sender,

        [Parameter(Mandatory = $true)]
        [string]$Recipient,

        [string]$CredentialUserName
    )

    $tlsText = if ($TlsEnabled) { 'Enabled' } else { 'Disabled' }
    $authText = if ($Authenticated) { "Credentials ($CredentialUserName)" } else { 'No credentials' }

    Write-Section -Title 'Test configuration'
    Write-InfoLine -Label 'Host' -Value $TargetHost
    Write-InfoLine -Label 'Port' -Value ([string]$TargetPort)
    Write-InfoLine -Label 'TLS/STARTTLS' -Value $tlsText
    Write-InfoLine -Label 'Authentication' -Value $authText
    Write-InfoLine -Label 'From' -Value $Sender
    Write-InfoLine -Label 'To' -Value $Recipient
    Write-InfoLine -Label 'Subject' -Value $subject
    Write-Host ''
}

try {
    Write-Logo

    $hasHost = $PSBoundParameters.ContainsKey('SmtpHost')
    $hasFrom = $PSBoundParameters.ContainsKey('From')
    $hasTo = $PSBoundParameters.ContainsKey('To')
    $hasPort = $PSBoundParameters.ContainsKey('Port')
    $hasCredential = $PSBoundParameters.ContainsKey('Credential')
    $interactiveMode = -not ($hasHost -and $hasFrom -and $hasTo)

    $SmtpHost = Read-RequiredText -Prompt 'HOST / MX record' -CurrentValue $SmtpHost
    $From = Read-RequiredText -Prompt 'From / sender address' -CurrentValue $From
    $To = Read-RequiredText -Prompt 'To / recipient address' -CurrentValue $To

    $useAuth = $UseCredentials.IsPresent

    if ($hasCredential) {
        $useAuth = $true
    }
    elseif ($interactiveMode -and -not $useAuth) {
        $useAuth = Read-YesNo -Prompt 'Use credentials for authenticated SMTP submission?' -Default $false
    }

    if ($useAuth -and $null -eq $Credential) {
        $Credential = Get-Credential -Message 'Enter the SMTP AUTH username and password.'
    }

    $defaultPort = if ($useAuth) { 587 } else { 25 }
    $resolvedPort = if ($hasPort) { $Port } elseif ($interactiveMode) { Read-SmtpPort -DefaultPort $defaultPort } else { $defaultPort }
    $targetHost = if ($useAuth) { $authSubmissionHost } else { $SmtpHost }

    if ($interactiveMode -and -not $PSBoundParameters.ContainsKey('DisableTls')) {
        $tlsEnabled = Read-YesNo -Prompt 'Use TLS/STARTTLS?' -Default $true
    }
    else {
        $tlsEnabled = -not $DisableTls.IsPresent
    }

    $fromAddress = New-MailAddress -Address $From -Label 'From'
    $toAddress = New-MailAddress -Address $To -Label 'To'
    $credentialUserName = if ($null -ne $Credential) { $Credential.UserName } else { '' }

    if ($useAuth -and $SmtpHost -ne $authSubmissionHost) {
        Write-StatusLine -Status 'INFO' -Message "Credential mode selected. SMTP target will be $authSubmissionHost instead of the entered HOST value '$SmtpHost'." -Color Yellow
    }

    Write-TestSummary `
        -TargetHost $targetHost `
        -TargetPort $resolvedPort `
        -TlsEnabled $tlsEnabled `
        -Authenticated $useAuth `
        -Sender $fromAddress.Address `
        -Recipient $toAddress.Address `
        -CredentialUserName $credentialUserName

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    $tlsText = if ($tlsEnabled) { 'Enabled' } else { 'Disabled' }
    $authText = if ($useAuth) { "Credentials ($credentialUserName)" } else { 'No credentials' }

    $body = @"
Hello,

This is a Microsoft 365 mail flow connector test from the Exchange Postie.

Test details:
Host: $targetHost
Port: $resolvedPort
TLS/STARTTLS: $tlsText
Authentication: $authText
From: $($fromAddress.Address)
To: $($toAddress.Address)
Sent at: $timestamp

If this message arrived successfully, the selected SMTP path accepted the test message.
"@

    $message = New-Object System.Net.Mail.MailMessage
    $smtpClient = New-Object System.Net.Mail.SmtpClient -ArgumentList $targetHost, $resolvedPort

    try {
        $message.From = $fromAddress
        [void]$message.To.Add($toAddress)
        $message.Subject = $subject
        $message.Body = $body
        $message.IsBodyHtml = $false

        $smtpClient.EnableSsl = $tlsEnabled
        $smtpClient.DeliveryMethod = [System.Net.Mail.SmtpDeliveryMethod]::Network
        $smtpClient.Timeout = 30000
        $smtpClient.UseDefaultCredentials = $false

        if ($useAuth) {
            $smtpClient.Credentials = $Credential.GetNetworkCredential()
        }

        Write-Section -Title 'Delivery attempt'
        Write-StatusLine -Status 'SEND' -Message 'Sending test message...' -Color Cyan
        $smtpClient.Send($message)
        Write-StatusLine -Status 'PASS' -Message 'Test message was accepted by the SMTP server.' -Color Green
        Write-Host ''
        exit 0
    }
    finally {
        if ($null -ne $message) {
            $message.Dispose()
        }

        if ($null -ne $smtpClient) {
            $smtpClient.Dispose()
        }
    }
}
catch {
    if ($null -ne $Credential) {
        $errorSummary = Get-ExceptionSummary -Exception $_.Exception -CredentialToProtect $Credential
    }
    else {
        $errorSummary = Get-ExceptionSummary -Exception $_.Exception
    }

    Write-Host ''
    Write-Section -Title 'Result'
    Write-StatusLine -Status 'FAIL' -Message 'Failed to send the test message.' -Color Red
    Write-InfoLine -Label 'Reason' -Value $errorSummary
    Write-Host ''
    exit 1
}
