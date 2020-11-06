# HP_BIOS_Security
Scripts to create Secure Platform and Sure Admin/EBAM certificates and provisioning payloads

HP Sure Admin is a certificate-based BIOS authentication mechanism that relies on the security of the Secure Platform Management (SPM) technology. By applying BIOS update or settings payloads that have been signed with the provisioned SPM of the client, it prevents rogue applications, agents, or malware from modifying the BIOS firmware code or settings and helps prevent those firmware attacks

there are 4 scripts that can be used to test the technology
  - create_certs.ps1 - uses OpenSSL to create public/private keys and pkcs#12 certificates for both SPM and Sure Admin/EBAM
  - create_payloads.ps1 - uses HP CMSL (version 1.6 or newer) commands to create SPM and Sure Admin/EBAM provision and devprovision payloads
  - provision_spm.ps1 - like the name suggests, it provisions the SPM Endorsement and Signing Keys on a client device
  - provision_ebam.ps1 - provisions the Sure Admin authntication payloads on a client device, that has been previously provisioned with SPM
