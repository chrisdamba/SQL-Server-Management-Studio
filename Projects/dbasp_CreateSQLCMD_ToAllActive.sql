 
DROP PROCEDURE dbasp_CreateSQLCMD_ToAllActive  
GO  
CREATE PROCEDURE dbasp_CreateSQLCMD_ToAllActive
	(
	@Command	VarChar(max)
	,@LoginName	sysname
	,@Password	sysname
	,@Excluded	varchar(max)
	,@SQLvers	varchar(max)
	)
AS	  
BEGIN  
	DECLARE	@TSQL	VarChar(max)

	DECLARE ActiveServerCursor CURSOR
	KEYSET
	FOR 
	SELECT	DISTINCT
		':CONNECT ' + SQLNAME 
		+ CASE Port
			WHEN 1433 THEN ''
			ELSE ',' + Port
			END
		+ CASE 	DomainName
			WHEN 'AMER' THEN ''
			ELSE ' -U ' + @LoginName + ' -P ' + @Password 
			END 
		+ CHAR(13) + CHAR(10)
		+ @Command + CHAR(13) + CHAR(10)
		+'GO' + CHAR(13) + CHAR(10)	
	from dbacentral.dbo.DBA_ServerInfo
	WHERE Active = 'Y'
	AND ServerName NOT IN 
	(SELECT DISTINCT ExtractedText FROM dbo.dbaudf_StringToTable(@Excluded,','))
	AND dbaadmin.dbo.Returnword(SQLver,4) IN 
	(SELECT DISTINCT ExtractedText FROM dbo.dbaudf_StringToTable(@SQLVers,','))
	ORDER BY SQLNAME
	OPEN ActiveServerCursor

	FETCH NEXT FROM ActiveServerCursor INTO @TSQL
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			PRINT @TSQL
		END
		FETCH NEXT FROM ActiveServerCursor INTO @TSQL
	END

	CLOSE ActiveServerCursor
	DEALLOCATE ActiveServerCursor
END
GO


exec dbasp_CreateSQLCMD_ToAllActive 
	--'EXEC msdb.dbo.sp_start_job N''UTIL - DBA Nightly Processing'''
	':r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql'
	,'DBAsledridge'
	,'Tigger4U'
	,'SEAVMSQLWVLOAD1,SEAPSHLSQL0A,FRETRZTSQL01,SEAFRESQLDBA01'
	,'2005,2008'

--SELECT	* FROM dbo.dbaudf_StringToTable ('SEAVMSQLWVLOAD1,SEAPSHLSQL0A,FRETRZTSQL01',',')



--REBOOT NEEDED
:CONNECT SEADCPCSQLA\A,1996 -U DBAsledridge -P Tigger4U
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT G1SQLB\B,1893 -U DBAsledridge -P Tigger4U
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT FREPTSSQL01
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT SEAPTRCSQLA\A,1608
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT SEADCSQLWVA\A,1501
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT SEADCSQLWVB\B,1477
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT G1SQLA\A,1252 -U DBAsledridge -P Tigger4U
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT FREPSQLRYLA01
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO
:CONNECT FREPSQLRYLB01
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO


--NETWORK ERROR

:CONNECT FRECSHWSQL01\A
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO

-- INSUFFICIENT MEMORY
:CONNECT SEAPDWDCSQLP0A
:r G:\Code\Operations\OnGoing\VSTS\CLR_Main\bin\Release\GettyImages.Operations.CLRTools.sql
GO




