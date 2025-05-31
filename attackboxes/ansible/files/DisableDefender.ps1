Import-Module GroupPolicy

# Define GPO name
$GPOName = "Disable Windows Defender - Test Lab"

try {
    # Create new GPO
    Write-Host "Creating GPO: $GPOName" -ForegroundColor Green
    $GPO = New-GPO -Name $GPOName -Comment "Disables Windows Defender for testing lab environment"
    
    # Configure registry settings to disable Windows Defender
    Write-Host "Configuring Windows Defender settings..." -ForegroundColor Yellow
    
    # Disable Real-time Protection
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableRealtimeMonitoring" -Type DWord -Value 1
    
    # Disable Windows Defender entirely
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" -ValueName "DisableAntiSpyware" -Type DWord -Value 1
    
    # Disable behavior monitoring
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableBehaviorMonitoring" -Type DWord -Value 1
    
    # Disable on access protection
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableOnAccessProtection" -Type DWord -Value 1
    
    # Disable scan on download
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableScanOnRealtimeEnable" -Type DWord -Value 1
    
    # Disable Windows Defender Security Center notifications
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -ValueName "DisableNotifications" -Type DWord -Value 1
    
    # Link GPO to domain (modify the DistinguishedName as needed for your environment)
    Write-Host "Linking GPO to domain..." -ForegroundColor Yellow
    $DomainDN = (Get-ADDomain).DistinguishedName
    New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes
    
    Write-Host "GPO created and linked successfully!" -ForegroundColor Green
    Write-Host "GPO Name: $GPOName" -ForegroundColor Cyan
    Write-Host "Linked to: $DomainDN" -ForegroundColor Cyan
    
    # Display GPO details
    Get-GPO -Name $GPOName | Select-Object DisplayName, CreationTime, ModificationTime, GpoStatus
    
} catch {
    Write-Error "Failed to create GPO: $($_.Exception.Message)"
}


# Optional: Force group policy update on all computers
Write-Host "`nTo apply immediately to all computers, run:" -ForegroundColor Magenta
Write-Host "Invoke-GPUpdate -Computer * -Force" -ForegroundColor White