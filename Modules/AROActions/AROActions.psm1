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

function Get-AROKubernetesObject {
    param(
        [string] $location,
        [string] $resourceId,
        [string] $kubeKind = '',
        [string] $kubeNamespace = '',
        [string] $kubeName = '',
        [string] $jmesPath = ''
    )
    try {
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
    param(
        [string] $location,
        [string] $resourceId
    )
    try {
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
    param(
        [string] $location,
        [string] $jmesPath = ''
    )
    try {
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
    param(
        [string] $location,
		[string] $resourceId,
        [string] $jmesPath = ''
    )
    try {
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
    param(
        [string] $location,
        [string] $resourceId,
        [string] $httpMethod,
        [string] $clusterObject
    )
    try {
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
    param(
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


Export-ModuleMember -Function Start-AROJIT, Check-Error, Get-AROKubernetesObject, Get-AROAzureResources, Get-AROClusters, Get-AROCluster, PutOrPatch-Cluster, Upgrade-Cluster, Test-PUCMDone, Get-Min
