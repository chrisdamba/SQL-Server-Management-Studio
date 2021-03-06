USE [DBAadmin]
GO
/****** Object:  StoredProcedure [dbo].[dbasp_Backup]    Script Date: 3/18/2015 3:28:40 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[dbasp_Backup] 
				(
				@DBname sysname = null
				,@PlanName sysname = null
				,@Mode CHAR(2) = null
				,@BkUpPath varchar(500) = null
				,@backup_name sysname = null
				,@DeletePrevious varchar(10) = 'before'
				,@FileGroups VarChar(MAX) = null
				,@ForceEngine SYSNAME = NULL
				,@ForceCompression bit = null
				,@ForceChecksum BIT = null
				,@CopyOnly BIT = 0
				,@process_mode sysname = 'normal'
				,@auto_diff char(1) = 'y'
				,@ForceSetSize INT = null
				,@BufferCount		INT		= NULL
				,@MaxTransferSize	INT		= NULL
				)
 

/***************************************************************
 **  Stored Procedure dbasp_Backup                  
 **  Written by Jim Wilson, Getty Images                
 **  September 05, 2013                                      
 **
 **  This procedure is used for various 
 **  database backup processing.
 **
 **  This proc accepts several input parms: 
 **
 **  Either @dbname or @planname is required.
 **
 **  - @dbname is the name of the database to be backed up.
 **
 **  - @PlanName is the maintenance plane name if one is being used.
 **
 **  - @Mode is the backup mode (BF = full, BD = differential, BL = t-log)
 **
 **  - @BkUpPath is the target output path (optional)
 **
 **  - @backup_name can be used to override the backup file name
 **    when backing up a single database. (optional)
 ** 
 **  - @DeletePrevious ('before', 'after' or 'none') indicates if
 **    and when you want to delete the previous backup file(s).
 **
 **  - @FileGroups is used for FG processing ('All', 'None', 'FGname' or null).
 ** 
 **  - @ForceEngine can force the backup engine that is used ('MSSQL' or 'REDGATE').
 **
 **  - @ForceCompression (0=off, 1=on) indicates if you want to force compression processing.
 ** 
 **  - @ForceChecksum (0=off, 1=on) will force the checksum option for the backup process.
 ** 
 **  - @CopyOnly will set the CopyOnly option for the backup process (0=off, 1=on).
 ** 
 **  - @process_mode (normal, pre_release, pre_calc, mid_calc)
 **    is for special processing where the backup file is written to a 
 **    sub folder of the backup share.
 ** 
 **  - @auto_diff (y or n) creates a differential backup for all
 **    non-system processed databases.
 **
 **  - @ForceSetSize sets the number of files used for multi-file backup processing (64 max).
 **
 **	WARNING: BufferCount and MaxTransferSize values can cause Memory Errors
 **	   The total space used by the buffers is determined by: buffercount * maxtransfersize * DB_Data_Devices
 **	   blogs.msdn.com/b/sqlserverfaq/archive/2010/05/06/incorrect-buffercount-data-transfer-option-can-lead-to-oom-condition.aspx
 **
 **	@BufferCount		If Specified, Forces Value to be used				  X	  X
 **	@MaxTransferSize	If Specified, Forces Value to be used (specifiy in bytes e.g. 524288 = 512kb)
 **	
 ***************************************************************/
  as
SET NOCOUNT ON

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	09/05/2013	Jim Wilson		New all in one backup process based on dbasp_backupDBs 
--	11/20/2013	Jim Wilson		New delete old file processing. 
--	12/02/2013	Jim Wilson		Revised backup cleanup for File Groups. 
--	12/26/2013	Jim Wilson		Set size for companion diff to 1. 
--	01/06/2014	Jim Wilson		Fixed missing #filelist table. 
--	03/07/2014	Jim Wilson		Delete previous before is now the default. 
--	03/10/2014	Jim Wilson		New check for full backup before diff or tran. 
--	08/19/2014	Jim Wilson		Added code to check for AvailGrp. 
--	10/28/2014	Steve Ledridge		Added Parameters for @MaxTransferSize and @BufferCount to be used for both Backup and Restore Database scripts.
--	11/24/2014	Steve Ledridge		Added Code to check if database is preferred backup replica
--	02/19/2015	Steve Ledridge		Added Code to check if database is Primary Replica.
--	03/02/2015	Steve Ledridge		Test for availability groups being enabled.
--	03/18/2015	Steve Ledridge		Prevent Full Backups for Calc Databases in Calc Window
--	======================================================================================

/***
Declare @DBname sysname
Declare @PlanName sysname
Declare @Mode CHAR(2)
Declare @BkUpPath varchar(500)
Declare @backup_name sysname
Declare @DeletePrevious varchar(10)
Declare @FileGroups VarChar(MAX)
Declare @ForceEngine SYSNAME
Declare @ForceCompression BIT
Declare @ForceChecksum BIT
Declare @CopyOnly BIT
Declare @process_mode sysname
Declare @auto_diff char(1)
Declare @ForceSetSize INT
Declare @BufferCount INT
Declare @MaxTransferSize INT

--Select @DBname = 'RM_Integration'
Select @PlanName = 'mplan_user_full'
Select @Mode = 'BD'
--Select @BkUpPath = 'D:\'
--Select @backup_name = 'master_db_test'
Select @DeletePrevious = 'before'
--Select @FileGroups = 'Primary, FG2'
--Select @ForceEngine = 'Redgate'
Select @ForceCompression = null
Select @ForceChecksum = 1
Select @CopyOnly = 0
--Select @process_mode = 'pre_calc'
Select @auto_diff = 'y'
--Select @ForceSetSize = 1
Select @BufferCount = null
Select @MaxTransferSize = null
--***/


DECLARE  
	 @miscprint			nvarchar(4000)
	,@cmd				nvarchar(4000)
	,@syntax_out			varchar(max)
	,@retcode			int
	,@std_backup_path		nvarchar(255)
	,@outpath 			nvarchar(500)
	,@outpath2			nvarchar(500)
	,@outpath3 			nvarchar(500)
	,@outpath_archive		nvarchar(500)
	,@fileexist_path		nvarchar(500)
	,@error_count			int
	,@parm01			nvarchar(100)
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_servername3		sysname
	,@charpos			int
	,@exists 			bit
	,@backup_type			sysname
	,@save_delete_mask_db		sysname
	,@save_delete_mask_diff		sysname
	,@save_FileGroups		VarChar(MAX) 
	,@hold_FileGroups		VarChar(MAX)
	,@delete_Data_db		XML 
	,@delete_Data_diff		XML 
	,@hold_single_FG		sysname
	,@hold_dd_id			int
	,@a				int
	,@save_productversion		sysname
	,@CalcWindow			nVarChar(50)


DECLARE
	 @save_DBname			sysname


----------------  initial values  -------------------
Select @error_count = 0
Select @exists = 0

Select @save_servername		= @@servername
Select @save_servername2	= @@servername
Select @save_servername3	= @@servername

Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))

	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')

	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end

Select @outpath3 = '\\' + @save_servername + '\' + @save_servername2 + '_dba_archive\' + @save_servername3 + '_RestoreFull_'



--  Create Temp Tables
declare @DBnames table	(name sysname)

declare @filegroupnames table (
			 name sysname
			,data_space_id int)

create table #DirectoryTempTable(cmdoutput nvarchar(255) null)

create table #DBdelete(dd_id [int] IDENTITY(1,1) NOT NULL
			,delete_Data_db XML null)

create table #fileexists ( 
	doesexist smallint,
	fileindir smallint,
	direxist smallint)




--  Check input parameters
If @Mode is null or @Mode not in ('BF', 'BD', 'BL')
   begin
	Print 'DBA Warning:  Invalid input parameter.  @Mode parm must be ''BF'', ''BD'' or ''BL''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If (@DBname is null or @DBname = '') and (@backup_name is not null)
   begin
	Print 'DBA Warning:  Invalid input parameters.  @backup_name can only be set for single DB backups.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @DeletePrevious not in ('before', 'after', 'none')
   begin
	Print 'DBA Warning:  Invalid input parameter.  @DeletePrevious parm must be ''before'', ''after'' or ''none''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @process_mode not in ('normal', 'pre_release', 'pre_calc', 'mid_calc')
   begin
	Print 'DBA Warning: Invalid input parameter.  @process_mode parm must be ''normal'', ''pre_release'', ''pre_calc'' or ''mid_calc''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @PlanName is not null and @PlanName <> ''
   begin
	If not exists (select * from msdb.dbo.sysdbmaintplans Where plan_name = @PlanName)
	   begin
		Print 'DBA WARNING: Invaild parameter passed to dbasp_backup - @PlanName parm is invalid'
		Select @error_count = @error_count + 1
		Goto label99
	   end
	Else
	   begin
		If @backup_name is not null
		   begin
			Print 'DBA Warning:  Invalid input parameters.  A specific backup name can only be set for a single DB backup.'
			Select @error_count = @error_count + 1
			Goto label99
		   end

		Print 'Process mode: Maintenance plan = ' + @PlanName
	   end
   end
Else If @DBname is not null
   begin
	If not exists(select 1 from master.sys.sysdatabases where name = @DBname)
	   begin
		Print 'DBA Warning:  Invalid input parameter.  Database ' + @DBname + ' does not exist on this server.'
		Select @error_count = @error_count + 1
		Goto label99
	   end
	Else
	   begin   
   		Print 'Process mode: Single DB = ' + @DBname
	   end
   end
Else
   begin
	Print 'DBA Warning:  Invalid input parameter.  @DBname or @PlanName must be specified'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @ForceSetSize is not null and @ForceSetSize > 64
   begin
	Print 'DBA WARNING: Invaild parameter passed to dbasp_backup - @ForceSetSize max is 64.'
	Select @error_count = @error_count + 1
	Goto label99
   end



If @backup_name is not null
   begin
	Select @auto_diff = 'n'
   end


--  Set backup path
Select @parm01 = @save_servername2 + '_backup'
If exists (select 1 from dbo.local_serverenviro where env_type = 'backup_path')
   begin
	Select @std_backup_path = (select top 1 env_detail from dbo.local_serverenviro where env_type = 'backup_path')
   end
Else
   begin
	exec dbaadmin.dbo.dbasp_get_share_path @parm01, @std_backup_path output
   end

Select @outpath = COALESCE(@BkUpPath, @std_backup_path)



If @process_mode = 'pre_release' and @outpath = @std_backup_path
   begin
	--  check to see if the @pre_release folder exists (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @std_backup_path + '\pre_release'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @std_backup_path + '\pre_release"'
		Print 'Creating pre_release folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output 
	   end

	--  set @outpath
	Select @outpath = @std_backup_path + '\pre_release'
   end
Else If @process_mode = 'pre_calc' and @outpath = @std_backup_path
   begin
	--  check to see if the @pre_calc folder exists (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @std_backup_path + '\pre_calc'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @std_backup_path + '\pre_calc"'
		Print 'Creating pre_release folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output 
	   end

	--  set @outpath
	Select @outpath = @std_backup_path + '\pre_calc'
   end
Else If @process_mode = 'mid_calc' and @outpath = @std_backup_path
   begin
	--  check to see if the @mid_calc folder exists (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @std_backup_path + '\mid_calc'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @std_backup_path + '\mid_calc"'
		Print 'Creating pre_release folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output 
	   end

	--  set @outpath
	Select @outpath = @std_backup_path + '\mid_calc'
   end



--  Make sure the path ends with '\'
Select @outpath2 = reverse(@outpath)
If left(@outpath2, 1) <> '\'
   begin
	Select @outpath2 = '\' + @outpath2
   end
Select	@outpath2 = reverse(@outpath2)
	,@outpath = @outpath2 -- Keep safe to reset in DB Loop

Print 'Standard Backup output path is ' + @outpath2




/****************************************************************
 *                MainLine
 ***************************************************************/
--  Populate temp table with DB's to process
delete from @DBnames

If @PlanName is not null
   begin
	Select @cmd = 'SELECT d.database_name
	   From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s ' + 
	  'Where d.plan_id = s.plan_id
	     and s.plan_name = ''' + @PlanName + ''''

	insert into @DBnames (name) exec (@cmd)

	delete from @DBnames where name is null or name = ''

	If exists (select 1 from @DBnames where name like '%All System Databases%')
	   begin
		Delete from @DBnames where name like '%All System Databases%'
		insert into @DBnames (name) values('master')
		insert into @DBnames (name) values('model')
		insert into @DBnames (name) values('msdb')
	   end
   end
Else
   begin
	insert into @DBnames (name) values(@DBname)
   end
        
--select * from @DBnames
If (select count(*) from @DBnames) = 0
   begin
	Print 'DBA Error:  No databases selected for backup.'
	select * from @DBnames
	Select @error_count = @error_count + 1
	Goto label99
   end



--  Start processing
start_dbnames:

Select	@save_DBname = (select top 1 name from @DBnames order by name)
	,@outpath2 = @outpath -- RESET IF CHANGED BY PRIOR DATABASE




---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
--			DATABASE AVAILABILITY GROUP CHECKS
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
SELECT @save_productversion = convert(sysname, SERVERPROPERTY ('productversion'))
IF	@save_productversion > '11.0.0000' --sql2012 or higher
  and	@save_productversion not like '9.00.%'
  and	object_id('sys.fn_hadr_backup_is_preferred_replica') is not null -- availability groups enabled on the server
   BEGIN
	---------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------
	--			CHECK IF DATABASE IS IN AVAILABILITY GROUP
	---------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------

	SET @a = 0
	-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
	SELECT @cmd = 'SELECT @a = 1 FROM master.sys.dm_hadr_database_replica_cluster_states WHERE database_name = ''' + @save_DBname  + ''''
	--Print @cmd
	--Print ''
	EXEC sp_executesql @cmd, N'@a int output', @a output

	IF @a = 0
	   BEGIN
		RAISERROR('DBA Note: DB %s is not in an Always On Availability Group.  Backups are unchanged from normal.', -1,-1,@save_DBname) with nowait
		GOTO AGCheck_end
	   END

	---------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------
	--			CHECK IF DATABASE IS PREFERRED REPLICA
	---------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------

	SET @a = 0
	-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
	SELECT @cmd = 'SELECT @a = sys.fn_hadr_backup_is_preferred_replica (''' + @save_DBname  + ''')'
	--Print @cmd
	--Print ''
	EXEC sp_executesql @cmd, N'@a int output', @a output

	IF @a = 0
	   BEGIN
		RAISERROR('DBA Note: Skipping DB %s.  This DB is not the prefered replica in an Always On Availability Group.', -1,-1,@save_DBname) with nowait
		GOTO loop_end
	   END
	ELSE
		RAISERROR('DBA Note: DB %s is the prefered replica in an Always On Availability Group.', -1,-1,@save_DBname) with nowait


	---------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------
	--			CHECK IF DATABASE IS PRIMARY REPLICA
	---------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------
	SET @a = 0
	-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
	
	-- ONLY VALID IN SQL 2014
	--Select @cmd = 'SELECT @a = sys.fn_hadr_is_primary_replica (''' + @save_DBname  + ''')'

	Select @cmd = 'SELECT		@a = ars.role
			FROM		sys.dm_hadr_availability_replica_states ars
			INNER JOIN	sys.databases dbs
				ON	ars.replica_id = dbs.replica_id
			WHERE		dbs.name = ''' + @save_DBname  + ''';
			SET	@a	= COALESCE(@a,1);'

	--Print @cmd
	--Print ''
	EXEC sp_executesql @cmd, N'@a int output', @a output

	IF @a != 1
	   BEGIN
		print @save_DBname
		raiserror('DBA Note: DB %s is NOT the Primary Replica. No Differential Backups can be done and Full Backups must be COPY_ONLY.', -1,-1,@save_DBname) with nowait

		-- Force Full Backups IF not Primary and trying to do a Differential.
		IF @Mode = 'BD'
			SET @Mode = 'BF'

		-- Force Copy Only for Full Backups.
		IF @Mode = 'BF'
			SET @CopyOnly = 1
	   END
	ELSE
		raiserror('DBA Note: DB %s is the Primary Replica. Backups are unchanged from normal.', -1,-1,@save_DBname) with nowait

   AGCheck_end:
   END

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
--				CHECK IF DATABASE IS IN CALC WINDOW
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------

	IF @Mode = 'BF'	-- CALCS WINDOW ONLY PREVENTS FULL BACKUPS ON RELATED DATABASE AND REVERTS THEM TO DIFFS
	BEGIN
		-- CHECK MASTER DATABASE TO SEE IF CALCS WINDOW IS OPEN
		SET @CalcWindow = NULL
		SELECT		@CalcWindow = CAST(value AS nVarChar(50))
		FROM		[Master].sys.fn_listextendedproperty(N'CalcWindow',default,default,default,default,default,default)

		IF @CalcWindow = 'Open'
		BEGIN
			raiserror('	-- *** CALCS WINDOW IS OPEN ***', -1,-1) with nowait
			SET @CalcWindow = NULL

			-- GET CALC WINDOW FROM SPECIFIC DATABASE TO SEE IF IT IS INCLUDED IN THE CALCS PROCESS
			SET		@cmd = 'SELECT @CalcWindow = CAST(value AS nVarChar(50)) FROM ['+ @save_DBname +'].sys.fn_listextendedproperty(N''CalcWindow'',default,default,default,default,default,default)'
			--Print @cmd
			--Print ''
			EXEC sp_executesql @cmd, N'@CalcWindow nVarChar(50) output', @CalcWindow output

			IF @CalcWindow = 'Open'
			BEGIN
				raiserror('DB %s is Included in the Calcs Window so A Full Backup cannot be performed. A Diff will be run instead.', -1,-1,@save_DBname) with nowait
				SET @Mode = 'BD'
			END
		END
	END


Print ' '
Print '=========================================================================== '
Print '** Start Backup Processing for DB: ' + @save_DBname
Print '=========================================================================== '
Print ' '


-------------------------------------------------------------
-------------------------------------------------------------
--	RESET PER-DATABASE BACKUP PATH IF OVERRIDE EXISTS
-------------------------------------------------------------
-------------------------------------------------------------
-- USE EXAMPLE:
--	INSERT INTO dbaadmin.dbo.Local_Control(Subject,Detail01,Detail02) VALUES ('backup_location_override','{DBNAME}','{PATH}')
--
-------------------------------------------------------------
-------------------------------------------------------------
SELECT		@OutPath2 = CASE RIGHT(Detail02,1) WHEN '\' THEN Detail02 ELSE Detail02+'\' END
from		dbaadmin.dbo.Local_Control 
WHERE		subject = 'backup_location_override'
	AND	Detail01 = @save_DBname


If not exists (select 1 from master.sys.databases where name = @save_DBname)
   begin
	Print 'DBA Warning:  Skip backup for missing DB: ' + @save_DBname
	goto loop_end
   end

-------------------------------------------------------------
-------------------------------------------------------------
--
--	IF DATABASE IS LOGSHIPPING PRIMARY DO NOT BACKUP TRANLOG
--
-------------------------------------------------------------
-------------------------------------------------------------
IF @Mode = 'BL' and @save_DBname in (SELECT primary_database from msdb.dbo.log_shipping_primary_databases)
   begin
	Select @miscprint = 'DBA INFO: Database (' + @save_DBname + ') is a Logshipping Primary DB, dbasp_backup cannot be used to do t-log backup'
	raiserror(@miscprint,-1,-1)
	goto loop_end
   end

IF @Mode = 'BL' and databaseproperty(@save_DBname, 'IsTrunclog') <> 0
   begin
	Select @miscprint = 'DBA INFO: Database (' + @save_DBname + ') is not in full recovery mode.  Transaction log backup request is being skipped.'
	raiserror(@miscprint,-1,-1)
	goto loop_end
   end



--  Check for filegroup backup
Select @save_FileGroups = null

If @mode = 'BF'
   begin
	If @FileGroups is not null
	   begin
		Select @save_FileGroups = @FileGroups
	   end
	Else If exists (select 1 from dbo.Local_Control where subject = 'backup_by_filegroup' and Detail01 = rtrim(@save_DBname))
	   begin
		Select @save_FileGroups = 'all'
	   end
   end

   
--  Set up for delete processing
Select @backup_type = CASE @Mode WHEN 'BF' THEN '_db_'
                                 WHEN 'BD' THEN '_dfntl_'
                                 WHEN 'BL' THEN '_tlog_'
                                 END



If @save_FileGroups is null or @save_FileGroups = 'none'
   begin
	Print 'Backup Type for File cleanup is ' + @backup_type + '.'

	Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

	SELECT @delete_Data_db = 
	( 
	SELECT FullPathName [Source] 
	FROM dbaadmin.dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
	FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
	) 
	Insert into #DBdelete values(@delete_Data_db)
	--SELECT * from #DBdelete 
   end
Else
   begin
	Select @charpos = charindex(',', @save_FileGroups)

	If @save_FileGroups = 'all'
	   begin
		Select @backup_type = ''
		Select @backup_type = '_FG'

		Print 'Backup Type for File cleanup is ' + @backup_type + '.'

		Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

		SELECT @delete_Data_db = 
		( 
		SELECT FullPathName [Source] 
		FROM dbaadmin.dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
		FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
		) 
		Insert into #DBdelete values(@delete_Data_db)
		--SELECT * from #DBdelete 
	   end
	Else IF @charpos = 0
	   begin
		Select @backup_type = ''
		Select @backup_type = '_FG$' + @save_FileGroups + '_'

		Print 'Backup Type for File cleanup is ' + @backup_type + '.'

		Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

		SELECT @delete_Data_db = 
		( 
		SELECT FullPathName [Source] 
		FROM dbaadmin.dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
		FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
		) 
		Insert into #DBdelete values(@delete_Data_db)
		--SELECT * from #DBdelete 
	   end
	Else
	   begin
		Select @hold_FileGroups = rtrim(@save_FileGroups)
		Select @hold_FileGroups = reverse(@hold_FileGroups)
		If left(@hold_FileGroups, 1) <> ','
		   begin
			Select @hold_FileGroups = ',' +  @hold_FileGroups
			Select @hold_FileGroups = reverse(@hold_FileGroups)
		   end

		start_FGnames_parse:

		Select @hold_single_FG = left(@hold_FileGroups, @charpos-1)

		Select @backup_type = ''
		Select @backup_type = '_FG$' + @hold_single_FG + '_'

		Print 'Backup Type for File cleanup is ' + @backup_type + '.'

		Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

		SELECT @delete_Data_db = 
		( 
		SELECT FullPathName [Source] 
		FROM dbaadmin.dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
		FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
		) 
		Insert into #DBdelete values(@delete_Data_db)
		--SELECT * from #DBdelete 

		Select @hold_FileGroups = substring(@hold_FileGroups, @charpos+1, len(@hold_FileGroups)-@charpos)
		Select @hold_FileGroups = ltrim(rtrim(@hold_FileGroups))

		Select @charpos = charindex(',', @hold_FileGroups)
		If @charpos > 0
		   begin
			goto start_FGnames_parse
		   end
	   end
   end
--SELECT * from #DBdelete 


Select @save_delete_mask_diff = @save_DBname + '_dfntl_*.*'

SELECT @delete_Data_diff = 
( 
SELECT FullPathName [Source] 
FROM dbaadmin.dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_diff, 0) 
FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
) 
--SELECT @delete_Data_diff 


--  Delete older files (if requested)
If @DeletePrevious = 'before' and @mode = 'BF' and @CopyOnly = 0
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Pre delete of older backup files'
	Print '=========================================================================== '
	Print ' '
	Start_DBdelete_before:
	If (Select count(*) from #DBdelete) > 0
	   begin
		Select @hold_dd_id = (select top 1 dd_id from #DBdelete)
		Select @delete_Data_db = (select delete_Data_db from #DBdelete where dd_id = @hold_dd_id) 

		If @delete_Data_db is not null
		   begin
			exec dbasp_FileHandler @delete_Data_db
		   end

		Delete from #DBdelete where dd_id = @hold_dd_id

		goto Start_DBdelete_before
	   end

	Print ' '
	Print '=========================================================================== '
	Print 'Pre delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbasp_FileHandler @delete_Data_diff
	   end
   end
Else If @mode = 'BD' and @DeletePrevious = 'before'
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Pre delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbasp_FileHandler @delete_Data_diff
	   end
   end


--  Check for existance of a full backup
If @mode <> 'BF' and not exists (SELECT 1 FROM msdb.dbo.backupset 
				WHERE database_name = @save_DBname
				AND backup_finish_date IS NOT NULL
				AND type IN ('D', 'F'))
   begin
	print 'No full backup exists for database ' + rtrim(@save_DBname)
	print 'Creating Full backup for @DBname = ' + rtrim(@save_DBname)

	exec dbo.dbasp_format_BackupRestore 
				@DBName			= @save_DBname
				, @Mode			= 'BF'
				, @FilePath		= @outpath2
				, @FileGroups		= @save_FileGroups
				, @ForceFileName	= @backup_name
				, @ForceSetSize		= @ForceSetSize
				, @ForceEngine		= @ForceEngine
				, @ForceCompression	= @ForceCompression
				, @ForceChecksum	= @ForceChecksum
				, @CopyOnly		= @CopyOnly
				, @SetName		= 'dbasp_Backup'
				, @SetDesc		= @PlanName
				, @Verbose		= 0
				,@BufferCount		= @BufferCount		
				,@MaxTransferSize	= @MaxTransferSize
				, @syntax_out		= @syntax_out output

	Print ''
	exec dbo.dbasp_PrintLarge @syntax_out 
	RAISERROR('',-1,-1) WITH NOWAIT

	--  Execute the backup
	Exec (@syntax_out)

	If (@@error <> 0 or @retcode <> 0)
	   begin
		Print 'DBA Error:  DB Backup Failure for command ' + @syntax_out
		Print '--***********************************************************'
		Print '@@error or @retcode was not zero'
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end
   end				



--  Create Backup code
Set @syntax_out = ''
If @mode = 'BL'
   begin
	exec dbo.dbasp_format_BackupRestore 
				@DBName			= @save_DBname
				, @Mode			= 'BL'
				, @FilePath		= @outpath2
				, @ForceFileName	= @backup_name
				, @ForceSetSize		= @ForceSetSize
				, @ForceEngine		= @ForceEngine
				, @ForceCompression	= @ForceCompression
				, @ForceChecksum	= @ForceChecksum
				, @CopyOnly		= @CopyOnly
				, @SetName		= 'dbasp_Backup'
				, @SetDesc		= @PlanName
				, @Verbose		= 0
				,@BufferCount		= @BufferCount		
				,@MaxTransferSize	= @MaxTransferSize
				, @syntax_out		= @syntax_out output
   end
Else
   begin
	exec dbo.dbasp_format_BackupRestore 
				@DBName			= @save_DBname
				, @Mode			= @Mode
				, @FilePath		= @outpath2
				, @FileGroups		= @save_FileGroups
				, @ForceFileName	= @backup_name
				, @ForceSetSize		= @ForceSetSize
				, @ForceEngine		= @ForceEngine
				, @ForceCompression	= @ForceCompression
				, @ForceChecksum	= @ForceChecksum
				, @CopyOnly		= @CopyOnly
				, @SetName		= 'dbasp_Backup'
				, @SetDesc		= @PlanName
				, @Verbose		= 0
				,@BufferCount		= @BufferCount		
				,@MaxTransferSize	= @MaxTransferSize
				, @syntax_out		= @syntax_out output
   end

--  Create Differential companion to full backup
If @mode = 'BF' 
  and @auto_diff = 'y' 
  and DB_ID(@save_DBname) > 4 
  and @CopyOnly = 0
   begin
	--  Create Backup code
	exec dbo.dbasp_format_BackupRestore 
				@DBName			= @save_DBname
				, @Mode			= 'BD'
				, @FilePath		= @outpath2
				, @ForceSetSize		= 1
				, @ForceEngine		= @ForceEngine
				, @ForceCompression	= @ForceCompression
				, @ForceChecksum	= @ForceChecksum
				, @SetName		= 'dbasp_Backup'
				, @SetDesc		= @PlanName
				, @Verbose		= 0
				,@BufferCount		= @BufferCount		
				,@MaxTransferSize	= @MaxTransferSize
				, @syntax_out		= @syntax_out output
   end

Print ''
exec dbo.dbasp_PrintLarge @syntax_out 
RAISERROR('',-1,-1) WITH NOWAIT


--  Execute the backup
Exec (@syntax_out)


If (@@error <> 0 or @retcode <> 0)
   begin
	Print 'DBA Error:  DB Backup Failure for command ' + @syntax_out
	Print '--***********************************************************'
	Print '@@error or @retcode was not zero'
	Print '--***********************************************************'
	Select @error_count = @error_count + 1
	goto label99
   end



--   Post Backup Delete Process
If @DeletePrevious = 'after' and @mode = 'BF' and @CopyOnly = 0
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Post delete of older backup files'
	Print '=========================================================================== '
	Print ' '
	Start_DBdelete_after:
	If (Select count(*) from #DBdelete) > 0
	   begin
		Select @hold_dd_id = (select top 1 dd_id from #DBdelete)
		Select @delete_Data_db = (select delete_Data_db from #DBdelete where dd_id = @hold_dd_id) 

		If @delete_Data_db is not null
		   begin
			exec dbasp_FileHandler @delete_Data_db
		   end

		Delete from #DBdelete where dd_id = @hold_dd_id

		goto Start_DBdelete_after 
	   end

	Print ' '
	Print '=========================================================================== '
	Print 'Post delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbasp_FileHandler @delete_Data_diff
	   end
   end
Else If @mode = 'BD' and @DeletePrevious = 'after'
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Post delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbasp_FileHandler @delete_Data_diff
	   end
   end


loop_end:

Delete from @DBnames where name = @save_DBname
If  (select count(*) from @DBnames) > 0
   begin
	goto start_dbnames
   end




--  End Processing  ---------------------------------------------------------------------------------------------
	
Label99:

Print ' '
Print '=========================================================================== '
Print '** End of Backup Processing'
Print '=========================================================================== '
Print ' '


drop table #DirectoryTempTable
drop table #DBdelete
drop table #fileexists


If @error_count > 0
   begin
	Print  ' '
	Select @miscprint = '--Example Syntax for dbasp_backup:'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--Full Backup for a specific database:'
	Print  @miscprint
	Select @miscprint = 'exec dbaadmin.dbo.dbasp_backup @DBname = ''dbname'', @Mode = ''BF'' -- BF=full, BD=diff, BL=t-log'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--Differential Backup for a group of database:'
	Print  @miscprint
	Select @miscprint = 'exec dbaadmin.dbo.dbasp_backup @PlanName = ''mplan_user_simple'', @Mode = ''BD'' -- BF=full, BD=diff, BL=t-log'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--All Available Input Parms for dbasp_backup:'
	Print  @miscprint
	Select @miscprint = 'exec dbaadmin.dbo.dbasp_backup @DBname = ''dbname'''
	Print  @miscprint
	Select @miscprint = '                               @PlanName = ''mplan_user_simple''       -- Cannot be used if @DBname is supplied'
	Print  @miscprint
	Select @miscprint = '                              ,@Mode = ''BF''                          -- BF=full, BD=differential, BL=transaction log'
	Print  @miscprint
	Select @miscprint = '                            --,@BkUpPath = ''g:\backup''               -- Override the standard backup path'
	Print  @miscprint
	Select @miscprint = '                            --,@backup_name = ''dbaadmin_db_test''     -- Override the standard backup name.  Only used with @DBname parm.'
	Print  @miscprint
	Select @miscprint = '                              ,@DeletePrevious = ''before''            -- ''before'', ''after'' or ''none'''
	Print  @miscprint
	Select @miscprint = '                              ,@FileGroups = null                    -- ''All'', ''None'', ''FGname'' or null.'
	Print  @miscprint
	Select @miscprint = '                              ,@ForceEngine = ''MSSQL''                -- ''MSSQL'' or ''REDGATE''.'
	Print  @miscprint
	Select @miscprint = '                            --,@ForceCompression = 1                 -- 0=off, 1=on'
	Print  @miscprint
	Select @miscprint = '                              ,@ForceChecksum = 1                    -- 0=off, 1=on'
	Print  @miscprint
	Select @miscprint = '                              ,@CopyOnly = 0                         -- 0=off, 1=on'
	Print  @miscprint
	Select @miscprint = '                              ,@process_mode = ''normal''              -- ''normal'', ''pre_release'', ''pre_calc'', ''mid_calc'''
	Print  @miscprint
	Select @miscprint = '                              ,@auto_diff = ''y''                      -- Automatic differential for every full backup (non-system DB).'
	Print  @miscprint
	Select @miscprint = '                            --,@ForceSetSize = 64                    -- Number of multi-file backup files (64 max, 32 Rdgate max)'
	Print  @miscprint
	Print  ' '
   end



 
