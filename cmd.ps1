# 1. Install IIS and necessary features
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, NET-Framework-45-Core, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console

# 2. Install .NET 6.0 Hosting Bundle (you need to download this manually from Microsoft's website)
# After downloading, run this command (adjust the path as necessary):
# Start-Process -FilePath "dotnet-hosting-6.0.0-win.exe" -ArgumentList "/install", "/quiet", "/norestart" -Wait

# 3. Install URL Rewrite Module (download from Microsoft's website and install)
# Start-Process -FilePath "rewrite_amd64_en-US.msi" -ArgumentList "/quiet", "/norestart" -Wait

# 4. Create a new application pool
$appPoolName = "YourAppPool"
New-WebAppPool -Name $appPoolName
Set-ItemProperty IIS:\AppPools\$appPoolName -name "managedRuntimeVersion" -value ""
Set-ItemProperty IIS:\AppPools\$appPoolName -name "startMode" -value "AlwaysRunning"
Set-ItemProperty IIS:\AppPools\$appPoolName -name "processModel.idleTimeout" -value "00:00:00"

# 5. Create a new website
$siteName = "YourSiteName"
$physicalPath = "C:\inetpub\wwwroot\YourSiteName"
New-Item -ItemType Directory -Force -Path $physicalPath
New-Website -Name $siteName -PhysicalPath $physicalPath -ApplicationPool $appPoolName -Force

# 6. Set website bindings (adjust as needed)
New-WebBinding -Name $siteName -IPAddress "*" -Port 5170 

# 7. Configure application pool identity (adjust as needed)
$identity = "ApplicationPoolIdentity" # or "LocalSystem", "LocalService", "NetworkService", or specific user
Set-ItemProperty IIS:\AppPools\$appPoolName -name "processModel.identityType" -value $identity

# 8. Enable necessary IIS modules
Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/modules" -name "." -value @{name='AspNetCoreModuleV2';lockItem='true'}

# 9. Configure web.config (create a basic one if it doesn't exist)
$webConfigPath = Join-Path $physicalPath "web.config"
if (-not (Test-Path $webConfigPath)) {
    @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" arguments=".\YourAppName.dll" stdoutLogEnabled="false" stdoutLogFile=".\logs\stdout" hostingModel="inprocess" />
    </system.webServer>
  </location>
</configuration>
"@ | Out-File -FilePath $webConfigPath -Encoding utf8
}

# 10. Set folder permissions
$acl = Get-Acl $physicalPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS AppPool\$appPoolName", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
Set-Acl $physicalPath $acl

# 11. Enable necessary Windows features for .NET 6.0
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All
Enable-WindowsOptionalFeature -Online -FeatureName NetFx4Extended-ASPNET45 -All

# 12. Restart IIS
iisreset /restart

# 13. Verify installation
Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Installed'} | Format-Table -Property Name,InstallState
Get-WebAppPool | Format-Table -Property Name,State,ManagedRuntimeVersion
Get-Website | Format-Table -Property Name,State,PhysicalPath,ApplicationPool