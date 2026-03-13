param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

foreach ($vm in $config.vms) {
    & (Join-Path $scriptRoot "create-vm.ps1") -ConfigPath $ConfigPath -VmName $vm.name
    & (Join-Path $scriptRoot "start-vm.ps1") -ConfigPath $ConfigPath -VmName $vm.name
}

Write-Host "Lab build completed for $($config.vms.Count) VM(s)."
