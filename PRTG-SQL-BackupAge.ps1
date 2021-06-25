<#       
    .SYNOPSIS
    Checks SQL Backup, Log Backup and Differential Backup Age

    .DESCRIPTION
    Using Powershell to check the Last Backup Date from every Database in a specific SQL Instanz
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

    .PARAMETER BackupAge
    disables or enables Backup Age Monitoring (default = enabled)
    
    .PARAMETER BackupAgeWarning
    Warning Limit in hours for Backups

    .PARAMETER BackupAgeError
    Error Limit in hours for Backups

    .PARAMETER LogAge
    disables or enables Log Backup Age Monitoring (default = enabled)
    
    .PARAMETER LogAgeWarning
    Warning Limit in hours for Log Backups

    .PARAMETER LogAgeError
    Error Limit in hours for Log Backups

    .PARAMETER DiffAge
    disables or enables differential Backup Age Monitoring (default = disabled)
    
    .PARAMETER DiffAgeWarning
    Warning Limit in hours for differential Backups

    .PARAMETER DiffAgeError
    Error Limit in hours for differential Backups

    .PARAMETER IgnorePattern
    Regular expression to describe the Database Name for Example "Test-SQL" to exclude this Database.
    Example: ^(Test123)$ excludes Test123
    Example2: ^(Test123.*|TestTest123)$ excludes TestTest123, Test123, Test123456 and more.
    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1
    
    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    PRTG-SQL-BackupAge.ps1 -sqlInstanz "SQL-Test" -BackupAgeWarning 56 -BackupAgeError 58 -IgnorePattern '(Test123SQL|SQL-ABC)'

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-SQL-BackupAge

    SQLServer Powershell Module
    https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver15
#>
param(
    [string]$sqlInstanz = '',
    [string]$username = '',
    [string]$password = '',
    [Boolean]$BackupAge = $true,
    [int]$BackupAgeWarning = '24',
    [int]$BackupAgeError = '27',
    [Boolean]$LogAge = $true,
    [int]$LogAgeWarning = '2',
    [int]$LogAgeError = '4',
    [Boolean]$DiffAge = $false,
    [int]$DiffAgeWarning = '24',
    [int]$DiffAgeError = '24',
    [string]$IgnorePattern = ''
)

#catch all unhadled errors
$ErrorActionPreference = "Stop"

trap{
    $Output = "line:$($_.InvocationInfo.ScriptLineNumber.ToString()) char:$($_.InvocationInfo.OffsetInLine.ToString()) --- message: $($_.Exception.Message.ToString()) --- line: $($_.InvocationInfo.Line.ToString()) "
    $Output = $Output.Replace("<","")
    $Output = $Output.Replace(">","")
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$Output</text>"
    Write-Output "</prtg>"
    if($server -ne $null)
        {
        $server.ConnectionContext.Disconnect()
        }
    Exit
}

#Target specified?
if($sqlInstanz -eq "")
    {
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>No SQLInstanz specified</text>"
    Write-Output "</prtg>"
    Exit
    }

#Import sqlServer Module
Try{
    Import-Module SQLServer
}
catch
{
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>Error Loading SQLServer Powershell Module, please install Module First</text>"
    Write-Output "</prtg>"
    Exit
}

#Connect SQL and Get Databases
Try{
    #SQL Auth
    if(($username -ne "") -and ($password -ne ""))
        {
        $SrvConn = new-object Microsoft.SqlServer.Management.Common.ServerConnection
        $SrvConn.ServerInstance = $sqlInstanz
        $SrvConn.LoginSecure = $false
        $SrvConn.Login = $username
        $SrvConn.Password = $password
        $server = new-object Microsoft.SqlServer.Management.SMO.Server($SrvConn)
        }
    #Windows Auth (running User)  
    else
        {
        $server = new-object "Microsoft.SqlServer.Management.Smo.Server" $sqlInstanz
        } 

    #Get Databases
    $databases = $server.Databases

    }

catch{
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>SQL Instanz $($sqlInstanz) not found or access denied</text>"
    Write-Output "</prtg>"
    Exit
    }




#hardcoded list that applies to all hosts
$IgnoreScript = '^(Test-SQL-123|Test-SQL-12345|tempdb)$' 


#Remove Ignored
if ($IgnorePattern -ne "") {
    $databases = $databases | where {$_.Name -notmatch $IgnorePattern}  
}

if ($IgnoreScript -ne "") {
    $databases = $databases | where {$_.Name -notmatch $IgnoreScript}  
}


#Database(s) found?
if(($databases -eq 0) -or ($databases -eq $null))
    {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>No Databases found</text>"
    Write-Output "</prtg>"
    Exit
    }

$RecoveryModelSimple = 0
$RecoveryModelFull = 0
$Backup_Ok = 0
$Backup_Warning = 0
$Backup_Error = 0
$Backup_Text = ""
$Diff_Ok = 0
$Diff_Warning = 0
$Diff_Error = 0
$Diff_Text = ""
$Log_Ok = 0
$Log_Warning = 0
$Log_Error = 0
$Log_Text = ""

$CurrentTime = Get-Date

foreach($database in $databases)
    {
    #Region: Backup
    if($BackupAge)
        {
        $Time = [math]::Round((($CurrentTime - $database.LastBackupDate).TotalHours),2)
        $TimeOutput = $database.LastBackupDate.ToString("dd.MM.yyyy-HH:mm")
        if($database.LastBackupDate -eq (Get-Date(0)))
            {
            $Backup_Error += 1
            $Backup_Text += "$($database.Name) never backed up; "
            }
        elseif($Time -gt $BackupAgeError)
            {
            $Backup_Error += 1
            $Backup_Text += "$($database.Name) $($TimeOutput); "
            #$Backup_Text += "$($database.Name) $($Time)h ago; "
            }
        elseif($Time -gt $BackupAgeWarning)
            {
            $Backup_Warning += 1
            $Backup_Text += "$($database.Name) $($TimeOutput); "
            #$Backup_Text += "$($database.Name) $($Time)h ago; "
            }
        else
            {
            $Backup_Ok += 1
            }
        }
    #End Region

    #Region: differential Backup       
    if($DifferentialAge)
        {
        $Time = [math]::Round((($CurrentTime - $database.LastDifferentialBackupDate).TotalHours),2)
        $TimeOutput = $database.LastDifferentialBackupDate.ToString("dd.MM.yyyy-HH:mm")
        if($database.LastDifferentialBackupDate -eq (Get-Date(0)))
            {
            $Diff_Error += 1
            $Diff_Text += "$($database.Name) never backed up; "
            }
        elseif($Time -gt $DiffAgeError)
            {
            $Diff_Error += 1
            $Diff_Text += "$($database.Name) $($TimeOutput); "
            #$Diff_Text += "$($database.Name) $($Time)h ago; "
            }
        elseif($Time -gt $DiffAgeWarning)
            {
            $Diff_Warning += 1
            $Diff_Text += "$($database.Name) $($TimeOutput); "
            #$Diff_Text += "$($database.Name) $($Time)h ago; "
            }
        else
            {
            $Diff_Ok += 1
            }
        }
    #End Region

    #Check Recovery Model
    if($database.RecoveryModel -eq "Simple")
        {
        $RecoveryModelSimple += 1
        }

    #If Full, then check Backups
    if($database.RecoveryModel -eq "Full")
        {
        $RecoveryModelFull += 1
                
        #Region: Log Backup
        if($LogAge)
            {
            $Time = [math]::Round((($CurrentTime - $database.LastLogBackupDate).TotalHours),2)
            $TimeOutput = $database.LastLogBackupDate.ToString("dd.MM.yyyy-HH:mm")
            if($database.LastLogBackupDate -eq (Get-Date(0)))
                {
                $Log_Error += 1
                $Log_Text += "$($database.Name) never backed up; "
                }
            elseif($Time -gt $LogAgeError)
                {
                $Log_Error += 1
                $Log_Text += "$($database.Name) $($TimeOutput); "
                #$Log_Text += "$($database.Name) $($Time)h ago; "
                }
            elseif($Time -gt $LogAgeWarning)
                {
                $Log_Warning += 1
                $Log_Text += "$($database.Name) $($TimeOutput); "
                #$Log_Text += "$($database.Name) $($Time)h ago; "
                }
            else
                {
                $Log_Ok += 1
                }
            }
        #End Region

        }
    }

#Region: disconnect SQL Server
$server.ConnectionContext.Disconnect()
#End Region


$xmlOutput = '<prtg>'

#Region: Output Text

#Text no Warnings or Errors
if(($Backup_Error -eq 0) -and ($Diff_Error -eq 0) -and ($Log_Error -eq 0) -and ($Backup_Warning -eq 0) -and ($Diff_Warning -eq 0) -and ($Log_Warning -eq 0))
    {
    $Ok_Text = "all Backups Ok; "

    if($BackupAge)
        {
        $Ok_Text += "no Backups older $($BackupAgeWarning)h (Warning) or $($BackupAgeError)h (Error); "
        }
    if($LogAge)
        {
        $Ok_Text += "no Log Backups older $($LogAgeWarning)h (Warning) or $($LogAgeError)h (Error); "
        }
    if($DiffAge)
        {
        $Ok_Text += "no Diff Backups older $($DiffAgeWarning)h (Warning) or $($DiffAgeError)h (Error); "
        }

    $xmlOutput = $xmlOutput + "<text>$Ok_Text</text>"
    }

#Text for Warnings and Errors
else
    {
    $ErrorText = ""
    if($Backup_Text -ne "")
        {
        $ErrorText += "Backup: $($Backup_Text) ### "
        }

    if($Diff_Text -ne "")
        {
        $ErrorText += "Diff Backup: $($Diff_Text) ### "
        }

    if($Log_Text -ne "")
        {
        $ErrorText += "Log Backup: $($Log_Text)"
        }

    $xmlOutput = $xmlOutput + "<text>$ErrorText</text>"
    }
#End Region

#Region Output Channel
if($BackupAge)
    {
    $xmlOutput = $xmlOutput + "<result>
        <channel>Backups Ok</channel>
        <value>$Backup_Ok</value>
        <unit>Count</unit>
        </result>
        <result>
        <channel>Backups Warning</channel>
        <value>$Backup_Warning</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxWarning>0</LimitMaxWarning>
        </result>
        <result>
        <channel>Backups Error</channel>
        <value>$Backup_Error</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxError>0</LimitMaxError>
        </result>"
    }

if($DiffAge)
    {
    $xmlOutput = $xmlOutput + "<result>
        <channel>Diff Backups Ok</channel>
        <value>$Diff_Ok</value>
        <unit>Count</unit>
        </result>
        <result>
        <channel>Diff Backups Warning</channel>
        <value>$Diff_Warning</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxWarning>0</LimitMaxWarning>
        </result>
        <result>
        <channel>Diff Backups Error</channel>
        <value>$Diff_Error</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxError>0</LimitMaxError>
        </result>"
    }  
    
if($LogAge)
    {
    $xmlOutput = $xmlOutput + "<result>
        <channel>Log Backup Ok</channel>
        <value>$Log_Ok</value>
        <unit>Count</unit>
        </result>
        <result>
        <channel>Log Backups Warning</channel>
        <value>$Log_Warning</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxWarning>0</LimitMaxWarning>
        </result>
        <result>
        <channel>Log Backups Error</channel>
        <value>$Log_Error</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxError>0</LimitMaxError>
        </result>"
    }

$xmlOutput = $xmlOutput + "<result>
        <channel>Recovery Mode Simple DBs</channel>
        <value>$RecoveryModelSimple</value>
        <unit>Count</unit>
        </result>
        <result>
        <channel>Recovery Mode Full DBs</channel>
        <value>$RecoveryModelFull</value>
        <unit>Count</unit>
        </result>"

$xmlOutput = $xmlOutput + "</prtg>"

$xmlOutput
#End Region