function global:prompt {
    # Standard PowerShell prompt, but also shows when env:KUBECONFIG is set.
    Write-Host -NoNewline "PS "
    if (Test-Path -Path "env:KUBECONFIG") {
        $segment = "[" + $($env:KUBECONFIG | Split-Path -Leaf) + "] "
        Write-Host -NoNewline -ForegroundColor Yellow $segment
    }
    Write-Host -NoNewline $ExecutionContext.SessionState.Path.CurrentLocation
    return "$('>' * ($NestedPromptLevel + 1)) "
}

# Override HOME to be "Work Folders"
$HOMEDRIVE = "C:\"
$HOMEPATH = "Users\" + $env:USERNAME + "\Work Folders"
Set-Variable HOME "$HOMEDRIVE$HOMEPATH" -Force
Set-Location $HOME

# Add standard POSIX commands to PATH (from Git package).
$env:PATH="C:\Program Files\Git\usr\bin;$env:PATH"

# Remove PowerShell aliases that get in the way of POSIX commands.
foreach ($name in Get-Alias) {
    if (Test-Path -Path "C:\Program Files\Git\usr\bin\$name.exe" -PathType Leaf) {
        # XXX PowerShell 6.0 has a Remove-Alias cmdlet,
        #     but it's not available (yet?) on the SAW.
        Remove-Item -force alias:\$name
    }
}

New-Alias -force -name kubectl -value \"Program Files"\Kubectl\kubectl
New-Alias -force -name kc -value kubectl

# Attempt slow-running jobs in parallel.
$jobs = @()

$jobs += (Start-Job -ScriptBlock {
    try {
        if ((Get-AzContext) -eq $null) {
            Write-Host "Connecting to Azure..."
            Connect-AzAccount 3>$null  # Suppress warning stream
        }
    } catch [System.Management.Automation.CommandNotFoundException] {
        Write-Host -ForegroundColor Yellow "Az.Accounts cmdlets not found. Consider installing Azure PowerShell package."
    }
})

$jobs += (Start-Job -ScriptBlock {
    Write-Output "Logging into Geneva Actions..."
    Login-GenevaActions -Env Public -RefreshToken
    $claims = Get-Claims
    Write-Host -NoNewline "Roles: "
    Write-Host -ForegroundColor Green "$(($claims | Where-Object Value -match "^ARO*").Value -join ', ')"
})

foreach ($job in $jobs) {
    while ($job.HasMoreData -or $job.State -eq "Running") {
        Receive-Job -Job $jobs
        Start-Sleep -Seconds 1
    }
}

# This is where kubeconfig files land.
$env:KUBECONFIGDIR="$env:USERPROFILE\Work Folders\Downloads"

# Delete expired .kubeconfig files in Downloads (older than 6 hours).
Get-ChildItem -Path "$env:KUBECONFIGDIR\*.kubeconfig" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddHours(-6)} | Remove-Item

# Pick up the newest .kubeconfig file in Downloads.
$kubeconfig=$(Get-ChildItem -Path "$env:KUBECONFIGDIR\*.kubeconfig" | Sort-Object -Property LastWriteTime -Descending | Select-Object -Index 0 | Resolve-Path)
if ($kubeconfig) {
    $env:KUBECONFIG=$kubeconfig.ProviderPath
}
