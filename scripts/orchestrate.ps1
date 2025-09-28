\
    # Phased orchestration
    . "$PSScriptRoot\\prep.ps1"
    vagrant up GW01 --provider=hyperv
    . "$PSScriptRoot\\..\\modules\\gateway\\verify.ps1"
    vagrant up --provider=hyperv
    Write-Host "[✓] Orchestration phase complete."
