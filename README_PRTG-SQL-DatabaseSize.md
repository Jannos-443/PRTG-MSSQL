# PRTG-SQL-DatabaseSize
# About

## Project Owner:

Jannos-443

## Project Details

Checks SQL database size, space available and used space for every database!

space available and used space (percent) is only shown if an maxlimit is set.
![PRTG-MSSQL](media/size_limit.png)


## HOW TO
1. Make sure your SQL User/Windows User has the required SQL Server permission
   required Custom SQL Server Role permission:

   - SERVER	CONNECT SQL

   - SERVER	VIEW SERVER STATE

   - SERVER	CONNECT ANY DATABASE

2. Make sure the SQLServer Module exists on the Probe
   - `https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver15`

3. Place `PRTG-SQL-DatabaseSize.ps1` under `C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML`

4. Create new Sensor

   | Settings | Value |
   | --- | --- |
   | EXE/Script Advanced | PRTG-SQL-DatabaseSize.ps1 |
   | Parameters | `-sqlInstanz "SQL-Test" -IgnorePattern '(SQL-ABC)'` |
   | Scanning Interval | 10 minutes |


5. Set the "$IgnorePattern" or "$IgnoreScript" parameter to exclude databases

6. Use "-HideSize", "-HideUsedSpace" or "-HideFreeSpace" if you want to hide something.



## Examples
Size for each mdf & ndf: `-sqlInstanz "SQL-Test" -ShowFile`

![PRTG-MSSQL](media/size_file.png)

Size for each Logfile: `-sqlInstanz "SQL-Test" -ShowLog`

![PRTG-MSSQL](media/size_log.png)

Full Database Size: `-sqlInstanz "SQL-Test" -ShowDatabase`

![PRTG-MSSQL](media/size_db.png)

Summed up DB Files for each: `-sqlInstanz "SQL-Test" -ShowFile -IncludeSum`
![PRTG-MSSQL](media/size_sum.png)

Summed Up DB File Sum for the DB "Test123": `-sqlInstanz "SQL-Test" -ShowFile -IncludeSum -IncludePattern '^(Test123)$'`

exceptions
------------------
You can either use the **parameter $IgnorePattern** to exclude a database on sensor basis, or set the **variable $IgnoreScript** within the script. Both variables take a regular expression as input to provide maximum flexibility. These regexes are then evaluated againt the **Database Name**

By default, the $IgnoreScript varialbe looks like this:

```powershell
$IgnoreScript = '^(Test-SQL-123|Test-SQL-12345.*)$'
```

For more information about regular expressions in PowerShell, visit [Microsoft Docs](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions).

".+" is one or more charakters
".*" is zero or more charakters