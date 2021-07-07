Import-Module JITShell -DisableNameChecking
Import-Module GenevaActionsCmdlets

function Start-AROJIT {
    <#
    .SYNOPSIS
        Checks and if necessary requests ARO-PlatformServiceAdministrator permissions from JITAccess.

    .PARAMETER ticket
        The IcM ticket number to use in a JIT request if a new JIT request is required.

    .PARAMETER justification
        The Justification text message to use in a JIT request if a new JIT request is required.

    .PARAMETER source
        The source of work items, defaults to "IcM", can be also set to "Other". For example parameter values check the "Automation Scripts - aka Search Criterion" tab in the bottom of aka.ms/jitaccess > Submit request after "Validate Resource" completed.

    .NOTES
        Read https://aka.ms/jitshell if you'd like to modify or develop this function.
    #>
    param(
        [int] $ticket,
        [string] $justification,
        [string] $source = 'IcM'
    )
    Login-GenevaActions -Env Public -RefreshToken
    $claims = Get-Claims
    if (-not ($claims |Where-Object {$_.Value -eq 'ARO-PlatformServiceAdministrator'})) {
        Write-Output 'Missing Access role claim - requesting new access via JIT'
        $jitrequest = New-JITRequest -env product -src $source -wid $ticket -Justification $justification -rtype DstsCtrls -stype ACIS -ins production,production -scp ARO   -AccessLevel PlatformServiceAdministrator -ver 2015-09-07.1.0
        $phase = (Get-JITRequest -id $jitrequest.id -Env product -ver $jitrequest.apiVersion -IncludeStateTransitionRecordList).StateTransitionRecords[0].Phase
        while (! @('Granted','Rejected','NotifyWait') -contains $phase) {
            Write-Output 'Waiting for JIT Access...'
            sleep 5
            $phase = (Get-JITRequest -id $jitrequest.id -Env product -ver $jitrequest.apiVersion -IncludeStateTransitionRecordList).StateTransitionRecords[0].Phase
        }
        if ($phase -eq 'Rejected') {
            Write-Warning 'JIT Access Request Rejected - Aborting'
            exit
        }
        if ($phase -eq 'NotifyWait') {
            Write-Warning 'JIT Access Request Needs Manual Approval - Notified approvers, Stopping script, restart script when approved'
            exit
        }
    }
    Login-GenevaActions -Env Public -RefreshToken
}

function Check-Error {
    param(
        [object] $gares
    )
    if ($gares.Status -eq 'Failed') {
        Write-Warning 'Error while invoking Geneva Action'
        Write-Output $gares.ResultMessage
        exit
    }
}

function Get-AROLocation {
    <#
    .SYNOPSIS
        Gets all Azure locations that include a "Microsoft.RedHatOpenShift" provider
    #>
    param()
    Get-AzLocation | Where-Object Providers -contains "Microsoft.RedHatOpenShift"
}

function Get-AROKubernetesObject {
    <#
    .SYNOPSIS
        Returns one or more Kubernetes objects from an OpenShift cluster

    .PARAMETER location
        The Azure location of the OpenShift cluster. (A valid location must include a "Microsoft.RedHatOpenShift" provider.)

    .PARAMETER resourceId
        The Azure resource ID of the OpenShift cluster.

    .PARAMETER kubeKind
        The kind of OpenShift object to get (e.g. node, pod, configmap, etc.).

    .PARAMETER kubeNamespace
        The OpenShift namespace from which to get objects.

    .PARAMETER kubeName
        The name of the OpenShift object to get.

    .PARAMETER jmesPath
        The JMESPath query to apply to the JSON output. (See https://jmespath.org for proper syntax.)

    .NOTES
        This wrappers the "GetKubernetesObjects" Geneva action.
    #>
    param(
        [ValidateScript(
            {
                # Only validate if an Azure context is available.
                (Get-AzContext) -eq $null -or $_ -in (Get-AROLocation | ForEach-Object {$_.Location})
            }
        )]
        [string] $location,
        [string] $resourceId,
        [string] $kubeKind = '',
        [string] $kubeNamespace = '',
        [string] $kubeName = '',
        [string] $jmesPath = ''
    )
    try {
        $location = $location.ToLower()  # Endpoint param is case-sensitive
        $gares = Invoke-GenevaActionsOperation -Extension 'Azure Red Hat OpenShift (ARO)' -Operation GetKubernetesObjects -Endpoint $location -_smeresourceid $resourceId -_smekubekind $kubeKind -_smekubenamespace $kubeNamespace -_smekubename $kubeName -_smejmespath $jmesPath -_smejsonmode true
    }
    catch {
        Write-Warning 'Exception when invoking Geneva Action'
        Write-Output $PSItem
        exit
    }
    $gares
}

function Get-AROAzureResources {
    <#
    .SYNOPSIS
        Returns the Azure resources of an OpenShift cluster

    .PARAMETER location
        The Azure location of the OpenShift cluster. (A valid location must include a "Microsoft.RedHatOpenShift" provider.)

    .PARAMETER resourceId
        The Azure resource ID of the OpenShift cluster.

    .NOTES
        This wrappers the "ListClusterResources" Geneva action.
    #>
    param(
        [ValidateScript(
            {
                # Only validate if an Azure context is available.
                (Get-AzContext) -eq $null -or $_ -in (Get-AROLocation | ForEach-Object {$_.Location})
            }
        )]
        [string] $location,
        [string] $resourceId
    )
    try {
        $location = $location.ToLower()  # Endpoint param is case-sensitive
        $gares = Invoke-GenevaActionsOperation -Extension 'Azure Red Hat OpenShift (ARO)' -Operation ListClusterResources -Endpoint $location -_smeresourceid $resourceId -_smejsonmode true
    }
    catch {
        Write-Warning 'Exception when invoking Geneva Action'
        Write-Output $PSItem
        exit
    }
    $gares
}

function Get-AROClusters {
    <#
    .SYNOPSIS
        Lists OpenShift clusters in a given Azure location

    .PARAMETER location
        The Azure location to get OpenShift clusters from. (A valid location must include a "Microsoft.RedHatOpenShift" provider.)

    .PARAMETER jmesPath
        The JMESPath query to apply to the JSON output. (See https://jmespath.org for proper syntax.)

    .NOTES
        This wrappers the "ListClusters" Geneva action.
    #>
    param(
        [ValidateScript(
            {
                # Only validate if an Azure context is available.
                (Get-AzContext) -eq $null -or $_ -in (Get-AROLocation | ForEach-Object {$_.Location})
            }
        )]
        [string] $location,
        [string] $jmesPath = ''
    )
    try {
        $location = $location.ToLower()  # Endpoint param is case-sensitive
        $gares = Invoke-GenevaActionsOperation -Extension 'Azure Red Hat OpenShift (ARO)' -Operation ListClusters -Endpoint $location -_smejmespath $jmesPath -_smejsonmode true
    }
    catch {
        Write-Warning 'Exception when invoking Geneva Action'
        Write-Output $PSItem
        exit
    }
    $gares
}

function Get-AROCluster {
    <#
    .SYNOPSIS
        Returns an OpenShift cluster

    .PARAMETER location
        The Azure location of the OpenShift cluster. (A valid location must include a "Microsoft.RedHatOpenShift" provider.)

    .PARAMETER resourceId
        The Azure resource ID of the OpenShift cluster.

    .PARAMETER jmesPath
        The JMESPath query to apply to the JSON output. (See https://jmespath.org for proper syntax.)

    .NOTES
        This wrappers the "GetCluster" Geneva action.
    #>
    param(
        [ValidateScript(
            {
                # Only validate if an Azure context is available.
                (Get-AzContext) -eq $null -or $_ -in (Get-AROLocation | ForEach-Object {$_.Location})
            }
        )]
        [string] $location,
        [string] $resourceId,
        [string] $jmesPath = ''
    )
    try {
        $location = $location.ToLower()  # Endpoint param is case-sensitive
        $gares = Invoke-GenevaActionsOperation -Extension 'Azure Red Hat OpenShift (ARO)' -Operation GetCluster -Endpoint $location -_smeresourceid $resourceId -_smejsonmode true
    }
    catch {
        Write-Warning 'Exception when invoking Geneva Action'
        Write-Output $PSItem
        exit
    }
    $gares
}

function PutOrPatch-Cluster {
    <#
    .SYNOPSIS
        Puts or patches an OpenShift cluster

    .PARAMETER location
        The Azure location of the OpenShift cluster. (A valid location must include a "Microsoft.RedHatOpenShift" provider.)

    .PARAMETER resourceId
        The Azure resource ID of the OpenShift cluster.

    .PARAMETER httpMethod
        The HTTP method to invoke (PUT or PATCH).

    .PARAMETER clusterObject
        The PUT or PATCH method payload, in YAML format.

    .NOTES
        This wrappers the "PutOrPatchCluster" Geneva action.
    #>
    param(
        [ValidateScript(
            {
                # Only validate if an Azure context is available.
                (Get-AzContext) -eq $null -or $_ -in (Get-AROLocation | ForEach-Object {$_.Location})
            }
        )]
        [string] $location,
        [string] $resourceId,
        [ValidateSet("PUT", "PATCH")]
        [string] $httpMethod,
        [string] $clusterObject
    )
    try {
        $location = $location.ToLower()  # Endpoint param is case-sensitive
        $gares = Invoke-GenevaActionsOperation -Extension 'Azure Red Hat OpenShift (ARO)' -Operation PutOrPatchCluster -Endpoint $location -_smeresourceid $resourceId -_smehttpmethod $httpMethod -_smeclusterobject $clusterObject -_smejsonmode true
    }
    catch {
        Write-Warning 'Exception when invoking Geneva Action'
        Write-Output $PSItem
        exit
    }
    $gares
}

function Upgrade-Cluster {
    <#
    .SYNOPSIS
        Upgrades an OpenShift cluster

    .PARAMETER location
        The Azure location of the OpenShift cluster. (A valid location must include a "Microsoft.RedHatOpenShift" provider.)

    .PARAMETER resourceId
        The Azure resource ID of the OpenShift cluster.

    .NOTES
        This wrappers the "UpgradeCluster" Geneva action.
    #>
    param(
        [ValidateScript(
            {
                # Only validate if an Azure context is available.
                (Get-AzContext) -eq $null -or $_ -in (Get-AROLocation | ForEach-Object {$_.Location})
            }
        )]
        [string] $location,
        [string] $resourceId
    )
    try {
        $gares = Invoke-GenevaActionsOperation -Extension 'Azure Red Hat OpenShift (ARO)' -Operation UpgradeCluster -Endpoint $location -_smeresourceid $resourceId -_smeclusterobject '{}' -_smeupgradey false -_smejsonmode true
    }
    catch {
        Write-Warning 'Exception when invoking Geneva Action'
        Write-Output $PSItem
        exit
    }
    $gares
}

function Ensure-AROClusterParameters {
    <#
    .SYNOPSIS
        Tries to infer missing -location and -resourceId parameters

    .PARAMETER location
        The value of another -location parameter, which may be an empty string.

    .PARAMETER resourceId
        The value of another -resourceId parameter, which may be an empty string.

    .DESCRIPTION
        If either the "location" or "resourceId" parameters are empty strings,
        attempt to infer their values if the following conditions are met:

        1. The "kubectl" package must be installed.
        2. The KUBECONFIG environment variable must be set.
        3. The value of KUBECONFIG must be the path of an existing file.

        If these conditions are met then "kubectl.exe" is invoked to obtain
        the cluster's "cluster" object, from which the location and resource ID
        can be extracted.

        If any of these conditions are not met, then an exception is thrown.

        If successful, or if both parameters were non-empty strings to begin with,
        return both "location" and "resourceId" strings.
    #>
    param(
        [string] $location = "",
        [string] $resourceId = ""
    )

    if ($location -eq "" -or $resourceId -eq "") {
        if (Test-Path -Path C:\"Program Files"\Kubectl\kubectl.exe -PathType Leaf) {
            if ((Test-Path -Path env:KUBECONFIG) -and (Test-Path -Path $env:KUBECONFIG -PathType Leaf)) {
                $cluster = (C:\"Program Files"\Kubectl\kubectl.exe get cluster cluster --output=json | ConvertFrom-Json)
                Write-Host -NoNewLine "Infering cluster from env:KUBECONFIG ("
                Write-Host -NoNewLine -ForegroundColor Green ($env:KUBECONFIG | Split-Path -Leaf)
                Write-Host ")"
                if ($location -eq "") {
                    $location = ($cluster).Spec.Location
                }
                if ($resourceId -eq "") {
                    $resourceId = ($cluster).Spec.ResourceId
                }
                return $location, $resourceId
            }
        }
        throw "Both -location and -resourceId parameters are required unless "`
            + "the Kubectl package is installed and env:KUBECONFIG is set to "`
            + "the path of a usable .kubeconfig file"
    }

    return $location, $resourceId
}

# Returns true if the last PUCM was successful and the RP version matches
# Used by both PUCM and Cluster Upgrade scripts
function Test-PUCMDone {
    param(
        [PSCustomObject] $cluster,
        [string] $rpCommit
    )

	if ($cluster.properties.provisionedBy -eq $rpCommit -and ($cluster.properties.provisioningState -eq 'Succeeded' -or ($cluster.properties.provisioningState -eq 'Failed' -and $cluster.properties.failedProvisioningState -eq 'Updating'))) {
		return $true
	} else {
		return $false
	}
}

# Simple Math.Min function
function Get-Min {
    param(
        [int] $x,
        [int] $y
    )

    if ($x -lt $y) {
        return $x
    } else {
        return $y
    }
}

Export-ModuleMember -Function Start-AROJIT, Check-Error, Get-AROLocation, Get-AROKubernetesObject, Get-AROAzureResources, Get-AROClusters, Get-AROCluster, PutOrPatch-Cluster, Upgrade-Cluster, Test-PUCMDone, Get-Min, Ensure-AROClusterParameters
