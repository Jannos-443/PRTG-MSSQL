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
   | Parameters | `-sqlInstance "SQL-Test"` |
   | Scanning Interval | 10 minutes |


5. Set the include/exclude parameter if required

6. Use "-HideSize", "-HideUsedSpace" or "-HideFreeSpace" if you want to hide something.



## Examples

Run as Windows User
```powershell
... -sqlInstance "SQL-Test"
```

Explicit User and Password
```powershell
... -sqlInstance "SQL-Test" -username 'YourUser' -password 'YourPassword'
```

Named SQL Istance
```powershell
... -sqlInstance "SQL-Server01.example.com\InstanceTest"
```

Size for each mdf & ndf file
```powershell
... -sqlInstance "SQL-Test" -ShowFile
```


Size for each Logfile
```powershell
... -sqlInstance "SQL-Test" -ShowLog
```


Full Database Size:
```powershell
... -sqlInstance "SQL-Test" -ShowDatabase
```

Summed up Files for each DB
```powershell
... -sqlInstance "SQL-Test" -ShowFile -IncludeSum
```

Exclude Databases starting with Test_
```powershell
... -sqlInstance "SQL-Test" -ShowDatabase -ExcludeDB '^(Test_.*)$'
```

## Screenshots

![PRTG-MSSQL](media/size_file.png)

![PRTG-MSSQL](media/size_log.png)

![PRTG-MSSQL](media/size_db.png)

![PRTG-MSSQL](media/size_sum.png)

## Exceptions

You can either use the **parameter $IncludeDB/ExcludeDB** to exclude/include a database on sensor basis, or set the **variable $ExcludeScript/$IncludeScript** within the script. Both variables take a regular expression as input to provide maximum flexibility. These regexes are then evaluated againt the **Database Name**

For more information about regular expressions in PowerShell, visit [Microsoft Docs](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions).

".+" is one or more charakters
".*" is zero or more charakters