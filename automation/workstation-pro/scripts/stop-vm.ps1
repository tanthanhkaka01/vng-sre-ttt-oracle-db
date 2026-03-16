param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$VmName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$vm = $config.vms | Where-Object { $_.name -eq $VmName } | Select-Object -First 1

if (-not $vm) {
    throw "VM name not found in config: $VmName"
}

if (-not (Test-Path $config.vmrunPath)) {
    throw "vmrun.exe not found: $($config.vmrunPath)"
}

$vmxPath = Join-Path $vm.destinationPath $vm.vmxName
if (-not (Test-Path $vmxPath)) {
    throw "VMX file not found: $vmxPath"
}

& $config.vmrunPath stop $vmxPath soft
Write-Host "VM stopped: $VmName"
