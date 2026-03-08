param(
	[string]$ClusterName = "argocd-local"
)

$ErrorActionPreference = "Stop"

function Assert-Command {
	param([string]$Name)
	if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
		throw "Missing required command: $Name"
	}
}

function Resolve-RepoUrl {
	$remote = (git config --get remote.origin.url)
	if ([string]::IsNullOrWhiteSpace($remote)) {
		throw "No git remote origin found. Set remote.origin.url before running bootstrap."
	}

	if ($remote -match "^git@github.com:(.+?)(?:\.git)?$") {
		return "https://github.com/$($Matches[1]).git"
	}

	if ($remote -match "^https://github.com/.+$") {
		if ($remote.EndsWith(".git")) {
			return $remote
		}

		return "$remote.git"
	}

	throw "Unsupported origin URL format: $remote"
}

Assert-Command kind
Assert-Command kubectl
Assert-Command git

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$kindConfig = Join-Path $repoRoot "argo-cd\cluster\kind-config.yaml"
$argocdIngress = Join-Path $repoRoot "argo-cd\cluster\argocd-server-ingress.yaml"
$appTemplate = Join-Path $repoRoot "argo-cd\cluster\dotnetwebapi-application.yaml"

$clusterExists = (kind get clusters) -contains $ClusterName
if (-not $clusterExists) {
	kind create cluster --name $ClusterName --config $kindConfig
} else {
	Write-Host "kind cluster '$ClusterName' already exists."
}

kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
kubectl wait --namespace ingress-nginx --for=condition=Ready pods --selector=app.kubernetes.io/component=controller --timeout=300s

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
# Work around CRD annotation size limits on some clusters by applying this CRD server-side.
kubectl apply --server-side -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/applicationset-crd.yaml"
kubectl wait --for=condition=Established crd/applicationsets.argoproj.io --timeout=120s
kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deployment argocd-server
kubectl wait --namespace argocd --for=condition=Available deployment/argocd-applicationset-controller --timeout=300s
kubectl wait --namespace argocd --for=condition=Available deployment/argocd-server --timeout=300s
kubectl wait --namespace argocd --for=condition=Available deployment/argocd-repo-server --timeout=300s
kubectl wait --namespace argocd --for=condition=Ready pod -l app.kubernetes.io/name=argocd-redis --timeout=300s

kubectl apply -f $argocdIngress

$repoUrl = Resolve-RepoUrl
$template = Get-Content -Raw -Path $appTemplate
$applicationManifest = $template.Replace("REPLACE_WITH_REPO_URL", $repoUrl)
$applicationManifest | kubectl apply -f -

Write-Host "Bootstrap complete."
Write-Host "Argo CD UI: http://argocd.localdev.me"
Write-Host "API URL: http://dotnetapi.localdev.me/weatherforecast"
Write-Host "Get Argo CD admin password with: ./argo-cd/scripts/get-argocd-admin-password.ps1"
