<#
    .SYNOPSIS
    Checks SQL Database Size, Space Available and used Space

    .DESCRIPTION
    Using Powershell to check the SQL Database Size, Space Available and Used Space from every Database in a specific SQL Instanz
    Exceptions can be made within this script by changing the variable $IgnoreScript. This way, the change applies to all PRTG sensors
    based on this script. If exceptions have to be made on a per sensor level, the script parameter $IgnorePattern can be used.

    Copy this script to the PRTG probe EXEXML scripts folder (${env:ProgramFiles(x86)}\PRTG Network Monitor\Custom Sensors\EXEXML)
    and create a "EXE/Script Advanced" sensor. Choose this script from the dropdown and set at least:

    .PARAMETER sqlInstanz
    FQDN or IP of the SQL Instanz

    .PARAMETER username (if not specified Windows Auth is used)
    SQL Auth Username

    .PARAMETER password
    SQL Auth Password (if not specified Windows Auth is used)

    .PARAMETER ShowFile
    Show Channel for each Database File

    .PARAMETER ShowLog
    Show Channel for each Database Log

    .PARAMETER ShowDatabase
    Show Channel for each Database (Database File + Log + ...)

    .PARAMETER IncludeSum
    Includes SUM Channel from all Log and/or DB Files (One Value with the Size from all Log/DB files from each DB)

    .PARAMETER IncludeSize
    Includes SIZE Channel from all Log and/or DB Files (One Value for each Log/DB File)

    .PARAMETER IncludeUsedSpace
    Includes Used Space (percent) Channel <- only shown if a maxlimit is set

    .PARAMETER IncludeFreeSpace
    Includes FreeSpace Channel <- only shown if a maxlimit is set

    .PARAMETER ExcludeDB
    Regular expression to describe the Databases to exclude
    Example: ^(Test123)$ excludes Test123
    Example2: ^(Test123.*|TestTest123)$ excludes TestTest123, Test123, Test123456 and more.
    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1

    .PARAMETER IncludeDB
    Regular expression to describe the Databases to include

    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    PRTG-SQL-DatabaseSize.ps1 -sqlInstanz "SQL-Test" -ExcludeDB '(Test123SQL|SQL-ABC)' -ShowDatabase

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-MSSQL

    SQLServer Powershell Module
    https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver15
#>
param(
    [string]$sqlInstanz = '',
    [string]$username = '',
    [string]$password = '',
    [string]$IncludeDB = '',
    [string]$ExcludeDB = '',
    [Switch]$ShowFile,
    [Switch]$ShowDatabase,
    [Switch]$ShowLog,
    [Switch]$IncludeSum,
    [Switch]$IncludeSize,
    [Switch]$IncludeUsedSpace,
    [Switch]$IncludeFreeSpace
)

#catch all unhadled errors
$ErrorActionPreference = "Stop"

trap {
    $Output = "line:$($_.InvocationInfo.ScriptLineNumber.ToString()) char:$($_.InvocationInfo.OffsetInLine.ToString()) --- message: $($_.Exception.Message.ToString()) --- line: $($_.InvocationInfo.Line.ToString()) "
    $Output = $Output.Replace("<", "")
    $Output = $Output.Replace(">", "")
    $Output = $Output.Replace("#", "")
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$Output</text>"
    Write-Output "</prtg>"
    if ($server -ne $null) {
        $server.ConnectionContext.Disconnect()
    }
    Exit
}

#Target specified?
if ($sqlInstanz -eq "") {
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>No SQLInstanz specified</text>"
    Write-Output "</prtg>"
    Exit
}

#Import sqlServer Module
Try {
    Import-Module SQLServer
}
catch {
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>Error Loading SQLServer Powershell Module, please install Module First</text>"
    Write-Output "</prtg>"
    Exit
}

#Nothing Selected?
if (-not (($ShowFile) -or ($ShowDatabase) -or ($ShowLog))) {
    $ShowFile = $true
}

if (-not (($IncludeSum) -or ($IncludeSize) -or ($IncludeUsedSpace) -or ($IncludeFreeSpace))) {
    $IncludeSize = $true
}

#Connect SQL and Get Databases
Try {
    #SQL Auth
    if (($username -ne "") -and ($password -ne "")) {
        $SrvConn = new-object Microsoft.SqlServer.Management.Common.ServerConnection
        $SrvConn.ServerInstance = $sqlInstanz
        $SrvConn.LoginSecure = $false
        $SrvConn.Login = $username
        $SrvConn.Password = $password
        $server = new-object Microsoft.SqlServer.Management.SMO.Server($SrvConn)
    }
    #Windows Auth (running User)
    else {
        $server = new-object "Microsoft.SqlServer.Management.Smo.Server" $sqlInstanz
    }

    #Get Databases
    $databases = $server.Databases
}

catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>SQL Instanz $($sqlInstanz) not found or access denied</text>"
    Write-Output "</prtg>"
    Exit
}


#Region: Filter

#hardcoded list that applies to all hosts
$ExcludeScript = '' #Example: $ExcludeScript = '^(Test-SQL-123|Test-SQL-12345)$'
$IncludeScript = ''

if ($ExcludeDB -ne "") {
    $databases = $databases | Where-Object { $_.Name -notmatch $ExcludeDB }
}

if ($ExcludeScript -ne "") {
    $databases = $databases | Where-Object { $_.Name -notmatch $ExcludeScript }
}

if ($IncludeDB -ne "") {
    $databases = $databases | Where-Object { $_.Name -match $IncludeDB }
}

if ($IncludeScript -ne "") {
    $databases = $databases | Where-Object { $_.Name -match $IncludeScript }
}

#End Region Filter


#Region: disconnect SQL Server
$server.ConnectionContext.Disconnect()
#End Region

#Database(s) found?
if (($databases -eq 0) -or ($null -eq $databases)) {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>No Databases found</text>"
    Write-Output "</prtg>"
    Exit
}


#Region: Output Text
$xmlOutput = '<prtg>'
$NoSizeTXT = "please check permission, could not get data from: "
$NoSizeCount = 0
foreach ($database in $databases) {
    $DBFileSum = 0
    $LogFileSum = 0
    if ($null -eq $database.size) {
        $NoSizeTXT += "$($database.Name); "
        $NoSizeCount += 1
    }
    else {
        #Region: DB File
        if ($ShowFile) { # Size for each Database File (mdf, ndf)
            $filegroups = $null
            $filegroups = $database.FileGroups
            foreach ($filegroup in $filegroups) {
                $files = $filegroup.Files
                foreach ($file in $files) {
                    $SizeMB = $null
                    $SizeMB = [math]::Round($file.Size / 1024)

                    #Log Size
                    $DBFileSum += $SizeMB
                    if ($includeSize) {
                        $xmlOutput = $xmlOutput + "<result>
                        <channel>DB: $($database.name) File: $($file.name) size</channel>
                        <value>$([decimal]$SizeMB)</value>
                        <unit>Custom</unit>
                        <CustomUnit>MB</CustomUnit>
                        </result>"
                    }

                    #Check if SizeLimit is set
                    if (($file.MaxSize -ne -1) -and ($file.MaxSize -ne 2147483648)) {
                        #Log Used Space
                        if ($IncludeUsedSpace) {
                            $Used = (($file.UsedSpace) / $file.MaxSize) * 100
                            $Used = [math]::Round($Used, 0)
                            $xmlOutput = $xmlOutput + "<result>
                            <channel>DB: $($database.name) File: $($file.name) used</channel>
                            <value>$Used</value>
                            <unit>Percent</unit>
                            </result>"
                        }

                        #Log Free MB
                        $SpaceAvailableMB = $null
                        $SpaceAvailableMB = [math]::Round(($file.Maxsize - $file.UsedSpace) / 1024)
                        if ($IncludeFreeSpace) {
                            $xmlOutput = $xmlOutput + "<result>
                            <channel>DB: $($database.name) File: $($file.name) free space</channel>
                            <value>$([decimal]($SpaceAvailableMB))</value>
                            <unit>Custom</unit>
                            <CustomUnit>MB</CustomUnit>
                            </result>"
                        }
                    }
                }
            }
            # Show file sum
            if ($IncludeSum) {
                $xmlOutput = $xmlOutput + "<result>
                <channel>DB: $($database.name) file sum</channel>
                <value>$([decimal]$DBFileSum)</value>
                <unit>Custom</unit>
                <CustomUnit>MB</CustomUnit>
                </result>"
            }
        }
        #End Region DB File

        #Region: Database
        if ($ShowDatabase) { # Full Database Size (DB + Log + ...)
            $SizeByte = [math]::Round($database.size * 1048576)
            $SpaceAvailableMB = [math]::Round(($database.SpaceAvailable) / 1024)

            #Database Size
            if ($includeSize) {
                $xmlOutput = $xmlOutput + "<result>
                <channel>$($database.name) size</channel>
                <value>$([decimal]$SizeByte)</value>
                <unit>BytesDisk</unit>
                </result>"
            }

            #Check if SizeLimit is set
            if ($null -ne $database.MaxSizeInBytes) {
                #Database Used Space
                if ($IncludeUsedSpace) {
                    $Used = ($SizeByte / $database.MaxSizeInBytes) * 100
                    $Used = [math]::Round($Used, 0)
                    $xmlOutput = $xmlOutput + "<result>
                    <channel>$($database.name) used</channel>
                    <value>$Used</value>
                    <unit>Percent</unit>
                    </result>"
                }

                #Database Free MB
                if ($IncludeFreeSpace) {
                    $xmlOutput = $xmlOutput + "<result>
                    <channel>$($database.name) free space</channel>
                    <value>$([decimal]($SpaceAvailableMB *1048576))</value>
                    <unit>BytesDisk</unit>
                    </result>"
                }
            }
        }
        #End Region Database

        #Region:  Log
        if ($ShowLog) {
            $LogFiles = $null
            $LogFiles = $database.LogFiles
            foreach ($LogFile in $LogFiles) {
                $SizeMB = $null
                $SizeMB = [math]::Round($LogFile.Size / 1024)
                $LogFileSum += $SizeMB

                #Log Size
                if ($includeSize) {
                    $xmlOutput = $xmlOutput + "<result>
                    <channel>DB: $($database.name) LOG: $($LogFile.name) size</channel>
                    <value>$([decimal]$SizeMB)</value>
                    <unit>Custom</unit>
                    <CustomUnit>MB</CustomUnit>
                    </result>"
                }

                #Check if SizeLimit is set
                if (($LogFile.MaxSize -ne -1) -and ($LogFile.MaxSize -ne 2147483648)) {
                    #Log Used Space
                    if ($IncludeUsedSpace) {
                        $Used = (($LogFile.UsedSpace) / $LogFile.MaxSize) * 100
                        $Used = [math]::Round($Used, 0)
                        $xmlOutput = $xmlOutput + "<result>
                        <channel>DB: $($database.name) LOG: $($LogFile.name) used</channel>
                        <value>$Used</value>
                        <unit>Percent</unit>
                        </result>"
                    }

                    #Log Free MB
                    $SpaceAvailableMB = $null
                    $SpaceAvailableMB = [math]::Round(($LogFile.Maxsize - $LogFile.UsedSpace) / 1024)
                    if ($IncludeFreeSpace) {
                        $xmlOutput = $xmlOutput + "<result>
                        <channel>DB: $($database.name) LOG: $($LogFile.name) free space</channel>
                        <value>$([decimal]($SpaceAvailableMB))</value>
                        <unit>Custom</unit>
                        <CustomUnit>MB</CustomUnit>
                        </result>"
                    }
                }
            }
            # Show Log sum
            if ($IncludeSum) {
                $xmlOutput = $xmlOutput + "<result>
                <channel>DB: $($database.name) log sum</channel>
                <value>$([decimal]$LogFileSum)</value>
                <unit>Custom</unit>
                <CustomUnit>MB</CustomUnit>
                </result>"
            }
        }
        #End Region Log
    }
}

if ($NoSizeCount -ne 0) {
    $xmlOutput += "<text>$($NoSizeTXT)</text>"
}

$xmlOutput += "</prtg>"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::WriteLine($xmlOutput)
    #https://kb.paessler.com/en/topic/64817-how-can-i-show-special-characters-with-exe-script-sensors
}

catch {
    $xmlOutput
}