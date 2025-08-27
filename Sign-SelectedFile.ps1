[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName PresentationCore, PresentationFramework, System.Windows.Forms

[xml]$XAML = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="CodeSign" Height="200" Width="400" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">

        <!-- Installed Certificates -->
        <ComboBox Name="cmbCerts" ToolTip="Select an installed code signing certificate"
            HorizontalAlignment="Left" Margin="5,5,0,0" VerticalAlignment="Top"
            Width="320" Height="25" FontSize="11"/>
        <Button Name="btnCertDetails" ToolTip="View certificate details"
            HorizontalAlignment="Left" Margin="330,2,0,0" VerticalAlignment="Top"
            Width="28" Height="28" Background="Transparent"
            BorderBrush="Transparent" BorderThickness="0"
            Cursor="Hand" FocusVisualStyle="{x:Null}">
            <Button.Template>
                <ControlTemplate TargetType="Button">
                    <Grid>
                        <Ellipse x:Name="circle" Width="22" Height="22" Fill="#FF2196F3"/>
                        <TextBlock Text="i" Foreground="White" FontWeight="Bold"
                                   FontSize="16" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Grid>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="circle" Property="Fill" Value="#FF1976D2"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter TargetName="circle" Property="Fill" Value="#FF0D47A1"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Button.Template>
        </Button>

        <!-- File to Sign -->
        <TextBox Name="txtFileToSignPath" Text="Select file you want to sign"
            ToolTip="Browse for the file you want to sign."
            HorizontalAlignment="Left" Height="25" Width="320" Margin="5,40,0,0"
            VerticalAlignment="Top" IsReadOnly="true" FontSize="11"/>
        <Button Name="btnFile" Content="▲" ToolTip="Browse for file to sign"
            HorizontalAlignment="Left" Margin="330,40,0,0" VerticalAlignment="Top"
            Width="30" Height="25" FontSize="12" Background="#FFDDDDDD"
            BorderThickness="0" Cursor="Hand"/>

        <!-- Timestamp Server -->
        <ComboBox Name="cmbTimestamp" ToolTip="Select timestamp server"
            HorizontalAlignment="Left" Margin="5,75,0,0" VerticalAlignment="Top"
            Width="355" Height="25" FontSize="11">
            <ComboBoxItem Content="http://timestamp.sectigo.com" />
            <ComboBoxItem Content="http://timestamp.digicert.com" />
            <ComboBoxItem Content="http://timestamp.acs.microsoft.com" />
            <ComboBoxItem Content="https://timestamp.sectigo.com/qualified" />
            <ComboBoxItem Content="http://rfc3161timestamp.globalsign.com/advanced" />
            <ComboBoxItem Content="http://timestamp.entrust.net/TSS/RFC3161sha2TS" />
        </ComboBox>

        <!-- Sign Button -->
        <Button Name="btnSign" ToolTip="Sign the selected file using the selected certificate."
            Margin="5,110,0,0" VerticalAlignment="Top" Height="30" Width="355"
            HorizontalAlignment="Left" Foreground="White" FontWeight="Bold" FontSize="13" Cursor="Hand">
            <Button.Template>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="btnBorder" CornerRadius="4" Background="#FF2196F3">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="btnBorder" Property="Background" Value="#FF1976D2"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter TargetName="btnBorder" Property="Background" Value="#FF0D47A1"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Button.Template>
            Sign File
        </Button>
    </Grid>
</Window>
"@

# Load GUI
$reader = (New-Object System.Xml.XmlNodeReader $XAML)
$Form = [Windows.Markup.XamlReader]::Load($reader)
$XAML.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name) }

# Helper to check if both cert and file are selected
function UpdateSignButtonState {
    $certSelected = $cmbCerts.SelectedItem -and $cmbCerts.SelectedItem.Tag
    $fileSelected = $txtFileToSignPath.Text -and (Test-Path $txtFileToSignPath.Text)
    $enabled = $certSelected -and $fileSelected
    $btnSign.IsEnabled = $enabled
    $border = $btnSign.Template.FindName("btnBorder",$btnSign)
    if ($border) {
        if ($enabled) {
            $border.Background = "#FF2196F3"
        } else {
            $border.Background = "LightGray"
        }
    }
}

# React to certificate selection changes
$cmbCerts.Add_SelectionChanged({
    UpdateSignButtonState
})

# React to file path changes (manual edits)
$txtFileToSignPath.Add_TextChanged({
    UpdateSignButtonState
})

# SHA256 + Timestamp server
$fdAlg = "SHA256"

# Update Sign button color dynamically
function Set-SignButtonColor($color) {
    switch ($color) {
        "Green" { $btnSign.Template.FindName("btnBorder",$btnSign).Background = "Green" }
        "Red"   { $btnSign.Template.FindName("btnBorder",$btnSign).Background = "Red" }
        default { $btnSign.Template.FindName("btnBorder",$btnSign).Background = "#FF2196F3" }
    }
}

# Populate certificates
$Form.Add_Loaded({
    $cmbTimestamp.SelectedIndex = 0
    $cmbCerts.Items.Clear()
    $btnSign.IsEnabled = $false

    $stores = @(
        "Cert:\CurrentUser\My"
    )

    $allCerts = foreach ($store in $stores) {
        Get-ChildItem -Path $store -ErrorAction SilentlyContinue | Where-Object {($_.EnhancedKeyUsageList.ObjectId -contains "1.3.6.1.5.5.7.3.3") }
    }

    if ($allCerts.Count -eq 0) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = "No code signing certificates found"
        $item.Tag = $null
        [void]$cmbCerts.Items.Add($item)
        $cmbCerts.SelectedIndex = 0
    } else {
        foreach ($cert in $allCerts) {
            # Extract CN and O from Subject
            $subject = $cert.Subject
            $cn = ($subject -split ',') | Where-Object { $_ -match '^CN=' } | ForEach-Object { $_.Trim() }
            $o = ($subject -split ',') | Where-Object { $_ -match '^O=' } | ForEach-Object { $_.Trim() }
            $display = "$cn,$o | TB: $($cert.Thumbprint)"
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $display
            $item.Tag = $cert.Thumbprint
            [void]$cmbCerts.Items.Add($item)
        }
        $cmbCerts.SelectedIndex = 0
    }
    UpdateSignButtonState
})

# File Dialog for File to Sign
$btnFile.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "All Files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtFileToSignPath.Text = $dlg.FileName
    UpdateSignButtonState
    }
})

# Sign Button
$btnSign.Add_Click({
    if (-not $txtFileToSignPath.Text -or -not (Test-Path $txtFileToSignPath.Text)) {
        $txtFileToSignPath.Background = 'LightPink'
        Set-SignButtonColor "Red"
        [System.Windows.MessageBox]::Show("Invalid file path.", 'ERROR', 'OK', 'Error')
        return
    } else { $txtFileToSignPath.Background = 'White' }

    $selectedCertThumb = $cmbCerts.SelectedItem.Tag
    $Cert = (Get-ChildItem Cert:\CurrentUser\My, Cert:\LocalMachine\My, Cert:\CurrentUser\Root, Cert:\LocalMachine\Root |
            Where-Object { $_.Thumbprint -eq $selectedCertThumb }) | Select-Object -First 1

    if (-not $Cert) {
        Set-SignButtonColor "Red"
        [System.Windows.MessageBox]::Show("Certificate not found in store (maybe token locked).", 'ERROR', 'OK', 'Error')
        return
    }

    # Check if private key is accessible
    if (-not $Cert.HasPrivateKey) {
        Set-SignButtonColor "Red"
        [System.Windows.MessageBox]::Show("Certificate's private key is not accessible. Is the hardware token plugged in and unlocked?", 'ERROR', 'OK', 'Error')
        return
    }
    try {
        Set-SignButtonColor "DodgerBlue"
        $Time_URL = $cmbTimestamp.SelectedItem.Content

        $sig = Set-AuthenticodeSignature -Certificate $Cert -FilePath $txtFileToSignPath.Text `
              -HashAlgorithm $fdAlg -TimestampServer $Time_URL -Force -ErrorAction Stop

        if ($sig.Status -eq "Valid") {
            Set-SignButtonColor "Green"
            [System.Windows.MessageBox]::Show("File signed successfully!", 'Result', 'OK', 'Information')
        } else {
            Set-SignButtonColor "Red"
            [System.Windows.MessageBox]::Show("Signing failed. Status: $($sig.Status)", 'Result', 'OK', 'Warning')
        }
    }
    catch {
        Set-SignButtonColor "Red"
        [System.Windows.MessageBox]::Show("Error during signing: $($_.Exception.Message)", 'ERROR', 'OK', 'Error')
    }
})

# Certificate Details Button
$btnCertDetails.Add_Click({
    if (-not $cmbCerts.SelectedItem -or -not $cmbCerts.SelectedItem.Tag) {
        [System.Windows.MessageBox]::Show("No certificate selected. Please select a valid code signing certificate from the dropdown.", 'No Certificate Selected', 'OK', 'Warning')
        return
    }
    $thumb = $cmbCerts.SelectedItem.Tag
    $certs = Get-ChildItem Cert:\CurrentUser\My, Cert:\LocalMachine\My, Cert:\CurrentUser\Root, Cert:\LocalMachine\Root |
            Where-Object { $_.Thumbprint -eq $thumb }
    if ($certs.Count -gt 0) {
        # Find the certificate whose subject matches the ComboBox display, if possible
        $selectedDisplay = $cmbCerts.SelectedItem.Content
        $cert = $certs | Where-Object { "$($_.Subject) | Issuer: $($_.Issuer) | Thumb: $($_.Thumbprint.Substring(0,8))..." -eq $selectedDisplay } | Select-Object -First 1
        if (-not $cert) { $cert = $certs | Select-Object -First 1 }
        $details = "Subject: $($cert.Subject)`r`nIssuer: $($cert.Issuer)`r`nThumbprint: $($cert.Thumbprint)`r`nValid From: $($cert.NotBefore)`r`nValid To: $($cert.NotAfter)"
        [System.Windows.MessageBox]::Show($details, 'Certificate Details', 'OK', 'Information')
    }
})

# Run GUI
$Form.ShowDialog() | Out-Null

# SIG # Begin signature block
# MIImngYJKoZIhvcNAQcCoIImjzCCJosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCs6iiQ0AIy3aD9
# Bgzv/VYbvwx5m/jNHO0MuRZH+9BXlaCCH68wggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggYaMIIEAqADAgECAhBiHW0MUgGeO5B5FSCJIRwKMA0GCSqG
# SIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0
# NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFQxCzAJBgNVBAYTAkdC
# MRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVi
# bGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAw
# ggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNsfvxYB5UXeWUzCxEeAEZG
# bEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFigOMYzB2OKhdqfWGVoYW3
# haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09fy1tsB8je/RV0mIk8XL/
# tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmTnAO5/arnY83jeNzhP06S
# hdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp4VqpB3MV/h53yl41aHU5
# pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8rNyfQJy/aOs5b4s+ac7I
# H60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ1f9+YEQIQty/NQd/2yGg
# W+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh2n5HirY4jKnFH/9gRvd+
# QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAg
# NpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritUpimqF6TNDDAOBgNVHQ8BAf8E
# BAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAb
# BgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1UdHwREMEIwQKA+oDyGOmh0
# dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9v
# dFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUFBzAChjpodHRwOi8vY3J0
# LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYucDdj
# MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0B
# AQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aVcdGRP4Wh60BAscjW4HL9
# hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWTsyNyBBsMLHqafvIhrCym
# laS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+w/KeFvPYfLF/ldYpmlG+
# vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWDRF/3sBp6fWXhz7DcML4i
# TAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfCipnx8CaLZeVme5yELg09
# Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJszkyeiaerlphwoKx1uHRzNyE6
# bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z76mKnzAfZxCl/3dq3dUNw4rg3
# sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGvspbOrTfOXyXvmPL6E52z
# 1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95Ejza63zdrEcxWLDX6xWls
# /GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6SivBBOHY+uqiirZtg0y9
# ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2RwwggZTMIIE
# u6ADAgECAhEAvRiiZXfNKzg6bheExGTBoTANBgkqhkiG9w0BAQwFADBUMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0
# aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIyMDkxMjAwMDAwMFoX
# DTI1MDkxMTIzNTk1OVowaTELMAkGA1UEBhMCQkcxDjAMBgNVBAgMBVNvZmlhMSQw
# IgYDVQQKDBtUZWFtIFZJU0lPTiAtIEJ1bGdhcmlhIEx0ZC4xJDAiBgNVBAMMG1Rl
# YW0gVklTSU9OIC0gQnVsZ2FyaWEgTHRkLjCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAJClioq3JCgCDq+k8NSgi2R5biatrXbFwfVL81X6ag1S4c6piutp
# VTBVpdabzxIrsnr2e0u3ihg18XeoxMU2P9Bhj5eLXVYO4NZk6DfnNj0qrcXet6Ve
# WhEsFP4dBOjTPS+3iTfYHsNu69GcniTssvxZrOCoWSRFYhh5dw+IEhlYSVqu2AES
# Mo/o0Wn28zQXOaXf+WNkX+RJqBXVGt4+t6iGBSwMQev0i9vgh+HDz26Yym59cmDc
# QWUQRMjL3fm/MZ+dUa8ZjtMrd+VveKyRuCe7ixi/75qNylAvm3HEaQzHl6BkEJQB
# +O9yzFbimQtMF5Q7N9tCYJ4f2j+dCxRiyZAnqE6c9YllxmYK4qAvFpK+SOF+CHJp
# HeMZvjlvJTnM6bu9A/5MEP82wVBvBLJYV+jBCXYn/5lU2VTXV3kSjbxZcKOB7TKQ
# /+oWjRs4Id99zzHk7AGMxgzUiJWTKSn/FxgkB10+ahxggEC7tSKpI+4dmJZ4icCJ
# 70HNqZRBNpAYeGJQznqq834g6nW2byhA8haAt2kSViYvbQ2suM/zcFPOtCXu3oDq
# /tweNMlEvPcGtpWElgHFofCBnt1KgtYt0k/BHe9SgsJ15hQCL6ddgiiMyfJ+tM//
# JnW2Y///0e5DFuu6t/Hl2fZEInyxNPM6P8AIUiPiIlWLa5uSHOIUoik9AgMBAAGj
# ggGJMIIBhTAfBgNVHSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNVHQ4E
# FgQU7ry0t6lC8tH64YblZ8UwaUkgdO4wDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB
# /wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSgYDVR0gBEMwQTA1BgwrBgEEAbIx
# AQIBAwIwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYG
# Z4EMAQQBMEkGA1UdHwRCMEAwPqA8oDqGOGh0dHA6Ly9jcmwuc2VjdGlnby5jb20v
# U2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3JsMHkGCCsGAQUFBwEBBG0w
# azBEBggrBgEFBQcwAoY4aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVi
# bGljQ29kZVNpZ25pbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3Nw
# LnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQCFdLO62K2HZV+uBQSGU9Hb
# 4U2pmM8nOG6KO642EminPrZP1Yv9eOxal+xQk8B2qBBpELERrMrl0cWWB3nWS2lU
# uq6Cbj9/R8OPA06E6fpYHDOgI53unCLg9vsXgGd3nZZor3f9TqGEE5e/crGkoNxj
# twYdghk/+Nt9Sb/dvdvTk0C/AqWmAcpmH/O+oNc+iEr8VPOlfZooweYH/PRSoALP
# VBEAZBG9kLgshpNPRtDBXC3QrXcVzAKhX3VnSPaDS78iD2HIhsNicBWyFEHlfy/S
# LFP7g3Nm1hNdOn04uU9V4ItvFCvAwN2B0FTF1irE+lLTrzNu282g+ZnJFDFJG/X3
# bnGfdi/5HgjpCYV/bgRzu2we/Jy1XtAetomEOjlb4HEI15ujI9aRlWWjxfydH83L
# 3sedpWvKf3GLw8u9lBd8Xh2tBwVCDZPze6F4PFkEs2+Vp03roUERLldCJ0IdZPaB
# aaB1yRy7TSVgHUSMWIxM5LwOzCTi7h45XVV/YAzyuPUwgga0MIIEnKADAgECAhAN
# x6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# ITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAw
# MDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3Rh
# bXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMs
# VO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4
# kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8
# BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2
# Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwF
# t+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9o
# HRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq
# 6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+r
# x3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvU
# BDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl
# 9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwID
# AQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunk
# Bnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08w
# DgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEB
# BGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsG
# AQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4H
# PRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qE
# JPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy
# 9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe
# 9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1U
# H410ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6
# A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjs
# Yg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0
# vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/D
# Jbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHb
# xtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAP
# vIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIG7TCCBNWgAwIBAgIQCoDvGEuN8QWC
# 0cR2p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMO
# RGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGlt
# ZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAwMDAw
# MFoXDTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1l
# c3RhbXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx+wvA
# 69HFTBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvNZh6w
# W2R6kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlLnh00
# Cll8pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmncOOM
# A3CoB/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjPKHW5KqCvpSduSwhwUmot
# uQhcg9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL4Q1O
# pbybpMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7wJNdoRORVbPR1VVnDuSeH
# VZlc4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCyFG1r
# oSrgHjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOgrY7rlRyTlaCCfw7aSURO
# wnu7zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K096V1hE0yZIXe+giAwW0
# 0aHzrDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGjggGV
# MIIBkTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zyMe39/dfzkXFjGVBDz2GM
# 6DAfBgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMC
# B4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQG
# CCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKG
# UWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRp
# bWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSg
# UqBQhk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRU
# aW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAI
# BgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3xHCcE
# ua5gQezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh8/Ym
# RDfxT7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/ML9lFfim8/9yJmZSe2F8
# AQ/UdKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu+WUqW4daIqToXFE/JQ/E
# ABgfZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4obEMnxYOX8VBRKe1uNnzQ
# VTeLni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq8/gV
# utDojBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasnM9AWcIQfVjnzrvwiCZ85
# EE8LUkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol/DJgddJ35XTxfUlQ+8Hg
# gt8l2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1R9xJ
# gKf47CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3ocCVccAvlKV9jEnstrniLv
# UxxVZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcBZU8atufk+EMF/cWuiC7P
# OGT75qaL6vdCvHlshtjdNXOCIUjsarfNZzGCBkUwggZBAgEBMGkwVDELMAkGA1UE
# BhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGln
# byBQdWJsaWMgQ29kZSBTaWduaW5nIENBIFIzNgIRAL0YomV3zSs4Om4XhMRkwaEw
# DQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAvBgkqhkiG9w0BCQQxIgQgCFB8kPaTpw5kqjhUOJxOcrnlE9OdOv5bVF6K
# SqqLTUQwDQYJKoZIhvcNAQEBBQAEggIAii8DpaoWnPFDtrlFh427VVSD6Z6uiDXN
# W3jMbQX0xi6DIvRaiYVlD2SUq10HdFH4mo35fCE+QfplExjpyrwjpj5if3Mbvhpk
# Gxh+D9L77vLexZR9sVqi3paA9XQVkZglCcXSFTa8vBncYLveTwQuBQA1p5Szta3U
# HthgGayGnB6wHt3ws4YTJsxOWuGafLGOexfwE2ZJjgvqFGCN8mPAK7Xun5IaN15J
# +Ie/yEhEGAtzgOiPEBF6eeQo4eKjeJm19lRzro4BjlCr4gRD9nq/0gaXUZ1KPPY0
# mJoPTgSSDsC16t/67dv4kpfEiou8ldeRE3FsUZMOWBGYjJWzamIys5v/tlPdQNCn
# 08hNSDhUMjUlc6vLv8JHm0Ofs/agKyyGzY0PrR2z6a/FcQqOjCYHQ/67RLEo+KB6
# H3YhowppR8nwEykLmbEXSYMCD/41D5Sr9TiDtazFYeAN/VbsKIiD9UikqeCs3jkp
# 2YWNi0gbTnf/JAdoXBD+YcLR3aKyY/bJ4cMcXF2nw3zm9fZbSE1yRQIRAVsKTCnP
# wyd+N3vek+sv+pTy3L1HBvzPqny7X37CEr2epeiQCBjz7sdh3ag7m5aU1Nq3WQKb
# h9lOve7vjTM9QkWhY/ZGw267rEEAbZ03b2BgeaKbSbBpYBcT+FMgF0/x1+sZcqUi
# Xp8J8zyirYqhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8CAQEwfTBpMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUg
# Q0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcN
# AQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjUwODI3MTA1MzU4WjAv
# BgkqhkiG9w0BCQQxIgQgEPNPCdAMKBD4z96DPYrkUZ/0ldf5eF9ojRbQ2Yj5Jl0w
# DQYJKoZIhvcNAQEBBQAEggIANcVBw/CHq7npHybpDP9aVYrgjueBZ1ZJX5cbIbau
# JYh21NhZuZRGBWMcnrQln0CY8xI8/fxNk0dnNmTTREgPS2oEypoTIKLYjj3tCCPS
# 2yxKc9rqp4p87QtnvAKIh6Vxnj9QZY3hk+d3m+UOLwZhRjgkTn33fWdYWHpU/WAV
# dU0794q/O7V+NyobOVhBOeGMLtYw/bMdQmsxPonuwKy9Q3Y/rWB7J1SiT9qTlIE9
# hTQn6fbzpKNNQsEUJBgfgGSmj0/3w+edCtFeOcu6pTjRp5MF9HNYSIGnoUablgS6
# cuIdUvu4ZSLfRw/i/2boQPgByF0pvGYQIwPYV9jTpIHvXL5GdIbZggT1zya7ryIi
# B+k9KJm9L3TZiMqGCXbDMGcFTt6tvzdj60ET5IqTA2bRPKJ+pDJ6sWLv4ca6Znmt
# GtLA1ZkKt+nOpet93lKmQs05/q3P5lpFswjyg7984/hqhKsgFI8jPZ5Z0nO8o6O8
# aZ3D/DmtRBTjgZw2zPFgtjcpfCHhhGYzbhcdvmGfDVQyRRwDbQLhdVbThfhmQiG5
# EPPHtGbkl6uQCllJjrL16dNvAj601y0ElHPbEo2qnZSFmdxMI5lkTFhwB5Tt8ta1
# nPYsIfXWGwoY0XmO9/OBVL4TzIuIb5RC7McD0bGbjUCUid327y4Mb31BBRe21nfm
# J5U=
# SIG # End signature block
