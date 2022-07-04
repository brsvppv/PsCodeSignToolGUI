##[Ps1 To Exe]
##
##Kd3HDZOFADWE8uO1
##Nc3NCtDXTlGDjqzx7Bp48WbhVG01Uuuerp+E9721+dXLriTLSJQATFFIwH+lXR/oF/sRWpU=
##Kd3HFJGZHWLWoLaVvnQnhQ==
##LM/RF4eFHHGZ7/K1
##K8rLFtDXTiW5
##OsHQCZGeTiiZ4dI=
##OcrLFtDXTiW5
##LM/BD5WYTiiZ4tI=
##McvWDJ+OTiiZ4tI=
##OMvOC56PFnzN8u+Vs1Q=
##M9jHFoeYB2Hc8u+Vs1Q=
##PdrWFpmIG2HcofKIo2QX
##OMfRFJyLFzWE8uK1
##KsfMAp/KUzWI0g==
##OsfOAYaPHGbQvbyVvnQnqxugEiZ6Dg==
##LNzNAIWJGmPcoKHc7Do3uAu+DDhlPovK2Q==
##LNzNAIWJGnvYv7eVvnRH6lzrUFsja8mX+ZWowIT8zOPrtWXtRpUYKQ==
##M9zLA5mED3nfu77Q7TV64AuzAlg4SMyXvIWuw4/c
##NcDWAYKED3nfu77Q7TV64AuzAgg=
##OMvRB4KDHmHQvbyVvnRH6lzrUFsja8mX+ZCuyIT8uarPtCHcCakdTlo3oibzCCs=
##P8HPFJGEFzWE8obQ4jk602Lda0cFLueOtbGm1oi9v8b4v2u5
##KNzDAJWHD2fS8u+Vgw==
##P8HSHYKDCX3N8u+Vgw==
##LNzLEpGeC3fMu77Ro2k3hQ==
##L97HB5mLAnfMu77Ro2k3hQ==
##P8HPCZWEGmaZ7/K1
##L8/UAdDXTlGDjpL2zxtCwXfJS3wDe8eniaWEy4W5zOPrtRHWRpYzfH1LpjrfC0+4avsVW8Eau91fUAUvTw==
##Kc/BRM3KXhU=
##
##
##fd6a9f26a06ea3bc99616d4851b372ba
#[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
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
            <Label Name="lblTitle" Content="Selected PFX CodeSign Certificate and Sign File using SHA256" HorizontalAlignment="Left" Margin="5,15,0,0" VerticalAlignment="Top" Width="355" Height="35" FontSize="12"/>
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

#SELECT CERTIFICATE
$btnSelectCert.Add_Click( {
        SelectCertificate
    })
#SELECT FILE TO SIGN
$btnFile.Add_Click( {
        SelectFileToSign
    })
#Perform Signing 
$btnPerformCodeSign.Add_Click({ 
        $PfxCertificate = $txtCertificatePath.Text 
        $fileToSign = $txtFileToSignPath.Text
        $CertPass = $pswdbCert.Password
        
        try {
            #Signining Arugments
            $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxCertificate, $CertPass)
            Set-AuthenticodeSignature -Certificate $Cert -FilePath $fileToSign -HashAlgorithm $fdAlg -TimestampServer $tURL -Force -ErrorAction STOP 
            [System.Windows.MessageBox]::Show("Completed", 'File Sign Result', 'OK', 'Information')
        }
        Catch [System.Exception] {
            $ErrorMSG = $_.Exception.Message 
            [System.Windows.MessageBox]::Show("An Error Occured During Signing $ErrorMSG", 'ERROR', 'OK', 'Error') 
    }            
})

$Form.ShowDialog() | out-null   
# SIG # Begin signature block
# MIIsPQYJKoZIhvcNAQcCoIIsLjCCLCoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDoiq+oUQQlZ5ce
# Fob/xBuSmZTuY1Bx0+cqfHBc7W1ZTqCCJVQwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggWxMIIEmaADAgECAhABJAr7
# HjgLihbxS3Gd9NPAMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAi
# BgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA2MDkwMDAw
# MDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERp
# Z2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsb
# hA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iT
# cMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGb
# NOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclP
# XuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCr
# VYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFP
# ObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTv
# kpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWM
# cCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls
# 5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBR
# a2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggFe
# MIIBWjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qY
# rhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8E
# BAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgweQYIKwYBBQUHAQEEbTBrMCQGCCsG
# AQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0
# dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEE
# AjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQEMBQADggEBAJoWAqUB74H7DbRYsnit
# qCMZ2XM32mCeUdfL+C9AuaMffEBOMz6QPOeJAXWF6GJ7HVbgcbreXsY3vHlcYgBN
# +El6UU0GMvPF0gAqJyDqiS4VOeAsPvh1fCyCQWE1DyPQ7TWV0oiVKUPL4KZYEHxT
# jp9FySA3FMDtGbp+dznSVJbHphHfNDP2dVJCSxydjZbVlWxHEhQkXyZB+hpGvd6w
# 5ZFHA6wYCMvL22aJfyucZb++N06+LfOdSsPMzEdeyJWVrdHLuyoGIPk/cuo260Vy
# knopexQDPPtN1khxehARigh0zWwbBFzSipUDdlFQU9Yu90pGw64QLHFMsIe2JzdE
# YEQwggYaMIIEAqADAgECAhBiHW0MUgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUA
# MFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNV
# BAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAz
# MjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUg
# U2lnbmluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCb
# K51T+jU/jmAGQ2rAz/V/9shTUxjIztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZ
# UKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYk
# wmMv0b/83nbeECbiMXhSOtbam+/36F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE2
# 15wzrK0h1SWHTxPbPuYkRdkP05ZwmRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+
# 8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9
# JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+
# EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9
# o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sC
# AwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0G
# A1UdDgQWBBQPKssghyi47G9IritUpimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYD
# VR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDAS
# MAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwu
# c2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmww
# ewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUF
# BzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEA
# Bv+C4XdjNm57oRUgmxP/BP6YdURhw1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug
# 2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCy
# KppP0OcxYEdU0hpsaqBBIZOtBajjcw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099i
# ChnyIMvY5HexjO2AmtsbpVn0OhNcWbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj
# 1lJziVKEoroGs9Mlizg0bUMbOalOhOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO3
# 7PU8ejfkP9/uPak7VLwELKxAMcJszkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqm
# KL5OTunAvtONEoteSiabkPVSZ2z76mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTq
# lLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQ
# ZH3pwWvqURR8AgQdULUvrxjUYbHHj95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWU
# H3fTv1Y8Wdho698YADR7TNx8X8z2Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63
# Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2RwwggaOMIIE9qADAgECAhEA
# mBkqF/fmYeYMpXFhWIavHDANBgkqhkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1Ymxp
# YyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIxMDgzMDAwMDAwMFoXDTIyMDgzMDIz
# NTk1OVowaTELMAkGA1UEBhMCQkcxDjAMBgNVBAgMBVNvZmlhMSQwIgYDVQQKDBtU
# ZWFtIFZJU0lPTiAtIEJ1bGdhcmlhIEx0ZC4xJDAiBgNVBAMMG1RlYW0gVklTSU9O
# IC0gQnVsZ2FyaWEgTHRkLjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# ANGNKjzpFwutqYPGm0I0y8dMFXmNNS76JrkS62SwILkMvJZ7gM/6cRAXCxWeUUmA
# 3puPcU5Fku5EU8tm6PrmwCaUuvOJbVgpkorLLulnS1Se26lH6BXKd3mpw2BtAJf3
# AOhxHlipeQiXyonHw0bcbgA2nCn0LzgijMtvO0lKVbOL9qwaOr4jJANeKMNdBBU7
# zSNMz5wR5OysaxzMcHpqd/iq5HR4aT31rJrmwlJcifmKOP38YeiObzrGtb456OnK
# xL+y9I6MkXBIi42nwG1C7u3mow++I3l20qGUctp944s5GrJuAgSfPX1xQWnEbXXr
# KyYMEKG4ZcEoPn3YpAXKH8zgLWtMDTdXVPl3iLQyBBoojrEMDX2bHqnpKeOonYnt
# 7MmwrNdBtQKrXJzvIizKjYVcLz7cvlPMc0wBK+axX87LkjgEKSKM2rUCPSHr81y4
# smDyYbHR+AeGl87ozIEr1S/FsA6J0i2lfUjzkrH46r+6RNtZxGAVBIrdH3ybh/od
# 2PsqJPg6TsZ+Pwnoxkdh2FxH4Ro1jH8gMdkcsFg5woP7Ghx+p28m1ybmdk1BSF2n
# B0J6dH1jlkDpGWCjq1FV5x10qvDx+sf4nZPI9Tk8qPi5FpV2XdcKxk+qxGN5RXhy
# fCSg+VetMhqAROu674Lz6VrdrVHrvORkL+/BmmX+uygZAgMBAAGjggHEMIIBwDAf
# BgNVHSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNVHQ4EFgQUclwXS6ZX
# jE1jEHVkshtLuZl1vTEwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYD
# VR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4QgEBBAQDAgQQMEoGA1UdIARDMEEw
# NQYMKwYBBAGyMQECAQMCMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5j
# b20vQ1BTMAgGBmeBDAEEATBJBgNVHR8EQjBAMD6gPKA6hjhodHRwOi8vY3JsLnNl
# Y3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNybDB5Bggr
# BgEFBQcBAQRtMGswRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQuc2VjdGlnby5jb20v
# U2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdo
# dHRwOi8vb2NzcC5zZWN0aWdvLmNvbTAmBgNVHREEHzAdgRtyLmthcmFpdmFub3ZA
# dGVhbS12aXNpb24uYmcwDQYJKoZIhvcNAQEMBQADggGBAGFItbyIdh7YGXBYDRVS
# 8CrBZ3JWKdv1Oeiqpl3ni5QpoS7oAo2ehMirGrRrA4Nom8fWy/3qsPaotGaEidQ8
# ieVifCSQZRrWhvV7DEuujoE+8SIqso+4IsWihmB9Kk/9qGfc3uhbzD4iZkMMUQSq
# vw9jxIYdFxvwdwO98tVqATHx1A+BwcereMf3tKw4OpXqEtERk62uMQT/C2nyOQSJ
# kZuW8iZTww8o8jBU2eFl+4v1HXnoPqY80o9eSPAzBIjJ3ePgAUXghIt5FEPUXyHi
# XTUGolw3LlkIyplHkkMpH4km1IleLzsvkWniDZGYAZAYuEO0KmnKhCdoM5PmtBrq
# zw6rDOUGp6NfqZPmsqu+p17Eq0LXz1Y5KONGc0v1dt4FTkse5ZhS+wFxhYOxKySZ
# nzQeFug854A6ZEAeV0iraaAEqsRsZyJs55mMeoP7O6gBFv4uw04xd+zS3QaJOBnC
# WvUEUqDbiHHPpD+L2zgewgYTq04sdrc5NfF+f2oXLiYw0jCCBq4wggSWoAMCAQIC
# EAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAw
# MDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQw
# OTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2
# EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuA
# hIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQ
# h0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7Le
# Sn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw5
# 4qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP2
# 9p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjF
# KfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHt
# Qr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpY
# PtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4J
# duyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGj
# ggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2
# mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNV
# HQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBp
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUH
# MAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIB
# fmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb
# 122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+r
# T4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQ
# sl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q6/aesXmZgaNWhqsK
# RcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKn
# N36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSe
# reU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no
# 8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcW
# oWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInw
# AM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7
# qS9EFUrnEw4d2zc4GqEr9u3WfPwwggbGMIIErqADAgECAhAKekqInsmZQpAGYzhN
# hpedMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2
# IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjIwMzI5MDAwMDAwWhcNMzMwMzE0
# MjM1OTU5WjBMMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4x
# JDAiBgNVBAMTG0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDIyIC0gMjCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBALkqliOmXLxf1knwFYIY9DPuzFxs4+AlLtIx
# 5DxArvurxON4XX5cNur1JY1Do4HrOGP5PIhp3jzSMFENMQe6Rm7po0tI6IlBfw2y
# 1vmE8Zg+C78KhBJxbKFiJgHTzsNs/aw7ftwqHKm9MMYW2Nq867Lxg9GfzQnFuUFq
# RUIjQVr4YNNlLD5+Xr2Wp/D8sfT0KM9CeR87x5MHaGjlRDRSXw9Q3tRZLER0wDJH
# GVvimC6P0Mo//8ZnzzyTlU6E6XYYmJkRFMUrDKAz200kheiClOEvA+5/hQLJhuHV
# GBS3BEXz4Di9or16cZjsFef9LuzSmwCKrB2NO4Bo/tBZmCbO4O2ufyguwp7gC0vI
# CNEyu4P6IzzZ/9KMu/dDI9/nw1oFYn5wLOUrsj1j6siugSBrQ4nIfl+wGt0ZvZ90
# QQqvuY4J03ShL7BUdsGQT5TshmH/2xEvkgMwzjC3iw9dRLNDHSNQzZHXL537/M2x
# wafEDsTvQD4ZOgLUMalpoEn5deGb6GjkagyP6+SxIXuGZ1h+fx/oK+QUshbWgaHK
# 2jCQa+5vdcCwNiayCDv/vb5/bBMY38ZtpHlJrYt/YYcFaPfUcONCleieu5tLsuK2
# QT3nr6caKMmtYbCgQRgZTu1Hm2GV7T4LYVrqPnqYklHNP8lE54CLKUJy93my3YTq
# J+7+fXprAgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIw
# ADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNVHSAEGTAXMAgGBmeBDAEEAjAL
# BglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2FL3MpdpovdYxqII+eyG8wHQYD
# VR0OBBYEFI1kt4kh/lZYRIRhp+pvHDaP3a8NMFoGA1UdHwRTMFEwT6BNoEuGSWh0
# dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZT
# SEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsGAQUFBwEBBIGDMIGAMCQGCCsG
# AQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wWAYIKwYBBQUHMAKGTGh0
# dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQw
# OTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggIBAA0t
# I3Sm0fX46kuZPwHk9gzkrxad2bOMl4IpnENvAS2rOLVwEb+EGYs/XeWGT76TOt4q
# OVo5TtiEWaW8G5iq6Gzv0UhpGThbz4k5HXBw2U7fIyJs1d/2WcuhwupMdsqh3KEr
# lribVakaa33R9QIJT4LWpXOIxJiA3+5JlbezzMWn7g7h7x44ip/vEckxSli23zh8
# y/pc9+RTv24KfH7X3pjVKWWJD6KcwGX0ASJlx+pedKZbNZJQfPQXpodkTz5GiRZj
# IGvL8nvQNeNKcEiptucdYL0EIhUlcAZyqUQ7aUcR0+7px6A+TxC5MDbk86ppCaiL
# fmSiZZQR+24y8fW7OK3NwJMR1TJ4Sks3KkzzXNy2hcC7cDBVeNaY/lRtf3GpSBp4
# 3UZ3Lht6wDOK+EoojBKoc88t+dMj8p4Z4A2UKKDr2xpRoJWCjihrpM6ddt6pc6pI
# allDrl/q+A8GQp3fBmiW/iqgdFtjZt5rLLh4qk1wbfAs8QcVfjW05rUMopml1xVr
# NQ6F1uAszOAMJLh8UgsemXzvyMjFjFhpr6s94c/MfRWuFL+Kcd/Kl7HYR+ocheBF
# ThIcFClYzG/Tf8u+wQ5KbyCcrtlzMlkI5y2SoRoR/jKYpl0rl+CL05zMbbUNrkdj
# OEcXW28T2moQbh9Jt0RbtAgKh1pZBHYRoad3AhMcMYIGPzCCBjsCAQEwaTBUMQsw
# CQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJT
# ZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhEAmBkqF/fmYeYMpXFh
# WIavHDANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCB0wGa97ocGR98CR9AGA7TKvTuV8ylF
# rRc7ugBKI45JnTANBgkqhkiG9w0BAQEFAASCAgBhmLaukDvdiHoQrktb1H+KIeKo
# jZ3LIDIqwLyzmuNHWbvySSB19Kmgg3TkHAZaA20mbCOkynuf3Xpb87mgsVPJQSeU
# A2Og0Ht5gfDeoOhdps9yboNADy6/EhIHeHOuY0k78vcbekD5qFbny9uFLEl5IcC5
# nbeXyQC1j9NhJOFiSjWglrkKEDv2Imj6o1SZUPSINRGXifgT0cUgtHBDakHPihfp
# 717KUErJZ00Knc8E3TSD997vIj3zoLek9w2D7irAGls4utsTjuREAmuakzHDbQdU
# HHFl5T9wB436hU4btSX9E429gsEGsv0eJsgvVlzV3nwhibJ3D4O5JTG+SlYz9krt
# S2GxWy5PT6bNDkYw3gYLJ2zs7BbMAY5dXxRE2M9ttBCyaaHWWKBSdpXKq+l2UcZt
# zNgvL1A6/Cdlx2o40hAyOvPg7NMwv36koXE9nZeLZRSPZd7fqtIbH5rvp+1f0hPM
# ulu30y5HbAGgg/x3QrV9RGhVh0f12SdnQbFOnCXvukT5FNmwp3ATnRB0lXr4PHDh
# 4XLCBW8xd9gtUOeSCMeHGfGfDtKtKWWoZXrxMqj/izx8p/RHTb6hyrkjEj/GVQY6
# 7sHLnRvMJuDNWLsWmTJ0hIRX8nCpDl4UX34ye34OaHosJzPk/3AaRkXTBHHdzM/4
# hcHG7tlewIkNBwADHqGCAyAwggMcBgkqhkiG9w0BCQYxggMNMIIDCQIBATB3MGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0ECEAp6SoieyZlCkAZjOE2Gl50wDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0B
# CQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMjA3MDQwOTMyNDVaMC8G
# CSqGSIb3DQEJBDEiBCAagSOLj7NjWAOtkiPL5fvOKCu9jMujXSKvPLjVUmNUAjAN
# BgkqhkiG9w0BAQEFAASCAgAFvuadYC1ysGmhgsGfc7vKhsY1ryUnytXfutePFIkJ
# Eq9iKFo5bRDpyQ9D8RBVlSPcCqVyxkk9QEgoEF784LsTAleg4LhkFAyeZKR84U9A
# yYiaOnEqtnrk669oBgthYUVJopl911Zzz0q2Ivl1isuQOFT0JNPywZLE/kr54weg
# oGJdFbI2lY8q3AWDpUDVwmRuL30neaL5TI0869LCMiQ4cM5KjcjIYfyAkeY5oLH3
# luhwIiIlNVaCUf+g1mnZ5HKv6omjwSPDSjylk8mQXD46SS44hOboIOUoYb7Q9mLu
# jHZlKIzRcWuLLjGryRysqBvl/k+13b7dVxceGfk+4Aix/GTXzR0EFKfZMIVBhGOb
# zWvtyrN+Kp3D9t2TXgxudQHnXAwkGZDu/4KRdfdd0RdTpPM0F8XAw09J8Khh10Ys
# kX1ewryEVxVbGEG+vYhU/jba07nnuo963GLqYQB7Sh68kSfGLiCl0FdPUrD4Orv0
# BgnoIc6TAWuo/kjL4YE83aRyiaqMsHTfRnexrNFJ1+KVwOSgVh8uejPOr00E4cp+
# iWArmNWfmppBxp1sJf0ZyZ4DD0OgMtnxb5hcKFbksURikBISqLcxn0cwH/wl6FXh
# 7E2aJAk32EEo/EKtLQ8z2Zv4qFocc3d2778pqzT2JkbxALdIB2tu/YKstauVQHPC
# pg==
# SIG # End signature block
