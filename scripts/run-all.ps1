\
    $ErrorActionPreference="Stop"
    . "$PSScriptRoot\\prep.ps1"
    vagrant up GW01 --provider=hyperv
    . "$PSScriptRoot\\..\\modules\\gateway\\verify.ps1"
    vagrant up --provider=hyperv
    . "$PSScriptRoot\\bench.ps1" -Requests 300 -Concurrency 15 -Endpoint "/info"
