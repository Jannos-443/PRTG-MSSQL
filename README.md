# PRTG-SQL-BackupAge
# About

## Project Owner:

Jannos-443

## Project Details

Checks SQL Backup, Log Backup and Differential Backup Age for every database!

| Parameter | Default Value |
| --- | --- |
| BackupAge | $true |
| BackupAgeWarning | 24 (hours) |
| BackupAgeError | 27 (hours) |
| LogAge | $true |
| LogAgeWarning | 24 (hours) |
| LogAgeError | 27 (hours) |
| DiffAge | $false |
| DiffAgeWarning | 24 (hours) |
| DiffAgeError | 24 (hours) |

## HOW TO

1. Make sure the SQLServer Module exists on the Probe
   - `https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver15`

2. Place `PRTG-SQL-BackupAge.ps1` under `C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML`

3. Create new Sensor

   | Settings | Value |
   | --- | --- |
   | EXE/Script | PRTG-SQL-BackupAge.ps1 |
   | Parameters | `-sqlInstanz "SQL-Test" -BackupAgeWarning 56 -BackupAgeError 58 -IgnorePattern '(SQL-ABC)'` |
   | Scanning Interval | 10 minutes |


4. Set the "$IgnorePattern" or "$IgnoreScript" parameter to exclude databases



## Examples
![PRTG-SQL-BackupAge](media/Error.png)
![PRTG-SQL-BackupAge](media/Ok.png)

database exceptions
------------------
You can either use the **parameter $IgnorePattern** to exclude a database on sensor basis, or set the **variable $IgnoreScript** within the script. Both variables take a regular expression as input to provide maximum flexibility. These regexes are then evaluated againt the **Database Name**

By default, the $IgnoreScript varialbe looks like this:

```powershell
$IgnoreScript = '^(VMTest123|TestExcludeWildcard.*)$'
```

For more information about regular expressions in PowerShell, visit [Microsoft Docs](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions).

".+" is one or more charakters
".*" is zero or more charakters
