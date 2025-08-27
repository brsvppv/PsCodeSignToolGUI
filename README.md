
# PsCodeSignToolGUI

This repository contains PowerShell GUI tools for code signing using certificates from trusted authorities. Below is an overview of the included scripts and their intended usage:


## Script Overview

### Sign-SelectedFile.ps1

#### Run Directly from GitHub
You can run the script directly from GitHub without downloading:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex (irm 'https://raw.githubusercontent.com/brsvppv/PsCodeSignToolGUI/refs/heads/main/Sign-SelectedFile.ps1')
```
- **Purpose:**
	- Sign files using a certificate installed in the Windows certificate store (supports hardware tokens and smart cards).
- **Certificate Store Used:**
	- Searches for code signing certificates in the following stores:
		- `Cert:\CurrentUser\My`
- **Where to Install Certificates:**
	- Certificates must be installed in one of the above stores. For hardware tokens, the certificate is typically available in `CurrentUser\My` when the token is plugged in and unlocked.
- **Features:**
	- GUI to select a file to sign and a code signing certificate from the store.
	- Supports hardware tokens (e.g., SafeNet) if the certificate is present and unlocked.
	- Visual feedback and error handling for missing certificates, locked tokens, and signing errors.



### Sign-SelectedFileUsingPFX.ps1

#### Run Directly from GitHub
You can run the script directly from GitHub without downloading:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex (irm 'https://raw.githubusercontent.com/brsvppv/PsCodeSignToolGUI/refs/heads/main/Sign-SelectedFileUsingPFX.ps1')
```
- **Purpose:**
	- Sign files using a PFX (PKCS#12) certificate file and password.
- **Certificate Store Used:**
	- Does not use the Windows certificate store. The certificate is loaded directly from the selected PFX file.
- **Where to Install Certificates:**
	- No installation required. You only need the PFX file and its password.
- **Features:**
	- GUI to select a PFX certificate file, enter its password, and select a file to sign.
	- Useful for signing with certificates not installed in the Windows certificate store.
	- **Note:** This script does **not** support hardware tokens (such as SafeNet). It only works with standard PFX files that are not protected by a hardware token.



## Hardware Token Support
- Only `Sign-SelectedFile.ps1` supports hardware tokens (such as SafeNet) for code signing. Make sure the token is plugged in and unlocked before signing. The certificate will appear in the Windows certificate store (usually `CurrentUser\My`) when the token is available.
- `Sign-SelectedFileUsingPFX.ps1` does **not** support hardware tokens and will not work with certificates stored on such devices.


## Requirements
- Windows with PowerShell
- Certificates from trusted authorities:
	- For `Sign-SelectedFile.ps1`: Must be installed in the Windows certificate store (`CurrentUser\My`, `LocalMachine\My`, `CurrentUser\Root`, or `LocalMachine\Root`).
	- For `Sign-SelectedFileUsingPFX.ps1`: Must be available as a PFX file with password.
- [Optional] SafeNet Authentication Client for hardware token support (only for `Sign-SelectedFile.ps1`)


## Usage

### Sign-SelectedFile.ps1
1. Install your code signing certificate in the Windows certificate store (`CurrentUser\My` is recommended for hardware tokens).
2. Plug in and unlock your hardware token (if used).
3. Run `Sign-SelectedFile.ps1`.
4. Select the file to sign and the certificate from the dropdown.
5. Click the sign button and follow any prompts.

### Sign-SelectedFileUsingPFX.ps1
1. Obtain your code signing certificate as a PFX file and note its password.
2. Run `Sign-SelectedFileUsingPFX.ps1`.
3. Select the PFX file, enter its password, and select the file to sign.
4. Click the sign button and follow any prompts.

For hardware token signing, use only `Sign-SelectedFile.ps1` and ensure the token is available and unlocked before starting.
