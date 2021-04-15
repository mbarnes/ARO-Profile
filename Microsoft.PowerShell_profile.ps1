New-Alias -force -name kubectl -value \"Program Files"\Kubectl\kubectl
New-Alias -force -name oc -value kubectl

New-Alias -force -name vim -value \"Program Files (x86)"\vim\vim74\vim

Write-Output "Logging into Geneva Actions..."
Login-GenevaActions -Env Public -RefreshToken
$claims = Get-Claims
Write-Host -NoNewline "Roles: "
Write-Host -ForegroundColor Green "$(($claims | Where-Object Value -match "^ARO*").Value -join ', ')"

# This is where kubeconfig files land.
$env:KUBECONFIGDIR="$env:USERPROFILE\Work Folders\Downloads"
Set-Location "$env:KUBECONFIGDIR"

# Pick up the newest .kubeconfig file in Downloads.
$kubeconfig=$(Get-ChildItem -Path "$env:KUBECONFIGDIR\*.kubeconfig" | Sort-Object -Property LastWriteTime -Descending | Select-Object -Index 0 | Resolve-Path)
if ($kubeconfig) {
    $env:KUBECONFIG=$kubeconfig.ProviderPath
    Write-Host "Set KUBECONFIG=$($kubeconfig | Split-Path -Leaf)"
}
