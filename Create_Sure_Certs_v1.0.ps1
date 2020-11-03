# Create_Sure_Certs.ps1
# Script to create the HP SecurePlatformManagement (SPM) and HP Sure Admin certificates 
# by Juergen Bayer, Dan Felman
# HP Inc - 11/3/2020
# version 1.0
<#
    OpenSSL is used by this script to generate certificates
    - openssl download (use for testing): https://sourceforge.net/projects/openssl-for-windows/
    - openssl man page: https://www.openssl.org/docs/manpages.html
    - good info on hashes/cryptographics functions: https://opensource.com/article/19/6/cryptography-basics-openssl-part-2

    This script will create certificates and payloads for use by HP SPM and HP Sure Admin activation
    Payloads are created and copied to a folder (default: C:\Payloads)

    Assumptions:

    Requires HP CMSL 1.6 or later installed
    Passwords: 
        Certificate passwords (if used) are in the script - and should be changed accordingly
        BIOS passwords are in this script, if used currently - and should be changed accordingly
    Names of certificates are hardcoded in script calls... not important to overall operation

    variable: $Show_CertsInfo           # will show information of created certificates (Default: $true)

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
    "`tCreate_BIOS_Certs.ps1 -SPM                  # To create only (certs and) SPM payloads"
    "`tCreate_BIOS_Certs.ps1 -SPM -SureAdmin       # Create (certs and) all payloads"
    exit
} # if ( ($PSBoundParameters.count -eq 0) -or ($help) )

#=====================================================================================
$Path = $PSScriptRoot
Set-Location $Path
$certsPath = "$($Path)\certs"                      # where to put the certificates created
$payloadPath = "$($Path)\payloads"                 # where to put the SPM/Sure Admin payload files

$OpenSSL_binPath = 'C:\OpenSSL-1.1.1h_win32'

if ((Get-Command "OpenSSL.exe" -ErrorAction SilentlyContinue) -eq $null) { 
    Write-Output "Adding OpenSSL.exe to the PATH"    
    $env:Path += ";$($OpenSSL_binPath)"                   # add Path to OpenSSL.exe - modify openssl.exe path as needed
}
if ((Get-Command "OpenSSL.exe" -ErrorAction SilentlyContinue) -eq $null) { 
   Write-Output "Unable to find OpenSSL.exe in your PATH. Please update in script" -ForegroundColor Red
   exit
}

# !!!! openssl requires access to its configuration file !!!!
$env:OPENSSL_CONF = (Split-Path -Path (get-command openssl.exe).source)+'\openssl.cnf'

# Certificate and BIOS passwords, if needed modify to suit existing BIOS password, or to add cert passwords

#$EKCertPwd = 'P@ssw0rd'                                  # used to protect Endorsement Private Key cert
$EKCertPwd = ''
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
<#
    Function Create_Certs
    
    args:
        $pCertPath_pem           # name of (Private Enhanced Mail) file to create, contains self-signed certificate
        $pCertPath_crt           # name of certificate file to create
        $pCertPath_pfx           # name of certificate private key (includes certificate)
        $pCertDN_subj            # information to add to add to x509 certificate
        $pCert_name              # name to give the pfx private cert
        $pCert_pwd               # password to add to pfx certificate

#>
Function Create_Certs {
    [CmdletBinding()]
	param( $pCertPath_pem,
        $pCertPath_crt, 
        $pCertPath_pfx,
        $pCertDN_subj,
        $pCert_name,
        $pCert_pwd )
    <#
    NOTES: The openssl '-subj' parameter should be updated to reflect information specifc to your organization. 
               If you do not include this parameter, openssl will prompt you for the information.
           -X509: means sign certificate as CA according to RFC 5280
           -nodes: means no DES (private key not passowrd protected)
           -newkey: add provate key, what format to use for encryption (here is rsa:2048)
           -keyout: exports the Private key
           -out: exports self-signed certificate
           cert file in PEM format: https://www.openssl.org/docs/manmaster/man1/openssl.html
              (a block of base-64 encoding with specific lines used to mark the start and end)
 
           NOTE: The PKCS#12 format is an archival file that stores both the certificate and the private key. 
           - This format is useful for migrating certificates and keys from one system to another as it contains all the necessary files. 
           - (PKCS#12 files use either the .pfx or .p12 file extension)

           https://www.openssl.org/docs/manmaster/man1/openssl-pkcs8.html - explanation of encryption algorithms (e.g. PBE-SHA1-3DES)

    NOTES: The files EK.pem and EKcert.crt are temp files that could be securely discarded.
            The private key in EK.pfx is not protected if no export password has been provided.
    #>

    write-Output "-> STEP 1: Create self-signed key pair certificate: $pCertPath_pem"
    openssl.exe req -x509 -nodes -newkey rsa:2048 -keyout $pCertPath_pem -out $pCertPath_crt -days 3650 -subj $pCertDN_subj 2>out-null

    write-Output "-> Step 2: Convert self-signed public certificate to PKCS#12 format: $pCertPath_pfx"
    openssl.exe pkcs12 -inkey $pCertPath_pem -in $pCertPath_crt -export -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -out $pCertPath_pfx -name $pCert_name -passout pass:$pCert_pwd 2>out-null

    if ( $Script:Show_CertsInfo ) {
        openssl.exe x509 -in $pCertPath_crt -text -noout -purpose      # Print Certificate Purpose
        openssl.exe rsa -text -in $pCertPath_pem -noout                # vew Private Key info
    }

} # Function Create_Certs

#=====================================================================================

# HP CMSL Version >=1.6 provides SPM/Sure Admin cmdlets

# =========================================
# HP Secure Platform management (SPM)
# =========================================

if ( $spm ) {
    # =========================================
    # Create the Endorsement Keys and Payload
    # =========================================

    write-Output 'Create SPM Endorsement key certificate'
    Create_Certs "EKpriv.pem" "EKcert.crt" "EK.pfx" $CertDN 'SPM Endorsement Key Certificate' $EKCertPwd
    write-Output 'Create the Endorsement Provisioning Payload: EKpayload.dat (with HP CMSL)'
    if ( Get-HPBIOSSetupPasswordIsSet ) {
        New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile EK.pfx -EndorsementKeyPassword $EKCertPwd -BIOSPassword $BIOSPwd -OutputFile EKpayload.dat
    } else {
        New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile EK.pfx -EndorsementKeyPassword $EKCertPwd -OutputFile EKpayload.dat
    }
    write-Output 'Create the Endorsement Key Deprovisioning Payload: EKDepropayload.dat (with HP CMSL)'
    New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile EK.pfx -EndorsementKeyPassword $EKCertPwd -OutputFile EKDepropayload.dat

    # =========================================
    # Create the Signing Keys and Payload
    # =========================================

    write-Output 'Create SPM Signing key certificate'
    Create_Certs "SKpriv.pem" "SKcert.crt" "SK.pfx" $CertDN 'SPM Signing Key Certificate' $SKCertPwd
    write-Output 'Create the Signing Key ProvisioningKey Payload: SKpayload.dat (with HP CMSL)'
    New-HPSecurePlatformSigningKeyProvisioningPayload -EndorsementKeyFile EK.pfx -EndorsementKeyPassword $EKCertPwd -SigningKeyFile SK.pfx -SigningKeyPassword $SKCertPwd -OutputFile SKpayload.dat
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
    New-HPSureAdminEnablePayload -SigningKeyFile SK.pfx -OutputFile SAEnablepayload.dat 
    write-Output 'Create the Sure Admin Disable Deprovisioning Payload: SADeproPayload.dat (with HP CMSL)'
    New-HPSureAdminDisablePayload -SigningKeyFile SK.pfx -OutputFile SADisablePayload.dat 

    # =========================================
    # Create Sure Admin Local Access Signing Key
    # - for local F10 access to BIOS
    # =========================================
    write-Output 'Create Sure Admin Local Access certificate'
    Create_Certs "LAK.pem" "LAKcert.crt" "LAK.pfx" $CertDN 'EBAM Local Access Signing Key Certificate' $LAKCertPwd

    # NOTE: Next command ONLY needed if asking a CA for the CRT certificate
    # create CSR (Certificate Signing Request) { -subj avoids asking for info }
    write-Output '-> STEP 1a: Create Local Access Signing Key CSR for Sure Admin (if needed for sending request to CA)'
    openssl.exe req -new -key "LAK.pem" -out "LAK.csr" -subj $certDN
    if ( $Script:Show_CertsInfo ) {
        write-output '-> STEP 1a: Verify CSR for Sure Admin'
        openssl req -text -in LAK.csr -noout -verify 2>&1 | Write-Output
    }

    write-Output 'Create the Sure Admin LAK Provisioning Payload: LAKpayload.dat (with HP CMSL)'
    New-HPSureAdminLocalAccessKeyProvisioningPayload -SigningKeyFile SK.pfx -LocalAccessKeyFile LAK.pfx -OutputFile LAKpayload.dat 
    write-Output 'Create the Sure Admin LAK Deprovisioning Payload: LAKDepropayload.dat (with HP CMSL)'
    New-HPSureAdminBIOSSettingValuePayload -SigningKeyFile SK.pfx -Name "Enhanced BIOS Authentication Mode Local Access Key 1" -Value "" -OutputFile LAKDepropayload.dat

    # =========================================
    # Create Local Access Signing Key QR Code (for phone app)
    # =========================================
    if ( Get-Command 'Convert-HPSureAdminCertToQRCode' -ErrorAction SilentlyContinue ) {
        write-Output 'Convert LAK certificate to QR Code (with HP CMSL)'
        Convert-HPSureAdminCertToQRCode -LocalAccessKeyFile .\LAK.pfx -OutputFile .\LAK_QRCode.jpg -LocalAccessKeyPassword $LAKCertPwd -Passphrase $LAKCertPwd # -ViewAs Image 
        Start-Sleep -s 1             # wait for QR code image to open 
    } else {
        write-Output '-> Please update HP CMSL to version 1.6 or later for QR Code conversion cmdlet' -ForegroundColor Red
    }

    write-Output 'Checking hashes next to verify LAK certificate keys match !!!'
    $pemhash = openssl rsa -modulus -in "LAK.pem" -noout | openssl.exe sha256
    $csrhash = openssl req -modulus -in "LAK.csr" -noout | openssl.exe sha256          # check CSR cert (if needed to ask a CA)
    $crthash = openssl x509 -modulus -in "LAKcert.crt" -noout | openssl.exe sha256     # check cert returned by CA
    if ( ($pemhash -eq $csrhash) -and ($pemhash -eq $crthash) ) {
         write-Output 'Local Access Key PEM, CSR,and CRT certificate hashes match'
    } else {
         write-Output 'Error creating Local Access Key certs'
    }
    if ( $Script:Show_CertsInfo ) {
        "key modules hash: $pemhash"
    }
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

# =========================================
# move required certificates to folder
# =========================================

write-Output "Moving certificate files to folder: $($certsPath)" -ForegroundColor Gray
if ( -not (Test-Path -Path $certsPath) ) {
    New-Item $certsPath -ItemType Directory -Force
}
Move-Item -Path "*.pfx" -Destination $certsPath -Force
Move-Item -Path "*.pem" -Destination $certsPath -Force
Move-Item -Path "*.csr" -Destination $certsPath -Force
Move-Item -Path "*.crt" -Destination $certsPath -Force
Move-Item -Path "*.jpg" -Destination $certsPath -Force

write-Output "NOTE: Protect .pfx cert files. (contain certificate + private key)"
