USE [DBAperf_reports]
GO
/****** Object:  StoredProcedure [dbo].[dbasp_DiskSpaceChecks_Import]    Script Date: 8/16/2013 4:25:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC	[dbo].[dbasp_DiskSpaceChecks_Import]
AS
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE		@TableName				SYSNAME
			,@BCP_CMD				VarChar(max)
			,@DeleteRecords_CMD		VarChar(max)
			,@DeleteFiles_CMD		VarChar(max)

DECLARE ImportCursor CURSOR
FOR
SELECT		[Import_Destination]									[TableName]
		,'EXEC xp_cmdshell ''bcp DBAperf_reports.dbo.' + [Import_Destination] + ' in "' 
			+ [FullPathName] + '" -T -N'''							[BCP_CMD]
		,'DELETE DBAperf_reports.dbo.' + [Import_Destination] + ' WHERE [ServerName] = '''
			+[ServerName]+''' AND [RunDate] = '''+CONVERT(VarChar(12),[DateCreated],101)
			+''''										[DeleteRecords_CMD]
		,'EXEC xp_cmdshell ''DEL "'+ [FullPathName] +'"'''					[DeleteFiles_CMD]
FROM		(
			SELECT		Name
					,FullPathName
					,DateCreated
					,REPLACE(
						[dbaadmin].[dbo].[ReturnPart](
							[dbaadmin].[dbo].[dbaudf_base64_decode](
								LEFT(REPLACE([Name],'$','='),LEN([Name])-4)
								)
							,1)
						,'$'
						,'\')							[ServerName]
					,[dbaadmin].[dbo].[ReturnPart](
						[dbaadmin].[dbo].[dbaudf_base64_decode](
							LEFT(REPLACE([Name],'$','='),LEN([Name])-4)
							)
						,2)							[Import_Destination]
			FROM		dbaadmin.dbo.dbaudf_FileAccess_Dir2
						(dbaadmin.dbo.dbaudf_getShareUNC('dbasql') + '\DiskSpaceChecks',null,0)
			WHERE		Extension = '.dat'
					AND	DateModified >= GetDate()-30
			) DataFiles
ORDER BY	[DateCreated]
 

OPEN ImportCursor;
FETCH ImportCursor INTO @TableName,@BCP_CMD,@DeleteRecords_CMD,@DeleteFiles_CMD;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP
		IF OBJECT_ID('DBAperf_reports.dbo.'+@TableName) IS NOT NULL
		BEGIN
			IF @TableName NOT IN ('DMV_DiskSpaceForecast','DMV_DiskSpaceUsage')
				EXEC (@DeleteRecords_CMD)

			IF @TableName NOT IN ('DMV_DiskSpaceForecast','DMV_DiskSpaceUsage')
				EXEC (@BCP_CMD)

			EXEC (@DeleteFiles_CMD)
		END
		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM ImportCursor INTO @TableName,@BCP_CMD,@DeleteRecords_CMD,@DeleteFiles_CMD;
END
CLOSE ImportCursor;
DEALLOCATE ImportCursor;

