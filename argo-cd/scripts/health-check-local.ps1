$ErrorActionPreference = "Stop"

function Get-StatusCode {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [hashtable]$Headers
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing -TimeoutSec 10
        return [int]$response.StatusCode
    }
    catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            return [int]$_.Exception.Response.StatusCode
        }

        throw
    }
}

$failed = $false

Write-Host "Checking ingress controller..."
$ingressPods = kubectl -n ingress-nginx get pods --no-headers 2>$null
if (-not $ingressPods) {
    Write-Host "FAIL: ingress-nginx pods not found"
    $failed = $true
}
else {
    Write-Host "OK: ingress-nginx pods found"
}

Write-Host "Checking Argo CD server deployment..."
$argocdReady = kubectl -n argocd get deployment argocd-server -o jsonpath="{.status.availableReplicas}" 2>$null
if ([string]::IsNullOrWhiteSpace($argocdReady) -or $argocdReady -eq "0") {
    Write-Host "FAIL: argocd-server is not available"
    $failed = $true
}
else {
    Write-Host "OK: argocd-server available replicas = $argocdReady"
}

Write-Host "Checking Argo Application status for dotnetwebapi..."
$appSyncStatus = kubectl -n argocd get application dotnetwebapi -o jsonpath="{.status.sync.status}" 2>$null
if ([string]::IsNullOrWhiteSpace($appSyncStatus)) {
    Write-Host "FAIL: Argo application 'dotnetwebapi' not found"
    $failed = $true
}
else {
    Write-Host "INFO: dotnetwebapi sync status = $appSyncStatus"
    if ($appSyncStatus -ne "Synced") {
        $comparisonError = kubectl -n argocd get application dotnetwebapi -o jsonpath="{.status.conditions[?(@.type=='ComparisonError')].message}" 2>$null
        if (-not [string]::IsNullOrWhiteSpace($comparisonError)) {
            Write-Host "INFO: Argo comparison error: $comparisonError"
        }
    }
}
Write-Host "Checking Argo hostless ingress on localhost..."
$argoLocalStatus = Get-StatusCode -Url "http://127.0.0.1/"
if ($argoLocalStatus -ge 200 -and $argoLocalStatus -lt 400) {
    Write-Host "OK: http://127.0.0.1/ returned $argoLocalStatus"
}
else {
    Write-Host "FAIL: http://127.0.0.1/ returned $argoLocalStatus"
    $failed = $true
}

Write-Host "Checking Argo host-based ingress..."
$argoHostStatus = Get-StatusCode -Url "http://127.0.0.1/" -Headers @{ Host = "argocd.localdev.me" }
if ($argoHostStatus -ge 200 -and $argoHostStatus -lt 400) {
    Write-Host "OK: argocd.localdev.me route returned $argoHostStatus"
}
else {
    Write-Host "FAIL: argocd.localdev.me route returned $argoHostStatus"
    $failed = $true
}

Write-Host "Checking API host-based ingress..."
$apiStatus = Get-StatusCode -Url "http://127.0.0.1/weatherforecast" -Headers @{ Host = "dotnetapi.localdev.me" }
if ($apiStatus -eq 200) {
    Write-Host "OK: dotnetapi.localdev.me/weatherforecast returned 200"
}
else {
    Write-Host "FAIL: dotnetapi.localdev.me/weatherforecast returned $apiStatus"
    Write-Host "Hint: ensure Argo application synced and API pods are ready."
    $failed = $true
}

if ($failed) {
    exit 1
}

Write-Host "All checks passed."
