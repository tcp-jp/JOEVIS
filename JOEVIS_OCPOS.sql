USE [OCPOS]

-- ********Backup OCPOS
DECLARE @SQLStatement VARCHAR(2000) 
SET @SQLStatement = 'C:\Tissl\leebus\Leebus-' + CONVERT(char(10), GetDate(),126) +'.bak' 
BACKUP DATABASE [OCPOS] TO  DISK = @SQLStatement
GO




