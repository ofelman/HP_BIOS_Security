# Create_Sure_Payloads.ps1
# Script to create the HP SecurePlatformManagement (SPM) and HP Sure Admin payloads 
# by Juergen Bayer, Dan Felman
# HP Inc - 11/3/2020
# version 1.0
<#
    This script will create payloads for use by HP SPM and HP Sure Admin activation
    Payloads are created and moved to a subfolder

    Assumptions:

    Requires HP CMSL 1.6 or later installed
    Passwords: 
        Certificate passwords (if used) are in the script - and should be changed accordingly
        BIOS passwords are in this script, if used currently - and should be changed accordingly
    Names of certificates are hardcoded in script calls... not important to overall operation

    arguments:

        -spm                            # create Secure Platform Management Payloads
        -sureadmin                      # create HP Sure Admin Payloads
        -payloadfolder <path>           # path to copy payloads to (defaults to '.\Payloads'

#>
[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false)] 
    [switch]$spm,
    [Parameter(Mandatory=$false)] 
    [switch]$sureadmin, 
    [Parameter(Mandatory=$false, ValueFromRemainingArguments)]
    [Switch]$help
)
#=====================================================================================
# work on command arguments
# if script runs with no arguments or with arg: '-help', just show runstring options

if ( ($PSBoundParameters.count -eq 0) -or ($help) ) {
    "Run script with options > "
    "`tCreate_BIOS_Certs.ps1 [-SPM] [-SureAdmin] [-h|-help]"
    "`tCreate_BIOS_Certs.ps1 -SPM                  # To create only SPM payloads"
    "`tCreate_BIOS_Certs.ps1 -SPM -SureAdmin       # Create all payloads"
    exit
} # if ( ($PSBoundParameters.count -eq 0) -or ($help) )

#=====================================================================================
$Path = $PSScriptRoot
Set-Location $Path
$payloadPath = "$($Path)\payloads"                 # where to put the SPM/Sure Admin payload files

$EKpfx = '.\certs\EK.pfx'
$SKpfx = '.\certs\SK.pfx'
$LAKpfx = '.\certs\LAK.pfx'

# Certificate and BIOS passwords, if needed modify to suit existing BIOS password, or to add cert passwords

#$SKCertPwd = 'P@ssw0rd'                                  # used to protect Signing Private Key cert
$SKCertPwd = ''
#$LAKCertPwd = 'P@ssw0rd'                                 # used to protect Local Access Private Key cert
$LAKCertPwd = ''

#$BIOSPwd = 'P@ssw0rd'
$BIOSPwd = ''

# modify for organization
$certDN = '/C=US/ST=State/L=City/O=Company/OU=Org/CN=SPMdemo'

$Show_CertsInfo = $true                                   # display cert info after creation

#=====================================================================================

# HP CMSL Version >=1.6 provides SPM/Sure Admin cmdlets

# =========================================
# HP Secure Platform management (SPM)
# =========================================

if ( $spm ) {
    # =========================================
    # Create the Endorsement Payload
    # =========================================

    #write-Output 'Create the Endorsement Provisioning Payload: EKpayload.dat (with HP CMSL)'
    if ( Get-HPBIOSSetupPasswordIsSet ) {
        New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -BIOSPassword $BIOSPwd -OutputFile EKpayload.dat
    } else {
        New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -OutputFile EKpayload.dat
    }
    write-Output 'Create the Endorsement Key Deprovisioning Payload: EKDepropayload.dat (with HP CMSL)'
    New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -OutputFile EKDepropayload.dat

    # =========================================
    # Create the Signing Keys and Payload
    # =========================================

    write-Output 'Create the Signing Key ProvisioningKey Payload: SKpayload.dat (with HP CMSL)'
    New-HPSecurePlatformSigningKeyProvisioningPayload -EndorsementKeyFile $EKpfx -EndorsementKeyPassword $EKCertPwd -SigningKeyFile $SKpfx -SigningKeyPassword $SKCertPwd -OutputFile SKpayload.dat
}

#=====================================================================================

# =========================================
# HP Sure Admin
# =========================================

if ( $sureadmin ) {

    # =========================================
    # Create Sure Admin Enable & Disable Payloads
    # - for remote access to F10 BIOS
    # =========================================
    write-Output 'Create the Sure Admin Enable Provisioning Payload: SApayload.dat (with HP CMSL)'
    New-HPSureAdminEnablePayload -SigningKeyFile $SKpfx -OutputFile SAEnablepayload.dat 
    write-Output 'Create the Sure Admin Disable Deprovisioning Payload: SADeproPayload.dat (with HP CMSL)'
    New-HPSureAdminDisablePayload -SigningKeyFile $SKpfx -OutputFile SADisablePayload.dat 

    write-Output 'Create the Sure Admin LAK Provisioning Payload: LAKpayload.dat (with HP CMSL)'
    New-HPSureAdminLocalAccessKeyProvisioningPayload -SigningKeyFile $SKpfx -LocalAccessKeyFile $LAKpfx -OutputFile LAKpayload.dat 
    write-Output 'Create the Sure Admin LAK Deprovisioning Payload: LAKDepropayload.dat (with HP CMSL)'
    New-HPSureAdminBIOSSettingValuePayload -SigningKeyFile $SKpfx -Name "Enhanced BIOS Authentication Mode Local Access Key 1" -Value "" -OutputFile LAKDepropayload.dat

}

#=====================================================================================

# =========================================
# Move required client payloads to folder
# =========================================

write-Output "Moving provisioning Payload files to folder: $($payloadPath)" -ForegroundColor Gray
if ( -not (Test-Path -Path $payloadPath) ) {
    New-Item $payloadPath -ItemType Directory -Force
}
Move-Item -Path "*.dat" -Destination $payloadPath -Force

