# Script to create the HP SecurePlatformManagement (SPM) and HP Sure Admin (EBAM) certificates 
# by Juergen Bayer, Dan Felman
# HP Inc - 11/6/2020
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

    arguments:

        -spm                            # create certificates for HP Secure Platform Management
        -ebam                           # create local access key certificate for HP Sure Admin
        -certpath <location for certs>  # folder to store certificates (default: .\certs)

#>
[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false)] [switch]$SPM,
    [Parameter(Mandatory=$false)] [switch]$EBAM, 
    [Parameter(Mandatory=$false)] [string]$CertPath = $PSScriptRoot+'\certs',
    [Parameter(Mandatory=$false, ValueFromRemainingArguments)] [switch]$Help
)
#=====================================================================================
# work on command arguments
# if script runs with no arguments or with arg: '-help', just show runstring options

if ( ($PSBoundParameters.count -eq 0) -or ($Help) ) {
    "Run script with options > "
    "`tCreate_Certs.ps1 [-SPM] | [-EBAM] [-CertPath <path>] [-h|-help]"
    "`tCreate_Certs.ps1 -SPM             # To create certs for SPM - default path to .\Certs"
    "`tCreate_Certs.ps1 -EBAM            # To create certs for Sure Admin/EBAM - default path to .\Certs"
    exit
} # if ( ($PSBoundParameters.count -eq 0) -or ($help) )

if ( $spm -and $ebam ) {
    "Please, chose either SPM or EBAM option"
    exit
}
#=====================================================================================


# where to put the certificates created
if (-not (Test-Path $CertPath)) {
    New-Item -Path $CertPath -ItemType directory | Out-Null
}
<#
    #------------------------------------------------------------------------
    # Uncomment, mod next few lines if you are using newly downloaded OpenSSL
    #------------------------------------------------------------------------

    $OpenSSL_binPath = 'C:\OpenSSL-1.1.1h_win32'

    if ((Get-Command "OpenSSL.exe" -ErrorAction SilentlyContinue) -eq $null) { 
         Write-Output "Adding OpenSSL.exe to the PATH"    
         $env:Path += ";$($OpenSSL_binPath)"                   # add Path to OpenSSL.exe - modify openssl.exe path as needed
    }
    if ((Get-Command "OpenSSL.exe" -ErrorAction SilentlyContinue) -eq $null) { 
        Write-Output "Unable to find OpenSSL.exe in your PATH. Please update in script" -ForegroundColor Red
        exit
    }

    #!!!! openssl requires access to its configuration file !!!!
    $env:OPENSSL_CONF = (Split-Path -Path (get-command openssl.exe).source)+'\openssl.cnf'
#>

# Certificate passwords to help protect Private Keys. 
# HP recommends at least the Signing Key certificate be protected with a password ($SKCertPwd)

#$EKCertPwd = 'P@ssw0rd'                         # used to protect Endrosement Private Key cert (may not be needed)
$EKCertPwd = ''
# -----
#$SKCertPwd = 'P@ssw0rd'                          # used to protect Signing Private Key cert - IMPORTANT !!!!
$SKCertPwd = ''
# -----
#$LAKCertPwd = 'P@ssw0rd'                        # used to protect Local Access Private Key cert
$LAKCertPwd = ''

# modify for organization
$CertSubj = '/C=US/ST=State/L=City/O=Company/OU=Org/CN=SPMdemo'

#=====================================================================================
<#
    Function Create_Certs

#>
Function Create_Certs {
	param(
        [string]$privKeyName,
        [string]$x509CertName,
        [string]$pkcs12CertName,
        [string]$certPwd,
        [string]$certSubj,
        [string]$certName
    )
    <#
    NOTES: Oenssl '-subj' parameter should be updated to reflect the organization. If not included, openssl will prompt for the information.
           -X509: means sign certificate as CA according to RFC 5280
           -nodes: means no DES (private key not passowrd protected)
           -newkey: add private key, what format to use for encryption (we use rsa:2048)
           -keyout: exports the Private key
           -out: exports self-signed certificate

           cert file in PEM format: https://www.openssl.org/docs/manmaster/man1/openssl.html
              (a block of base-64 encoding with specific lines used to mark the start and end)
 
           NOTE: The PKCS#12 format is an archival file that stores both the certificate and the private key. 
           - This format is useful for migrating certificates and keys from one system to another as it contains all the necessary files. 
           - (PKCS#12 files use either the .pfx or .p12 file extension)

           https://www.openssl.org/docs/manmaster/man1/openssl-pkcs8.html - explanation of encryption algorithms (e.g. PBE-SHA1-3DES)

    NOTES: Files like EKpriv.pem and EKcert.crt are temp files that could be securely discarded.
            The private .pfx key is not protected if no export password has been provided.
    #>

    write-Output "-> STEP 1: Create private key $privKeyName and self-signed X.509 certificate $x509CertName"
    openssl.exe req -x509 `
        -nodes `
        -newkey rsa:2048 `
        -keyout (Join-Path $CertPath $privKeyName) `
        -out (Join-Path $CertPath $x509CertName) `
        -days 3650 `
        -subj $CertSubj 2>$null

    write-Output "-> STEP 2: Create PKCS#12 certificate $pkcs12CertName"
    openssl.exe pkcs12 `
        -inkey (Join-Path $CertPath $privKeyName) `
        -in (Join-Path $CertPath $x509CertName) `
        -export `
        -keypbe PBE-SHA1-3DES `
        -certpbe PBE-SHA1-3DES `
        -out (Join-Path $CertPath $pkcs12CertName) `
        -name $certName `
        -passout pass:$certPwd 2>$null

} # Function Create_Certs

#=====================================================================================

# =========================================
# HP Secure Platform management (SPM)
# =========================================

if ($SPM) {
    # =========================================
    # Create the Endorsement and Signing Keys
    # =========================================

    Write-Host 'Create SPM Endorsement key certificate EK.pfx'
    Create_Certs EKpriv.pem EKcert.crt EK.pfx $EKCertPwd $certSubj 'SPM Endorsement Key Certificate'
    
    Write-Host 'Create SPM Signing key certificate SK.pfx'
    Create_Certs SKpriv.pem SKcert.crt SK.pfx $SKCertPwd $certSubj 'SPM Signing Key Certificate'
}

#=====================================================================================

# =========================================
# HP Sure Admin (EBAM)
# =========================================

# NOTE: The Sure Admin Payload will be created with CMSL without requiring a new certificate
#       The Local Access Key certificate next will be used to allow F10 user access to BIOS

if ($EBAM) {
    # =========================================
    # Create EBAM local access key certificate
    # =========================================

    Write-Host 'Create HP Sure Admin local access key certificate LAK.pfx'
    Create_Certs LAKpriv.pem LAKcert.crt LAK.pfx $LAKCertPwd $certSubj 'EBAM Local Access Key Certificate'
}
