USE [master]
GO
EXEC sp_configure 'show advanced option', 1;RECONFIGURE WITH OVERRIDE;EXEC sp_configure 'xp_cmdshell', 1;RECONFIGURE WITH OVERRIDE;;EXEC sp_configure 'Ole Automation Procedures', 1;RECONFIGURE WITH OVERRIDE;
GO

IF OBJECT_ID('Getty_Deploy_SQL') IS NOT NULL
	DROP PROCEDURE dbo.[Getty_Deploy_SQL]
GO
CREATE PROCEDURE dbo.[Getty_Deploy_SQL]
AS
SET NOCOUNT ON

Section0:	-- Setup
BEGIN
	DECLARE @TcpPort				VARCHAR(5)		,@AWEDefault			INT				,@save_SQL_install_date	DateTime		,@ServerString3			sysname			
			,@RegKey				VARCHAR(1000)	,@Platform				VARCHAR(255)	,@save_id				INT				,@NameChangeMsg			sysname
			,@ServerName			SYSNAME			,@PhysicalMemory 		INT				,@save_ip				sysname			,@RedgateInstalled		bit
			,@MaxMemory				INT				,@charpos				INT				,@RedgateTested			bit				,@ServerString2			sysname
			,@OldPort				VarChar(5)		,@CPUCores				INT				,@CloneEnvNum			sysname			,@RC					int
			,@OldServerName			SYSNAME			,@TempDBFiles			INT				,@job_name				sysname			,@job_status			varchar(10)
			,@machinename			sysname			,@LoginMode				INT				,@run_date				VarChar(20)		,@run_time				VarChar(20)
			,@instancename			sysname			,@DBName				SysName			,@Overide				VarChar(5)		,@cmd					varchar(8000)
			,@InstanceNumber		VarChar(50)		,@ServiceActLogin		sysname			,@Edition				VARCHAR(255)	,@central_server		sysname
			,@DefaultDataDir		VarChar(8000)	,@ServiceActPass		sysname			,@EnvNum				sysname			,@ScriptPath			VarChar(8000)
			,@DefaultLogDir			VarChar(8000)	,@ServiceExt			varchar(10)		,@ProdServerMatch		sysname			,@ServerToClone			sysname
			,@DefaultBackupDir		VarChar(8000)	,@RedGateKey			VarChar(50)		,@SAPassword			sysname			,@RedgateConfigured		bit
			,@DynamicCode			VarChar(8000)	,@SqlIsClustered		NVARCHAR(1)		,@OldDllVersion			VARCHAR(20)		,@OldExeVersion			VARCHAR(20)
			,@OldLicenseVersionId	VARCHAR(1)		,@OldLicenseVersionText VARCHAR(20)		,@NewDllVersion			VARCHAR(20)		,@NewExeVersion			VARCHAR(20)
			,@NewLicenseVersionId	VARCHAR(1)		,@NewLicenseVersionText VARCHAR(20)		,@SerialNumber			VARCHAR(30)		,@CmdshellState			INT
			,@SqbFileExistsExec		VARCHAR(1024)	,@SqbExistsResult		VARCHAR(50)		,@SqbTestFileCreateExec VARCHAR(1024)	,@SqbTestFileExistsExec VARCHAR(1024)
			,@SqbTestFileDeleteExec VARCHAR(1024)	,@ExecRetryCount		INT				,@SqbSetupExec			VARCHAR(1024)	,@TypeExitCodeFileExec	VARCHAR(1024)
			,@DelExitCodeFileExec	VARCHAR(1024)	,@SqbExecutionResult	INT				,@SqbInstallRetry		BIT				,@SqbTestFileExistsResult VARCHAR(50)
			,@SqbExecutionResultText VARCHAR(512)	,@RedGateNetworkPath	VARCHAR(260)	,@SqlProductVersion		NVARCHAR(20)	,@SqlMajorVersion		INT
			,@SQLRestartRequired	BIT				,@ShareName				varchar(255)	,@ServerString1			sysname			,@RunSection			INT				
			,@SectionDescript		VarChar(max)	,@Feature_Flop			bit				,@Feature_NetSend		BIT				,@NetSendRecip			VarChar(1000)	
			,@Msg					VarChar(max)	,@MsgCommand			VarChar(8000)	,@Feature_SnglStep		BIT				,@HealthCheckRecip		VarChar(1000)	
			,@Feature_SQLConfig		BIT				,@Feature_OpsDBs		BIT				,@Feature_RedGate		BIT				,@Feature_Clone			BIT				
			,@Feature_HealthChk		BIT				,@Feature_Summary		BIT				,@SeedValue				INT				,@JobName				SYSNAME
			,@job_id					UniqueIdentifier
			
SELECT		@Feature_SnglStep	= 0				,@Feature_NetSend	= 1			,@Feature_Flop		= 1			,@Feature_Clone		= 1
			,@Feature_SQLConfig	= 1				,@Feature_OpsDBs	= 1			,@Feature_RedGate	= 1			,@Feature_HealthChk	= 1
			,@Feature_Summary	= 1				,@MaxMemory			= 2048		,@ServerToClone		= NULL
			,@NetSendRecip		= 'sledridge'	,@HealthCheckRecip	= 'steve.ledridge@gettyimages.com'			,@central_server	= 'SEAFRESQLDBA01'
			,@SAPassword		= 'gettygtg'	,@RedGateNetworkPath= '\\seafresqldba01\DBA_Docs\utilities\RedGate_SQLbackup\Red_Gate_6.4\AutomatedInstall'
			,@RedGateKey		= '010-110-127441-4B91'							

	-- THIS TABLE NEEDS CREATED BEFORE ANY STATUS MESSAGES CAN BE CREATED
	IF (OBJECT_ID('tempdb..#StatusOutput'))	IS NOT NULL	DROP TABLE #StatusOutput
	CREATE	TABLE	#StatusOutput		([rownum] int identity primary key,[TextOutput] VARCHAR(8000));

	-- POPULATE TEMP TABLE WITH CURRENT STORED DATA
	IF OBJECT_ID('master.dbo.ServerDeploymentStatus') IS NOT NULL
	BEGIN
		SET IDENTITY_INSERT #StatusOutput ON
		
		INSERT INTO #StatusOutput(rownum,TextOutput)
		SELECT		rownum,TextOutput
		FROM		master.dbo.ServerDeploymentStatus
		
		SET IDENTITY_INSERT #StatusOutput OFF
	END

	SET @Msg =	'          Creating Temp Tables';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	BEGIN -- TEMP TABLES
		IF OBJECT_ID('tempdb..#ServerMatrix')	IS NOT NULL	DROP TABLE #ServerMatrix
		IF OBJECT_ID('tempdb..#EnvLogins')		IS NOT NULL	DROP TABLE #EnvLogins		
		IF OBJECT_ID('tempdb..#File_Exists')	IS NOT NULL	DROP TABLE #File_Exists
		IF OBJECT_ID('tempdb..#RGBTest')		IS NOT NULL	DROP TABLE #RGBTest
		IF OBJECT_ID('tempdb..#RMTSHARE')		IS NOT NULL	DROP TABLE #RMTSHARE
		IF (OBJECT_ID('tempdb..#ExecOutput'))	IS NOT NULL	DROP TABLE #ExecOutput
		IF (OBJECT_ID('tempdb..#Summary'))		IS NOT NULL	DROP TABLE #Summary
		IF (OBJECT_ID('tempdb..#FileText'))		IS NOT NULL	DROP TABLE #FileText

		CREATE	TABLE	#ServerMatrix		(SQLName sysname, EnvNum sysname, ProdServerMatch sysname, port sysname);
		CREATE	TABLE	#EnvLogins			(EnvNum sysname, ServiceActLogin sysname, ServiceActPass sysname);
		CREATE	TABLE	#ExecOutput			([rownum] int identity primary key,[TextOutput] VARCHAR(8000));
		CREATE	TABLE	#XP_MSVER_RESULTS	([Index] int, [Name] varchar(255), [Internal_Value] varchar(255), [Character_Value] varchar(255));
		CREATE	TABLE	#File_Exists		(isFile bit, isDir bit, hasParentDir bit)
		CREATE	TABLE	#RGBTest			([database] sysname,[login] sysname,processed INT,level1_size INT,level2_size INT,level3_size INT,level4_size INT)
		CREATE	TABLE	#Summary			([Metric] sysname primary key,[Value] sql_variant);
		CREATE	TABLE	#FileText			(LinNo INT,Line VarChar(max))
	END

	SET @Msg = '          STARTING SQL INSTALL:' + CAST(Getdate() as VarChar(50));IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

	IF NOT EXISTS (SELECT value FROM fn_listextendedproperty('NEWServerDeployStep', default, default, default, default, default, default))
	BEGIN
		SET @Msg = '          Creating NEWServerDeployStep Extended Property';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC sys.sp_addextendedproperty @Name = 'NEWServerDeployStep', @value = 1
	END

	SET @Msg =	'          Getting xp_MSver Values';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	INSERT	INTO	#XP_MSVER_RESULTS	EXEC master..xp_msver

	SET @Msg =	'          Setting Properties and Variables';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SELECT	@instancename		= isnull('\'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
			,@ServerName		= REPLACE(@@SERVERNAME,@instancename,'')
			,@machinename		= convert(nvarchar(100), serverproperty('machinename')) + @instancename
			,@ServiceExt		= isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
			,@ServerToClone		= COALESCE(@ServerToClone,	CASE @Feature_Clone 
																WHEN 0 THEN @@SERVERNAME 
																ELSE	CASE -- PROGRAMATIC DETERMINATIONS
																			WHEN @@SERVERNAME Like 'GMSSQLTEST02%' THEN REPLACE(@@SERVERNAME,'Test02','Test01')
																			ELSE COALESCE(@ServerToClone,REPLACE(@machinename,'-N',''),@@ServerName) 
																		END
															END)
			,@Platform			= (Select TOP 1 Character_Value FROM #XP_MSVER_RESULTS WHERE name = 'Platform')
			,@PhysicalMemory	= (Select TOP 1 Internal_Value  FROM #XP_MSVER_RESULTS WHERE name = 'PhysicalMemory')
			,@Edition			= (Select TOP 1 CAST(convert(sysname, serverproperty('Edition')) AS VarChar(255)))
			,@SqlProductVersion	= CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR)
			,@SqlMajorVersion	= CAST(SUBSTRING(@SqlProductVersion, 1, CHARINDEX('.', @SqlProductVersion) - 1) AS INT)
			,@SqlIsClustered	= CAST(SERVERPROPERTY('IsClustered') AS VARCHAR(1))
			,@ExecRetryCount	= 10		,@SqbExecutionResult	= -1		,@SqbInstallRetry	= 1		,@SQLRestartRequired = 0
			,@NewDllVersion = 'Install Not Run', @NewLicenseVersionText = 'Install Not Run', @SqbExecutionResultText = 'Install Not Run'
	       
	SET @Msg =	'          Populating #EnvLogins Table';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	INSERT INTO #EnvLogins
	SELECT	'alpha'			,'amer\SQLAdminAlpha'		,'v&5enewU@'		UNION ALL
	SELECT	'beta'			,'amer\SQLAdminBeta'		,'#r3&=azuB'		UNION ALL
	SELECT	'candidate01'	,'amer\SQLAdminCandidate'	,'kE@uFr89A'		UNION ALL
	SELECT	'dev01'			,'AMER\SQLAdminDev'			,'squ33zepl@y'		UNION ALL
	SELECT	'dev02'			,'AMER\SQLAdminDev'			,'squ33zepl@y'		UNION ALL
	SELECT	'dev04'			,'AMER\SQLAdminDev'			,'squ33zepl@y'		UNION ALL
	SELECT	'load01'		,'AMER\SQLAdminLoad'		,'squ33zepl@y'		UNION ALL
	SELECT	'load02'		,'AMER\SQLAdminLoad'		,'squ33zepl@y'		UNION ALL
	SELECT	'load03'		,'AMER\SQLAdminLoad'		,'squ33zepl@y'		UNION ALL
	SELECT	'stage'			,'AMER\SQLAdminStage2010'	,'Hyp0d@syr8ngE'	UNION ALL
	SELECT	'test01'		,'AMER\SQLAdminTest'		,'squ33zepl@y'		UNION ALL
	SELECT	'test02'		,'AMER\SQLAdminTest'		,'squ33zepl@y'		UNION ALL
	SELECT	'test03'		,'AMER\SQLAdminTest'		,'squ33zepl@y'		UNION ALL
	SELECT	'test04'		,'AMER\SQLAdminTest'		,'squ33zepl@y'	

	SET @Msg =	'          Populating #ServerMatrix Table';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	INSERT INTO #ServerMatrix
	SELECT 'FREAGMSSQL01\A','alpha','G1SQLA\A','1252' UNION ALL
	SELECT 'FREAGMSSQL01\B','alpha','G1SQLB\B','1893' UNION ALL
	SELECT 'FREAGMSSQL01\HGA','alpha','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'FREBASPSQL01\A','beta','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'FREBGMSSQLB01\B','beta','G1SQLB\B','1893' UNION ALL
	SELECT 'FREBGMSSQLB01\HGA','beta','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'FRECASPSQL01\A','candidate01','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'FRECGMSSQLA01\A','candidate01','G1SQLA\A','1252' UNION ALL
	SELECT 'FRECGMSSQLB01\B','candidate01','G1SQLB\B','1893' UNION ALL
	SELECT 'FRECGMSSQLB01\HGA','candidate01','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'FRECPCXSQL01\A','candidate01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'FRECPCXSQL01\A','candidate01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'FRECPCXSQL01\A','candidate01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'FRECPCXSQL01\A','candidate01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'FRECPCXSQL01\A','candidate01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'FRECSHWSQL01\A','candidate01','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FRECSHWSQL01\A','candidate01','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FRECSHWSQL01\A','candidate01','FREPSQLEDW01','1433' UNION ALL
	SELECT 'FRECSHWSQL01\A','candidate01','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'FRETHYPERSQL01','candidate01','FREPHYPERSQL01','1433' UNION ALL
	SELECT 'ASPSQLDEV01\A','dev01','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'CATSQLDEV01','dev01','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'CATSQLDEV01\A','dev01','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'DAPSQLDEV01','dev01','SEAFRESQL01','1433' UNION ALL
	SELECT 'DAPSQLDEV01','dev01','SEAFRESQL01','1433' UNION ALL
	SELECT 'DEVSHSQL01\A','dev01','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'DEVSHSQL01\A','dev01','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FREDCOGSRS01','dev01','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FREDGSYSSQL01','dev01','SEAPGSYSSQL01','1433' UNION ALL
	SELECT 'FREDMRTSQL01\A','dev01','SEADCCSO01','1433' UNION ALL
	SELECT 'FREDMRTSQL01\A','dev01','SEADCSQLWVA\A','1501' UNION ALL
	SELECT 'FREDMRTSQL01\B','dev01','SEADCSQLWVB\B','1477' UNION ALL
	SELECT 'FREDRZTSQL01\A01','dev01','SEAPTRCSQLA\A','1608' UNION ALL
	SELECT 'FREDSQLDIST01','dev01','SEAPSQLDIST0A','1433' UNION ALL
	SELECT 'FREDSQLEDW01','dev01','FREPSQLEAS01','1433' UNION ALL
	SELECT 'FREDSQLEDW01','dev01','FREPSQLEDW01','1433' UNION ALL
	SELECT 'FREDSQLTAX01','dev01','SEAPSQLTAX0A','1433' UNION ALL
	SELECT 'FREDSQLTOL01\A01','dev01','SEAPSCOMSQLA','1433' UNION ALL
	SELECT 'FREDSQLTOL01\A01','dev01','SEAEXSQLMOM03','1433' UNION ALL
	SELECT 'FRETSQLTAX01','dev01','SEAPSQLTAX0A','1433' UNION ALL
	SELECT 'GINSSQLDEV01\A','dev01','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'GINSSQLDEV01\A','dev01','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'SEAFREDWDMSDD01','dev01','SEAPDWDCSQLD0A','1433' UNION ALL
	SELECT 'SEAFREDWDMSDD01','dev01','SEAPDWDCSQLP0A','1433' UNION ALL
	SELECT 'SEAFREDWDMSPD01','dev01','SEAPDWDCSQLP0A','1433' UNION ALL
	SELECT 'SEAFREDWDMSPD01','dev01','SEAPDWDCSQLD0A','1433' UNION ALL
	SELECT 'SEAFRESQLDWD01','dev01','FREPSQLEDW01','1433' UNION ALL
	SELECT 'SEAFRESQLT01\DEV','dev01','SEAFRESQL01','1433' UNION ALL
	SELECT 'SEALABSSQL01','dev01','SEADCLABSSQL01\A','1166' UNION ALL
	SELECT 'SEAVMSQLMSDEV01\A','dev01','SEADCSQLWVB\B','1477' UNION ALL
	SELECT 'ASPSQLDEV01\A02','dev02','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'CRMSQLDEV02','dev02','FREPCOGSRS01','1433' UNION ALL
	SELECT 'DEVSHSQL02\A','dev02','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FREDMRTSQL02\A','dev02','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FREDMRTSQL02\B','dev02','SEADCSQLWVB\B','1477' UNION ALL
	SELECT 'GINSSQLDEV02\A','dev02','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'GINSSQLDEV02\A','dev02','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEAPSQLMVINT01','1433' UNION ALL
	SELECT 'NYMVSQLDEV02','dev02','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'PCSQLDEV01\A02','dev02','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLDEV01\A02','dev02','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLDEV01\A02','dev02','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLDEV01\A02','dev02','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLDEV01\A02','dev02','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'GINSSQLDEV04\A','dev04','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'GINSSQLDEV04\A','dev04','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'GMSSQLDEV04\A','dev04','G1SQLA\A','1252' UNION ALL
	SELECT 'GMSSQLDEV04\B','dev04','G1SQLB\B','1893' UNION ALL
	SELECT 'GMSSQLDEV04\HGA','dev04','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'ASPSQLLOAD01\A','load01','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'FRELGMSSQLA\A','load01','G1SQLA\A','1252' UNION ALL
	SELECT 'FRELGMSSQLB\B','load01','G1SQLB\B','1893' UNION ALL
	SELECT 'FRELRZTSQL01\A01','load01','SEAPTRCSQLA\A','1608' UNION ALL
	SELECT 'FRELSHLSQL01','load01','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'FRELSHLSQL01','load01','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'FRESCRMSQL01','load01','FREPCOGSRS01','1433' UNION ALL
	SELECT 'PCSQLLOADA\A','load01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLLOADA\A','load01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLLOADA\A','load01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLLOADA\A','load01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLLOADA\A','load01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'SEAFRESQLBOT01\HGA','load01','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'SHAREDSQLLOAD01\A','load01','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FRELASPSQL02\A','load02','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'FRELRZTSQL01\A02','load02','SEAPTRCSQLA\A','1608' UNION ALL
	SELECT 'GMSSQLLOAD02\A','load02','G1SQLA\A','1252' UNION ALL
	SELECT 'GMSSQLLOAD02\B','load02','G1SQLB\B','1893' UNION ALL
	SELECT 'GMSSQLLOAD02\HGA','load02','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'PCSQLLOAD02\A','load02','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'SHAREDSQLLOAD02\A','load02','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FRESCOGSRS01','stage','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FRESCRMSQL02','stage','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FRESEDSQL0A','stage','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'FRESSHLSQL01\A','stage','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'FRESSQLDIST0A','stage','SEAPSQLDIST0A','1433' UNION ALL
	SELECT 'FRESSQLEDW01','stage','FREPSQLEAS01','1433' UNION ALL
	SELECT 'FRESSQLRYL01','stage','FREPSQLRYLA01','1433' UNION ALL
	SELECT 'FRESSQLRYL11','stage','FREPSQLRYLA11','1433' UNION ALL
	SELECT 'FRESSQLRYL12','stage','FREPSQLRYLA12','1433' UNION ALL
	SELECT 'FRESSQLRYLI01','stage','FREPSQLRYLI01','1433' UNION ALL
	SELECT 'FRESSQLTAX01','stage','SEAPSQLTAX0A','1433' UNION ALL
	SELECT 'GONESSQLA\A','stage','G1SQLA\A','1252' UNION ALL
	SELECT 'GONESSQLB\B','stage','G1SQLB\B','1893' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAINTRASQL01','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAINTRASQL01','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAFRESQLBOA','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAFRESQLBOA','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAFRESQLBOA','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAFRESQLBOA','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAPSQLSHR02A','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAPSQLSHR02A','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAPSQLSHR02A','1433' UNION ALL
	SELECT 'SEAFRESQLBOT01','stage','SEAPSQLSHR02A','1433' UNION ALL
	SELECT 'SEAFRESQLSTGDAP','stage','SEAFRESQL01','1433' UNION ALL
	SELECT 'SEAFRESQLT01\STAGE','stage','SEAFRESQL01','1433' UNION ALL
	SELECT 'SEAFRESQLTALS01','stage','SEAFRESQLTAL04','1433' UNION ALL
	SELECT 'SEAFRESQLTALS02','stage','SEAFRESQLTAL05','1433' UNION ALL
	SELECT 'SEAFRESQLWVSTGA\A','stage','FREPCOGSRS01','1433' UNION ALL
	SELECT 'SEAFRESQLWVSTGB\B','stage','SEADCSQLWVB\B','1477' UNION ALL
	SELECT 'SEASTGASPSQLA\A','stage','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'SEASTGPCSQLA\A','stage','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'SEASTGSHSQLA\A','stage','FREPCOGSRS01','1433' UNION ALL
	SELECT 'SEASTRCSQLA','stage','SEAPTRCSQLA\A','1608' UNION ALL
	SELECT 'SEASDELSQL01','staging','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'ASPSQLTEST01\A','test01','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'CRMSQLTEST01','test01','FREPCOGSRS01','1433' UNION ALL
	SELECT 'DAPSQLTEST01','test01','SEAFRESQL01','1433' UNION ALL
	SELECT 'DAPSQLTEST01','test01','SEAFRESQL01','1433' UNION ALL
	SELECT 'FREDUSPSSQL01','test01','SEAPSQLSPS0A','1433' UNION ALL
	SELECT 'FREDUSPSSQL01','test01','SEAPSQLSPS0A','1433' UNION ALL
	SELECT 'FRETCOGSRS01','test01','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FRETMRTSQL01\A','test01','SEADCSQLWVA\A','1501' UNION ALL
	SELECT 'FRETMRTSQL01\B','test01','SEADCSQLWVB\B','1477' UNION ALL
	SELECT 'FRETRZTSQL01\A01','test01','SEAPTRCSQLA\A','1608' UNION ALL
	SELECT 'FRETSCOMRPTSQL1','test01','SEAPSCOMSQLDWA','1433' UNION ALL
	SELECT 'FRETSCOMRPTSQL1','test01','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FRETSCOMSQL01','test01','SEAPSCOMSQLA','1433' UNION ALL
	SELECT 'FRETSQLDIST01','test01','SEAPSQLDIST0A','1433' UNION ALL
	SELECT 'FRETSQLEDW01','test01','FREPSQLEAS01','1433' UNION ALL
	SELECT 'FRETSQLNOE01','test01','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FRETSQLNOE01','test01','FREPSQLNOE01','1433' UNION ALL
	SELECT 'FRETUSPSSQL1','test01','SEAPSQLSPS0A','1433' UNION ALL
	SELECT 'FRETUSPSSQL1','test01','SEAPSQLSPS0A','1433' UNION ALL
	SELECT 'FRETUSPSSQL1','test01','SEAPSQLSPS0A','1433' UNION ALL
	SELECT 'FRETUSPSSQL1','test01','SEAPSQLTFS0A','1433' UNION ALL
	SELECT 'GINSSQLTEST01\A','test01','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'GINSSQLTEST01\A','test01','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'GMSSQLTEST01\A','test01','G1SQLA\A','1252' UNION ALL
	SELECT 'GMSSQLTEST01\B','test01','G1SQLB\B','1893' UNION ALL
	SELECT 'GMSSQLTEST01\HGA','test01','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'PCSQLTEST01\A','test01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLTEST01\A','test01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLTEST01\A','test01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLTEST01\A','test01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'PCSQLTEST01\A','test01','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'SEAFRESQLBOT01\TEST','test01','FREPCOGSRS01','1433' UNION ALL
	SELECT 'SEAFRESQLDWT01','test01','FREPSQLEDW01','1433' UNION ALL
	SELECT 'SEAFRESQLT01\TEST','test01','SEAFRESQL01','1433' UNION ALL
	SELECT 'SEAFRESQLTALTST','test01','SEAFRESQLTAL05','1433' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'TESTSHSQL01\A','test01','SEAPEDSQL0A','1433' UNION ALL
	SELECT 'ASPSQLTEST01\A02','test02','SEADCASPSQLA\A','1511' UNION ALL
	SELECT 'CRMSQLTEST02','test02','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FRETMRTSQL02\A','test02','FREPCOGSRS01','1433' UNION ALL
	SELECT 'FRETMRTSQL02\B','test02','SEADCSQLWVB\B','1477' UNION ALL
	SELECT 'FRETRZTSQL01\A02','test02','SEAPTRCSQLA\A','1608' UNION ALL
	SELECT 'FRETSQLDIP02','test02','FREPVARSQL01','1433' UNION ALL
	SELECT 'FRETSQLRYL02','test02','FREPSQLRYLB01','1433' UNION ALL
	SELECT 'FRETSQLRYLI02','test02','FREPSQLRYLI01','1433' UNION ALL
	SELECT 'GINSSQLTEST02\A','test02','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'GINSSQLTEST02\A','test02','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'GMSSQLTEST02\A','test02','G1SQLA\A','1252' UNION ALL
	SELECT 'GMSSQLTEST02\B','test02','G1SQLB\B','1893' UNION ALL
	SELECT 'GMSSQLTEST02\HGA','test02','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'PCSQLTEST01\A02','test02','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'TESTSHSQL02\A','test02','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FRETRZTSQL01\A03','test03','SEAPTRCSQLA\A','1608' UNION ALL
	SELECT 'FRETSQLRYL03','test03','FREPSQLRYLB01','1433' UNION ALL
	SELECT 'FRETSQLRYLI03','test03','FREPSQLRYLI01','1433' UNION ALL
	SELECT 'GINSSQLTEST03\A','test03','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'GINSSQLTEST03\A','test03','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'GMSSQLTEST03\A','test03','G1SQLA\A','1252' UNION ALL
	SELECT 'GMSSQLTEST03\B','test03','G1SQLB\B','1893' UNION ALL
	SELECT 'GMSSQLTEST03\HGA','test03','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'FRETCRMSQL04','test04','FREPCOGSRS01','1433' UNION ALL
	SELECT 'GINSSQLTEST04\A','test04','SEAFRESQLRPT01','1433' UNION ALL
	SELECT 'GINSSQLTEST04\A','test04','SEAPSHLSQL0A\A','1433' UNION ALL
	SELECT 'GMSSQLTEST04\A','test04','G1SQLA\A','1252' UNION ALL
	SELECT 'GMSSQLTEST04\B','test04','G1SQLB\B','1893' UNION ALL
	SELECT 'GMSSQLTEST04\B','test04','G1SQLB\B','1893' UNION ALL
	SELECT 'GMSSQLTEST04\HGA','test04','SEAFRESQLRPT01','2082' UNION ALL
	SELECT 'FREBGMSSQLA01\A','beta','G1SQLA\A','1252' UNION ALL
	SELECT 'FREBPCXSQL01\A','beta','SEADCPCSQLA\A','1996' UNION ALL
	SELECT 'FREBSHWSQL01\A','beta','SEADCSHSQLA\A','4889' UNION ALL
	SELECT 'FREDMRTSQL02\A','dev02','SEADCSQLWVA\A','1501' UNION ALL
	SELECT 'FRETMRTSQL02\A','test02','SEADCSQLWVA\A','1501'
	
	SET @Msg =	'          Cleaning #ServerMatrix Table';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	DELETE	#ServerMatrix
	WHERE	Port = '1433'
	AND		SQLName IN (SELECT DISTINCT SQLName FROM #ServerMatrix WHERE Port != '1433')

	IF NOT EXISTS (SELECT * FROM #ServerMatrix WHERE SQLName = @MachineName)
		INSERT INTO #ServerMatrix VALUES (@MachineName,'test01',@MachineName,'0')

	-- CHECK FOR REDGATE
	IF @Feature_RedGate = 1
	BEGIN -- CHECK FOR REDGATE
		SET @Msg =	'                Check Redgate';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

		SELECT		@RedgateInstalled		= 0
					,@RedgateConfigured		= 0
					,@RedgateTested			= 0
					
		TRUNCATE TABLE #File_Exists
		INSERT INTO #File_Exists exec master.dbo.xp_fileexist 'C:\Program Files (x86)\Red Gate\SQL Backup 6\SQBServerSetup.exe'
		IF EXISTS (SELECT * FROM #File_Exists WHERE isFile = 1 AND isDir = 0)
			SET		@RedgateInstalled		= 1

		TRUNCATE TABLE #File_Exists
		INSERT INTO #File_Exists exec master.dbo.xp_fileexist 'C:\Program Files\Red Gate\SQL Backup 6\SQBServerSetup.exe'
		IF EXISTS (SELECT * FROM #File_Exists WHERE isFile = 1 AND isDir = 0)
			SET		@RedgateInstalled		= 1

		IF EXISTS (SELECT * from MASTER.dbo.sysobjects WHERE NAME = 'sqbutility')
			SET		@RedgateConfigured		= 1

		TRUNCATE TABLE #RGBTest
		If OBJECT_ID('master.dbo.sqbtest') IS NOT NULL
		BEGIN	
			INSERT INTO #RGBTest
			exec master.dbo.sqbtest 'dbaadmin'
		END

		If Exists (Select * From #RGBTest where [database] = 'dbaadmin')
			SET @RedgateTested = 1


		SET @Msg =	'          Getting Redgate SQLBackup information';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		-- GET REDGATE INFORMATION
			-- If the SQL Backup components are already installed, attempt to get the current version details.
			IF OBJECT_ID('master..sqbutility') IS NOT NULL
			  BEGIN
				-- A version has been installed, we need to find out which (we use #ExecOutput to get rid of the
				-- blank result sets)
				INSERT #ExecOutput(TextOutput) EXECUTE master..sqbutility 30, @OldDllVersion OUTPUT;
				INSERT #ExecOutput(TextOutput) EXECUTE master..sqbutility 1030, @OldExeVersion OUTPUT;
				INSERT #ExecOutput(TextOutput) EXECUTE master..sqbutility 1021, @OldLicenseVersionId OUTPUT, NULL, @SerialNumber OUTPUT;

				-- Clean the temporary table
				TRUNCATE TABLE #ExecOutput;

				-- Convert the License Edition into Text
				SELECT @OldLicenseVersionText =
				  CASE WHEN @OldLicenseVersionId = '0' THEN 'Trial: Expired'
					   WHEN @OldLicenseVersionId = '1' THEN 'Trial'
					   WHEN @OldLicenseVersionId = '2' THEN 'Standard'
					   WHEN @OldLicenseVersionId = '3' THEN 'Professional'
					   WHEN @OldLicenseVersionId = '6' THEN 'Lite'
				  END
			  END
			ELSE
			  BEGIN
				SET @OldDllVersion = 'Not Installed';
				SET @OldExeVersion = 'Not Installed';
				SET @OldLicenseVersionId = '-1';
				SET @OldLicenseVersionText = 'Unknown';
				SET @SerialNumber = 'Unknown';
			  END
	END
	
	--GET PORT AND ENVIRONMENT
	SET @Msg =	'          Getting Port and Environment From #ServerMatrix';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SELECT	@TcpPort			= Port
			,@EnvNum			= EnvNum
			,@ProdServerMatch	= ProdServerMatch
	From	#ServerMatrix 
	WHERE	SQLName				= @ServerToClone

	-- GET SERVICE ACCOUNT INFO
	SET @Msg =	'          Getting Service Account Information';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SELECT	@ServiceActLogin	= ServiceActLogin
			,@ServiceActPass	= ServiceActPass
	FROM	#EnvLogins
	WHERE	EnvNum				= @EnvNum

	-- GET DEFAULT DIRECTORIES
	SET @Msg =	'          Getting Data, Log, and Backup Locations';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	IF		@EnvNum IN ('alpha','beta','candidate01')
		SELECT	@DefaultDataDir		= 'E:\MSSQL$INSTANCENAME$\Data'
				,@DefaultLogDir		= 'F:\MSSQL$INSTANCENAME$\Log'
				,@DefaultBackupDir	= 'G:\MSSQL$INSTANCENAME$\Backup'
	ELSE
		SELECT	@DefaultDataDir		= 'E:\MSSQL$INSTANCENAME$\Data'
				,@DefaultLogDir		= 'E:\MSSQL$INSTANCENAME$\Log'
				,@DefaultBackupDir	= 'E:\MSSQL$INSTANCENAME$\Backup'
			
	SELECT	@DefaultDataDir		= REPLACE(@DefaultDataDir,'$INSTANCENAME$',@instancename)
			,@DefaultLogDir		= REPLACE(@DefaultLogDir,'$INSTANCENAME$',@instancename)
			,@DefaultBackupDir	= REPLACE(@DefaultBackupDir,'$INSTANCENAME$',@instancename)

	-- GET CURRENT INSTANCE NUMBER VALUES
	SET @Msg =	'          Getting Current Instance Number';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET		@RegKey				= 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' 
	EXEC	master..xp_regread 
				@rootkey		= 'HKEY_LOCAL_MACHINE' 
				,@key			= @RegKey 
				,@value_name	= @@SERVICENAME
				,@value			= @InstanceNumber OUTPUT

	-- GET CURRENT AUTHENTICATION VALUE
	SET @Msg =	'          Getting Current Authentication Mode';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET		@RegKey				= 'SOFTWARE\Microsoft\Microsoft SQL Server\'+@InstanceNumber+'\MSSQLServer'
	EXEC	master..xp_regread
				@rootkey		= 'HKEY_LOCAL_MACHINE' 
				,@key			= @RegKey 
				,@value_name	= 'LoginMode'
				,@value			= @LoginMode OUTPUT		

	-- GET CURRENT PORT VALUES
	SET @Msg =	'          Getting Current TCP/IP Port';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET		@RegKey				= 'SOFTWARE\Microsoft\Microsoft SQL Server\'+@InstanceNumber+'\MSSQLSERVER\SuperSocketNetLib\Tcp\IPAll\'
	EXEC	master..xp_regread
				@rootkey		= 'HKEY_LOCAL_MACHINE' 
				,@key			= @RegKey 
				,@value_name	= 'TcpPort'
				,@value			= @OldPort OUTPUT
				
	-- CHECK SERVER RENAME
	SET @Msg =	'          Check Server Name Status';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	IF isnull(nullif(@machinename,''),@@servername) != @@servername
	BEGIN
		IF EXISTS (SELECT * From sys.servers where name = @machinename) AND NOT EXISTS (SELECT * FROM sys.servers where name = @@SERVERNAME)
			SET @NameChangeMsg = 'SEVER NAME CHANGE PENDING SQL RESTART'
		ELSE
		BEGIN
			SET @NameChangeMsg = 'SERVER NAME NEEDS CHANGED TO ' +  @machinename
		END
	END
	ELSE
		SET @NameChangeMsg = 'SERVER NAME IS SET'

	-- Get Install Date
	SET @Msg =	'          Get SQL Install Date';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	Select @save_SQL_install_date = (select createdate from master.sys.syslogins where name = 'BUILTIN\Administrators')
			
	--  Capture IP
	SET @Msg =	'          Get Current IP Address';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	BEGIN --GET IP ADDRESS				
		TRUNCATE TABLE #ExecOutput
		Select @cmd = 'nslookup ' + @ServerName
		insert #ExecOutput(TextOutput) exec master.sys.xp_cmdshell @cmd
		Delete from #ExecOutput where nullif(TextOutput,'') is null

		If (select count(*) from #ExecOutput) > 0
		   begin
			Select @save_id = (select top 1 rownum from #ExecOutput where TextOutput like '%Name:%')

			Select @save_ip = (select top 1 TextOutput  from #ExecOutput where TextOutput like '%Address:%' and rownum > @save_id order by rownum)
			Select @save_ip = ltrim(substring(@save_ip, 9, 20))
			Select @save_ip = rtrim(@save_ip)

			Select @charpos = charindex(':', @save_ip)
			IF @charpos <> 0
			   begin
				select @save_ip = substring(@save_ip, 1, @charpos-1)
			   end
		   end
		Else
		   begin
			Select @save_ip = 'Error'
		   end
		SET @Msg =	'            -- NSLOOKUP Method Found Current IP Address = ' + COALESCE(@save_ip,'NULL') ;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

		-- If nslookup didn't work, try ping
		If nullif(nullif(@save_ip,''),'Error') is null
		   begin
			TRUNCATE TABLE #ExecOutput
			Select @cmd = 'ping ' + @ServerName + ' -4'
			insert #ExecOutput(TextOutput) exec master.sys.xp_cmdshell @cmd
			Delete from #ExecOutput where nullif(TextOutput,'') is null
			Delete from #ExecOutput where TextOutput not like '%Reply from%'
		        	
			If (select count(*) from #ExecOutput) > 0
			   begin
				Select @save_ip = (select top 1 TextOutput from #ExecOutput where TextOutput like '%Reply from%')
				Select @save_ip = ltrim(substring(@save_ip, 11, 20))
				Select @charpos = charindex(':', @save_ip)
				IF @charpos <> 0
				   begin
					select @save_ip = substring(@save_ip, 1, @charpos-1)
				   end
			   end
			Else
			   begin
				Select @save_ip = 'Error'
			   end
			SET @Msg =	'            -- PING Method Found Current IP Address = ' + COALESCE(@save_ip,'NULL') ;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		   end				
	END
	
SectionLoop:

	SELECT	@RunSection			= CAST(value AS INT)
			,@SectionDescript	= CASE @RunSection
									WHEN 1 THEN 'Pre-Config	: Set Standard SQL Settings ,Name Change and Restart SQL if Needed'
									WHEN 2 THEN 'Operations	: Install Operations Databases'
									WHEN 3 THEN 'Clone		: Clone DBs and Settings from Another Server'
									WHEN 4 THEN 'Flop 1		: Rename SQL After Name Changes then Restart SQL'
									WHEN 5 THEN 'Flop 2		: Fix Shares and Services after Rename'
									WHEN 6 THEN 'Final		: Perform final Configurations'
									WHEN 7 THEN 'Summary	: '
											ELSE 'Other		: Not Performing SQL Deployments'
											END
	FROM	fn_listextendedproperty('NEWServerDeployStep', default, default, default, default, default, default)

	SET @Msg =	'';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET @Msg =	'';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET @Msg =	'          -----------------------------------------------------';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET @Msg =	'          -----------------------------------------------------';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET @Msg =	'          Starting Section ' + CAST(@RunSection AS VarChar) + ' : ' + @SectionDescript;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET @Msg =	'          -----------------------------------------------------';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET @Msg =	'          -----------------------------------------------------';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	SET @Msg =	'';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
	
	SET @RunSection = isnull(@RunSection,8)
	IF @RunSection > 7 Goto Summary
	IF @RunSection = 2 Goto Section2
	IF @RunSection = 3 Goto Section3
	IF @RunSection = 4 Goto Section4
	IF @RunSection = 5 Goto Section5
	IF @RunSection = 6 Goto Section6
	IF @RunSection = 7 Goto Section7
END
Section1:	-- Pre-Config
BEGIN

	BEGIN -- CREATE SCHEDULED TASK TO RESTART SQL EVERY MINUTE
		SET @Msg =	'              Creating Scheduled Task to Restart SQL if Service is Stopped';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode	= 'If Exist "c:\RestartSQL'+isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')+'" (NET STOP MSSQL'+isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')+' /YES)'+CHAR(13)+CHAR(10)+'If Exist "c:\RestartSQL'+isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')+'" (DEL c:\RestartSQL'+isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')+')'+CHAR(13)+CHAR(10)+'NET START SQLAgent'+isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
		SET		@ScriptPath		= 'C:\RestartSQL'+isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')+'.cmd'
		EXEC	[dbo].[dbasp_FileAccess_Write] 
					@DynamicCode
					,@ScriptPath
		
		SET		@DynamicCode	= isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
		SET		@DynamicCode	= 'SCHTASKS.EXE /CREATE /SC MINUTE /MO 1 /TN "RESTART SQL INSTANCE '+REPLACE(@DynamicCode,'$','')+'" /ST 00:00:00 /SD 01/01/2000 /TR "C:\RestartSQL'+@DynamicCode+'.cmd" /RU SYSTEM /F'
		EXEC	XP_CMDSHELL @DynamicCode, no_output
	END	

	BEGIN -- RENAME IF NEEDED
		SET @Msg =	'              Checking if Server Rename has occured';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		IF isnull(nullif(@machinename,''),@@servername) != @@servername 
		BEGIN
			IF EXISTS (SELECT * FROM sys.servers where name = @@SERVERNAME)
				EXEC sp_dropserver @@servername; 
			IF NOT EXISTS (SELECT * FROM sys.servers where name = @machinename)
				EXEC sp_addserver @machinename, 'local'
			SET @Msg = '                -- SERVER NAME CHANGED TO ' +  @machinename;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET @SQLRestartRequired = 1
		END
		ELSE 
		BEGIN
			SET @Msg = '                -- SERVER NAME ALREADY SET';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END
	END
		
	BEGIN -- GENERIC FILE COPY PROCESSES
		SET @Msg =	'                Copy "System32" files';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		Select	@cmd = 'xcopy \\' + @central_server + '\' + @central_server + '_builds\dbaadmin\system32\*.*  %windir%\system32 /Q /C /Y'
		SET @Msg =		'                  -- ' + @cmd;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		exec	master.sys.xp_cmdshell @cmd, no_output
		
		SET @Msg =	'                Copy "WinZip" files';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		Select	@cmd = 'xcopy "\\seafresqldba01\DBA_Docs\utilities\WinZip 9 SR1\Install" "C:\Program Files (x86)\WinZip\" /Q /C /E /Y'
		SET @Msg =		'                  -- ' + @cmd;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		exec	master.sys.xp_cmdshell @cmd, no_output
			
		-- INSTALL WinZip
		SET @Msg =	'                Install WinZip';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		Select	@cmd = '"C:\Program Files (x86)\WinZip\winzip32.exe" /noqp /notip /autoinstall'
		SET @Msg =		'                  -- ' + @cmd;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		exec	master.sys.xp_cmdshell @cmd, no_output
		
		--SET @Msg =	'                Install WinZip Command Line Tools';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		--Select	@cmd = '"C:\WinZip\WinZip Command Line Support Add-On 1.1 SR-1 - wzcline.exe" /noqp /notip /autoinstall'
		--SET @Msg =		'                  -- ' + @cmd;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		--exec	master.sys.xp_cmdshell @cmd, no_output
			
		SET @Msg =	'                Copy C:\DBA_DiskCheck_DoNotDelete.txt';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		Select	@cmd = 'if not exist c:\DBA_DiskCheck_DoNotDelete.txt (copy \\' + @central_server + '\' + @central_server + '_builds\dbaadmin\DBA_DiskCheck_DoNotDelete.txt  c:\ /Y)'
		SET @Msg =		'                  -- ' + @cmd;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		exec	master.sys.xp_cmdshell @cmd, no_output
	END
	
	BEGIN -- DEFAULT DIRECTORY SETUPS
		TRUNCATE TABLE #File_Exists
		SET @DynamicCode = LEFT(@DefaultDataDir,3)
		INSERT INTO #File_Exists
		exec xp_fileexist @DynamicCode
		IF NOT EXISTS (SELECT * FROM #File_Exists WHERE isDir = 1)
		BEGIN
			SET @Msg =	'*** DEFAULT DATA DRIVE DOES NOT EXIST, CAN NOT CONTINUE. ***';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			GOTO TheEnd
		END
			
		-- SET DEFAULT DATA, LOG, AND BACKUP DIRECTORYS
		SET @Msg =	'              Creating Default Data Directory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode	= 'MD ' +  @DefaultDataDir
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		TRUNCATE TABLE #File_Exists
		INSERT INTO #File_Exists
		exec xp_fileexist @DefaultDataDir
		IF NOT EXISTS (SELECT * FROM #File_Exists WHERE isDir = 1)
		BEGIN
			SET @Msg = '*** DEFAULT DATA DIRECTORY DOES NOT EXIST, CAN NOT CONTINUE. ***';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			GOTO TheEnd
		END
		
		SET @Msg =	'              Setting Default Data Directory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC	master..xp_instance_regwrite
					@rootkey		= 'HKEY_LOCAL_MACHINE' 
					,@key			= 'Software\Microsoft\MSSQLServer\MSSQLServer' 
					,@value_name	= 'DefaultData'
					,@type			= 'REG_SZ' 
					,@value			= @DefaultDataDir 

		TRUNCATE TABLE #File_Exists
		SET @DynamicCode = LEFT(@DefaultLogDir,3)
		INSERT INTO #File_Exists
		exec xp_fileexist @DynamicCode
		IF NOT EXISTS (SELECT * FROM #File_Exists WHERE isDir = 1)
		BEGIN
			SET @Msg = '*** DEFAULT LOG DRIVE DOES NOT EXIST, CAN NOT CONTINUE. ***';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			GOTO TheEnd
		END
		
		SET @Msg =	'              Creating Default Log Directory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode	= 'MD ' +  @DefaultLogDir
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		TRUNCATE TABLE #File_Exists
		INSERT INTO #File_Exists
		exec xp_fileexist @DefaultLogDir
		IF NOT EXISTS (SELECT * FROM #File_Exists WHERE isDir = 1)
		BEGIN
			SET @Msg = '*** DEFAULT LOG DIRECTORY DOES NOT EXIST, CAN NOT CONTINUE. ***';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			GOTO TheEnd
		END
		
		SET @Msg =	'              Setting Default Log Directory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC	master..xp_instance_regwrite
					@rootkey		= 'HKEY_LOCAL_MACHINE' 
					,@key			= 'Software\Microsoft\MSSQLServer\MSSQLServer' 
					,@value_name	= 'DefaultLog'
					,@type			= 'REG_SZ' 
					,@value			= @DefaultLogDir 

		TRUNCATE TABLE #File_Exists
		SET @DynamicCode = LEFT(@DefaultBackupDir,3)
		INSERT INTO #File_Exists
		exec xp_fileexist @DynamicCode
		IF NOT EXISTS (SELECT * FROM #File_Exists WHERE isDir = 1)
		BEGIN
			SET @Msg = '*** DEFAULT BACKUP DRIVE DOES NOT EXIST, CAN NOT CONTINUE. ***';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			GOTO TheEnd
		END
		
		SET @Msg =	'              Creating Default Backup Directory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode	= 'MD ' +  @DefaultBackupDir
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		TRUNCATE TABLE #File_Exists
		INSERT INTO #File_Exists
		exec xp_fileexist @DefaultBackupDir
		IF NOT EXISTS (SELECT * FROM #File_Exists WHERE isDir = 1)
		BEGIN
			SET @Msg = '*** DEFAULT BACKUP DIRECTORY DOES NOT EXIST, CAN NOT CONTINUE. ***';Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			GOTO TheEnd
		END
		
		SET @Msg =	'              Setting Default Backup Directory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC	master..xp_instance_regwrite
					@rootkey		= 'HKEY_LOCAL_MACHINE' 
					,@key			= 'Software\Microsoft\MSSQLServer\MSSQLServer' 
					,@value_name	= 'BackupDirectory'
					,@type			= 'REG_SZ' 
					,@value			= @DefaultBackupDir 
	END

	BEGIN -- SET SECURITY POLICY VALUES FOR SERVICE ACCOUNT
		SET @Msg =	'                Setting Service Account Rights';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =	'                  -- SeServiceLogonRight';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeServiceLogonRight -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeLockMemoryPrivilege';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeLockMemoryPrivilege -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeBatchLogonRight';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeBatchLogonRight -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeTcbPrivilege';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeTcbPrivilege -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeAssignPrimaryTokenPrivilege';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeAssignPrimaryTokenPrivilege -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeTakeOwnershipPrivilege';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeTakeOwnershipPrivilege -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeCreatePermanentPrivilege';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeCreatePermanentPrivilege -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeInteractiveLogonRight';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeInteractiveLogonRight -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                  -- SeDebugPrivilege';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ntrights +r SeDebugPrivilege -u "'+@ServiceActLogin+'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output

		SET @Msg =	'                Apply SECEDIT Policy Template';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'secedit /configure /db secedit.sdb /cfg %windir%\system32\SQLServiceAccounts.inf /quiet'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	
		
		SET @Msg =	'                Update Group Security Policy';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'gpupdate'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	
	END
	
	BEGIN -- CONFIGURE SERVICE ACCOUNTS
		SET @Msg =	'                Setting Service Account Logins and Passwords';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'strComputer = "."
		Set objWMIService = GetObject("winmgmts:" _
			& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
		Set colServiceList = objWMIService.ExecQuery _
			("Select * from Win32_Service")
		For Each objservice in colServiceList
			If objService.name = "MSSQL'+@ServiceExt+'" or objService.name = "SQLAgent'+@ServiceExt+'" or objService.name = "SQLBrowser" or objService.name = "SQL Backup Agent-'+@instancename+'" Then
			wscript.echo objservice.name
				errReturn = objService.Change( , , , , , ,"'+@ServiceActLogin+'", "'+@ServiceActPass+'")
			End If 
		Next'

		SET		@ScriptPath		= @DefaultBackupDir + '\SetSQLServiceAccount.vbs'
		EXEC	[dbo].[dbasp_FileAccess_Write] 
					@DynamicCode
					,@ScriptPath
		-- CHANGE SERVICE ACOUNT
		SET		@DynamicCode = 'cscript "'+ @ScriptPath +'"'
		EXEC	XP_CMDSHELL @DynamicCode, no_output
	END	
			
	BEGIN -- ADD MEMBERS TO LOCAL ADMIN GROUP
		SET @Msg =	'                Adding Accounts to Local Administrators Group';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =	'                  -- "Amer\DevArchitects"';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'net localgroup "Administrators" "Amer\DevArchitects" /add'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	

		SET @Msg =	'                  -- "Amer\DevDBAs"';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'net localgroup "Administrators" "Amer\DevDBAs" /add'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	

		SET @Msg =	'                  -- "Amer\SeaDevelopers"';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'net localgroup "Administrators" "Amer\SeaDevelopers" /add'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	

		SET @Msg =	'                  -- "Amer\TestQALeads"';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'net localgroup "Administrators" "Amer\TestQALeads" /add'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	

		SET @Msg =	'                  -- "Amer\TestQualAssurance"';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'net localgroup "Administrators" "Amer\TestQualAssurance" /add'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	

		SET @Msg =	'                  -- "Amer\SeaSQLProdFull"';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'net localgroup "Administrators" "Amer\SeaSQLProdFull" /add'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	

		SET @Msg =	'                  -- "Amer\SeaSQLTestFull"';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'net localgroup "Administrators" "Amer\SeaSQLTestFull" /add'
		EXEC	XP_CMDSHELL @DynamicCode, no_output	
	END	

	BEGIN -- CREATE LOGIN FOR THE SERVICE ACCOUNT
		IF NOT EXISTS (SELECT * FROM syslogins where name = @ServiceActLogin)
		BEGIN
			SET @Msg =	'              Create Login for The Service Account';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET	@DynamicCode	= 'CREATE LOGIN ['+@ServiceActLogin+'] FROM WINDOWS WITH DEFAULT_DATABASE=[master]'
			EXEC (@DynamicCode)
		END
	END

	BEGIN -- ADD THE SERVICE ACCOUNT TO SYSADMIN ROLE
		SET @Msg =	'              Add The Service Account to sysadmin Role';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET	@DynamicCode	= 'EXEC master..sp_addsrvrolemember @loginame = N'''+@ServiceActLogin+''', @rolename = N''sysadmin'''
		EXEC (@DynamicCode)
	END
	
	BEGIN -- CREATE LOGIN FOR LOCAL ADMINISTRATOR GROUP
		IF NOT EXISTS (SELECT * FROM syslogins where name = REPLACE(@MachineName,@InstanceName,'')+'\Administrator')
		BEGIN
			SET @Msg =	'              Create Login for Local Administrator Group';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET	@DynamicCode	= 'CREATE LOGIN ['+REPLACE(@MachineName,@InstanceName,'')+'\Administrator] FROM WINDOWS WITH DEFAULT_DATABASE=[master]'
			EXEC (@DynamicCode)
		END
	END
	
	BEGIN -- ADD LOCAL ADMINISTRATOR GROUP TO SYSADMIN ROLE
		SET @Msg =	'              Add Local Administrator Group to sysadmin Role';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET	@DynamicCode	= 'EXEC master..sp_addsrvrolemember @loginame = N'''+REPLACE(@MachineName,@InstanceName,'')+'\Administrator'', @rolename = N''sysadmin'''
		EXEC (@DynamicCode)
	END
	
	BEGIN -- SET MODEL DB RECOVERY TO SIMPLE
		SET @Msg =	'              Setting Recover to Simple on Model DB';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET	@DynamicCode	= 'ALTER DATABASE [model] SET RECOVERY SIMPLE WITH NO_WAIT'
		EXEC (@DynamicCode)
	END
	
	BEGIN -- SET SA PASSWORD
		SET @Msg =	'              Setting CHECK_EXPIRATION=OFF and CHECK_POLICY=OFF for [sa]';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'ALTER LOGIN [sa] WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'
		EXEC(@DynamicCode)

		SET @Msg =	'              Setting the [sa] Password';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode = 'USE MASTER;ALTER LOGIN [sa] WITH PASSWORD=N'''+@SAPassword+''''
		EXEC(@DynamicCode)

		SET @Msg =	'              Setting [sa] to Enabled';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		ALTER LOGIN [sa] ENABLE
	END
	
	BEGIN -- CALCULATE AWE DEFAULT
		SET @Msg =	'              Calculating AWE Setting';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		IF UPPER(SUBSTRING(@Edition, 1, 7)) = 'EXPRESS'
		  SET @AWEDefault = 0
		ELSE
		IF UPPER(SUBSTRING(@Edition, 1, 9)) = 'WORKGROUP'
		  SET @AWEDefault = 0
		ELSE
		  SET @AWEDefault = 1

		IF @Platform LIKE '%64'
			SET @AWEDefault = 0
	END
	
	BEGIN -- CALCULATE MAX MEMORY
		SET @Msg =	'              Calculating Max Memory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		IF @MaxMemory IS NULL --DONT CALCULATE IF SET ABOVE
		BEGIN
			IF @PhysicalMemory < 3072
				SET @MaxMemory = @PhysicalMemory * 0.7

			IF @PhysicalMemory >= 3072 
				SET @MaxMemory = @PhysicalMemory * 0.8
		END
		ELSE
		BEGIN
			SET @Msg =	'                -- Calculation Overridden with fixed number';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END
	END
	
	BEGIN -- SET CONFIGURATION VALUES
		SET @Msg =	'              Setting sp_Configure Values';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =	'                -- Max Memory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'max server memory (MB)', @MaxMemory;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- AWE';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'awe enabled', @AWEDefault;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- Show Advanced';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'show advanced option', 1;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- Agent XPs';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'Agent XPs', 1;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- XP_CmdShell';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'xp_cmdshell', 1;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- Ole Automation';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'Ole Automation Procedures', 1;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- CLR';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'clr enabled', 1;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- Trigger Results';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'disallow results from triggers', 1;
		RECONFIGURE WITH OVERRIDE; 
		SET @Msg =	'                -- Remote Proc Trans';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'remote proc trans', 1;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- Remote Admin';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure 'remote admin connections', 1;
		RECONFIGURE WITH OVERRIDE;
		SET @Msg =	'                -- User Options';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbasp_sp_configure N'user options', 0
		RECONFIGURE WITH OVERRIDE;
	END
		
	BEGIN -- SET AUTHENTICATION TO MIXED
		IF @LoginMode != 2
		BEGIN
			SET @Msg =	'              Changing Authentication Mode to Mixed';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			EXEC	master..xp_regwrite
						@rootkey		= 'HKEY_LOCAL_MACHINE' 
						,@key			= @RegKey 
						,@value_name	= 'LoginMode'
						,@type			= 'REG_DWORD' 
						,@value			= 2
			SET @Msg =	'Authentication Set to Mixed';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END
		ELSE
		BEGIN
			SET @Msg =	'              Authentication Mode Already Set to Mixed';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END
	END
	
	BEGIN -- CHANGE PORT
		IF		@TcpPort != isnull(nullif(@OldPort,''),'0')
		BEGIN
			SET @Msg =	'              Changing TCP/IP Port Number From ' + @OldPort + ' to ' + @TcpPort;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET		@RegKey				= 'SOFTWARE\Microsoft\Microsoft SQL Server\'+@InstanceNumber+'\MSSQLSERVER\SuperSocketNetLib\Tcp\IPAll\'
			EXEC	master..xp_regwrite
						@rootkey		= 'HKEY_LOCAL_MACHINE' 
						,@key			= @RegKey 
						,@value_name	= 'TcpPort'
						,@type			= 'REG_SZ' 
						,@value			= @TcpPort 
		END
		ELSE 
		BEGIN
			SET @Msg =	'              TCP/IP Port Number Already Set to ' + @TcpPort;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END
	END
	
	BEGIN -- SET AGENT JOB HISTORY AND SERVICE RESTART VALUES
		SET @Msg =	'              Setting SQL Agent History and Service Restart Values';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC	msdb.dbo.sp_set_sqlagent_properties
					@jobhistory_max_rows			=10000
					,@jobhistory_max_rows_per_job	=1000
					,@sqlserver_restart				=1
					,@monitor_autostart				=1
	END
	
	BEGIN -- RELOCATE TEMPDB
		IF NOT EXISTS (select * From TempDB..sysfiles where filename = @DefaultDataDir + '\tempdb.mdf')
		BEGIN
			SET @Msg =	'              Relocating TempDB Data Device';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET @DynamicCode = 'ALTER DATABASE TempDB MODIFY FILE (NAME = tempdev, FILENAME = '''+@DefaultDataDir+'\tempdb.mdf'')'
			EXEC (@DynamicCode)
			SET @SQLRestartRequired = 1
		END
		ELSE 
		BEGIN
			SET @Msg =	'              TempDB Data Device is in the Correct Location';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END

		IF NOT EXISTS (select * From TempDB..sysfiles where filename = @DefaultLogDir + '\templog.ldf')
		BEGIN
			SET @Msg =	'              Relocating TempDB Log Device';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET @DynamicCode = 'ALTER DATABASE TempDB MODIFY FILE (NAME = templog, FILENAME = '''+@DefaultLogDir+'\templog.ldf'')'
			EXEC (@DynamicCode)
			SET @SQLRestartRequired = 1
		END
		ELSE 
		BEGIN
			SET @Msg =	'              TempDB Log Device is in the Correct Location';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END
	END
	
	BEGIN -- MODIFY NUMBER OF DATA DEVICES FOR TEMPDB
		SET @Msg =	'              Checking if Additional TempDB Data Devices are Needed';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT	@CPUCores		= [dbo].[dbaudf_CPUInfo]('Cores')
				,@TempDBFiles	= count(*)
		From	sys.master_files 
		where	db_name(database_id)= 'tempdb' 
			and	type = 0

		WHILE	@CPUCores > (SELECT count(*) From sys.master_files where db_name(database_id)= 'tempdb' and	type = 0)
		BEGIN
			SET	@TempDBFiles = @TempDBFiles + 1
			SET @Msg =	'                -- Adding Device tempdev_'+RIGHT('00'+CAST(@TempDBFiles AS VarChar),2);IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET @DynamicCode =
			'ALTER DATABASE TempDB ADD FILE (NAME = tempdev_'+RIGHT('00'+CAST(@TempDBFiles AS VarChar),2)+', FILENAME = '''+@DefaultDataDir+'\tempdb_'+RIGHT('00'+CAST(@TempDBFiles AS VarChar),2)+'.mdf'')'
			EXEC (@DynamicCode)
		END
	END
	
	-- COPY REDGATE TOOLS AND INSTALLER
	IF @Feature_RedGate = 1
	BEGIN
		SET @Msg =	'              Checking if RedGate Files are already Coppied';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		IF @RedgateInstalled = 1
		BEGIN
			SET @Msg =	'                  -- RedGate Files are already Coppied';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			goto SkipRedgateCopy
		END

		SET @Msg =	'              Copying RedGate SQLBackup';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
        -- Check that the file exists (returning "1" if valid), if it doesn't, we cannot do the installation
        SET @SqbFileExistsExec = 'if exist ' + @RedGateNetworkPath + '\SqbServerSetup.exe echo 1';
        INSERT #ExecOutput(TextOutput) EXECUTE master..xp_cmdshell @SqbFileExistsExec; 
            
        -- Parse the output, pulling it from the temporary table (TOP 1 to get rid of subsequent rows)
        SET @Msg =	'                -- Checking For Network Files';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
        SELECT TOP 1 @SqbExistsResult = CAST(TextOutput AS VARCHAR(50)) FROM #ExecOutput; 
        
        -- Clean the temporary table
        TRUNCATE TABLE #ExecOutput;		

		IF @SqbExistsResult IS NOT NULL
		BEGIN
			SET @Msg =	'                -- Creating Directory';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);		
			SET @DynamicCode = 'MD "C:\Program Files (x86)\Red Gate\SQL Backup 6\"'
			EXEC	XP_CMDSHELL @DynamicCode, no_output
			
			SET @Msg =	'                -- Copying Files';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET @DynamicCode = 'XCOPY "' + @RedGateNetworkPath + '\*.*" "C:\Program Files (x86)\Red Gate\SQL Backup 6\" /Q /C /Y /E'
			EXEC	XP_CMDSHELL @DynamicCode, no_output
			
			SET @Msg =	'                -- Creating Shortcut';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET @DynamicCode = 'Move /Y "C:\Program Files (x86)\Red Gate\SQL Backup 6\Red Gate" "C:\Documents and Settings\All Users\Start Menu\Programs\Red Gate"'
			EXEC	XP_CMDSHELL @DynamicCode, no_output			

		END
		ELSE
		BEGIN
			SET @Msg =	'                -- Redgate Files were not found';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		END
		
		SET @SqbExistsResult = NULL

SkipRedgateCopy:

	-- INSTALL REDGATE BACKUP
		SET @Msg =	'              Checking if RedGate SQLBackup is already Installed';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		IF @OldDllVersion != 'Not Installed'
		BEGIN
			SET @Msg =	'                  -- Redgate SQLBackup is already Installed';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			goto SkipRedgateInstall
		END

		SET @Msg =	'              Installing RedGate SQLBackup';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
        -- Check that the file exists (returning "1" if valid), if it doesn't, we cannot do the installation
        SET @SqbFileExistsExec = 'if exist "C:\Program Files (x86)\Red Gate\SQL Backup 6\SqbServerSetup.exe" echo 1';
        INSERT #ExecOutput(TextOutput) EXECUTE master..xp_cmdshell @SqbFileExistsExec; 
            
        -- Parse the output, pulling it from the temporary table (TOP 1 to get rid of subsequent rows)
        SET @Msg =	'                -- Checking For Install File';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
        SELECT TOP 1 @SqbExistsResult = CAST(TextOutput AS VARCHAR(50)) FROM #ExecOutput; 
        
        -- Clean the temporary table
        TRUNCATE TABLE #ExecOutput;

		-- Check that we can create files in the directory (for exitcodefile), if we can't then no point
        -- doing the installation
        SET @Msg =	'                -- Checking if exitcode file can be written';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
        SET @SqbTestFileCreateExec = 'echo 1 > "C:\Program Files (x86)\Red Gate\SQL Backup 6\exitcodetest.txt"';
        SET @SqbTestFileExistsExec = 'if exist "C:\Program Files (x86)\Red Gate\SQL Backup 6\exitcodetest.txt" echo 1';
        SET @SqbTestFileDeleteExec = 'del "C:\Program Files (x86)\Red Gate\SQL Backup 6\exitcodetest.txt"';

		EXECUTE master..xp_cmdshell @SqbTestFileCreateExec, no_output; 
        INSERT #ExecOutput(TextOutput) EXECUTE master..xp_cmdshell @SqbTestFileExistsExec; 
        EXECUTE master..xp_cmdshell @SqbTestFileDeleteExec, no_output; 

        -- Parse the output, pulling it from the temporary table
        SELECT TOP 1 @SqbTestFileExistsResult = CAST (TextOutput AS VARCHAR(50)) FROM #ExecOutput;

        -- Clean the temporary table again
        TRUNCATE TABLE #ExecOutput;

		IF @SqbExistsResult IS NOT NULL AND @SqbTestFileExistsResult IS NOT NULL
		BEGIN
            -- Generate the command strings for 'reading' and deleting the exitcode file, with instance-specific naming
            SET @TypeExitCodeFileExec = 'type "C:\Program Files (x86)\Red Gate\SQL Backup 6\exitcode_' + REPLACE(@MachineName,'\','_') + '.txt"';
            SET @DelExitCodeFileExec = 'del "C:\Program Files (x86)\Red Gate\SQL Backup 6\exitcode_' + REPLACE(@MachineName,'\','_') + '.txt"';

            -- Generate the command to execute the installation, including any applicable credentials and instance details
            SET @Msg =	'                -- Building Command Line';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
            SET @SqbSetupExec = '"C:\Program Files (x86)\Red Gate\SQL Backup 6\SqbServerSetup.exe" /VERYSILENT /SUPPRESSMSGBOXES '
		      + '/LOG /EXITCODEFILE exitcode_' + REPLACE(@MachineName,'\','_')+ '.txt';

            IF @ServiceActLogin IS NOT NULL AND @ServiceActPass IS NOT NULL
              SET @SqbSetupExec = @SqbSetupExec + ' /SVCUSER ' + @ServiceActLogin
                + ' /SVCPW ' + @ServiceActPass; -- affix windows credentials (plain text)

            --IF @SqlUsername IS NOT NULL AND @SqlPassword IS NOT NULL
            --  SET @SqbSetupExec = @SqbSetupExec + ' /SQLUSER ' + @SqlUsername
            --    + ' /SQLPW ' + @SqlPassword; -- affix SQL credentials

            IF @InstanceName <> '' -- already converted null to an empty string
              SET @SqbSetupExec = @SqbSetupExec + ' /I ' + REPLACE(@InstanceName,'\',''); -- add instance details

            WHILE @ExecRetryCount > 0 AND @SqbInstallRetry = 1
              BEGIN
                -- Perform the execution and get the exit code
                SET @Msg =	'                -- Installing...';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
                EXECUTE master..xp_cmdshell @SqbSetupExec, no_output;
                
                SET @Msg =	'                -- Reading Exit Code File';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
                INSERT #ExecOutput(TextOutput) EXECUTE master..xp_cmdshell @TypeExitCodeFileExec; 
                -- Parse the output, pulling it from the temporary table
                SELECT @SqbExecutionResult = CAST(TextOutput AS INT) FROM #ExecOutput; 

                -- If the exit code is 5, we want to retry in a few seconds
                IF @SqbExecutionResult = 5
                  BEGIN
					SET @Msg =	'                  -- Failed, Waiting 10 Seconds to Retry';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
                    SET @ExecRetryCount = @ExecRetryCount - 1;
                    WAITFOR DELAY '00:00:10'; -- Wait for 10 seconds and try again
                  END
                ELSE 
                  SET @SqbInstallRetry = 0; -- Set retry flag to 0
              END

            -- Clean up and delete the temporary exit code file
            SET @Msg =	'                -- Deleting Exit Code File';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
            INSERT #ExecOutput(TextOutput) EXECUTE master..xp_cmdshell @DelExitCodeFileExec;

            -- Parse the output code, and generate the necessary text
            IF @SqbExecutionResult = 0
            BEGIN
				SET @Msg =	'                  -- Successfull';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
				SET @SqbExecutionResultText = 'Successful (0).';
            END
            ELSE 
              BEGIN
                IF @SqbExecutionResult < 8192
                  SELECT @SqbExecutionResultText = 
                    CASE WHEN @SqbExecutionResult = 5 
                           THEN 'Unsuccessful: Another Installation is currently running, try again later (5).'
                         WHEN @SqbExecutionResult = 6000
                           THEN 'Unsuccessful: Current user has insufficient permissions to modify Windows Services (6000).'
                         WHEN @SqbExecutionResult = 6010
                           THEN 'Unsuccessful: Windows 2003 Itanium Edition requires SP1 to be installed first (6010).'
                         WHEN @SqbExecutionResult = 6020
                           THEN 'Unsuccessful: Service account username could not be validated (6020).'
                         WHEN @SqbExecutionResult = 6030
                           THEN 'Unsuccessful: Service account username was ambiguous, fully qualify it (6030).'
                         WHEN @SqbExecutionResult = 6040
                           THEN 'Unsuccessful: Service account password is invalid (6040).'
                         WHEN @SqbExecutionResult = 6100
                           THEN 'Unsuccessful: Current user is denied "Log On As A Service" rights (6100).'
                         WHEN @SqbExecutionResult = 6110
                           THEN 'Unsuccessful: Unable to grant "Log On As A Service" rights (6110).'
                         WHEN @SqbExecutionResult = 6200
                           THEN 'Unsuccessful: SQL Authenticated Username or Password is incorrect (6200).'
                         WHEN @SqbExecutionResult = 6210
                           THEN 'Unsuccessful: SQL Authenticated Account is not a member of the sysadmin role (6210).'
                         ELSE 'Unsuccessful: Check installation log for further information (' + CAST(@SqbExecutionResult AS VARCHAR(8)) + ').'
                  END
                ELSE
                  BEGIN
                    -- Installation was 'successful', but a post-installation check failed
                    SET @SqbExecutionResultText = 'The following post-installation checks failed: ';

                    IF @SqbExecutionResult % 524288 / 262144 = 1 
                      SET @SqbExecutionResultText = @SqbExecutionResultText + 'The version of xp_sqlbackup.dll is incorrect (262144); ';

                    IF @SqbExecutionResult % 262144 / 131072 = 1 
                      SET @SqbExecutionResultText = @SqbExecutionResultText + 'The file xp_sqlbackup.dll was not installed correctly (131072); ';

                    IF @SqbExecutionResult % 131072 / 65536 = 1 
                      SET @SqbExecutionResultText = @SqbExecutionResultText + 'The SQL Backup Agent service was unable to start within 1 minute (65536); ';

                    IF @SqbExecutionResult % 65536 / 32768 = 1 
                      SET @SqbExecutionResultText = @SqbExecutionResultText + 'The SQL Backup Agent service could not be registered correctly (32768); ';    

                    IF @SqbExecutionResult % 32768 / 16384 = 1 
                      SET @SqbExecutionResultText = @SqbExecutionResultText + 'The version of the SQL Backup Agent service is incorrect (16384); ';    

                    IF @SqbExecutionResult % 16384 / 8192 = 1 
                      SET @SqbExecutionResultText = @SqbExecutionResultText + 'The SQL Backup Agent service executable was not installed (8192); ';    
                  END
              END
		END
        ELSE
          BEGIN
            -- Installer file does not exist, so return generic message
            SET @SqbExecutionResult = -1;
            SET @SqbExecutionResultText = 'Unsuccessful: The file could not be found (-1).';
          END
		SET @Msg =	'                  -- ' + @SqbExecutionResultText;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

		
         -- If the SQL Backup components are now installed, attempt to get the current version details.
			SET @Msg =	'                -- ReColecting RedGate SQLBackup Values';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

			SELECT		@RedgateInstalled		= 0
						,@RedgateConfigured		= 0
						,@RedgateTested			= 0
						
			TRUNCATE TABLE #File_Exists
			INSERT INTO #File_Exists exec master.dbo.xp_fileexist 'C:\Program Files (x86)\Red Gate\SQL Backup 6\SQBServerSetup.exe'
			IF EXISTS (SELECT * FROM #File_Exists WHERE isFile = 1 AND isDir = 0)
				SET		@RedgateInstalled		= 1

			TRUNCATE TABLE #File_Exists
			INSERT INTO #File_Exists exec master.dbo.xp_fileexist 'C:\Program Files\Red Gate\SQL Backup 6\SQBServerSetup.exe'
			IF EXISTS (SELECT * FROM #File_Exists WHERE isFile = 1 AND isDir = 0)
				SET		@RedgateInstalled		= 1

			IF EXISTS (SELECT * from MASTER.dbo.sysobjects WHERE NAME = 'sqbutility')
				SET		@RedgateConfigured		= 1

			TRUNCATE TABLE #RGBTest
			If OBJECT_ID('master.dbo.sqbtest') IS NOT NULL
			BEGIN	
				INSERT INTO #RGBTest
				exec master.dbo.sqbtest 'dbaadmin'
			END

			If Exists (Select * From #RGBTest where [database] = 'dbaadmin')
				SET @RedgateTested = 1

            IF OBJECT_ID('master..sqbutility') IS NOT NULL
              BEGIN
                -- A version has been installed, we need to find out which (we use #ExecOutput to get rid of the
                -- blank result sets)
                INSERT #ExecOutput(TextOutput) EXECUTE master..sqbutility 30, @NewDllVersion OUTPUT;
                INSERT #ExecOutput(TextOutput) EXECUTE master..sqbutility 1030, @NewExeVersion OUTPUT;
                INSERT #ExecOutput(TextOutput) EXECUTE master..sqbutility 1021, @NewLicenseVersionId OUTPUT, NULL, @SerialNumber OUTPUT;

                -- Clean the temporary table
                TRUNCATE TABLE #ExecOutput;

                -- Convert the License Edition into Text
                SELECT @NewLicenseVersionText =
                  CASE WHEN @NewLicenseVersionId = '0' THEN 'Trial: Expired'
                       WHEN @NewLicenseVersionId = '1' THEN 'Trial'
                       WHEN @NewLicenseVersionId = '2' THEN 'Standard'
                       WHEN @NewLicenseVersionId = '3' THEN 'Professional'
                       WHEN @NewLicenseVersionId = '6' THEN 'Lite'
                END
              END
            ELSE
              BEGIN
                SET @NewDllVersion = 'Not Installed';
                SET @NewExeVersion = 'Not Installed';
                SET @NewLicenseVersionId = '-1';
                SET @NewLicenseVersionText = 'Unknown';
                SET @SerialNumber = 'Unknown';
              END
	END
              
SkipRedgateInstall:       

	BEGIN -- NEXT SECTION NAVIGATION
		EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 2
		
		-- FORCE RESTART IS NEEDED
		SET @SQLRestartRequired = 1
		GOTO SQLRestart
	END
	
END	
Section2:	-- Operations
BEGIN

	BEGIN -- DROP AND CREATE EMPTY DBAADMIN DATABASE
		SET @Msg =	'                DROP AND CREATE EMPTY DBAADMIN DATABASE';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET	@DBName	= 'dbaadmin'
		SET	@DynamicCode	= 
		'IF EXISTS (SELECT name FROM sys.databases WHERE name = N''' + @DBName +''')
			ALTER DATABASE [' + @DBName +'] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
			
		IF EXISTS (SELECT name FROM sys.databases WHERE name = N''' + @DBName +''')
			DROP DATABASE [' + @DBName +']

		CREATE DATABASE [' + @DBName +'] ON  PRIMARY 
		( NAME = N''' + @DBName +''', FILENAME = N''' + @DefaultDataDir + '\' + @DBName +'.mdf'' )
		 LOG ON 
		( NAME = N''' + @DBName +'_log'', FILENAME = N''' + @DefaultLogDir + '\' + @DBName +'_log.ldf'')'

		EXEC	(@DynamicCode)
	END

	BEGIN -- DROP AND CREATE EMPTY DBAPERF DATABASE
		SET @Msg =	'                DROP AND CREATE EMPTY DBAPERF DATABASE';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET	@DBName	= 'dbaperf'
		SET	@DynamicCode	= 
		'IF EXISTS (SELECT name FROM sys.databases WHERE name = N''' + @DBName +''')
			ALTER DATABASE [' + @DBName +'] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
			
		IF EXISTS (SELECT name FROM sys.databases WHERE name = N''' + @DBName +''')
			DROP DATABASE [' + @DBName +']

		CREATE DATABASE [' + @DBName +'] ON  PRIMARY 
		( NAME = N''' + @DBName +''', FILENAME = N''' + @DefaultDataDir + '\' + @DBName +'.mdf'' )
		 LOG ON 
		( NAME = N''' + @DBName +'_log'', FILENAME = N''' + @DefaultLogDir + '\' + @DBName +'_log.ldf'')'

		EXEC	(@DynamicCode)
	END
		
	BEGIN -- DROP AND CREATE EMPTY DEPLINFO DATABASE
		SET @Msg =	'                DROP AND CREATE EMPTY DEPLINFO DATABASE';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET	@DBName	= 'deplinfo'
		SET	@DynamicCode	= 
		'IF EXISTS (SELECT name FROM sys.databases WHERE name = N''' + @DBName +''')
			ALTER DATABASE [' + @DBName +'] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
			
		IF EXISTS (SELECT name FROM sys.databases WHERE name = N''' + @DBName +''')
			DROP DATABASE [' + @DBName +']

		CREATE DATABASE [' + @DBName +'] ON  PRIMARY 
		( NAME = N''' + @DBName +''', FILENAME = N''' + @DefaultDataDir + '\' + @DBName +'.mdf'' )
		 LOG ON 
		( NAME = N''' + @DBName +'_log'', FILENAME = N''' + @DefaultLogDir + '\' + @DBName +'_log.ldf'')'

		EXEC	(@DynamicCode)
	END
	
	BEGIN -- DEPLOY DBAADMIN DATABASE
		SET @Msg =	'                START DEPLOY DBAADMIN DATABASE';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

		-- DEPLOY DB
		SET @Msg =		'                Identify Most Recent DBAADMIN Build';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		TOP 1 
					@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + path +'"'
		FROM		master.dbo.dbaudf_dir('\\seafresqldba01\builds\dbaadmin\production\')
		WHERE		Name Like 'dbaadmin_2005_release%'
		ORDER BY	ModifyDate DESC
		
		SET @Msg =		'                Deploy DBAADMIN Database';IF @Feature_NetSend=1 BEGIN SET @MsgCommand	= 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =		'                  -- ' + @DynamicCode;IF @Feature_NetSend=1 BEGIN SET @MsgCommand	= 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 
	END
	
	BEGIN -- DEPLOY DBAPERF DATABASE
		SET @Msg =	'                START DEPLOY DBAPERF DATABASE';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =		'                Identify Most Recent DBAPERF Build';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		TOP 1 
					@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + path +'"'
		FROM		master.dbo.dbaudf_dir('\\seafresqldba01\builds\dbaperf\production\')
		WHERE		Name Like 'dbaperf_2005_release%'
		ORDER BY	ModifyDate DESC
		SET @Msg =		'                Deploy DBAPERF Database';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =		'                  -- ' + @DynamicCode;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC		XP_CMDSHELL  @DynamicCode, no_output
	END
	
	BEGIN -- DEPLOY DEPLINFO DATABASE
		SET @Msg =	'                START DEPLOY DEPLINFO DATABASE';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =		'                Identify Most Recent DEPLINFO Build';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		TOP 1 
					@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + path +'"'
		FROM		master.dbo.dbaudf_dir('\\seafresqldba01\builds\deplinfo\')
		WHERE		Name Like 'deplinfo_2005_20%'
		ORDER BY	ModifyDate DESC
		SET @Msg =		'                Deploy DEPLINFO Database';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET @Msg =		'                  -- ' + @DynamicCode;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC		XP_CMDSHELL  @DynamicCode, no_output
	END
	
	BEGIN -- BUILD SHARES
		SET @Msg =	'                Build Shares';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		
		TRUNCATE TABLE #ExecOutput
		SET @DynamicCode	= 'sqlcmd -S' + @@ServerName + ' -E -Q"EXEC dbaadmin.dbo.dbasp_dba_sqlsetup ''' + @DefaultBackupDir + '''"'
		INSERT INTO #ExecOutput(TextOutput)
		EXEC master.sys.xp_cmdshell @DynamicCode

		SET @DynamicCode	= 'sqlcmd -S' + @@ServerName + ' -E -Q"EXEC dbaadmin.dbo.dbasp_create_NXTshare"'
		INSERT INTO #ExecOutput(TextOutput)
		EXEC master.sys.xp_cmdshell @DynamicCode	
		
		DELETE #ExecOutput WHERE nullif(TextOutput,'') IS NULL
		UPDATE #ExecOutput SET TextOutput = '                  -- ' + TextOutput
		
		INSERT INTO #StatusOutput(TextOutput) SELECT TextOutput FROM #ExecOutput;
		
		SET @Msg = ''
		SELECT @Msg=@Msg+TextOutput+CHAR(13)+CHAR(10) FROM #ExecOutput WHERE [rownum] <= 40 ;Print @Msg;

		SET @Msg = ''
		SELECT @Msg=@Msg+TextOutput+CHAR(13)+CHAR(10) FROM #ExecOutput WHERE [rownum] > 40 ;Print @Msg;
	END
	
	BEGIN -- FIX JOB OUTPUTS
		SET @Msg =	'                Fix Job Outputs';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbaadmin.dbo.dbasp_FixJobOutput
	END

	BEGIN -- DISABLE MAINTENANCE JOBS
		SET @Msg =	'                Disable Check-In and Archive Jobs';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC msdb.dbo.sp_update_job @Job_Name = 'UTIL - DBA Nightly Processing', @enabled = 0
		EXEC msdb.dbo.sp_update_job @Job_Name = 'UTIL - DBA Archive process', @enabled = 0
	END

	BEGIN -- CREATE DEPLOYMENT JOBS
		SET @Msg =		'                Create Deployment Jobs';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

		TRUNCATE TABLE #ExecOutput
		SET @DynamicCode	= 'sqlcmd -S' + @@ServerName + ' -E -Q"EXEC deplinfo.dbo.dpsp_addjob_streamline"'
		INSERT INTO #ExecOutput(TextOutput)
		EXEC master.sys.xp_cmdshell @DynamicCode	

		SET @DynamicCode	= 'sqlcmd -S' + @@ServerName + ' -E -Q"EXEC deplinfo.dbo.dpsp_ahp_addjob"'
		INSERT INTO #ExecOutput(TextOutput)
		EXEC master.sys.xp_cmdshell @DynamicCode
			
		DELETE #ExecOutput WHERE nullif(TextOutput,'') IS NULL
		UPDATE #ExecOutput SET TextOutput = '                  -- ' + TextOutput

		INSERT INTO #StatusOutput(TextOutput) SELECT TextOutput FROM #ExecOutput 

		SET @Msg = ''
		SELECT @Msg=@Msg+TextOutput+CHAR(13)+CHAR(10) FROM #ExecOutput WHERE [rownum] <= 40 ;Print @Msg;

		SET @Msg = ''
		SELECT @Msg=@Msg+TextOutput+CHAR(13)+CHAR(10) FROM #ExecOutput WHERE [rownum] > 40 ;Print @Msg;
	END

	BEGIN -- NEXT SECTION NAVIGATION
		IF @ServerToClone = @@SERVERNAME
		BEGIN
			IF  @Feature_Flop = 1
				EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 4
			ELSE
				EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 5	
		END
		ELSE	
			EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 3
		
		-- CHECK IF SQL RESTART IS NEEDED OR IF IN SINGLE STEP MODE
		IF @SQLRestartRequired = 1
			GOTO SQLRestart
		
		IF @Feature_SnglStep = 1
			Goto Summary

		Goto SectionLoop
	END
END	
Section3:	-- Clone
BEGIN
	SELECT		@ServerString1		= LEFT(@ServerToClone,CHARINDEX ('\',@ServerToClone+'\')-1)
				,@ServerString2		= REPLACE(@ServerToClone,'\','$')
				,@ServerString3		= CASE WHEN CHARINDEX ('\',@ServerToClone) > 0 THEN REPLACE(@ServerToClone,'\','(')+')' ELSE @ServerToClone END

	BEGIN -- COPY DBA_ARCHIVE FILES FROM CLONED SERVER
		SET @Msg =		'                Copying dba_archive directory from ' + @ServerString1;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@DynamicCode			= 'XCOPY \\'+@ServerString1+'\'+@ServerString2+'_dba_archive\*.* \\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\ /Q /C /Y'
		SET @Msg =		'                  -- ' + @DynamicCode;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 
	END
			
	BEGIN -- CREATE EMPTY SHELL DATABASES
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYScreatedatabases.gsql'
					,@DynamicCode		= ''
					
		SELECT		@DynamicCode	= @DynamicCode
					+ 'IF DB_ID('''+DBName+''') IS NOT NULL DROP DATABASE ['+DBName+'];'+CHAR(13)+CHAR(10)
					+ 'SET @DynamicText = ''CREATE DATABASE ['+DBName+'];'''+CHAR(13)+CHAR(10)
					+ 'EXEC (@DynamicText)'+CHAR(13)+CHAR(10)
		FROM		(
					SELECT		DISTINCT REPLACE(Line,'Create database ','') [DBName]
					FROM		master.dbo.dbaudf_FileAccess_Read(@ScriptPath,NULL)
					WHERE		line like 'Create database %'
						AND		line NOT Like '%master'
						AND		line NOT Like '%model'
						AND		line NOT Like '%msdb'
						AND		line NOT Like '%tempdb'
						AND		line NOT Like '%dbaadmin'
						AND		line NOT Like '%dbaperf'
						AND		line NOT Like '%deplinfo'
					) DBs


		SELECT		@DynamicCode	= 'DECLARE @DynamicText VarChar(8000)'+CHAR(13)+CHAR(10)+@DynamicCode
		EXEC		(@DynamicCode)
	END

	BEGIN -- CREATE EMPTY BUILD TABLE IN EACH SHELL DB
		exec sp_msforeachdb		
			'USE ?;
			IF EXISTS (SELECT * FROM dbaadmin.dbo.db_sequence where db_name = DB_NAME()) and OBJECT_ID(''Build'') IS NULL
			CREATE TABLE [dbo].[Build](
				[iBuildID] [int] IDENTITY(1,1) NOT NULL,
				[vchName] [nvarchar](40) NOT NULL,
				[vchLabel] [nvarchar](100) NOT NULL,
				[dtBuildDate] [datetime] NOT NULL DEFAULT (getdate()),
				[vchNotes] [nvarchar](255) NULL,
			 CONSTRAINT [PKCL_Build] PRIMARY KEY CLUSTERED 
			(
				[iBuildID] ASC
			)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
			) ON [PRIMARY]'
	END

	BEGIN -- CREATE AGENT JOB TO BACKUP AND RESTORE ANY NON-DEPLOYABLE DATABASES
		SELECT	@JobName		= 'DBASETUP_dbasp_CloneDBs_' + convert(varchar(64),NEWID())
				,@DynamicCode	= 'EXECUTE [master].[dbo].[dbasp_CloneDBs] @ServerToClone = '''+@ServerToClone+''''
				,@job_id		= NULL
				,@ScriptPath	= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\CloneDatabases.log'
		EXECUTE msdb..sp_add_job @JobName, @owner_login_name='sa', @delete_level = 1, @job_id=@job_id OUTPUT
		EXECUTE msdb..sp_add_jobserver @job_id=@job_id, @server_name=@@servername
		EXECUTE msdb..sp_add_jobstep @job_id=@job_id, @step_name='Step1', @command = @DynamicCode, @database_name = 'master', @on_success_action = 1,@output_file_name=@ScriptPath,@flags=2 
		EXECUTE msdb..sp_start_job @job_id=@job_id
	END
	
	BEGIN -- CREATE AGENT JOB TO PULL ALL BASE BACKUPS
		
		SELECT	@JobName		= 'DBASETUP_Base_pullSQB_' + convert(varchar(64),NEWID())
				,@DynamicCode	= 'EXECUTE [dbaadmin].[dbo].[dbasp_Base_pullSQB]'
				,@job_id		= NULL
				,@ScriptPath	= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\PullSQBs.log'
		EXECUTE msdb..sp_add_job @JobName, @owner_login_name='sa', @delete_level = 1, @job_id=@job_id OUTPUT
		EXECUTE msdb..sp_add_jobserver @job_id=@job_id, @server_name=@@servername
		EXECUTE msdb..sp_add_jobstep @job_id=@job_id, @step_name='Step1', @command = @DynamicCode, @database_name = 'master', @on_success_action = 1,@output_file_name=@ScriptPath,@flags=2  
		EXECUTE msdb..sp_start_job @job_id=@job_id
	END
	
	BEGIN -- CREATE LINKED SERVERS
		SET @Msg =	'                Running _SYSaddlinkedservers.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

		SELECT	@ScriptPath	= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSaddlinkedservers.gsql'

		TRUNCATE TABLE #FileText
		
		INSERT INTO #FileText
		SELECT * 
		FROM  master.dbo.dbaudf_FileAccess_Read(@ScriptPath,NULL)

		-- SET PASSWORDS
			-- oneuser
			UPDATE	#FileText
				SET	Line = REPLACE([Line],'''xyz''','''gtgdev''')
			WHERE	line like '%sp_addlinkedsrvlogin%'
				AND	Line Like '%@rmtuser = ''oneuser''%'

			-- RP_LINK
			UPDATE	#FileText
				SET	Line = REPLACE([Line],'''xyz''','''Nur3em@iA''')
			WHERE	line like '%sp_addlinkedsrvlogin%'
				AND	Line Like '%@rmtuser = ''RP_Link''%'

			-- vitriauser
			UPDATE	#FileText
				SET	Line = REPLACE([Line],'''xyz''','''vitriauser''')
			WHERE	line like '%sp_addlinkedsrvlogin%'
				AND	Line Like '%@rmtuser = ''vitriauser''%'

			-- serviceuser
			UPDATE	#FileText
				SET	Line = REPLACE([Line],'''xyz''','''serviceuser''')
			WHERE	line like '%sp_addlinkedsrvlogin%'
				AND	Line Like '%@rmtuser = ''serviceuser''%'

		SELECT	@DynamicCode = ''
				,@ScriptPath = REPLACE(@ScriptPath,'.gsql','_Updated.gsql') 

		SELECT	@DynamicCode = @DynamicCode + Line + CHAR(13) + CHAR(10)
		FROM	#FileText
		ORDER BY LinNo

		EXECUTE [dbaadmin].[dbo].[dbasp_FileAccess_Write] 
		   @String = @DynamicCode
		  ,@Path = @ScriptPath

		SELECT	@DynamicCode	= 'sqlcmd -S' + @@SERVERNAME + ' -E -i"'+@ScriptPath+'"'
		EXEC xp_CmdShell @DynamicCode
	END
	
	BEGIN -- CHANGE DB OWNER
		SET @Msg =	'                Running _SYSchgdbowner.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSchgdbowner.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 			
	END
	
	BEGIN -- ADD MASTER LOGINS
		SET @Msg =	'                Running _SYSaddmasterlogins.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSaddmasterlogins.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 
	END			

	BEGIN -- DROP DB USERS
		SET @Msg =	'                Running _SYSdropDBusers.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSdropDBusers.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 
	END			

	BEGIN -- CREATE DB USERS
		SET @Msg =	'                Running _SYScreateDBusers.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYScreateDBusers.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 			
	END			

	BEGIN -- ADD DB ROLES
		SET @Msg =	'                Running _SYSadddbroles.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSadddbroles.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 			
	END			

	BEGIN -- ADD DB ROLE MEMBERS
		SET @Msg =	'                Running _SYSadddbrolemembers.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSadddbrolemembers.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 			
	END			

	BEGIN -- ADD SERVER ROLE MEMBERS
		SET @Msg =	'                Running _SYSaddsrvrolemembers.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSaddsrvrolemembers.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 			
	END			

	BEGIN -- ADD SYSTEM MESSAGES
		SET @Msg =	'                Running _SYSaddsysmessages.gsql';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SELECT		@ScriptPath			= '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\'+REPLACE(@@SERVERNAME,'\','$')+'_dba_archive\BeforeClone\'+@ServerString3+'_SYSaddsysmessages.gsql'
					,@DynamicCode = 'SQLCMD -S '+ @@SERVERNAME + ' -E -i "' + @ScriptPath +'"'
		EXEC		XP_CMDSHELL  @DynamicCode, no_output 
	END			

	BEGIN -- BUILD OUT ANY ASPSTATE DATABASES
		SET @Msg =	'                Checking for ASPState Databases';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		IF EXISTS (SELECT * FROM master..sysdatabases where name like 'aspstate%')
		BEGIN
			SET @Msg =	'                  -- Rebuilding All ASPState Databases';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);

			-- DOUBLE CHECK ASP_WEB_USER LOGIN
			if not exists (select 1 from syslogins where name = 'asp_web_user')
				create login asp_web_user with password ='Webl0g1'
					
			DECLARE ASPStateDB_Cursor CURSOR FOR
				SELECT name FROM master..sysdatabases where name like 'aspstate%'
			OPEN ASPStateDB_Cursor
			FETCH NEXT FROM ASPStateDB_Cursor INTO @DBName
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2)
				BEGIN
					SET @Msg =	'                    -- Rebuilding '+@DBName;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
					SELECT	@DynamicCode	= 'C:\WINDOWS\Microsoft.NET\Framework64\v2.0.50727\aspnet_regsql.exe -E -S '+@@SERVERNAME+' -ssadd -sstype c -d ' + @DBName
					exec xp_cmdshell @DynamicCode, no_output

					SET @Msg =	'                      -- Setting Permissions on '+@DBName;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
					SET		@DynamicCode	= '
					USE '+@DBName+';

					if not exists (select 1 from sysusers where name = ''asp_web_user'')
						exec sp_adduser ''asp_web_user''

					grant exec on GetMajorVersion to asp_web_user
					grant exec on CreateTempTables to asp_web_user
					grant exec on TempGetVersion to asp_web_user
					grant exec on GetHashCode to asp_web_user
					grant exec on TempGetAppID to asp_web_user
					grant exec on TempGetStateItem to asp_web_user
					grant exec on TempGetStateItem2 to asp_web_user
					grant exec on TempGetStateItem3 to asp_web_user
					grant exec on TempGetStateItemExclusive to asp_web_user
					grant exec on TempGetStateItemExclusive2 to asp_web_user
					grant exec on TempGetStateItemExclusive3 to asp_web_user
					grant exec on TempReleaseStateItemExclusive to asp_web_user
					grant exec on TempInsertUninitializedItem to asp_web_user
					grant exec on TempInsertStateItemShort to asp_web_user
					grant exec on TempInsertStateItemLong to asp_web_user
					grant exec on TempUpdateStateItemShort to asp_web_user
					grant exec on TempUpdateStateItemShortNullLong to asp_web_user
					grant exec on TempUpdateStateItemLong to asp_web_user
					grant exec on TempUpdateStateItemLongNullShort to asp_web_user
					grant exec on TempRemoveStateItem to asp_web_user
					grant exec on TempResetTimeout to asp_web_user
					grant exec on DeleteExpiredSessions to asp_web_user

					USE master;
					ALTER AUTHORIZATION ON DATABASE::'+@DBName+' TO sa;
					  
					USE '+@DBName+';
					Alter database '+@DBName+' set recovery simple;'

					EXEC (@DynamicCode)
				END
				FETCH NEXT FROM ASPStateDB_Cursor INTO @DBName
			END
			CLOSE ASPStateDB_Cursor
			DEALLOCATE ASPStateDB_Cursor
		END
	END
			
	BEGIN -- NEXT SECTION NAVIGATION
		-- CHECK IF NAME FLOPPING IS GOING TO HAPPEN
		IF  @Feature_Flop = 1
			EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 4
		ELSE
			EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 5
		
		-- CHECK IF SQL RESTART IS NEEDED OR IF IN SINGLE STEP MODE
		IF @SQLRestartRequired = 1
			GOTO SQLRestart
		
		IF @Feature_SnglStep = 1
			Goto Summary

		Goto SectionLoop
	END
END
Section4:	-- Flop 1
BEGIN
	-- RENAME
	IF @Feature_Flop = 1 AND @machinename = @ServerToClone AND @machinename != @@servername 
	BEGIN
		IF EXISTS (SELECT * FROM sys.servers where name = @@SERVERNAME)
			EXEC sp_dropserver @@servername; 
		IF NOT EXISTS (SELECT * FROM sys.servers where name = @machinename)
			EXEC sp_addserver @machinename, 'local'
		SET @Msg =	'                SERVER NAME CHANGED TO ' +  @machinename;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 5
		SET @SQLRestartRequired = 1
	END
	ELSE IF @Feature_Flop = 1 AND @machinename != @ServerToClone
	BEGIN
		SET @Msg =	'WAITING FOR SQL RENAME BY WEB TEAM';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		GOTO Summary
	END
	ELSE IF @Feature_Flop = 1 AND @machinename = @ServerToClone
	BEGIN
		SET @Msg =	'SERVER ALREADY RENAMED';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 5
	END	
	-- CHECK IF SQL RESTART IS NEEDED OR IF IN SINGLE STEP MODE
	IF @SQLRestartRequired = 1
		GOTO SQLRestart
	
	IF @Feature_SnglStep = 1
		Goto Summary

	Goto SectionLoop
END		
Section5:	-- Flop 2
BEGIN
	BEGIN -- DROP AND RECREATE SHARES
		--DROP SHARES
		SET @Msg =	'                Drop Existing Shares';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		CREATE TABLE #RMTSHARE ([Output] VarChar(max))
		SET		@DynamicCode	= 'RMTSHARE \\' + REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')
		INSERT INTO #RMTSHARE
		exec	xp_CmdShell		@DynamicCode

		UPDATE	#RMTSHARE SET [Output] = dbaadmin.dbo.dbaudf_ReturnPart(REPLACE([Output],' ','|'),1)
		DELETE	#RMTSHARE WHERE	isnull(dbaadmin.dbo.dbaudf_ReturnPart(REPLACE([Output],'_','|'),2),'') NOT IN ('backup','base','builds','dba','dbasql','ldf','log','mdf','nxt','SQLjob')

		DECLARE ShareCursor CURSOR 
		FOR
		SELECT [Output] FROM #RMTSHARE 

		OPEN ShareCursor
		FETCH NEXT FROM ShareCursor INTO @ShareName
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN
				SET @Msg =	'                  -- Dropping Share ' + @ShareName;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
				SET		@DynamicCode	= 'RMTSHARE \\' + REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'') + '\' + @ShareName + ' /DELETE'
				exec	xp_CmdShell		@DynamicCode, no_output 
			END
			FETCH NEXT FROM ShareCursor INTO @ShareName
		END
		CLOSE ShareCursor
		DEALLOCATE ShareCursor
		DROP TABLE #RMTSHARE
	
		-- BUILD SHARES
		SET @Msg =	'                Build Shares';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		
		TRUNCATE TABLE #ExecOutput
		SET @DynamicCode	= 'sqlcmd -S' + @@ServerName + ' -E -Q"EXEC dbaadmin.dbo.dbasp_dba_sqlsetup ''' + @DefaultBackupDir + '''"'
		INSERT INTO #ExecOutput(TextOutput)
		EXEC master.sys.xp_cmdshell @DynamicCode

		SET @DynamicCode	= 'sqlcmd -S' + @@ServerName + ' -E -Q"EXEC dbaadmin.dbo.dbasp_create_NXTshare"'
		INSERT INTO #ExecOutput(TextOutput)
		EXEC master.sys.xp_cmdshell @DynamicCode	
	END
	
	BEGIN -- FIX JOB OUTPUTS
		SET @Msg =	'                Fix Job Outputs';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC dbaadmin.dbo.dbasp_FixJobOutput
	END
	
	BEGIN -- NEXT SECTION NAVIGATION
		EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 6
		
		-- CHECK IF SQL RESTART IS NEEDED OR IF IN SINGLE STEP MODE
		IF @SQLRestartRequired = 1
			GOTO SQLRestart
		
		IF @Feature_SnglStep = 1
			Goto Summary

		Goto SectionLoop
	END
END
Section6:	-- Finalize 1
BEGIN
	BEGIN -- SET ALL DB OWNERS TO SA
		SET @Msg =	'                Changing DB Owner in all User Databases to [sa]';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);	
		exec sp_MSForEachDB 'IF DB_ID(''?'') > 4 ALTER AUTHORIZATION ON Database::? TO [sa]'  
	END
	
	BEGIN -- SET SERVICE ACCOUNT ON REDGATE BACKUP SERVICE
		IF @Feature_RedGate = 1
		BEGIN
			SET @Msg =	'                Setting Redgate Service Account Logins to ' +@ServiceActLogin;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET		@DynamicCode = 'strComputer = "."
			Set objWMIService = GetObject("winmgmts:" _
				& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
			Set colServiceList = objWMIService.ExecQuery _
				("Select * from Win32_Service")
			For Each objservice in colServiceList
				If objService.name = "SQL Backup Agent-'+@instancename+'" Then
				wscript.echo objservice.name
					errReturn = objService.Change( , , , , , ,"'+@ServiceActLogin+'", "'+@ServiceActPass+'")
				End If 
			Next'

			SET		@ScriptPath		= @DefaultBackupDir + '\SetSQLServiceAccount.vbs'
			EXEC	[dbo].[dbasp_FileAccess_Write] 
						@DynamicCode
						,@ScriptPath
						
			-- CHANGE REDGATE SERVICE ACOUNT
			SET		@DynamicCode = 'cscript "'+ @ScriptPath +'"'
			EXEC	XP_CMDSHELL @DynamicCode, no_output

			SET @Msg =	'                Stoping Redgate Agent on Instance '+ @instancename;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET		@DynamicCode = 'NET STOP "SQL Backup Agent-'+ REPLACE(@instancename,'\','') +'"'
			exec xp_cmdshell @DynamicCode, no_output

			SET @Msg =	'                Starting Redgate Agent on Instance '+ @instancename;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			SET		@DynamicCode = 'NET START "SQL Backup Agent-'+ REPLACE(@instancename,'\','') +'"'
			exec xp_cmdshell @DynamicCode, no_output

			--SET @Msg =	'                Fixing Redgate login on Instance '+ @instancename;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			----FIX REDGATE SA LOGIN
			--IF OBJECT_ID('sqbsetlogin') IS NULL
			--	exec sp_addextendedproc 'sqbsetlogin','xp_sqlbackup' 

			--exec sqbsetlogin 'sa',@SAPassword
		END
	END

	BEGIN -- CLEAN OUT DBA INFO TABLES		
		SET @Msg =	'                Clear Out Local DBA Info Tables';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		DELETE		dbaadmin.dbo.DBA_ServerInfo		--WHERE SQLName != @@SERVERNAME
		DELETE		dbaadmin.dbo.DBA_DBInfo			--WHERE SQLName != @@SERVERNAME
	END
	
	BEGIN -- NEXT SECTION NAVIGATION
		EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 7
		
		-- CHECK IF SQL RESTART IS NEEDED OR IF IN SINGLE STEP MODE
		IF @SQLRestartRequired = 1
			GOTO SQLRestart
		
		IF @Feature_SnglStep = 1
			Goto Summary

		Goto SectionLoop
	END
END
Section7:	-- Finalize 2
BEGIN
	BEGIN -- DELETE SCHEDULED TASK TO RESTART SQL EVERY MINUTE
		SET @Msg =	'                Delete Scheduled Task to Restart SQL Services';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		SET		@DynamicCode	= isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
		SET		@DynamicCode	= 'SCHTASKS.EXE /DELETE /TN "RESTART SQL INSTANCE '+REPLACE(@DynamicCode,'$','')+'" /F'
		EXEC	XP_CMDSHELL @DynamicCode, no_output
	END
		
	BEGIN -- ENABLE AND RUN CHECKIN JOB
		SET @Msg =	'                Enable Check-In and Archive Jobs';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC msdb.dbo.sp_update_job @Job_Name = 'UTIL - DBA Nightly Processing', @enabled = 1
		EXEC msdb.dbo.sp_update_job @Job_Name = 'UTIL - DBA Archive process', @enabled = 1

		SET	@job_name	= 'UTIL - DBA Nightly Processing'
		SET @Msg =	'                Run Job : ' + @job_name;IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		
		SELECT		TOP 1
					@run_date	= run_date
					,@run_time	= run_time
		From		msdb.dbo.sysjobhistory
		WHERE		job_id = (Select job_id FROM msdb.dbo.sysjobs where name = @job_name)
		ORDER BY	run_date desc, run_time desc
			
		IF	@run_date = CONVERT(VarChar(10),getdate(),112)
			BEGIN
				SET @DynamicCode = '                  -- Checkin Job already Run Today at : ' 
					+ STUFF(STUFF(@run_date,7,0,'-'),5,0,'-') + '  ' 
					+ STUFF(STUFF(RIGHT('000000' + @run_time,6),5,0,'.'),3,0,':') 
				RAISERROR(@DynamicCode,-1,-1) WITH NOWAIT
			END					
		Else
			BEGIN
				exec msdb.dbo.sp_Start_Job @job_name=@job_name, @output_flag=0
				RAISERROR('                  -- Checkin Job has been Started.',-1,-1) WITH NOWAIT
			END

		EXECUTE @RC = [dbaadmin].[dbo].[dbasp_Check_Jobstate] 
		   @job_name
		  ,@job_status OUTPUT

		WHILE @job_status = 'active'
		BEGIN
			RAISERROR('                   -- Checkin Job is Currently Running.',-1,-1) WITH NOWAIT
			WAITFOR DELAY '00:00:30'
			EXECUTE @RC = [dbaadmin].[dbo].[dbasp_Check_Jobstate] 
			   @job_name
			  ,@job_status OUTPUT
		END	

		RAISERROR('                  -- Checkin Job has been Completed.',-1,-1) WITH NOWAIT
	END
	
	BEGIN -- ENABLE AND RUN ARCHIVE JOB
		SET @Msg =	'                Run Job : UTIL - DBA Archive process';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		EXEC msdb.dbo.sp_start_job @Job_Name = 'UTIL - DBA Archive process', @output_flag=0

		SET @job_name = 'UTIL - DBA Archive process'
		EXECUTE @RC = [dbaadmin].[dbo].[dbasp_Check_Jobstate] 
		   @job_name
		  ,@job_status OUTPUT

		WHILE @job_status = 'active'
		BEGIN
			RAISERROR('                   -- Archive Job is Currently Running.',-1,-1) WITH NOWAIT
			WAITFOR DELAY '00:00:30'
			EXECUTE @RC = [dbaadmin].[dbo].[dbasp_Check_Jobstate] 
			   @job_name
			  ,@job_status OUTPUT
		END	
		
		RAISERROR('                  -- Archive Job has been Completed.',-1,-1) WITH NOWAIT
	END

	BEGIN -- FLUSH DNS
		SET @Msg =	'                Flush DNS';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
		exec xp_cmdshell 'ipconfig /flushdns', no_output 
	END
		
	BEGIN -- RUN HEALTH CHECK
		If @Feature_HealthChk = 1
		BEGIN
			SET @Msg =	'                Run Health Check Report';IF @Feature_NetSend=1 BEGIN SET @MsgCommand = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @MsgCommand, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			TRUNCATE TABLE #ExecOutput
			SET @DynamicCode	= 'sqlcmd -S' + @@ServerName + ' -E -Q"EXEC dbaadmin.dbo.dbasp_check_SQLhealth @rpt_recipient=''' + @HealthCheckRecip + '''"'
			INSERT INTO #ExecOutput(TextOutput)
			EXEC master.sys.xp_cmdshell @DynamicCode
		END
	END
	
END
Summary:	-- Summary
BEGIN
	TRUNCATE TABLE #Summary
	INSERT INTO #Summary([Value],[Metric])
	
	SELECT		@machinename																,'Machine Name'				UNION ALL
	SELECT		@@ServerName																,'@@SERVERNAME'				UNION ALL
	SELECT		@ServerName																	,'@ServerName'				UNION ALL	
	SELECT		@ServerToClone																,'@ServerToClone'			UNION ALL	
	SELECT		@NameChangeMsg																,'Name Verification'		UNION ALL
	SELECT		@InstanceNumber																,'Instance Number'			UNION ALL
	SELECT		@instancename																,'@instancename'			UNION ALL	
	SELECT		@ServiceExt																	,'@ServiceExt'				UNION ALL	
	SELECT		serverproperty('ProductVersion')											,'ProductVersion'			UNION ALL
	SELECT		serverproperty('ProductLevel')												,'ProductLevel'				UNION ALL
	SELECT		@Edition																	,'Edition'					UNION ALL
	SELECT		@Platform																	,'@Platform'				UNION ALL		
	SELECT		@PhysicalMemory																,'@PhysicalMemory'			UNION ALL
	SELECT		dbo.dbaudf_CPUInfo('Sockets')												,'CPU Sockets'				UNION ALL
	SELECT		dbo.dbaudf_CPUInfo('Cores')													,'CPU Cores'				UNION ALL
	SELECT		CASE @LoginMode WHEN 2 THEN 'Mixed' ELSE 'Not Mixed' END					,'Login Mode'				UNION ALL
	SELECT		@OldPort																	,'Port'						UNION ALL
	SELECT		@save_ip																	,'IP Address'				UNION ALL
	SELECT		@save_SQL_install_date														,'SQL Install Date'			UNION ALL
	SELECT		@RedgateInstalled															,'RedGate Installed'		UNION ALL
	SELECT		@RedgateConfigured															,'RedGate Configured'		UNION ALL
	SELECT		@RedgateTested																,'RedGate Tested'			UNION ALL
	SELECT		@OldDllVersion																,'RedGate PreviousVersion'	UNION ALL
	SELECT		@OldLicenseVersionText														,'RedGate PreviousLicense'	UNION ALL
	SELECT		@NewDllVersion																,'RedGate NewVersion'		UNION ALL
	SELECT		@NewLicenseVersionText														,'RedGate NewLicense'		UNION ALL
	SELECT		@SerialNumber																,'RedGate SerialNumber'		UNION ALL
	SELECT		@SqbExecutionResultText														,'RedGate InstallStatus'	UNION ALL
	SELECT		@DefaultDataDir																,'Default Data Directory'	UNION ALL
	SELECT		@DefaultLogDir																,'Default Log Directory'	UNION ALL
	SELECT		@DefaultBackupDir															,'Default Backup Directory'	UNION ALL
	SELECT		GETDATE()																	,'Date Finished'			UNION ALL
	SELECT		@SAPassword																	,'SA Password'				UNION ALL
	SELECT		@ServiceActLogin															,'Service Account Login'	UNION ALL
	SELECT		@ServiceActPass																,'Service Account Password'	UNION ALL
	SELECT		value																		,'NEWServerDeployStep'
	FROM		fn_listextendedproperty('NEWServerDeployStep', default, default, default, default, default, default)

	BEGIN -- SHOW SHARES
		SELECT		@DynamicCode = '\\'+REPLACE(@@ServerName,'\'+@@SERVICENAME,'')
		INSERT INTO #Summary([Metric],[Value])
		SELECT		'Share: ' +REPLACE(REPLACE([Name],REPLACE(@@SERVERNAME,'\','$'),''),@ServerName,'')		
					,[Path]
		FROM		dbo.dbaudf_dir(@DynamicCode)
		WHERE		IsFileSystem = 1
	END
		
	BEGIN -- WRITE SUMMARY FILE
		SET @DynamicCode = @DefaultBackupDir + '\ServerDeploymentSummary.htm'

		IF OBJECT_ID('master.dbo.ServerDeploymentSummary') IS NOT NULL
			DROP TABLE master.dbo.ServerDeploymentSummary
			
		Select  CAST(@@ServerName AS VarChar(50))[ServerName]
				,CAST([Metric] AS VarChar(50))[Metric_Name]
				,CAST([Value] AS VarChar(100))[Metric_Value] 
		Into	master.dbo.ServerDeploymentSummary 
		From	#Summary
		
		EXECUTE master.dbo.SaveTableAsHTML @DBFetch = 'Select * From master.dbo.ServerDeploymentSummary', @Header = 0,@PCWrite=@DynamicCode, @DBUltra = 0
		PRINT 'file://'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'/'+REPLACE(@@SERVERNAME,'\','$')+'_backup/ServerDeploymentSummary.htm'
	END
		
	BEGIN -- NEXT SECTION NAVIGATION
		IF @RunSection = 7
			EXEC sys.sp_updateextendedproperty @Name = 'NEWServerDeployStep', @value = 8
		
		Goto TheEnd
	END
END
SQLRestart:	-- SQL Restart
BEGIN
		-- CHECK IF SQL RESTART IS NEEDED
	IF @SQLRestartRequired = 1
	BEGIN
		SET @Msg = 'WAITING FOR SQL RESTART';IF @Feature_NetSend=1 BEGIN SET @DynamicCode = 'NET SEND ' + @NetSendRecip + ' ' + @Msg; exec xp_CmdShell @DynamicCode, no_output; END Print @Msg; INSERT INTO #StatusOutput(TextOutput) Values(@Msg);
			
		SET		@DynamicCode	= ' '
		SET		@ScriptPath		= 'C:\RestartSQL'+isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
		EXEC	[dbo].[dbasp_FileAccess_Write] 
					@DynamicCode
					,@ScriptPath		
	END	
END
TheEnd:		-- The End
BEGIN
	-- DROP STATUS TABLE
	IF OBJECT_ID('master.dbo.ServerDeploymentStatus') IS NOT NULL
		DROP TABLE master.dbo.ServerDeploymentStatus

	-- WRITE STATUS TABLE
	SELECT * INTO master.dbo.ServerDeploymentStatus FROM #StatusOutput
 
 	-- WRITE STATUS FILE
	SET @DynamicCode = @DefaultBackupDir + '\ServerDeploymentStatus.htm'
	EXECUTE master.dbo.SaveTableAsHTML @DBFetch = 'Select * From master.dbo.ServerDeploymentStatus', @Header = 0,@PCWrite=@DynamicCode, @DBUltra = 0
	PRINT 'file://'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'/'+REPLACE(@@SERVERNAME,'\','$')+'_backup/ServerDeploymentStatus.htm'
  
	-- DROP TEMP TABLES
	IF OBJECT_ID('tempdb..#ServerMatrix')	IS NOT NULL	DROP TABLE #ServerMatrix
	IF OBJECT_ID('tempdb..#EnvLogins')		IS NOT NULL	DROP TABLE #EnvLogins		
	IF OBJECT_ID('tempdb..#File_Exists')	IS NOT NULL	DROP TABLE #File_Exists
	IF OBJECT_ID('tempdb..#RGBTest')		IS NOT NULL	DROP TABLE #RGBTest
	IF OBJECT_ID('tempdb..#RMTSHARE')		IS NOT NULL	DROP TABLE #RMTSHARE
	IF (OBJECT_ID('tempdb..#ExecOutput'))	IS NOT NULL	DROP TABLE #ExecOutput
	IF (OBJECT_ID('tempdb..#Summary'))		IS NOT NULL	DROP TABLE #Summary
	IF (OBJECT_ID('tempdb..#FileText'))		IS NOT NULL	DROP TABLE #FileText
END
GO

GO
IF OBJECT_ID('dbasp_RestoreDatabase') IS NOT NULL
	DROP PROCEDURE dbasp_RestoreDatabase
GO
CREATE PROCEDURE dbasp_RestoreDatabase
	--------------------------------------------------------------------------------------			
	--------------------------------------------------------------------------------------			
	--									DEFINE PARAMETERS
	--------------------------------------------------------------------------------------			
	--------------------------------------------------------------------------------------			
		(
		@DBName					SYSNAME			
		,@File_Backup			VarChar(2048)
		,@Path_Backup			VarChar(2048)	= NULL

		,@AltDBName				SYSNAME			= NULL
		,@Path_MDF				VarChar(2048)	= NULL
		,@Path_NDF				VarChar(2048)	= NULL
		,@Path_LDF				VarChar(2048)	= NULL
		,@Mask_BackMid			SYSNAME			= '_db_2'
		,@Mask_DiffMid			SYSNAME			= '_dfntl_2'			
												
		,@Flag_Partial			CHAR(1)			= 'N'
		,@Flag_Differential		CHAR(1)			= 'N'
		,@Flag_NoRecovery		CHAR(1)			= 'N'
		,@Flag_ScriptOnly		CHAR(1)			= 'Y'
		,@Flag_IgnoreCtlTbl		CHAR(1)			= 'N'
		,@Flag_SourcePath		CHAR(1)			= 'N'
		,@Flag_ForceNewLDF		CHAR(1)			= 'N'
		,@Flag_DropDB			CHAR(1)			= 'N'
		,@Flag_DiffOnly			CHAR(1)			= 'N'
		,@Flag_PostShrink		CHAR(1)			= 'N'
		,@Flag_DifOnlyFailComp	CHAR(1)			= 'N'
		,@Flag_DateStampFiles	CHAR(1)			= 'N'
												
		,@CSV_filegroups		VarChar(2048)	= NULL
		,@CSV_files				VarChar(2048)	= NULL
		,@ScriptOutput			VarChar(max)	= null OUTPUT
		)
	--------------------------------------------------------------------------------------			
	--------------------------------------------------------------------------------------			
	--									START OF CODE
	--------------------------------------------------------------------------------------			
	--------------------------------------------------------------------------------------			
AS
DECLARE		@ShareName				sysname
			,@Path_Default_MDF		VarChar(2048)
			,@Path_Default_NDF		VarChar(2048)
			,@Path_Default_LDF		VarChar(2048)
			,@BkUpMethod			VarChar(50)
			,@DynamicCode			VarChar(8000)
			,@CRLF					VarChar(10)
			,@DateTime_Both			DateTime
			,@DateTime_Date			VarChar(8)
			,@DateTime_Time			VarChar(4) --HHMM

IF (OBJECT_ID('tempdb..#ExecOutput'))	IS NOT NULL	DROP TABLE #ExecOutput
CREATE TABLE	#ExecOutput			([rownum] int identity primary key,[TextOutput] VARCHAR(8000));

-- STRIP PATH OUT OF FILENAME IF EXISTS
IF nullif(@Path_Backup,'') IS NULL AND CHARINDEX('\',@File_Backup) > 0
BEGIN
	 SELECT		@Path_Backup	= REVERSE(STUFF(REVERSE(@File_Backup),1,CHARINDEX('\',REVERSE(@File_Backup))-1,''))
				,@File_Backup	= REPLACE(@File_Backup,@Path_Backup,'')
END

-- GET DEFAULT BACKUP SHARE IF PATH NOT SET
IF nullif(@Path_Backup,'') IS NULL
BEGIN			
	SELECT @ShareName = REPLACE(@@SERVERNAME,'\','$') + '_Backup'
	exec dbaadmin.dbo.dbasp_get_share_path @ShareName,@Path_Backup OUT
END


SELECT		@CRLF					= CHAR(13)+CHAR(10)
									-- CLEAN OFF TRAILING SLASHES
			,@Path_Backup			= REPLACE(REPLACE(@Path_Backup+'|','\|',''),'|','')
			,@Path_MDF				= REPLACE(REPLACE(@Path_MDF+'|','\|',''),'|','')
			,@Path_NDF				= REPLACE(REPLACE(@Path_NDF+'|','\|',''),'|','')
			,@Path_LDF				= REPLACE(REPLACE(@Path_LDF+'|','\|',''),'|','')


DECLARE	@Output			TABLE
							(
							[rownum]		int identity primary key
							,[TextOutput]	nVARCHAR(4000)
							)
									
DECLARE @filelist		TABLE
							(
							LogicalName nvarchar(128) null, 
							PhysicalName nvarchar(260) null, 
							Type char(1) null, 
							FileGroupName nvarchar(128) null, 
							Size numeric(20,0) null, 
							MaxSize numeric(20,0) null,
							FileId bigint null,
							CreateLSN numeric(25,0) null,
							DropLSN numeric(25,0) null,
							UniqueId uniqueidentifier null,
							ReadOnlyLSN numeric(25,0) null,
							ReadWriteLSN numeric(25,0) null,
							BackupSizeInBytes bigint null,
							SourceBlockSize int null,
							FileGroupId int null,
							LogGroupGUID sysname null,
							DifferentialBaseLSN numeric(25,0) null,
							DifferentialBaseGUID uniqueidentifier null,
							IsReadOnly bit null,
							IsPresent bit null,
							TDEThumbprint varbinary(32) null
							)

IF @Flag_DateStampFiles = 'Y'
	SELECT		@DateTime_Both	= GetDate()
				,@DateTime_Time	= convert(varchar(8), @DateTime_Both, 8)
				,@DateTime_Date	= '_' + convert(char(8), @DateTime_Both, 112) 
					+ substring(@DateTime_Time, 1, 2) 
					+ substring(@DateTime_Time, 4, 2) 
					+ substring(@DateTime_Time, 7, 2) 

-- USE @FILE_BACKUP AS MASK TO IDENTIFY MOST RECENT SPECIFIC FILE
SELECT		TOP 1 @File_Backup = Name+'.'+Ext
FROM		(
			SELECT		name
						,REPLACE(REPLACE(REPLACE(Path,@Path_Backup+'\',''),Name+'.',''),Name,'') ext
						,path
						,CAST(ModifyDate AS DateTime) ModifyDate
						,IsFileSystem	
						,IsFolder	
						,error
			FROM		dbaadmin.dbo.dbaudf_Dir(@Path_Backup)
			WHERE		IsFolder		= 0
				AND		IsFileSystem	= 1
				AND		Error			IS NULL
			)Dir
WHERE		Name+'.'+Ext Like '%' + @File_Backup + '%'
ORDER BY	ModifyDate Desc

-- IDENTIFY BACKUP METHOD
SELECT	@BkUpMethod = CASE
	WHEN @File_Backup like '%.BKP%' THEN 'LS'
	WHEN @File_Backup like '%.SQB%' THEN 'RG'
	ELSE 'MS' END

-- CHECK IF APP IS INSTALLED FOR CURRENT BACKUP METHOD	
IF	@BkUpMethod = 'LS' AND OBJECT_ID('master.dbo.xp_backup_database') IS NULL
BEGIN
	RAISERROR('DBA ERROR: Can Not Restore LiteSpeed Backup File, Software Not Installed.',16,-1)
	GOTO TheEnd
END

IF	@BkUpMethod = 'RG' AND OBJECT_ID('master.dbo.sqlbackup') IS NULL
BEGIN
	RAISERROR('DBA ERROR: Can Not Restore RedGate Backup File, Software Not Installed.',16,-1)
	GOTO TheEnd
END

-- READ FILELIST FROM BACKUP FILE
IF @BkUpMethod = 'MS' and SERVERPROPERTY ('productversion') >= '10.00.0000'
BEGIN
	SET @DynamicCode = 'RESTORE FILELISTONLY FROM DISK = '''+@Path_Backup+'\'+@File_Backup+''''
	insert into @filelist
	EXEC (@DynamicCode)
END
ELSE IF @BkUpMethod = 'MS' and SERVERPROPERTY ('productversion') < '10.00.0000'
BEGIN
	SET @DynamicCode = 'RESTORE FILELISTONLY FROM DISK = '''+@Path_Backup+'\'+@File_Backup+''''
	insert into @filelist(LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileId,CreateLSN,DropLSN,UniqueId,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroupId,LogGroupGUID,DifferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent)
	EXEC (@DynamicCode)
END
ELSE IF @BkUpMethod = 'RG'
BEGIN
	SET @DynamicCode = 'Exec master.dbo.sqlbackup ''-SQL "RESTORE FILELISTONLY FROM DISK = '''''+@Path_Backup+'\'+@File_Backup+'''''"'''
	insert into @filelist(LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize,FileId,CreateLSN,DropLSN,UniqueId,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroupId,LogGroupGUID,DifferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent)
	EXEC (@DynamicCode)
END
ELSE IF @BkUpMethod = 'LS'
BEGIN
	SET @DynamicCode = 'EXEC master.dbo.xp_restore_filelistonly @filename = '''+@Path_Backup +'\'+@File_Backup+''''
	insert into @filelist(LogicalName,PhysicalName,Type,FileGroupName,Size,MaxSize)
	EXEC (@DynamicCode)
END

-- GET PATHS FROM SHARES
SELECT @ShareName = REPLACE(@@SERVERNAME,'\','$') + '_mdf'
exec dbaadmin.dbo.dbasp_get_share_path @ShareName,@Path_Default_MDF OUT

SELECT @ShareName = REPLACE(@@SERVERNAME,'\','$') + '_ndf'
exec dbaadmin.dbo.dbasp_get_share_path @ShareName,@Path_Default_NDF OUT

-- USE MDF FOR NDF IF SHARE NOT CREATED
SELECT	@Path_Default_NDF = COALESCE(@Path_Default_NDF,@Path_Default_MDF)

SELECT @ShareName = REPLACE(@@SERVERNAME,'\','$') + '_ldf'
exec dbaadmin.dbo.dbasp_get_share_path @ShareName,@Path_Default_LDF OUT

--GET PATHS FROM DBAADMIN DB IF NOT FOUND FROM SHARES
SELECT		@Path_Default_MDF = CASE RIGHT(filename,CHARINDEX('.',REVERSE(filename))-1)
								WHEN 'mdf' THEN COALESCE(@Path_Default_MDF,REPLACE(filename,'\'+RIGHT(filename,CHARINDEX('\',REVERSE(filename))-1),''))
								ELSE @Path_Default_MDF END
			,@Path_Default_NDF = CASE RIGHT(filename,CHARINDEX('.',REVERSE(filename))-1)
								WHEN 'ndf' THEN COALESCE(@Path_Default_NDF,REPLACE(filename,'\'+RIGHT(filename,CHARINDEX('\',REVERSE(filename))-1),''))
								ELSE @Path_Default_NDF END					
			,@Path_Default_LDF = CASE RIGHT(filename,CHARINDEX('.',REVERSE(filename))-1)
								WHEN 'ldf' THEN COALESCE(@Path_Default_LDF,REPLACE(filename,'\'+RIGHT(filename,CHARINDEX('\',REVERSE(filename))-1),''))
								ELSE @Path_Default_LDF END					
FROM		dbaadmin.sys.sysfiles

-- START BUILDING SCRIPT
INSERT INTO	@Output([TextOutput])
			SELECT 'RESTORE DATABASE ['+@DBName+']'

-- CREATE LINES FOR FILES AND/OR FILEGROUPS
If @Flag_Partial = 'Y' and (nullif(@CSV_filegroups,'') IS NOT NULL OR nullif(@CSV_files,'') IS NOT NULL)
BEGIN
	INSERT INTO	@Output([TextOutput])
	SELECT		CASE WHEN [rownum] = 1 THEN '' ELSE ',' END + [CommandText]
	FROM		(
				SELECT		Rank() OVER(ORDER BY [set],[nmbr]) [rownum],[CommandText]
				FROM		(		
							SELECT		1 [Set],OccurenceId [nmbr],'	FILE		=''' + SplitValue + '''' [CommandText]
							FROM		dbaadmin.dbo.dbaudf_split(@CSV_files,',')
							UNION ALL
							SELECT		2 [Set],OccurenceId [nmbr],'	FILEGROUP	=''' + SplitValue + ''''
							FROM		dbaadmin.dbo.dbaudf_split(@CSV_filegroups,',')
							) Data
				)Data
	ORDER BY	[rownum]			
END			
			
-- WHERE TO RESTORE FROM			
INSERT INTO	@Output([TextOutput])
SELECT		'FROM DISK = '''+@Path_Backup+'\'+@File_Backup+''''

-- GENERATE INITAL WITH CLAUSE
IF @Flag_Differential = 'Y' OR @Flag_NoRecovery = 'Y'
BEGIN
	IF @Flag_Partial = 'Y' AND nullif(@CSV_filegroups,'') IS NOT NULL
	BEGIN
		INSERT INTO	@Output([TextOutput])
		SELECT		'WITH	PARTIAL'		UNION ALL
		SELECT		'		,NORECOVERY'	UNION ALL
		SELECT		'		,REPLACE'
	END
	ELSE
	BEGIN
		INSERT INTO	@Output([TextOutput])
		SELECT		'WITH	NORECOVERY'	UNION ALL
		SELECT		'		,REPLACE'	END
END	
ELSE
BEGIN
	IF @Flag_Partial = 'y' and @CSV_filegroups is not null and @CSV_filegroups <> ''
	BEGIN
		INSERT INTO	@Output([TextOutput])
		SELECT		'WITH	PARTIAL'		UNION ALL
		SELECT		'		,REPLACE'	END
	ELSE
	BEGIN
		INSERT INTO	@Output([TextOutput])
		SELECT		'WITH	REPLACE'	END
END

-- CALCULATE MOVE STATEMENTS
INSERT INTO	@Output([TextOutput])
SELECT		CASE @BkUpMethod
			WHEN 'LS' THEN '		,@with = ''MOVE "'+[LogicalName]+'" TO "'+COALESCE([Overide],[DeviceDefault],[DatabaseDefault],[ServerDefault])+'"'''
			ELSE '		,MOVE '''+[LogicalName]+''' TO '''+COALESCE([Overide],[DeviceDefault],[DatabaseDefault],[ServerDefault])+''''
			END
FROM		(
			SELECT		BUFiles.LogicalName																				[LogicalName]
						,RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)										[FileName]
						,REPLACE(PhysicalName,'\'+RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1),'')		[FilePath]
						,RIGHT(PhysicalName,CHARINDEX('.',REVERSE(PhysicalName))-1)										[FileExtension]
						,DBFiles.filename																				[DeviceDefault]
						,DBPathByGroup.[FilePath]+'\'+RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)		[DatabaseDefault]
						,CASE RIGHT(PhysicalName,CHARINDEX('.',REVERSE(PhysicalName))-1)
							WHEN 'mdf'	THEN @Path_Default_MDF + '\' + RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)
							WHEN 'ndf'	THEN @Path_Default_NDF + '\' + RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)
							WHEN 'ldf'	THEN @Path_Default_LDF + '\' + RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)
							END																							[ServerDefault]
						,CASE RIGHT(PhysicalName,CHARINDEX('.',REVERSE(PhysicalName))-1)
							WHEN 'mdf'	THEN @Path_MDF + '\' + RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)
							WHEN 'ndf'	THEN @Path_NDF + '\' + RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)
							WHEN 'ldf'	THEN @Path_LDF + '\' + RIGHT(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1)
							END																							[Overide]
			FROM		@filelist BUFiles
			LEFT JOIN	sys.sysaltfiles DBFiles
				ON		DBFiles.dbid = DB_ID(@DBName)
				AND		DBFiles.name = BUFiles.LogicalName
			LEFT JOIN	(
						SELECT		dbid
									,groupid
									,MIN(REPLACE(filename,'\'+RIGHT(filename,CHARINDEX('\',REVERSE(filename))-1),'')) [FilePath]
						FROM		sys.sysaltfiles 
						GROUP BY	dbid,groupid
						HAVING		MAX(REPLACE(filename,'\'+RIGHT(filename,CHARINDEX('\',REVERSE(filename))-1),'')) = MIN(REPLACE(filename,'\'+RIGHT(filename,CHARINDEX('\',REVERSE(filename))-1),''))
						) DBPathByGroup		
				ON		DBPathByGroup.dbid		= DB_ID(@DBName)
				AND		DBPathByGroup.groupid	= BUFiles.FileGroupId
			)Data

-- POPULATE VARIABLE FROM CODE TABLE
SELECT		@DynamicCode = NULL
SELECT		@DynamicCode = COALESCE(@DynamicCode+@CRLF+TextOutput,TextOutput)
FROM		@Output
ORDER BY	rownum

-- ADJUST CODE BASED ON METHOD BEING USED
IF @BkUpMethod = 'MS'
	SELECT	@DynamicCode	= '/*  Note:  Microsoft Syntax will be used for this restore */' + @CRLF + @CRLF + @DynamicCode + @CRLF

IF @BkUpMethod = 'RG'
BEGIN
	IF		@ScriptOutput IS NOT NULL
	BEGIN
		IF	@ScriptOutput = ''
			SELECT	@DynamicCode	= '/*  Note:  RedGate Syntax will be used for this restore */' + @CRLF + @CRLF
									+ 'Declare @cmd nvarchar(4000);' + @CRLF
									+ 'Select @cmd = ''-SQL "'+REPLACE(@DynamicCode,'''','''''')+'"'';' + @CRLF
									+ 'SET @cmd = REPLACE(REPLACE(REPLACE(@cmd,CHAR(9),'' ''),CHAR(13)+char(10),'' ''),''  '','' '');' + @CRLF
									+ 'Exec master.dbo.sqlbackup @cmd;' + @CRLF 
		ELSE	
			SELECT	@DynamicCode	= '/*  Note:  RedGate Syntax will be used for this restore */' + @CRLF + @CRLF
									+ 'Select @cmd = ''-SQL "'+REPLACE(@DynamicCode,'''','''''')+'"'';' + @CRLF
									+ 'SET @cmd = REPLACE(REPLACE(REPLACE(@cmd,CHAR(9),'' ''),CHAR(13)+char(10),'' ''),''  '','' '');' + @CRLF
									+ 'Exec master.dbo.sqlbackup @cmd;' + @CRLF 
	END
	ELSE
	SELECT	@DynamicCode	= '/*  Note:  RedGate Syntax will be used for this restore */' + @CRLF + @CRLF
							+ 'Declare @cmd nvarchar(4000);' + @CRLF
							+ 'Select @cmd = ''-SQL "'+REPLACE(@DynamicCode,'''','''''')+'"'';' + @CRLF
							+ 'SET @cmd = REPLACE(REPLACE(REPLACE(@cmd,CHAR(9),'' ''),CHAR(13)+char(10),'' ''),''  '','' '');' + @CRLF
							+ 'Exec master.dbo.sqlbackup @cmd;' + @CRLF 
END
ELSE IF @BkUpMethod = 'LS'
BEGIN
	SELECT	@DynamicCode	= '/*  Note:  LiteSpeed Syntax will be used for this restore */' + @CRLF + @CRLF + @DynamicCode + @CRLF
			,@DynamicCode	= REPLACE(REPLACE(@DynamicCode,'RESTORE DATABASE [','EXEC master.dbo.xp_backup_database @database = '''),']','''')
			,@DynamicCode	= REPLACE(@DynamicCode,'FROM DISK ='			,'		,@filename =')
			,@DynamicCode	= REPLACE(@DynamicCode,'WITH	NORECOVERY'		,'		,@with = ''NORECOVERY''')
			,@DynamicCode	= REPLACE(@DynamicCode,'WITH	PARTIAL'		,'		,@with = ''PARTIAL''')
			,@DynamicCode	= REPLACE(@DynamicCode,'WITH	REPLACE'		,'		,@with = ''REPLACE''')
			,@DynamicCode	= REPLACE(@DynamicCode,'		,NORECOVERY'	,'		,@with = ''NORECOVERY''')
			,@DynamicCode	= REPLACE(@DynamicCode,'		,REPLACE'		,'		,@with = ''REPLACE''')
END


-- DISPLAY OR EXECUTE FINAL STATEMENT
IF @Flag_ScriptOnly = 'Y'
BEGIN
	IF		@ScriptOutput IS NULL
		PRINT	(@DynamicCode)

	SET @ScriptOutput = @ScriptOutput + CHAR(13)+CHAR(10)+@DynamicCode
END
ELSE
BEGIN
	-- USE CP_CMDSHELL IN ORDER TO CONTROL THE OUTPUT
	PRINT	'		-- STARTING DATABASE RESTORE ' + CAST(Getdate() as VarChar)
	SELECT	@DynamicCode	= 'SET NOCOUNT ON;'+REPLACE(REPLACE(REPLACE(REPLACE(@DynamicCode,CHAR(9),' '),@CRLF,' '),'  ',' '),'"','""')
			,@DynamicCode	= 'sqlcmd -S"' + @@ServerName + '" -E -Q"'+@DynamicCode+'" -w65535 -h-1'
	INSERT INTO #ExecOutput([TextOutput])
	EXEC	XP_CMDSHELL  @DynamicCode
	PRINT	'		-- FINISHED DATABASE RESTORE ' + CAST(Getdate() as VarChar)
	SELECT	@DynamicCode = ''
	SELECT	@DynamicCode = @DynamicCode + '			-- ' + REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([TextOutput],CHAR(9),' '),'     ',' '),'    ',' '),'   ',' '),'  ',' ') + @CRLF
	FROM	#ExecOutput 
	WHERE	nullif([TextOutput],'') IS NOT NULL
	PRINT	@DynamicCode
	
	IF @Flag_NoRecovery = 'Y'
	BEGIN
		PRINT	''
		PRINT	'			-- DATABASE STILL "RESTORING" AND IS NOT YET USABLE.'
		PRINT	'				-- USE THE FOLLOWING TO COMPLETE: RESTORE DATABASE ['+@DBName+'] WITH RECOVERY'
	END	
END
TheEnd:

GO

GO
IF OBJECT_ID('dbasp_CloneDBs') IS NOT NULL
	DROP PROCEDURE	dbasp_CloneDBs
GO
CREATE PROCEDURE	dbasp_CloneDBs
	(
	@ServerToClone		sysname
	,@DeployableDBS		bit			= 0
	,@NonDeployableDBs	bit			= 1
	,@OpsDBs			bit			= 1
	,@systemDBs			bit			= 0
	)
AS
	DECLARE		@DynamicCode		VARCHAR(8000)
				,@DBName			SYSNAME
				,@machinename		VarChar(8000)
				,@instancename		VarChar(8000)
				,@ServerName		varchar(8000)
				,@ServiceExt		varchar(8000)
				,@Msg				VarChar(max)
				,@DefaultBackupDir	VarChar(8000)
				,@ScriptOutput		VarChar(max)
				,@statement			nVarChar(4000)
				,@Params			nVarChar(4000)
				,@BackupFile		VarChar(8000)
			
	SELECT		@instancename		= isnull('\'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
				,@ServerName		= REPLACE(@@SERVERNAME,@instancename,'')
				,@machinename		= convert(nvarchar(100), serverproperty('machinename')) + @instancename
				,@ServiceExt		= isnull('$'+nullif(REPLACE(@@SERVICENAME,'MSSQLSERVER',''),''),'')
				
	IF (OBJECT_ID('tempdb..#ExecOutput_CloneDBs'))	IS NOT NULL	DROP TABLE #ExecOutput_CloneDBs
	CREATE	TABLE	#ExecOutput_CloneDBs ([rownum] int identity primary key,[TextOutput] VARCHAR(8000));

	DECLARE CloneDBCusrsor CURSOR
	FOR
	SELECT		name
	FROM		Master..sysdatabases
	WHERE		name NOT LIKE 'ASPState%'
		and		name NOT IN ('tempdb', 'pubs', 'Northwind')
		and		(name NOT IN ('master', 'msdb', 'model')						OR @systemDBs			= 1)
		and		(name NOT IN ('dbaadmin', 'dbaperf', 'deplinfo','deplcontrol'
								,'gears','dbacentral','dbaperf_reports'
								,'operations','RunBook','RunBook05','MetricsOps'
								,'DeployMaster')								OR @OpsDBs				= 1)
		and		(name NOT IN (select db_name From dbaadmin.dbo.db_sequence)		OR @DeployableDBS		= 1)
		and		(name NOT IN (	SELECT name from master..sysdatabases 
								where name not in (select db_name From dbaadmin.dbo.db_sequence)
								AND name NOT LIKE 'ASPState%' 
								and name NOT IN ('tempdb', 'pubs', 'Northwind') 
								and name NOT IN ('master', 'msdb', 'model') 
								AND name NOT IN ('dbaadmin', 'dbaperf', 'deplinfo','deplcontrol','gears','dbacentral','dbaperf_reports','operations','RunBook','RunBook05','MetricsOps','DeployMaster')
								)												OR	@NonDeployableDBS	= 1) 	

	OPEN CloneDBCusrsor
	FETCH NEXT FROM CloneDBCusrsor INTO @DBName
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			TRUNCATE TABLE #ExecOutput_CloneDBs
			
			SELECT	@Msg			= 'Backing up Database: ' + @DBName
					,@DynamicCode	= 'EXEC dbaadmin.dbo.dbasp_BackupDBs @DBName='''+@DBName+''',@target_path=''\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')
									+ '\'+REPLACE(@@SERVERNAME,'\','$')+'_backup'',@backup_name='''+@DBName+''',@DeletePrevious = ''Before'''+';'
					,@DynamicCode	= 'sqlcmd -S' + @ServerToClone + ' -E -Q"'+@DynamicCode+'"'

			RAISERROR (@Msg,-1,-1) WITH NOWAIT
			INSERT #ExecOutput_CloneDBs(TextOutput) EXEC master.sys.xp_cmdshell @DynamicCode
			RAISERROR ('	Done...',-1,-1) WITH NOWAIT
			
			SELECT		@BackupFile = REPLACE(TextOutput,'Output file will be: ','')
			FROM		#ExecOutput_CloneDBs 
			WHERE		TextOutput like 'Output file will be:%'

			SELECT		@Msg			= 'Restoring Database: ' + @DBName
			RAISERROR	(@Msg,-1,-1) WITH NOWAIT
			EXEC		master.dbo.dbasp_RestoreDatabase @DBName=@DBName,@File_Backup=@BackupFile,@Flag_NoRecovery='Y',@Flag_ScriptOnly = 'N'
			RAISERROR ('	Done...',-1,-1) WITH NOWAIT
			
			SELECT	@Msg			= 'Recovering Database: ' + @DBName
					,@DynamicCode	= 'RESTORE DATABASE ['+@DBName+'] WITH RECOVERY;'

			RAISERROR (@Msg,-1,-1) WITH NOWAIT
			EXEC (@DynamicCode)
			RAISERROR ('	Done...',-1,-1) WITH NOWAIT
			PRINT ''
		END
		FETCH NEXT FROM CloneDBCusrsor INTO @DBName
	END

	CLOSE CloneDBCusrsor
	DEALLOCATE CloneDBCusrsor
GO

GO
IF OBJECT_ID('SaveTableAsHTML') IS NOT NULL
	DROP PROCEDURE [dbo].[SaveTableAsHTML]
GO
CREATE PROCEDURE [dbo].[SaveTableAsHTML]
		@PCWrite varchar(1000) = NULL,
		@DBFetch varchar(4000),
		@DBWhere varchar(2000) = NULL,
		@DBThere varchar(2000) = NULL,
		@DBUltra bit = 1,
		@TableStyle varchar(1000) = 'border-width: thin; border-spacing: 2px; border-style: solid; border-color: gray; border-collapse: collapse;',
		@Header bit = 1 -- Output header. Default is 1.
	AS

	SET NOCOUNT ON

	DECLARE	@DBAE			varchar(40)		,@hString 		varchar(8000)	,@Size 			int				,@FileO			int
			,@Task 			varchar(6000)	,@tString 		varchar(8000)	,@Wide 			smallint		,@TmpPathObj	int
			,@Bank 			varchar(4000)	,@fString 		varchar(50)		,@More 			smallint		,@TmpPath		varchar(127)
			,@Cash 			varchar(2000)	,@Name 			varchar(100)	,@DBAI 			varchar(2000)	,@TmpFile		varchar(127)
			,@Risk 			varchar(2000)	,@Same 			varchar(100)	,@DBAO 			varchar(8000)	,@TmpFilename	varchar(1000)
			,@Next 			varchar(8000)	,@Rank 			smallint		,@DBAU 			varchar(8000)	,@HeaderString	varchar(8000)
			,@Save 			varchar(8000)	,@Kind 			varchar(20)		,@Fuse 			int				,@sHeaderString	varchar(8000)
			,@Work 			varchar(8000)	,@Mask 			bit				,@File 			int				,@HeaderDone	int
			,@Wish 			varchar(8000)	,@Bond 			bit				,@FuseO			int				,@sql			nvarchar(4000)
			,@aHeader		nvarchar(9)		,@zHeader		nvarchar(9)		,@Return		int				,@Retain		int				
			,@Status		int				,@TPre			varchar(10)		,@TDo3			tinyint			,@TDo4			tinyint

	SELECT	@Status	= 0
			,@TPre	= '', @DBAI = '', @DBAO = '', @DBAU = ''
			,@TDo3	= LEN(@TPre)
			,@TDo4	= LEN(@TPre) + 1		
			,@DBAE	= '##SaveFile' + RIGHT(CONVERT(varchar(10),@@SPID+100000),5)
			,@Task	= 'IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects WHERE name = ' + CHAR(39) + @DBAE + CHAR(39) + ') DROP TABLE ' + @DBAE
			,@Bank	= @TPre + @DBFetch	
	EXECUTE (@Task)

	IF NOT EXISTS (SELECT * FROM sysobjects WHERE RTRIM(type) = 'U' AND name = @Bank)
	BEGIN
		SET @Bank = CASE WHEN LEFT(LTRIM(@DBFetch),6) = 'SELECT' THEN '(' + @DBFetch + ')' ELSE @DBFetch END
		SET @Bank = REPLACE(@Bank,         CHAR(94),CHAR(39))
		SET @Bank = REPLACE(@Bank,CHAR(45)+CHAR(45),CHAR(32))
		SET @Bank = REPLACE(@Bank,CHAR(47)+CHAR(42),CHAR(32))
	END

	IF @DBWhere IS NOT NULL
	BEGIN
		SET @Cash = REPLACE(@DBWhere,'WHERE'       ,CHAR(32))
		SET @Cash = REPLACE(@Cash,         CHAR(94),CHAR(39))
		SET @Cash = REPLACE(@Cash,CHAR(45)+CHAR(45),CHAR(32))
		SET @Cash = REPLACE(@Cash,CHAR(47)+CHAR(42),CHAR(32))
	END

	IF @DBThere IS NOT NULL
	BEGIN
		SET @Risk = REPLACE(@DBThere,'ORDER BY'    ,CHAR(32))
		SET @Risk = REPLACE(@Risk,         CHAR(94),CHAR(39))
		SET @Risk = REPLACE(@Risk,CHAR(45)+CHAR(45),CHAR(32))
		SET @Risk = REPLACE(@Risk,CHAR(47)+CHAR(42),CHAR(32))
	END

	IF ASCII(LEFT(@Bank,1)) < 64
	BEGIN
		SET @Task = 'SELECT * INTO ' + @DBAE + ' FROM ' + @Bank + ' AS T WHERE 0 = 1'
		IF @Status = 0 EXECUTE (@Task) SET @Return = @@ERROR
		IF @Status = 0 SET @Status = @Return

		DECLARE Fields CURSOR FAST_FORWARD FOR
		SELECT C.name, C.colid, T.name, C.isnullable, C.iscomputed, C.length, C.prec, C.scale
		FROM tempdb.dbo.sysobjects AS O
		JOIN tempdb.dbo.syscolumns AS C
		  ON O.id = C.id
		JOIN tempdb.dbo.systypes AS T
		  ON C.xusertype = T.xusertype
		WHERE O.name = @DBAE
		ORDER BY C.colid

		SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain
	END
	ELSE
	BEGIN
		DECLARE Fields CURSOR FAST_FORWARD FOR
		SELECT C.name, C.colid, T.name, C.isnullable, C.iscomputed, C.length, C.prec, C.scale
		FROM sysobjects AS O
		JOIN syscolumns AS C
		  ON O.id = C.id
		JOIN systypes AS T
		  ON C.xusertype = T.xusertype
		WHERE ISNULL(OBJECTPROPERTY(O.id,'IsMSShipped'),1) = 0
		 AND RTRIM(O.type) IN ('U','V','IF','TF')
		 AND O.name = @Bank
		ORDER BY C.colid
		
		SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain
	END

	OPEN Fields
	SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain

	FETCH NEXT FROM Fields INTO @Same, @Rank, @Kind, @Mask, @Bond, @Size, @Wide, @More
	SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain

	-- Convert to character for header.
	SELECT	@HeaderString = '', @sHeaderString = '', @aHeader = '<th>', @zHeader = '</th>'

	WHILE @@FETCH_STATUS = 0 AND @Status = 0
	BEGIN
		-- Build header.
		IF LEN(@HeaderString) > 0 SET @HeaderString = @HeaderString + '+lower(''<tr>'')' + '+ISNULL(''' + @Same + ''',SPACE(0))+' + 'lower(''</tr>'')+'
		IF LEN(@HeaderString) = 0 SET @HeaderString = '+lower(''<tr>'')' + '+ISNULL(''' + @Same + ''',SPACE(0))+' + 'lower(''</tr>'')+'
		IF LEN(@sHeaderString) > 0 SET @sHeaderString = @sHeaderString + @aHeader + ISNULL(@Same, SPACE(0)) + @zHeader
		IF LEN(@sHeaderString) = 0 SET @sHeaderString = @aHeader + ISNULL(@Same, SPACE(0)) + @zHeader

		IF @Kind IN ('char','varchar','nchar','nvarchar')
		BEGIN
			IF @Rank = 1 SET @DBAU = 'lower(''<td>'')' + '+ISNULL(CONVERT(varchar(40),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
			IF @Rank > 1 SET @DBAU = @DBAU + '+lower(''<td>'')' + '+ISNULL(CONVERT(varchar(40),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
		END

		IF @Kind IN ('bit','tinyint','smallint','int','bigint')
		BEGIN
			IF @Rank = 1 SET @DBAU = 'lower(''<td>'')' + '+ISNULL(CONVERT(varchar(40),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
			IF @Rank > 1 SET @DBAU = @DBAU + '+lower(''<td>'')' + '+ISNULL(CONVERT(varchar(40),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
		END

		IF @Kind IN ('numeric','decimal','money','smallmoney','float','real')
		BEGIN
			IF @Rank = 1 SET @DBAU = 'lower(''<td>'')' + '+ISNULL(CONVERT(varchar(80),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
			IF @Rank > 1 SET @DBAU = @DBAU + '+lower(''<td>'')' + '+ISNULL(CONVERT(varchar(80),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
		END

		IF @Kind IN ('uniqueidentifier')
		BEGIN
			IF @Rank = 1 SET @DBAU = 'lower(''<td>'')' + '+ISNULL(CONVERT(varchar(80),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
			IF @Rank > 1 SET @DBAU = @DBAU + '+lower(''<td>'')' + '+ISNULL(CONVERT(varchar(80),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
		END

		IF @Kind IN ('datetime','smalldatetime')
		BEGIN
			IF @Rank = 1 SET @DBAU = 'lower(''<td>'')' + '+ISNULL(CONVERT(varchar(40),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
			IF @Rank > 1 SET @DBAU = @DBAU + '+lower(''<td>'')' + '+ISNULL(CONVERT(varchar(40),' + @Same + '),SPACE(0))+' + 'lower(''</td>'')'
		END

		FETCH NEXT FROM Fields INTO @Same, @Rank, @Kind, @Mask, @Bond, @Size, @Wide, @More
		SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain
	END

	CLOSE Fields DEALLOCATE Fields

	IF LEN(@DBAU) = 0 SET @DBAU = '*'

	SELECT	@DBAI = ' SELECT '
			,@DBAO = '   FROM ' + @Bank + ' AS T'
				+ CASE WHEN @DBWhere IS NULL THEN '' ELSE ' WHERE (' + @Cash + ') AND 0 = 0' END
				+ CASE WHEN @DBThere IS NULL THEN '' ELSE ' ORDER BY ' + @Risk + ',' + CHAR(39) + 'DBA' + CHAR(39) END

	IF LEN(ISNULL(@PCWrite,'*')) > 7 AND @DBUltra = 0
	BEGIN
		SELECT	@tString	= ' select lower(''<html><body><table border='') + CHAR(34) + ''1'' + CHAR(34) + '' style='' + CHAR(34) + lower(''' + @TableStyle + ''') + CHAR(34) + ''>'' UNION ALL '
				,@fString	= ' UNION ALL select ''</table></body></html>'''
				,@hString	= ''
		IF @Header = 1
		BEGIN
			SET @hString = ' select ''<tr>' + @sHeaderString + '</tr>'' UNION ALL '
		END
		SET @Wish = 'set nocount on; USE ' + DB_NAME() + @tString + @hString + @DBAI + '''<tr>''+' + @DBAU + '+''</tr>''' + @DBAO + @fString
		-- SET @Work = 'bcp "' + @Wish + '" queryout "' + @PCWrite + '" -c -T' -- Query length of BCP is limited to only 1023 chars.
		-- Create SQL script file.
		IF @Status = 0 EXECUTE @Status = sp_OACreate 'Scripting.FileSystemObject', @FuseO OUTPUT
		IF @Status = 0 EXECUTE @Status = sp_OAGetProperty @FuseO, 'GetSpecialFolder(2)', @TmpPathObj OUTPUT
		IF @Status = 0 EXECUTE @Status = sp_OAGetProperty @TmpPathObj, 'Path', @TmpPath OUTPUT
		IF @Status = 0 EXECUTE @Status = sp_OAGetProperty @FuseO, 'GetTempName', @TmpFile OUTPUT
		SET @TmpFilename = @TmpPath + '\' + @TmpFile
		IF @Status = 0 EXECUTE @Status = sp_OAMethod @FuseO, 'CreateTextFile', @FileO OUTPUT, @TmpFilename, -1
		IF @Status <> 0 GOTO ABORT
		IF @Status = 0 EXECUTE @Status = sp_OAMethod @FileO, 'Write', NULL, @Wish
		IF @Status = 0 EXECUTE @Status = sp_OAMethod @FileO, 'Close'

		SET @Work = 'osql -i "' + @TmpFilename + '" -o "' + @PCWrite + '" -n -h-1 -w8000 -E'
		EXECUTE @Return = master.dbo.xp_cmdshell @Work, NO_OUTPUT
		SET @Retain = @@ERROR
		IF @Status = 0 SET @Status = @Retain
		IF @Status = 0 SET @Status = @Return

		EXECUTE @Status = sp_OAMethod @FuseO, 'DeleteFile', NULL, @TmpFilename
		EXECUTE @Status = sp_OADestroy @FuseO

		GOTO ABORT
	END

	IF LEN(ISNULL(@PCWrite,'*')) > 7
	BEGIN
		IF @Status = 0 EXECUTE @Return = sp_OACreate 'Scripting.FileSystemObject', @Fuse OUTPUT
		SET @Retain = @@ERROR
		IF @Status = 0 SET @Status = @Retain
		IF @Status = 0 SET @Status = @Return

		IF @Status = 0 EXECUTE @Return = sp_OAMethod @Fuse, 'CreateTextFile', @File OUTPUT, @PCWrite, -1
		SET @Retain = @@ERROR
		IF @Status = 0 SET @Status = @Retain
		IF @Status = 0 SET @Status = @Return

		IF @Status <> 0 GOTO ABORT
	END

	SET @DBAI = 'DECLARE Records CURSOR GLOBAL FAST_FORWARD FOR' + @DBAI

	IF @Status = 0 EXECUTE (@DBAI+@DBAU+@DBAO) SET @Return = @@ERROR
	IF @Status = 0 SET @Status = @Return

	OPEN Records
	SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain

	FETCH NEXT FROM Records INTO @Next
	SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain

	SET @HeaderDone = 0
	WHILE @@FETCH_STATUS = 0 AND @Status = 0
	BEGIN
		SET @Save = ''

		IF ISNULL(@File,0) = 0
		BEGIN
			-- Print header (TEXT).
			IF @HeaderDone = 0
			BEGIN
				PRINT '<table border="1" style="' + @TableStyle + '">' + CHAR(13) + CHAR(10)
				SET @HeaderDone = 1
			END
			IF @Header = 1
			BEGIN
				PRINT '<tr>' + @sHeaderString + '</tr>' + CHAR(13) + CHAR(10)
				SET @Header = 0
			END
			PRINT '<tr>' + @Next + '</tr>'
		END
		ELSE
		BEGIN
			-- Print header (FILE).
			IF @HeaderDone = 0
			BEGIN
				SET @Save = @Save + '<html><body><table border="1" style="' + @TableStyle + '">' + CHAR(13) + CHAR(10)
				SET @HeaderDone = 1
			END
			IF @Header = 1
			BEGIN
				SET @Save = @Save + '<tr>' + @sHeaderString + '</tr>' + CHAR(13) + CHAR(10)
				SET @Header = 0
			END

			-- Print the data.
			SET @Save = @Save + '<tr>' + @Next + '</tr>' + CHAR(13) + CHAR(10)
			IF @Status = 0 EXECUTE @Return = sp_OAMethod @File, 'Write', NULL, @Save
			IF @Status = 0 SET @Status = @Return
		END

		FETCH NEXT FROM Records INTO @Next
		SET @Retain = @@ERROR IF @Status = 0 SET @Status = @Retain
	END

	CLOSE Records DEALLOCATE Records

	-- Print footer (TEXT).
	IF ISNULL(@File,0) = 0
	BEGIN
		PRINT '</table>' + CHAR(13) + CHAR(10)
	END
	ELSE
	BEGIN
		SET @Save = '</table></body></html>' + CHAR(13) + CHAR(10)
		IF @Status = 0 EXECUTE @Return = sp_OAMethod @File, 'Write', NULL, @Save
	END

	-- Close.
	IF ISNULL(@File,0) <> 0
	BEGIN
		EXECUTE @Return = sp_OAMethod @File, 'Close', NULL
		IF @Status = 0 SET @Status = @Return

		EXECUTE @Return = sp_OADestroy @File
		IF @Status = 0 SET @Status = @Return

		EXECUTE @Return = sp_OADestroy @Fuse
		IF @Status = 0 SET @Status = @Return
	END

	ABORT: -- This label is referenced when OLE automation fails.

	IF @Status = 1 OR @Status NOT BETWEEN 0 AND 50000 RAISERROR ('SaveTableAsHTML Windows error [%d]',16,1,@Status)

	SET @Task = 'IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects WHERE name = ' + CHAR(39) + @DBAE + CHAR(39) + ') DROP TABLE ' + @DBAE
	EXECUTE (@Task)

	RETURN (@Status)
GO

GO
IF OBJECT_ID('dbaudf_FileAccess_Read') IS NOT NULL
	DROP FUNCTION [dbo].[dbaudf_FileAccess_Read]
GO
CREATE FUNCTION [dbo].[dbaudf_FileAccess_Read]
						(
						@Path VARCHAR(4000)
						,@Filename VARCHAR(1024)= NULL -- CAN BE NULL IF PASSING THE FILENAME AS PART OF THE PATH
						)
						RETURNS @File TABLE
								(
								[LineNo]	int identity(1,1)
								,[line]		varchar(8000)
								) 
BEGIN

	DECLARE  @objFileSystem int
			,@objTextStream int
			,@objErrorObject int
			,@strErrorMessage Varchar(1000)
			,@Command varchar(1000)
			,@hr int
			,@String VARCHAR(8000)
			,@YesOrNo INT
			,@OpenAsUnicode int
			,@TextStreamTest nvarchar(10)
			,@char_value int
			,@RetryCount	int


	SET	@RetryCount	= 0
	step1:
	SELECT	@strErrorMessage ='opening the File System Object'
	EXECUTE	@hr = sp_OACreate  'Scripting.FileSystemObject' , @objFileSystem OUT
		IF @hr != 0 
		BEGIN
			SET @RetryCount = @RetryCount + 1
			IF @RetryCount > 5 
			BEGIN
				GOTO DoneReading
			END
			goto step1
		END

	Select	@objErrorObject		= @objFileSystem
			,@strErrorMessage	= 'Opening file "'+@path+'\'+@filename+'"'
			,@command			= @path+COALESCE(CASE WHEN RIGHT(@Path,1) = '\' THEN '' ELSE '\' END+@filename,'')

	SET	@RetryCount	= 0
	step2:
	EXECUTE	@hr = sp_OAMethod @objFileSystem, 'OpenTextFile', @objTextStream OUT, @command, 1, false, 0--for reading, FormatASCII
		IF @hr != 0 
		BEGIN
			SET @RetryCount = @RetryCount + 1
			IF @RetryCount > 5 
			BEGIN
				GOTO DoneReading
			END
			goto step2
		END
	----------------------------------------
	----------------------------------------
	-- CHECK TEXT FORMAT ASCII/UNICODE
	----------------------------------------
	----------------------------------------
	SET	@RetryCount	= 0
	step3:
	--  Read the first byte of the file into @TextStreamTest
	EXECUTE @HR = sp_OAMethod @objTextStream, 'Read(1)', @TextStreamTest OUTPUT
		IF @hr != 0 AND @hr !=  -2146828226
		BEGIN
			SET @RetryCount = @RetryCount + 1
			IF @RetryCount > 5 
			BEGIN
				GOTO DoneReading
			END
			goto step3
		END
		
	IF @HR = -2146828226   -- (File was empty)
		SELECT @char_value = 65  -- force an ascii value (small 'a')
	ELSE
		SELECT @char_value = unicode(@TextStreamTest)

	--  Test the first bite of the file.  Unicode files will have char(239), char(254), char(255) or null at the start.
	If (@char_value in (239, 254, 255) or @char_value is null)
	   SET @OpenAsUnicode = -1
	else
	   SET @OpenAsUnicode = 0
	----------------------------------------
	----------------------------------------
	-- REOPEN FILE AS CORRECT FORMAT
	----------------------------------------
	----------------------------------------
	SET	@RetryCount	= 0
	step4:
	execute @hr = sp_OAMethod   @objFileSystem  , 'OpenTextFile', @objTextStream OUT, @command,1,false,@OpenAsUnicode
		IF @hr != 0 
		BEGIN
			SET @RetryCount = @RetryCount + 1
			IF @RetryCount > 5 
			BEGIN
				GOTO DoneReading
			END
			goto step4
		END	
	----------------------------------------
	----------------------------------------
	CheckFile:
	SET	@RetryCount	= 0
	execute @hr = sp_OAGetProperty @objTextStream, 'AtEndOfStream', @YesOrNo OUTPUT
		IF @hr != 0 
		BEGIN
			SET @RetryCount = @RetryCount + 1
			IF @RetryCount > 5 
			BEGIN
				GOTO DoneReading
			END
			goto CheckFile
		END	
		
		
	WHILE @YesOrNo	= 0
	BEGIN
		ReadLine:
		SET	@RetryCount	= 0
		execute @hr = sp_OAMethod  @objTextStream, 'Readline', @String OUTPUT
			IF @hr != 0 
			BEGIN
				SET @RetryCount = @RetryCount + 1
				IF @RetryCount > 5 
				BEGIN
					GOTO DoneReading
				END
				goto ReadLine
			END	
			
		INSERT INTO @file(line) SELECT @String

		CheckFile2:
		SET	@RetryCount	= 0
		execute @hr = sp_OAGetProperty @objTextStream, 'AtEndOfStream', @YesOrNo OUTPUT
			IF @hr != 0 
			BEGIN
				SET @RetryCount = @RetryCount + 1
				IF @RetryCount > 5 
				BEGIN
					GOTO DoneReading
				END
				goto CheckFile2
			END			
	END
	
	DoneReading:

	IF @objTextStream IS NOT NULL
		execute @hr = sp_OAMethod  @objTextStream, 'Close'
			IF @hr != 0 
			BEGIN
				SET @RetryCount = @RetryCount + 1
				IF @RetryCount > 5 
				BEGIN
					GOTO Destroy
				END
				goto DoneReading
			END		

	Destroy:
	IF @objTextStream IS NOT NULL			
		EXECUTE  @hr = sp_OADestroy @objTextStream
			IF @hr != 0 
			BEGIN
				SET @RetryCount = @RetryCount + 1
				IF @RetryCount > 5 
				BEGIN
					GOTO ExitCode
				END
				goto Destroy
			END	
	ExitCode:
		
	RETURN 
END
GO

GO
IF OBJECT_ID('dbasp_FileAccess_Write') IS NOT NULL
	DROP PROCEDURE [dbo].[dbasp_FileAccess_Write]
GO
CREATE PROCEDURE [dbo].[dbasp_FileAccess_Write]
		(
		@String			Varchar(max)			--8000 in SQL Server 2000
		,@Path			VARCHAR(4000)
		,@Filename		VARCHAR(1024)	= NULL	-- CAN BE NULL IF PASSING THE FILENAME AS PART OF THE PATH
		,@Append		bit				= 0		-- DEFAULT IS TO OVERWRITE
		)
	as
	SET NOCOUNT ON

	DECLARE		@objFileSystem		int
				,@objTextStream		int
				,@objErrorObject	int
				,@strErrorMessage	Varchar(1024)
				,@Command			varchar(1024)
				,@hr				int
				,@fileAndPath		varchar(1024)
				,@Method			INT
		
	SET			@Method = CASE @Append WHEN 0 THEN 2 ELSE 8 END

	select @strErrorMessage='opening the File System Object'
	EXECUTE @hr = sp_OACreate  'Scripting.FileSystemObject' , @objFileSystem OUT

	Select @FileAndPath=@path+COALESCE(CASE WHEN RIGHT(@Path,1) = '\' THEN '' ELSE '\' END+@filename,'')
	if @HR=0 Select @objErrorObject=@objFileSystem , @strErrorMessage=CASE @Append WHEN 0 THEN 'Creating file "' ELSE 'Appending file "' END +@FileAndPath+'"'
	if @HR=0 execute @hr = sp_OAMethod   @objFileSystem,'OpenTextFile',@objTextStream OUT,@FileAndPath,@Method,True

	if @HR=0 Select @objErrorObject=@objTextStream, 
		@strErrorMessage='writing to the file "'+@FileAndPath+'"'
	if @HR=0 execute @hr = sp_OAMethod  @objTextStream, 'Write', Null, @String

	if @HR=0 Select @objErrorObject=@objTextStream, @strErrorMessage='closing the file "'+@FileAndPath+'"'
	if @HR=0 execute @hr = sp_OAMethod  @objTextStream, 'Close'

	if @hr<>0
		begin
		Declare 
			@Source varchar(1024),
			@Description Varchar(1024),
			@Helpfile Varchar(1024),
			@HelpID int
		
		EXECUTE sp_OAGetErrorInfo  @objErrorObject, 
			@source output,@Description output,@Helpfile output,@HelpID output
		Select @strErrorMessage='Error whilst '
				+coalesce(@strErrorMessage,'doing something')
				+', '+coalesce(@Description,'')
		raiserror (@strErrorMessage,16,1)
		end
	EXECUTE  sp_OADestroy @objTextStream
	EXECUTE sp_OADestroy @objTextStream
GO	

GO	
	IF OBJECT_ID('dbaudf_CPUInfo') IS NOT NULL
	DROP FUNCTION [dbo].[dbaudf_CPUInfo]
GO
	CREATE FUNCTION [dbo].[dbaudf_CPUInfo](@Attribute sysname)
	RETURNS INT
	AS
	BEGIN
		DECLARE		@WmiServiceLocator			int
					,@WmiService				int
					,@CounterCollection			int
					,@CounterObject				int
					,@Freespace					float
					,@Value						INT
					,@NumberOfCores				INT
					,@NumberOfLogicalProcessors	INT
					,@Count						int
					,@CPULoop					INT
					,@Property					nVarChar(200)
					,@Value2					sysname
		DECLARE		@SocketList					TABLE (SocketDesignation sysname)
					
		SELECT		@CPULoop					= 0
					,@NumberOfCores				= 0
					,@NumberOfLogicalProcessors	= 0
					 
		exec sp_OACreate 'WbemScripting.SWbemLocator', @WmiServiceLocator output; 
		exec sp_OAMethod @WmiServiceLocator, 'ConnectServer', @WmiService output, '.', 'root\cimv2'; 
		exec sp_OAMethod @WmiService, 'execQuery', @CounterCollection output, 'Select * from Win32_Processor';
		 
		exec sp_OAGetProperty @CounterCollection,'Count', @Count OUT

		WHILE @CPULoop < @Count
		BEGIN
			SET		@Property = 'Win32_Processor.DeviceID=''CPU'+CAST(@CPULoop AS VarChar)+''''
			exec sp_OAMethod @CounterCollection, 'Item', @CounterObject output, @Property;

			SET		@Value = 0
			exec	sp_OAGetProperty @CounterObject, 'NumberOfCores', @Value output;
			SET		@NumberOfCores = @NumberOfCores + @Value
			
			SET		@Value = 0
			exec	sp_OAGetProperty @CounterObject, 'NumberOfLogicalProcessors', @Value output; 
			SET		@NumberOfLogicalProcessors = @NumberOfLogicalProcessors + @Value
		
			SET		@Value2 = ''
			exec	sp_OAGetProperty @CounterObject, 'SocketDesignation', @Value2 output;
			 
			IF @Value2 NOT IN (SELECT SocketDesignation FROM @SocketList)
					INSERT INTO @SocketList(SocketDesignation) VALUES(@Value2)

			SET		@CPULoop = @CPULoop + 1

		END
		
		IF @Count > 0 AND @NumberOfLogicalProcessors = 0
			SELECT	@NumberOfLogicalProcessors	= @Count
					,@Count						= COUNT(*)
					,@NumberOfCores				= @NumberOfLogicalProcessors / @Count
			FROM	@SocketList		 
		
		IF @Attribute = 'Sockets'
			SET @Value = @Count
		ELSE IF @Attribute = 'Cores'
			SET @Value = @NumberOfCores
		ELSE
			SET @Value = @NumberOfLogicalProcessors

		RETURN @Value
	END
GO

GO	
	IF OBJECT_ID('dbaudf_Dir') IS NOT NULL
	DROP FUNCTION [dbo].[dbaudf_Dir]
GO
	CREATE FUNCTION [dbo].[dbaudf_Dir](@Wildcard VARCHAR(8000))
	RETURNS @MyDir TABLE 
	(
		   [name] VARCHAR(2000),    --the name of the filesystem object
		   [path] VARCHAR(2000),    --Contains the item's full path and name. 
		   [ModifyDate] DATETIME,   --the time it was last modified 
		   [IsFileSystem] INT,      --1 if it is part of the file system
		   [IsFolder] INT,          --1 if it is a folsdder otherwise 0
		   [error] VARCHAR(2000)    --if an error occured, gives the error otherwise null
	)
	AS
	BEGIN
	   DECLARE 
		   @objShellApplication INT, 
		   @objFolder INT,
		   @objItem INT,
		   @objErrorObject INT,
		   @objFolderItems INT, 
		   @strErrorMessage VARCHAR(1000), 
		   @Command VARCHAR(1000), 
		   @hr INT, --OLE result (0 if OK)
		   @count INT,@ii INT,
		   @name VARCHAR(2000),--the name of the current item
		   @path VARCHAR(2000),--the path of the current item 
		   @ModifyDate DATETIME,--the date the current item last modified
		   @IsFileSystem INT, --1 if the current item is part of the file system
		   @IsFolder INT --1 if the current item is a file
	   IF LEN(COALESCE(@Wildcard,''))<2 
		   RETURN

	   SELECT  @strErrorMessage = 'opening the Shell Application Object' 
	   EXECUTE @hr = sp_OACreate 'Shell.Application', 
		   @objShellApplication OUT 
	   IF @HR = 0  
		   SELECT  @objErrorObject = @objShellApplication, 
				   @strErrorMessage = 'Getting Folder"' + @wildcard + '"', 
				   @command = 'NameSpace("'+@wildcard+'")' 
	   IF @HR = 0  
		   EXECUTE @hr = sp_OAMethod @objShellApplication, @command, 
			   @objFolder OUT
	   IF @objFolder IS NULL RETURN --nothing there. Sod the error message
	   --and then the number of objects in the folder
		   SELECT  @objErrorObject = @objFolder, 
				   @strErrorMessage = 'Getting count of Folder items in "' + @wildcard + '"', 
				   @command = 'Items.Count' 
	   IF @HR = 0  
		   EXECUTE @hr = sp_OAMethod @objfolder, @command, 
			   @count OUT
		IF @HR = 0 --now get the FolderItems collection 
			SELECT  @objErrorObject = @objFolder, 
					@strErrorMessage = ' getting folderitems',
				   @command='items()'
		IF @HR = 0  
			EXECUTE @hr = sp_OAMethod @objFolder, 
				@command, @objFolderItems OUTPUT 
	   SELECT @ii = 0
	   WHILE @hr = 0 AND @ii< @count --iterate through the FolderItems collection
				BEGIN 
					IF @HR = 0  
						SELECT  @objErrorObject = @objFolderItems, 
								@strErrorMessage = ' getting folder item ' 
									   + CAST(@ii AS VARCHAR(5)),
							   @command='item(' + CAST(@ii AS VARCHAR(5))+')'
							   --@Command='GetDetailsOf('+ cast(@ii as varchar(5))+',1)'
					IF @HR = 0  
						EXECUTE @hr = sp_OAMethod @objFolderItems, 
							@command, @objItem OUTPUT 

					IF @HR = 0  
						SELECT  @objErrorObject = @objItem, 
								@strErrorMessage = ' getting folder item properties'
									   + CAST(@ii AS VARCHAR(5))
					IF @HR = 0  
						EXECUTE @hr = sp_OAMethod @objItem, 
							'path', @path OUTPUT
					IF @HR = 0  
						EXECUTE @hr = sp_OAMethod @objItem, 
							'name', @name OUTPUT
					IF @HR = 0  
						EXECUTE @hr = sp_OAMethod @objItem, 
							'ModifyDate', @ModifyDate OUTPUT
					IF @HR = 0  
						EXECUTE @hr = sp_OAMethod @objItem, 
							'IsFileSystem', @IsFileSystem OUTPUT
					IF @HR = 0  
						EXECUTE @hr = sp_OAMethod @objItem, 
							'IsFolder', @IsFolder OUTPUT
				   INSERT INTO @MyDir ([NAME], [path], ModifyDate, IsFileSystem, IsFolder)
					   SELECT @NAME, @path, @ModifyDate, @IsFileSystem, @IsFolder
				   IF @HR = 0  EXECUTE sp_OADestroy @objItem 
				   SELECT @ii=@ii+1
				END 
			IF @hr <> 0  
				BEGIN 
					DECLARE @Source VARCHAR(255), 
						@Description VARCHAR(255), 
						@Helpfile VARCHAR(255), 
						@HelpID INT 
	     
					EXECUTE sp_OAGetErrorInfo @objErrorObject, @source OUTPUT, 
						@Description OUTPUT, @Helpfile OUTPUT, @HelpID OUTPUT 
					SELECT  @strErrorMessage = 'Error whilst ' 
							+ COALESCE(@strErrorMessage, 'doing something') + ', ' 
							+ COALESCE(@Description, '') 
					INSERT INTO @MyDir(error) SELECT  LEFT(@strErrorMessage,2000) 
				END 
			EXECUTE sp_OADestroy @objFolder 
			EXECUTE sp_OADestroy @objShellApplication

	RETURN
	END
GO
	
GO	
	IF OBJECT_ID('dbasp_sp_configure') IS NOT NULL
	DROP PROCEDURE [dbo].[dbasp_sp_configure]
GO
	CREATE Procedure dbasp_sp_configure (@configname VarChar(35),@configvalue Int)
	AS
	BEGIN
		DECLARE	@DynamicText	VarChar(8000)
		SET		@DynamicText	= 'EXEC sp_configure '''+@configname+''', ' + CAST(@configvalue as VarChar)

		SET		@DynamicText	= 'sqlcmd -S' + @@ServerName + ' -E -Q"' + @DynamicText + '"'
		EXEC master.sys.xp_cmdshell @DynamicText, no_output 
	END
GO
	
GO	
	IF OBJECT_ID('dbasp_LogSQLStartup') IS NOT NULL
	DROP PROCEDURE [dbo].[dbasp_LogSQLStartup]
GO
	CREATE PROCEDURE dbasp_LogSQLStartup
	AS
		DECLARE @OutPutText VarChar(8000)
		SET		@OutPutText = 'STARTING SQL ' + CAST(GetDate() AS VarChar(50))
		IF OBJECT_ID('master.dbo.ServerDeploymentStatus') IS NOT NULL
		BEGIN
			INSERT INTO master.dbo.ServerDeploymentStatus(TextOutput) Values(@OutPutText) 
		END
		ELSE
		BEGIN
			SELECT	IDENTITY(int,1,1) [rownum], @OutPutText [TextOutput]
			INTO	master.dbo.ServerDeploymentStatus
		END
		exec xp_cmdshell 'NET SEND sledridge SQL SERVEICE STARTED'
		EXEC master.dbo.[Getty_Deploy_SQL]
GO		

GO	
	EXEC sp_procoption
		@ProcName		= 'master.dbo.dbasp_LogSQLStartup'
		,@OptionName	= 'STARTUP' 
		,@OptionValue	= 'on'
GO		



--EXEC sys.sp_dropextendedproperty @Name = 'NEWServerDeployStep'

--EXEC [Getty_Deploy_SQL]

