# Create_Payloads.ps1
# Script to create the HP SecurePlatformManagement (SPM) and HP Sure Admin (EBAM) payloads 
# EBAM = Enhanced BIOS Authentication Mode
# by Juergen Bayer, Dan Felman
# HP Inc - 11/6/2020
# version 1.0
<#
    This script will create payloads for use by HP SPM and HP Sure Admin (EBAM) activation and deactivation
    Payloads are created and moved to a subfolder .\payloads (by default)

    Assumptions:

    Requires HP CMSL 1.6 or later installed
    Passwords: 
        Certificate passwords: (if used) are in the script - and should be changed accordingly
        BIOS passwords: are in this script, if used currently - and should be changed accordingly

    Names of certificates are hardcoded in script calls... not important to overall operation

    arguments: (chose -spm or -ebam)

        -spm                            # create Secure Platform Management Payloads
        -ebam                           # create HP Sure Admin Payloads
        -CertsPath <path>
        -PayloadsPath <path>
#>
[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false)] [switch]$spm,
    [Parameter(Mandatory=$false)] [switch]$ebam, 
    [Parameter(Mandatory=$false)] [switch]$provision=$true, 
    [Parameter(Mandatory=$false)] [switch]$deprovision=$false, 
    [Parameter(Mandatory=$false)] [string]$CertsPath = $PSScriptRoot+'\certs',
    [Parameter(Mandatory=$false)] [string]$PayloadsPath = $PSScriptRoot+'\payloads',
    [Parameter(Mandatory=$false, ValueFromRemainingArguments)] [Switch]$help
)
#=====================================================================================
# work on command arguments
# if script runs with no arguments or with arg: '-help', just show runstring options

if ( ($PSBoundParameters.count -eq 0) -or ($help) ) {
    "Run script with options >"
    "`n`tCreate_Payloads.ps1 [[-SPM]|[-EBAM]] [-provision|-deprovision] [-CertsPath <path>] [-PayloadsPath <path>] [-h|-help]"
    "`n`tCreate_Payloads.ps1 -SPM                   # To create SPM provision payloads (defaults to -Provision)"
    "`tCreate_Payloads.ps1 -SPM -deprovision      # To create SPM deprovision payloads"
    "`tCreate_Payloads.ps1 -EBAM                  # Create all payloads (defaults to -Provision)"
    "`tCreate_Payloads.ps1 -EBAM -deprovision     # Create all payloads"
    "`n-CertsPath defaults to .\certs"
    "-PayloadsPath defaults to .\payloads"
    exit
} # if ( ($PSBoundParameters.count -eq 0) -or ($help) )

if ( ($spm -and $ebam) -or (-not $spm -and -not $ebam) ) {
    'Please select either -spm or -ebam option'
    exit
}
write-host $deprovision
if ( $deprovision ) {
    $provision = $false
}
#=====================================================================================
$Path = $PSScriptRoot
Set-Location $Path

# paths to the Private Key certs

$EKpfx = "$($certsPath)\EK.pfx"
$SKpfx = "$($certsPath)\SK.pfx"
$LAKpfx = "$($certsPath)\LAK.pfx"

# Certificate and BIOS passwords, if needed modify to suit existing BIOS password, or to add cert passwords

#$EKCertPwd = 'P@ssw0rd'                         # used to protect Endrosement Private Key cert (may not be needed)
$EKCertPwd = ''
# -----
#$SKCertPwd = 'P@ssw0rd'                          # used to protect Signing Private Key cert - IMPORTANT !!!!
$SKCertPwd = ''
# -----
#$LAKCertPwd = 'P@ssw0rd'                        # used to protect Local Access Private Key cert
$LAKCertPwd = ''

# If BIOS passwords are currently used, modify to suit
# --- required to create (and provision) the SPM Endorsement Key

#$BIOSPwd = 'P@ssw0rd'
$BIOSPwd = ''

# modify for organization
$certDN = '/C=US/ST=State/L=City/O=Company/OU=Org/CN=SPMdemo'

#=====================================================================================

# =========================================
# HP Secure Platform management (SPM)
# =========================================

if ( $spm ) {
    # =========================================
    # Create the Endorsement Payload
    # =========================================

    if ( $provision ) {
        write-Output 'Create the Endorsement Provisioning Payload: EKpayload.dat'
        if ( Get-HPBIOSSetupPasswordIsSet ) {
            New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -BIOSPassword $BIOSPwd -OutputFile EKpayload.dat
        } else {
            New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -OutputFile EKpayload.dat
        }
        # =========================================
        # Create the Signing Keys and Payload
        # =========================================
        write-Output 'Create the Signing Key Provisioning Payload: SKpayload.dat'
        New-HPSecurePlatformSigningKeyProvisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -SigningKeyFile $SKpfx -SigningKeyPassword $SKCertPwd -OutputFile SKpayload.dat
    } # if ( $provision )

    if ( $deprovision ) {
        write-Output 'Create the Endorsement Key Deprovisioning Payload: EKDepropayload.dat'
        New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -OutputFile EKDepropayload.dat
    } # if ( $deprovision )

} # if ( $spm )

#=====================================================================================

# HP CMSL Version >=1.6 adds Sure Admin (Enhanced BIOS Authentication Mode) cmdlets

# =========================================
# HP Sure Admin / EBAM
# =========================================

if ( $ebam ) {

    # =========================================
    # Create EBAM Enable & Disable Payloads
    # - for remote AND F10 BIOS access
    # =========================================
    if ( $provision ) {
        write-Output 'Create the Sure Admin Enable Provisioning Payload: SAEnablepayload.dat'
        New-HPSureAdminEnablePayload -SigningKeyFile $SKpfx -SigningKeyPassword $SKCertPwd -OutputFile SAEnablepayload.dat 
        
        write-Output 'Create the Sure Admin LAK Provisioning Payload: LAKpayload.dat'
        New-HPSureAdminLocalAccessKeyProvisioningPayload -SigningKeyFile $SKpfx -SigningKeyPassword $SKCertPwd -LocalAccessKeyFile $LAKpfx -OutputFile LAKpayload.dat 
    }
    if ( $deprovision ) {
        write-Output 'Create the Sure Admin Disable Deprovisioning Payload: SADeproPayload.dat'
        New-HPSureAdminDisablePayload -SigningKeyFile $SKpfx -SigningKeyPassword $SKCertPwd -OutputFile SADisablePayload.dat 

        write-Output 'Create the Sure Admin LAK Deprovisioning Payload: LAKDepropayload.dat'
        New-HPSureAdminBIOSSettingValuePayload -SigningKeyFile $SKpfx -SigningKeyPassword $SKCertPwd -Name "Enhanced BIOS Authentication Mode Local Access Key 1" -Value "" -OutputFile LAKDepropayload.dat
    }

} # if ( $ebam )

#=====================================================================================

# =========================================
# Move required client payloads to folder
# =========================================

write-Output "Moving provisioning Payload files to folder: $($payloadsPath)"
if ( -not (Test-Path -Path $payloadsPath) ) {
    New-Item $payloadsPath -ItemType Directory -Force
}
Move-Item -Path "*.dat" -Destination $payloadsPath -Force

