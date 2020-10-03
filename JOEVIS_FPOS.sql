/*
============
Backup FPOS5
============
*/
USE FPOS5
DECLARE @SQLStatement VARCHAR(2000) 
SET @SQLStatement = 'C:\JOEVIS\JOEVIS_Backup_' + CONVERT(char(10), GetDate(),126) +'.bak' 
BACKUP DATABASE [FPOS5] TO  DISK = @SQLStatement

/*
=====================
Print job queue purge
=====================
*/
USE FPOS5
DELETE PrintJob;

/*
================
Shrink databases
================
*/
DBCC SHRINKDATABASE (FPOS5, 10);
DBCC SHRINKDATABASE (FPOS5_Log, TRUNCATEONLY);
DBCC SHRINKFILE (FPOS5_Log, 1);

/*
===================
Rebuild SQL Indexes
===================
*/
USE FPOS5;   
DBCC DBREINDEX ('sale', ' ', 80);
DBCC DBREINDEX ('SaleCoupon', ' ', 80);  
DBCC DBREINDEX ('SaleCreditCard', ' ', 80); 
DBCC DBREINDEX ('SaleDiscount', ' ', 80); 
DBCC DBREINDEX ('SaleGiftSold', ' ', 80); 
DBCC DBREINDEX ('SaleGiftUsed', ' ', 80); 
DBCC DBREINDEX ('SaleItem', ' ', 80); 
DBCC DBREINDEX ('SaleItemCoupon', ' ', 80); 
DBCC DBREINDEX ('SaleItemDiscount', ' ', 80); 
DBCC DBREINDEX ('SaleMedia', ' ', 80); 
DBCC DBREINDEX ('SalePMS', ' ', 80); 
DBCC DBREINDEX ('SaleShare', ' ', 80); 
DBCC DBREINDEX ('SaleTax', ' ', 80); 
DBCC DBREINDEX ('SaleTender', ' ', 80); 
DBCC DBREINDEX ('Total', ' ', 80); 
DBCC DBREINDEX ('Activity', ' ', 80); 

USE FPOS5_Log;
DBCC DBREINDEX ('Log', ' ', 80);


/*
===============
Check DB Health
===============
*/
USE FPOS5
DBCC CHECKDB; 

-- Must find the below.
-- CHECKDB found 0 allocation errors and 0 consistency errors in database 'FPOS5'.


