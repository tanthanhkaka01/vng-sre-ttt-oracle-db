param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$VmName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }
    return Get-Content -Raw -Path $Path | ConvertFrom-Json
}

function Get-VmDefinition {
    param($Config, [string]$Name)
    $vm = $Config.vms | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if (-not $vm) {
        throw "VM name not found in config: $Name"
    }
    return $vm
}

function Update-VmxValue {
    param(
        [string]$Path,
        [string]$Key,
        [string]$Value
    )

    $content = Get-Content -Path $Path
    $replacement = '{0} = "{1}"' -f $Key, $Value
    $found = $false

    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i] -match ('^{0}\s*=' -f [regex]::Escape($Key))) {
            $content[$i] = $replacement
            $found = $true
        }
    }

    if (-not $found) {
        $content += $replacement
    }

    Set-Content -Path $Path -Value $content
}

function Remove-VmxKeys {
    param(
        [string]$Path,
        [string[]]$Patterns
    )

    $content = Get-Content -Path $Path
    $filteredContent = foreach ($line in $content) {
        $skipLine = $false
        foreach ($pattern in $Patterns) {
            if ($line -match $pattern) {
                $skipLine = $true
                break
            }
        }

        if (-not $skipLine) {
            $line
        }
    }

    Set-Content -Path $Path -Value $filteredContent
}

$config = Get-Config -Path $ConfigPath
$vm = Get-VmDefinition -Config $config -Name $VmName

if (-not (Test-Path $config.templatePath)) {
    throw "Template path not found: $($config.templatePath)"
}

if (Test-Path $vm.destinationPath) {
    throw "Destination already exists: $($vm.destinationPath)"
}

Copy-Item -Path $config.templatePath -Destination $vm.destinationPath -Recurse

$vmxFiles = Get-ChildItem -Path $vm.destinationPath -Filter *.vmx
if ($vmxFiles.Count -ne 1) {
    throw "Expected exactly one VMX file in $($vm.destinationPath)"
}

$oldVmxPath = $vmxFiles[0].FullName
$newVmxPath = Join-Path $vm.destinationPath $vm.vmxName
Rename-Item -Path $oldVmxPath -NewName $vm.vmxName

Remove-VmxKeys -Path $newVmxPath -Patterns @(
    '^uuid\.bios\s*=',
    '^uuid\.location\s*=',
    '^ethernet\d+\.generatedAddress\s*=',
    '^ethernet\d+\.generatedAddressOffset\s*=',
    '^ethernet\d+\.addressType\s*='
)

Update-VmxValue -Path $newVmxPath -Key "displayName" -Value $vm.name
Update-VmxValue -Path $newVmxPath -Key "memsize" -Value ([string]$vm.memoryMb)
Update-VmxValue -Path $newVmxPath -Key "numvcpus" -Value ([string]$vm.numVcpus)
Update-VmxValue -Path $newVmxPath -Key "uuid.action" -Value "create"
Update-VmxValue -Path $newVmxPath -Key "msg.autoAnswer" -Value "TRUE"

Write-Host "VM created successfully: $($vm.name)"
Write-Host "VMX path: $newVmxPath"
