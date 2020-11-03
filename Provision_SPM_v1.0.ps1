# Script: Provision_SPM
# by Juergen Bayer, Dan Felman
# HP Inc - 11/3/2020
# version 1.0
<#
    This script is required to run twice for provisioning of Secure Platform (SPM)
    ... first, to provision the Endorsement Key Payload and reboot (PPI required)
    ... second, to provision the Signing Key Payload (no reboot required)

    Assumptions:

    client device requires HP CMSL 1.6 or later installed
    client device has Poweshell scripting authorization
    Endorsement and Signing Payload files already created and transferred to client
    Payload.dat files created by these CMSL commands on a secure platform
        - New-HPSecurePlatformEndorsementKeyProvisioningPayload
        - New-HPSecurePlatformSigningKeyProvisioningPayload
    This script resides on same folder as payload files (otherwise, provide paths in runstring)

    Provision Steps:
        - install CMSL on device
        - download payload files to device
        - confirm PS scripting is allowed
        - run script as Administrator with '-action provision' option
        - confirm device has not been provisioned 'NotConfigured', deprovision if necessary
          NOTE: reboot is required between Endorsement key provisioning and signing key provisioning

    Deprovision steps:
        - run script/commands as Administrator
        - run script as Administrator with '-action deprovision' option
#>
[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false, HelpMessage="Select one of 'Provision|Deprovision'")] 
    [validateNotNullOrEmpty()]
    [ValidateSet('Provision', 'Deprovision')] 
    [string]$action,
    [Parameter(Mandatory=$false, ValueFromRemainingArguments)]
    [Switch]$help,
    [Parameter(Mandatory=$false)]
    [string]$Endorsement='EKpayload.dat',
    [Parameter(Mandatory=$false)]
    [string]$Signing='SKpayload.dat',
    [Parameter(Mandatory=$false)]
    [string]$Deprovision='EKDepropayload.dat'
)

if ( ($PSBoundParameters.count -eq 0) -or ($help) ) {
    "Run script with options > "
    "`tProvision_SPM.ps1 -action provision | deprovision  # assume files in current folder"
    "`tProvision_SPM.ps1 -action provision [[-Endorsement <file>] [-Signing <file>]] | deprovision [[-Deprovision <file>]]"
    exit
}
# if file path options selected, make sure the file in each arg exists
switch ( $PSBoundParameters.Keys ) {
    'Endorsement' { 
        if ( -not (test-path -Path $PSBoundParameters['Endorsement']) ) {'--- Endorsement file not found'; exit} }
    'Signing' {
        if ( -not (test-path -Path $PSBoundParameters['Signing']) ) {'--- Signing file not found'; exit} }
    'Deprovision' {
        if ( -not (test-path -Path $PSBoundParameters['Deprovision']) ) {'--- Deprovision file not found'; exit} }
}
# by default, if Bitlocker is On, suspend it, as the provision of new cert will change 
$SuspendBitlocker = $true

# find the current status of SPM provisioning

$SPMstate = Get-HPSecurePlatformState
"SPM State: $($SPMstate.state)"             # can return: NotConfigured, Provisioned, ProvisioningInProgress
"SPM Features: $($SPMstate.featuresInUse)"  # can return: None, SureAdmin, SureRecover, SureRun

# and the Bitlocker status

$BitlockerState = Get-BitLockerVolume -MountPoint C:
$BitlockerStatus = $BitlockerState.protectionstatus
"Bitlocker Protection Status: $($BitlockerStatus)" # will return 'On' or 'Off'

$path =  $psscriptroot
Set-Location  $path

<#
    Provision

    Assume provision payload files on script folder or passed as an arg
#>

if ( $action -eq 'provision' ) {
    'action: provision'
    # ----------------------------------------------------------
    # Endorsement Key first - will show ProvisioningInProgress
    # then Signing Key - will show Provisioned

    if ( $SPMstate.state -match 'not' ) {

        "Provisioning SPM EK Payload: $($Endorsement)"
        Set-HPSecurePlatformPayload -PayloadFile $Endorsement

        # deal with Bitlocker now
        if ( $SuspendBitlocker -and ($BitlockerStatus -match 'on') ) {
            $BitlockerState = Suspend-BitLocker -MountPoint C: -RebootCount 1   # 1 = suspend to next reboot
            "Bitlocker Protection Status now: $($BitlockerState.protectionstatus)"
        }
        'Endorsement Key is provisioned. Please reboot, accept PPI and rerun script'
        exit             # to allow reboot, and allow security PPI change in BIOS (PIN shown on reboot)
    
    } else {
        if ( $SPMstate.state -match 'inprogress' ) {
            "Provisioning SPM SK Payload (SPM EK Provisioned), payload: $($Signing)"
            Set-HPSecurePlatformPayload -PayloadFile $Signing
            '...SPM provisioning done'
        } else {
            'SPM already is Provisioned'
        }
    } # else if ( $SPMstate.state -match 'not' )
}

# ----------------------------------------------------------

<#
    Deprovision

    Assume deprovision payloads on machine
#>

if ( $action -eq 'deprovision' ) {
    'action: deprovision'
    # if deprovisioning is needed, deprovision feature first, then SPM
    # (provisioning keys will be required to deprovision)
    if ($SPMstate.featuresInUse -match 'sure') {
        "SPM Deprovisioning can not proceed. Features need deprovisioned first: $($SPMstate.featuresInUse)"
        return -1
    } else {
        "Deprovisioning SPM EK Payload: $($Deprovision)"
        Set-HPSecurePlatformPayload -PayloadFile $Deprovision
        '...SPM deprovisioning done'
    }
} # if ( $action -eq 'deprovision' )

return 0