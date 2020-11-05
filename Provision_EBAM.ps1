# Script: Provision_SureAdmin
# by Juergen Bayer, Dan Felman
# HP Inc - 11/5/2020
# Version 1.0

# Script will provision, or deprovision the HP Sure Admin feature Payload
<#
    Assumptions:

    client device requires HP CMSL 1.6 or later installed
    client device has Poweshell script authorization
    Client has HP SPM provisioned

    Provision Steps:
        - make sure HP CMSL 1.6 or later is installed
        - download payload files to device
        - run script/commands as Administrator, with appropriate provision|deprovision runstring action
        - confirm PS scripting is allowed
        - if provisioning, confirm device has been provisioned 'Provisioned'
        - if deprovisioning, script will confirm Sure Admin has been provisioned first

#>
[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false, HelpMessage="Select one of 'Provision|Deprovision'")] 
    [validateNotNullOrEmpty()] [ValidateSet('Provision', 'Deprovision')] 
    [string]$action,
    [Parameter(Mandatory=$false, ValueFromRemainingArguments)]
    [Switch]$help,
    [Parameter(Mandatory=$false)]
    [string]$SAEnable='SAEnablepayload.dat',
    [Parameter(Mandatory=$false)]
    [string]$LAKEnable='LAKpayload.dat',
    [Parameter(Mandatory=$false)]
    [string]$SADisable='SADisablePayload.dat',
    [Parameter(Mandatory=$false)]
    [string]$LAKDisable='LAKDepropayload.dat'
)

if ( ($PSBoundParameters.count -eq 0) -or ($help) ) {
    "Run script with options > "
    "-Provision"
    "`t> Provision_EBAM.ps1 -action provision       # assume provision files in current folder"
    "`t> Provision_EBAM.ps1 -action provision [[-SAEnable <file>] [-LAKEnable <file>]]"
    "`t`tNOTE: If -LAKEnable argument is passed or LAKpayload.dat is in the script folder, it will be provisioned"
    "-Deprovision"
    "`t> Provision_EBAM.ps1 -action deprovision     # assume deprovision files in current folder"
    "`t> Provision_EBAM.ps1 -action deprovision [[-Deprovision <file>]]"
    "`t`tNOTE: If -LAKDisable argument is passed or LAKDepropayload.dat is in the script folder, it will be provisioned"
    exit
}
switch ( $PSBoundParameters.Keys ) {
    'SAEnable' { 
        if ( -not (test-path -Path $PSBoundParameters['SAEnable']) ) {'--- SAEnable file not found'; exit} }
    'LAKEnable' {
        if ( -not (test-path -Path $PSBoundParameters['LAKEnable']) ) {'--- LAKEnable file not found'; exit} }
    'Deprovision' {
        if ( -not (test-path -Path $PSBoundParameters['Deprovision']) ) {'--- Deprovision file not found'; exit} }
}

# find out the status of SPM provisioning

$SPMstate = Get-HPSecurePlatformState
"SPM State: $($SPMstate.state)"             # can return: NotConfigured, Provisioned, ProvisioningInProgress
"SPM Features: $($SPMstate.featuresInUse)"  # can return: None, SureAdmin, SureRecover, SureRun

$path =  $psscriptroot
Set-Location  $path

# ----------------------------------------------------------
<#
    Provision

    Assume provision payload files on script folder, or passed as args
#>
if ( $action -match 'provision' ) {
    'action: provision'

    if ( $SPMstate.state -match 'provisioned' ) {

        if ( -not ($SPMstate.featuresInUse -match 'admin') ) {

            "Provisioning Sure Amdin feature Enable Payload: $($SAEnable)"
            Set-HPSecurePlatformPayload -PayloadFile $SAEnable

            '... Sure Admin Enable provisioning done, next provision Local Access Payload (if available)'
            if ( test-path $LAKEnable ) {
                "Provisioning Sure Amdin Local Access Key: $($LAKEnable)"
                Set-HPSecurePlatformPayload -PayloadFile $LAKEnable
                '... Sure Admin Local Access Key provisioning done'
            } # if ( test-path LAKpayload.dat )

        } else {
            'HP Sure Admin already provisioned on this device'
        } # else if ( -not ($SPMstate.featuresInUse -match 'admin') )

    } else {
        'SPM Provisioning is required for HP Sure Admin to be enabled'
        return -1
    } # else if ( $SPMstate.state -match 'provisioned' )

} #if ( $action -match 'provision' ) {

# ----------------------------------------------------------
<#
    Deprovision

    Assume deprovision payload on machine
#>
if ( $action -match 'deprovision' ) {
    'action: deprovision'

    if ( $SPMstate.state -match 'provisioned' ) {

        if ( $SPMstate.featuresInUse -match 'admin' ) {
            "deprovisiong Sure Admin Feature: $($SADisable)"
            Set-HPSecurePlatformPayload -PayloadFile $SADisable
            '... Sure Admin deprovisioning (disable) done'
            if ( test-path $LAKDisable ) {
                "Provisioning EBAM Local Access Key: $($LAKDisable)"
                Set-HPSecurePlatformPayload -PayloadFile $LAKDisable
                '... Sure Admin Local Access Key deprovisioning done'
            } # if ( test-path LAKDisable.dat )
        } # if ( $SPMstate.featuresInUse -match 'admin' )

    } else {
        'This platform has no Sure Platform provisioning'
        return -1
    }

} # if ( $action -match 'deprovision' )

return 0
