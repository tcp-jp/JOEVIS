
/*
============
Backup FPOS5
============
*/
USE FPOS5
DECLARE @SQLStatement VARCHAR(2000) 
SET @SQLStatement = 'C:\JOEVIS\JOEVIS_Backup_' + CONVERT(char(10), GetDate(),126) +'.bak' 
BACKUP DATABASE [FPOS5] TO  DISK = @SQLStatement
