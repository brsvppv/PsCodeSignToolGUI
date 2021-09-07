[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationCore, PresentationFramework
[xml]$XAML = @"
<Window
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
     
        Title="CodeSignGUI" Height="200" Width="355" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
        <Grid Background="{DynamicResource {x:Static SystemColors.WindowBrushKey}}" Height="200" Width="355" VerticalAlignment="Center" HorizontalAlignment="Center" >
            <Label Name="lblTitle" Content="Selected PFX Code Sign Certificate + File for Digital Signature" HorizontalAlignment="Left" Margin="5,15,0,0" VerticalAlignment="Top" Width="355" Height="35" FontSize="12"/>
            <TextBox Name="txtCertificatePath" Text="Select Code Signing Certificate" HorizontalAlignment="Left" Height="20" Width="300" Margin="15,56,0,0" VerticalAlignment="Top"  FontSize="11" IsReadOnly="false"/>
            <TextBox Name="txtFileToSignPath" Text="Select File to Sign" HorizontalAlignment="Left" Height="20" Width="300" Margin="15,83,0,0" VerticalAlignment="Top" FontSize="11" IsReadOnly="false"/>   
            <Button Name="btnSelectCert" Content="..." HorizontalAlignment="Left" Margin="314,56,0,0" VerticalAlignment="Top" Width="27" Height="20"/>
            <Button Name="btnFile" Content="..." HorizontalAlignment="Left" Margin="314,83,0,0" VerticalAlignment="Top" Width="27" Height="20"/>
            <Button Name="btnPerformCodeSign" Content="Perform Code Signing" Margin="0,150,0,0" VerticalAlignment="Top" Height="23" Width="335" HorizontalAlignment="Center" />
            <Label Name="lblCertPswd" Content="Certificate Password:" HorizontalAlignment="Left" Margin="5,104,0,0" VerticalAlignment="Top" Width="117" Height="27"/>
            <PasswordBox Name="pswdbCert" HorizontalAlignment="Left" Margin="127,108,0,0" VerticalAlignment="Top" Width="214"  Height="20"/>      
            </Grid>
    </Window>
"@
#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml) 
try { $Form = [Windows.Markup.XamlReader]::Load( $reader ) }
catch { Write-Host "Unable to load Windows.Markup.XamlReader"; exit }
# Store Form Objects In PowerShell
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name) }

#SHA256 Algorythm for Signing
$fdAlg = "SHA256"
#TimeStamp For Signing
$tURL = "http://timestamp.digicert.com"

#Select Code Signing Certificate
Function SelectCertificate { 
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect = $false # Multiple files can be chosen
        Filter      = 'Certificate (*.pfx)|*.pfx' # Specified file types
    }
    [void]$FileBrowser.ShowDialog()
    
    If ($FileBrowser.FileNames -like "*\*")
    { $fullPath = $FileBrowser.FileNames }
    else {
        
        $res = [System.Windows.Forms.MessageBox]::Show("No File Selected, Try Again ?", "Select a location", [System.Windows.Forms.MessageBoxButtons]::YesNo)
        if ($res -eq "No") {
            return
        }
    }
    $filedirectory = Split-Path -Parent $FileBrowser.FileName
    $certName = [System.IO.Path]::GetFileName($fullPath)          
    $txtCertificatePath.Text = "$filedirectory" + "\" + "$certName"
    return $FileBrowser.FileNames   
}
#Select File to Sign
Function SelectFileToSign { 
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect = $false # Multiple files can be chosen
        #Filter      = 'Certificate (*.pfx)|*.pfx' # Specified file types
    }
    [void]$FileBrowser.ShowDialog()
    
    If ($FileBrowser.FileNames -like "*\*")
    { $fullPath = $FileBrowser.FileNames }
    else {
        
        $res = [System.Windows.Forms.MessageBox]::Show("No File Selected, Try Again ?", "Select a location", [System.Windows.Forms.MessageBoxButtons]::YesNo)
        if ($res -eq "No") {
            return
        }
    }
    $filedirectory = Split-Path -Parent $FileBrowser.FileName
    $fname = [System.IO.Path]::GetFileName($fullPath)          
    $txtFileToSignPath.Text = "$filedirectory" + "\" + "$fname"
    return $FileBrowser.FileNames   
}

# $performSigning Button Validation Function
function ButtonEnable {
    if ($txtCertificatePath.Text -eq "Select Code Signing Certificate" -bor $txtFileToSignPath.Text -eq "Select File to Sign" -bor $pswdbCert.Password -eq "") {
        $btnPerformCodeSign.IsEnabled = $false
    }
    else {
        $btnPerformCodeSign.IsEnabled = $true
    }
}
#Set Values on Form Load
$Form.Add_Loaded( {
        $btnPerformCodeSign.IsEnabled = $false
    })

#Perofrm button validation on TextChange
$txtCertificatePath.Add_TextChanged( {
        ButtonEnable
    })
#Perofrm button validation on TextChange
$txtFileToSignPath.Add_TextChanged( {
        ButtonEnable
    })
#Perofrm button validation on PSWD/TextChange
$pswdbCert.Add_PasswordChanged( {
        ButtonEnable
    })
#SELECT SIGN TOOL PATH  
#default sign tool location:
#"C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64"

#SELECT CERTIFICATE
$btnSelectCert.Add_Click( {
        SelectCertificate
        
    })
#SELECT FILE TO SIGN
$btnFile.Add_Click( {
        SelectFileToSign
    })
#Perform Signing 
$btnPerformCodeSign.Add_Click( {
        #Set Path SignTool Location
        Set-Location $txtSignToolPath.Text
        #Get-PfxCertificate -FilePath 
        $PfxCertificate = $txtCertificatePath.Text 
        $fileToSign = $txtFileToSignPath.Text
        $CertPass = $pswdbCert.Password
        $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxCertificate, $CertPass)
        try {
            #Signining Arugments

            Set-AuthenticodeSignature -Certificate $Cert -FilePath $fileToSign -HashAlgorithm $fdAlg -TimestampServer $tURL -Force -ErrorAction STOP 
    
        }
        Catch {
            [System.Windows.MessageBox]::Show("An Error Occured During Signing  $_", 'ERROR', 'OK', 'Error') 
        }
        [System.Windows.MessageBox]::Show("Completed", 'File Sign Result', 'OK', 'Information')
    })

$Form.ShowDialog() | out-null   