<#
.SYNOPSIS
Creates a Windows shortcut for launching Exchange Postie with its custom icon.
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Path $PSScriptRoot -Parent
$shortcutPath = Join-Path -Path $packageRoot -ChildPath 'Exchange Postie.lnk'
$launcherPath = Join-Path -Path $PSScriptRoot -ChildPath 'Launch-ExchangePostie.cmd'
$iconPath = Join-Path -Path $PSScriptRoot -ChildPath 'ExchangePostie.ico'

if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
    throw "Could not find launcher: $launcherPath"
}

if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw "Could not find icon: $iconPath"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)

$shortcut.TargetPath = $launcherPath
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.IconLocation = "$iconPath,0"
$shortcut.Description = 'Run Exchange Postie'
$shortcut.WindowStyle = 1
$shortcut.Save()

Write-Host "Created shortcut: $shortcutPath"
