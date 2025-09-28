\
    $env:VM_VSWITCH = $env:VM_VSWITCH ?? "VM-Net"
    . "$PSScriptRoot\\..\\modules\\network\\ensure.ps1"
    . "$PSScriptRoot\\..\\modules\\network\\verify.ps1"
    Write-Host "[✓] Prep complete."
