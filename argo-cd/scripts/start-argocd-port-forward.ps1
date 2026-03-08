param(
    [int]$LocalPort = 8080,
    [switch]$UseService
)

$ErrorActionPreference = "Stop"

Write-Host "Starting resilient Argo CD port-forward on localhost:$LocalPort"
Write-Host "Press Ctrl+C to stop."

while ($true) {
    try {
        if ($UseService) {
            kubectl -n argocd port-forward svc/argocd-server "$LocalPort`:80"
        }
        else {
            $pod = kubectl -n argocd get pod -l app.kubernetes.io/name=argocd-server -o jsonpath="{.items[0].metadata.name}"
            if ([string]::IsNullOrWhiteSpace($pod)) {
                throw "Could not find argocd-server pod"
            }

            kubectl -n argocd port-forward "pod/$pod" "$LocalPort`:8080"
        }
    }
    catch {
        Write-Warning "Port-forward ended: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 1
    Write-Host "Reconnecting..."
}
