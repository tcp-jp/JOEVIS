# JOEVIS 

## What is it?
JOEVIS.exe written in batch is the first iteration of the JOEVIS application. In version 1.0.0 there is currently only a single run script. This script does the following : 

## What does it do?
#### A quick rundown...
1. Creates a folder to store backups and logs if it does not already exist.
1. Checks if 7-Zip is installed, if it is not it installs it. 
1. Creates a scheduled task to run the program every morning if it does not already exist.
1. Sets the primary DNS of the device to the gateway address and the secondary address to Google's primary DNS
1. Checks the local network to see if there are any remote devices matching the requriements
1. Checks if the current day's backup already exists and exists if this is the case.
  1. If remote devices were found matching the requirements it checks to see if they have the backup and will copy the backup to them if required
1. Disables the firewall 
1. Disables UAC
1. Clears temp files
1. Disables Windows Updates
1. Runs a SQL query
  1. Does a backup of important data
  1. Clears tables to improve performance
  1. Shrinks the database
  1. Reindexes the necessary tables
  1. Checks DB health
1. Zips this backup.
  1. If there is no backup it performs a second attempt of this and zips again
1. Checks success of Zip. Retrying on failure
  1. If this fails it logs a fatal error to a seperate file
  1. On success checks integrity of zip
    1. Performs second zip in case of corruption
1. Checks free space left on device and compares to amount of space required to keep the next fortnight of backups
1. Checks database health from scan performed earlier
1. Purge old backups (local) older than a fortnight
1. If remote devices are found attempt to copy backup over to them
1. If remote devices are found matching requriements they are also purged for older than a fortnight

## The Inner Workings Explained
The default batch start. Remove prompt, enabledelayedexpansion to use variables within for loops and goto main function
```
@echo off
setlocal enabledelayedexpansion

goto main
```

The main function calls all other subroutines that build the program
```
:main
call :prelim
call :maintenance
call :mainSQL
call :zipRawBackup
call :checkBackupSuccess
call :checkFreeSpace
call :checkDBHealth
call :purgeOldBackups
if NOT [%deviceList%]==[] for %%a in (%deviceList:~0,-1%) do (echo Copying to %%a >> %log% && call :copyToDevice %%a)
pause
if NOT [%deviceList%]==[] (for %%a in (%deviceList:~0,-1%) do (
        forfiles -p "\\%%a\JOEVIS" -s -m *.zip -d -%daysToKeep% -c "cmd /c del /q @path" 
        echo Old files purged on %computername% >> %log% && cls))
echo JOEVIS finished for %backupDate% >> %log%
echo Terminating >> %log%
exit
```

The prelim is where the variables are defined and requirements checked 
```
:prelim
cls
set pwd=C:\JOEVIS\
if not exist %pwd% mkdir %pwd%
icacls %pwd% /q /c /t /grant "everyone":F >nul
set backupDate=%date:/=-%
set backupDate=%backupDate:~6,4%-%backupDate:~3,2%-%backupDate:~0,2%
set bakFile=%pwd%JOEVIS_Backup_%backupDate%.bak
set zipFile=%pwd%JOEVIS_Backup_%backupDate%.zip
set remoteZip=JOEVIS\JOEVIS_Backup_%backupDate%.zip
set log=%pwd%JOEVIS_%backupDate%.log
set sqlLog=%pwd%JOEVIS_SQL_%backupDate%.log
set errorLog=%pwd%JOEVIS_Error_%backupDate%.log
set daysToKeep=14
set passwords="P@S5W0rd1 P@S5W0rd2 P@S5W0rd3"
cls
cls
cls
echo JOEVIS Started for date %backupDate% >> %log%
call :checkRequirements
echo Settings : >> %log%
echo.    Days To Keep : %daysToKeep% >> %log%
call :getNetAddress
cls
call :checkForDevices
cls
call :checkAlreadyRun
cls
goto :eof
```

```
:checkRequirements
cls
echo Checking requirements >> %log% 
::nslookup, 7zip
call :7zip
cls
call :scheduledTask
cls
call :setDNS
cls
goto :eof
```


```
:7zip
cls
echo Checking for 7-Zip >> %log%
dir "%programfiles(x86)%" | find /i "7-zip" && cls && echo.    7-Zip found in %programfiles(x86)% >> %log% && set path=%path%;%programfiles(x86)%\7-Zip\; && goto :eof 
dir "%programfiles%" | find /i "7-zip" && echo.    7-Zip found in %programfiles% >> %log% && set path=%path%;%programfiles%\7-Zip\; && goto :eof
echo.    7-Zip not found in Program Files folders. Downloading... >> %log%
powershell -command (new-object system.net.webclient).downloadfile('https://www.7-zip.org/a/7z1900.exe', '%pwd%7-ZipInstaller.exe') && echo.    7-Zip installer successfully downloaded >> %log%
%pwd%7-ZipInstaller.exe /S && echo.    7-Zip installed successfully >> %log%
set path=%path%;%programfiles(x86)%\7-Zip\; 
del %pwd%7-ZipInstaller.exe /f
cls
goto :eof
```


```
:scheduledTask
cls
echo Checking Scheduled Task exists >> %log%
schtasks /query /tn "JOEVIS\JOEVIS" | find /i "joevis" || cls && schtasks /create /ru %username% /rp tissl /tr c:\windows\system32\JOEVIS.exe /tn "JOEVIS\JOEVIS" /sc daily /st 02:30 /rl highest && cls && echo Task does not exist. Task has now been created. Please ensure all settings are correct >> %log% && goto :eof
echo.    Task exists >> %log%
cls
goto :eof
```


```
:setDNS
cls
echo Ensuring DNS settings are correct >> %log%
for /f "tokens=2 delims=:" %%a in ('netsh interface ip show config ^| find /i "gateway" ^| find /i "default" ^| findstr /r "[0-9]*[.][0-9]*[.][0-9]*[.][0-9]*"') do set dns=%%a)
set dns=%dns:~22,-1%
netsh interface ip show dns "Ethernet" | find "%dns%" || echo Primary DNS is not set to gateway. Setting to gateway >> %log% && netsh interface ip set dns "Ethernet" static %dns% 2>> %log%
netsh interface ip show dns "Ethernet" | find "8.8.8.8" || echo Secondary DNS is not set to 8.8.8.8. Setting to 8.8.8.8 >> %log% && netsh interface ip add dns "Ethernet"  8.8.8.8 index=2 2>> %log%
echo DNS settings are correct>> %log%
cls
goto :eof
```

```
:getNetAddress
cls
for /f "tokens=2 delims=:" %%a in ('netsh interface ipv4 show addresses Ethernet ^| find /i "IP"') do (set gateway=%%a)
cls
for /f "tokens=1,2,3 delims=." %%b in ('echo %gateway%') do (set gateway=%%b.%%c.%%d.)
echo.    Network address is %gateway% >> %log%
cls
goto :eof
```


```
:checkForDevices
cls
echo. >> %log%
echo Checking for devices on the network >> %log%
set names=
for /l %%a in (2,1,253) do ( 
    for /f "tokens=2 delims=:" %%b in ('nslookup %gateway%%%a 2^>nul ^| find /i "name" | find /i "pos"') do (
        cls
        set store=%%b
        set names=!names!!store:~4,-1!,
        echo.    Found device !store:~4,-1! >> %log%)
    )
set deviceList=%names%
if [%deviceList%]==[] (echo No devices found >> %log%)
cls
goto :eof
```

```
:checkAlreadyRun
cls
if exist "%zipFile%" (echo. >> %log%
    cls
    echo JOEVIS Backup already exists for today >> %log% 
    cls)

if exist "%bakFile%" (echo. >> %log%
    echo JOEVIS backup found but not zipped >> %log%
    cls
    call :zipRawBackup
    cls)

if not [%deviceList%]==[] (echo Remote devices found >> %log%
    call :checkRemoteBackups)
if exist "%zipFile%" (echo Exiting >> %log% && exit)
goto :eof
```

```
:checkRemoteBackups
cls
for /f %%a in ("%zipFile%") do (set fileSize=%%~za)
for %%a in (%deviceList:~0,-1%) do (
        cls
        if exist \\%%a\%remoteZip% (echo Backup found on %%a >> %log%)
        if not exist \\%%a\%remoteZip% (echo Backup not found on %%a >> %log%
            echo Attempting to copy over todays backup to %%a >> %log%
            call :copyToDevice %%a)
echo Finished checking backups on remote devices >> %log%)
goto :eof
```

```
:maintenance
echo. >> %log%
echo Setting system configuration >> %log%
echo Disabling Firewalls >> %log%
netsh advfirewall set allprofiles state off 
cls
echo.    Firewalls Disabled >> %log%
echo Checking UAC >> %log%
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System | find /i "lua" | find "1" || echo.    UAC disabled >> %log% 
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System | find /i "lua" | find "1" && echo.    UAC enabled. Disabling >> %log% && reg.exe ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 0 /f >> %log% && echo.    UAC will be disabled on next reboot >> %log%
del %tmp% /q /f 2>nul && echo Temp files cleared >> %log%
sc queryex wuauserv | find /i "stop" || echo Stopping Windows Updates service >> %log% && sc stop wuauserv >> %log%
echo Disabling Windows Update service >> %log%
sc config wuauserv start= disabled >> %log% 
goto :eof
```

```
:mainSQL
cls
call :posCheck
echo. >> %log%
set pos=%pos:~0,-1%
echo Running main %pos% SQL script >> %log%
for %%a in (%passwords:~1,-1%) do (sqlcmd -S %computername%\%instance% -U sa -P %%a -i "JOEVIS_%pos%.sql" >> %sqlLog%
    if "%errorlevel%" EQU "0" goto :eof)
echo SQL Finished with errors. Please resolve issues >> %log%
cls
goto :eof
```

```
:posCheck
cls
reg query "HKLM\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL" /v CESSQL && cls
if "%ERRORLEVEL%" EQU "0" (set pos=FPOS 
    set instance=CESSQL 
    goto :eof)
reg query "HKLM\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL" /v MSSSQL && cls
if "%ERRORLEVEL%" EQU "0" (set pos=FPOS 
    set instance=MSSQL 
    goto :eof)
reg query "HKLM\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL" /v OCSERVER && cls
if "%ERRORLEVEL%" EQU "0"  (set pos=OCPOS
    set instance=OCServer
    goto :eof)  
echo ** FATAL ERROR ** >> %log%
echo Error: Failed to find SQL instance >> %log%
cls
exit
```

```
:backupSQL
cls
echo Likely error in SQL. Check logs to resolve >> %log%
echo Running %pos% backup only script >> %log%
for %%a in %passwords% do (sqlcmd -S %computername%\%instance% -U sa -P %%a -i "JOEVIS_%pos%_Backup_Only.sql" >> %sqlLog%
    cls
    if "%errorlevel%" EQU "0" goto :eof)
echo SQL Error(s). Please resolve issues >> %log%
cls
goto :eof
```

```
:checkBackupSuccess
cls
echo Checking if zip file exists >> %log%
if exist "%zipFile%" (echo Zip backup file exists >> %log% && goto :eof) 
if exist "%bakFile%" (echo Raw backup file exists >> %log% && call :zipRawBackup && goto :eof) 
if not exist "%bakFile%" (echo ** FATAL ERROR ** >> %errorLog% && echo Error: Failed to create raw backup file >> %log% && exit )
goto :eof
```

```
:zipRawBackup
cls
if not exist "%bakFile%" (echo Raw backup does not exist >> %log% && call :backupSQL && goto :eof)
echo Zipping raw backup file >> %log%
7z a "%zipFile%" "%bakFile%" | find /i "Everything is Ok" >> %log% && echo Raw backup successfully zipped >> %log% 
call :checkBackupSuccess
call :checkCorruptZip
cls
goto :eof
```

```
:copyToDevice
cls
if not exist "\\%~1\JOEVIS" (md "\\%~1\JOEVIS") && echo JOEVIS directory made on %~1 >> %log%
if exist "\\%~1\JOEVIS\JOEVIS_Backup_%backupDate%.zip" (echo JOEVIS backup found on %~1 >> %log% && goto :eof)
echo Checking free space in %~1\JOEVIS\ >> %log%
for /f "tokens=3 delims= " %%a in ('dir \\%~1\JOEVIS\ /-c 2^>^>%log% ^| find /i "free"') do (set freeSpace=%%a
    cls
    echo %~1 has %freeSpace% total free space >> %log%
    if %freeSpace% gtr %minSizeLeft% (
            cls
            echo JOEVIS backup not found on %~1 >> %log% 
            copy source "%zipFile%" destination \\%~1\JOEVIS\JOEVIS_Backup_%backupDate%.zip /y && echo Backup copied to %~1 >> %log% && goto :eof) else echo %~1 has not got enough free space to copy backup zip over >> %log%)
cls
goto :eof
```

```
:checkCorruptZip
cls
for /f %%a in ("%zipFile%") do (set fileSize=%%~za)
if %fileSize% LSS 1100 (echo Very small zip file. Creating another in case of corruption >> %log% 
    rename "%zipFile%" "%zipFile:~0,-4%_First.zip" 
    call :zipRawBackup && goto :eof)
del %bakFile% /f
cls
goto :eof
```

```
:checkFreeSpace
cls
echo. >> %log%
echo Checking free space left in bytes on device >> %log%
for /f "tokens=3 delims= " %%a in ('dir %pwd% /-c ^| find /i "free"') do (set freeSpace=%%a)
echo Local C: has %freeSpace% free space left >> %log%
echo Getting zip filesize >> %log%
if not exist "%zipFile%" (echo Zip file not found on %computername%. Checking for .bak file >> %log%)
if exist "%bakFile%" (call :zipRawBackup)
for /f %%a in ("%zipFile%") do (set fileSize=%%~za)
set /a minSizeLeft=%fileSize%*%daysToKeep%
echo Zip filesize is %fileSize%. Minimum required space set to %minSizeLeft% (%fileSize%*%daysToKeep%) >> %log%
if %freeSpace% lss %daysToKeep% (echo %computername% is going to run out of space soon >> %log%)
```

```
:checkDBHealth
cls
echo Checking DB health >> %log%
find /i "CHECKDB found 0 allocation errors and 0 consistency errors in database 'FPOS5'" %sqlLog% && echo.    No issues found >> %log% && goto :eof
echo Errors found in DB health >> %log%
echo Errors found in DB health >> %errorLog%
cls
goto :eof
```


```
:purgeOldBackups
cls
echo Purging old files >> %log%
forfiles -p "c:\JOEVIS" -s -m *.* -d -%daysToKeep% -c "cmd /c del /q @path" && echo Old files purged on %computername% >> %log%
echo Local files purged >> %log%
cls
goto :eof
```

```
if NOT [%deviceList%]==[] for %%a in (%deviceList:~0,-1%) do (echo Copying to %%a >> %log% && call :copyToDevice     %%a)
if NOT [%deviceList%]==[] (for %%a in (%deviceList:~0,-1%) do (
    forfiles -p "\\%%a\JOEVIS" -s -m *.zip -d -%daysToKeep% -c "cmd /c del /q @path"
    echo Old files purged on %computername% >> %log% && cls))
echo JOEVIS finished for %backupDate% >> %log% 
echo Terminating >> %log%
exit
```

-- Automation tool that backs up important data from SQL, checks system configuration settings and posts backups to devices on the network.


