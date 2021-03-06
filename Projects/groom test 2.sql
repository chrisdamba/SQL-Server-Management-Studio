USE [SystemCenterReporting]
GO
/****** Object:  StoredProcedure [dbo].[p_GroomDatawarehouseTables]    Script Date: 10/07/2010 18:18:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--ALTER PROC [dbo].[p_GroomDatawarehouseTables]
--AS
BEGIN
        
    DECLARE     @SaveRowCount       INTEGER
    DECLARE     @SaveError          INTEGER
    DECLARE     @ClassID            UNIQUEIDENTIFIER
    DECLARE     @GroomTableName     NVARCHAR(255)
    DECLARE     @GroomColumnName    NVARCHAR(255)
    DECLARE     @GroomDays          INTEGER
    DECLARE     @Command            NVARCHAR(2000)
    DECLARE     @Dependency         NVARCHAR(1000)
    DECLARE     @StartGroomTime     DATETIME
    DECLARE     @EndGroomTime       DATETIME
    DECLARE     @TargetClassName    NVARCHAR(255)
    DECLARE     @TargetFKColumnName NVARCHAR(255)
    
    --
    -- Do not run if data transfer job is already running. 
    -- SP1 fix #50314: When a package is running or when grooming
    -- is running, we will take a lock (sp_getapplock) on the 
    -- resource MOM.Datawarehousing.DTSPackageGenerator.exe for the
    -- session (connection).
    -- We will not allow another instance or the exe and/or
    -- grooming to run simultaneously. 
    -- Earlier, we were taking a lock on the WarehouseTransformInfo
    -- table for the duration of the run (by having a transaction)
    -- and it was preventing the transaction log truncation.
    --
  
    EXECUTE @SaveError = sp_getapplock @Resource = N'MOM.Datawarehousing.DTSPackageGenerator.exe', 
                                       @LockMode = N'Exclusive',
                                       @LockOwner = N'Session'
   
    IF (@SaveError < 0)
    BEGIN
        GOTO Error_AlreadyRunning_Exit
    END
    
    --
    -- Define a temporary table that holds the list of all source and target
    -- class ids from the relationship constraints table.
    --

    CREATE TABLE #tmpRelationshipConstraints
    (
        SourceClassID         UNIQUEIDENTIFIER NOT NULL,
        TargetClassID         UNIQUEIDENTIFIER NOT NULL
    )   
    
    SET @SaveError = @@ERROR
    
    IF (@SaveError <> 0)
    BEGIN
        GOTO Error_Exit
    END

    -- Populate the table
    -- Note: We are incluing all target class ids that are not dw classes
    -- as well. This is because we do not want to groom the dw class which
    -- acts as a source, if there is a non dw target class that depends on it.
    -- It does not matter if the source is a non dw class and the target is a
    -- dw class.
    
    INSERT INTO #tmpRelationshipConstraints
    SELECT RC.SourceClassID AS SourceClassID,
           RC.TargetClassID AS TargetClassID
    FROM dbo.SMC_Meta_RelationshipConstraints AS RC
    WHERE RC.SourceClassID IN (SELECT WCS.ClassID
                               FROM dbo.SMC_Meta_WarehouseClassSchema AS WCS with (NOLOCK))
    
    
    --
    -- Save the rowcount and error in local variables
    --
    
    SET @SaveRowCount = @@ROWCOUNT
    SET @SaveError = @@ERROR
    
    IF (@SaveError <> 0)
    BEGIN
        GOTO Error_Exit
    END
    
       
    --
    -- Define a temporary table to hold the ordered list of classids (ordered
    -- in the delete order)
    --
    
    CREATE TABLE #tmpDeleteList
    (
        ClassID             UNIQUEIDENTIFIER NOT NULL,
        DeleteOrder         INT IDENTITY(1,1)
    )   
    
    SET @SaveError = @@ERROR
    
    IF (@SaveError <> 0)
    BEGIN
        GOTO Error_Exit
    END
    

    --
    -- Construct an ordered list of warehouse tables to be groomed
    --

    -- Repeat while there are rows in the #tmpRelationshipConstraints table
        
    WHILE @SaveRowCount <> 0
    BEGIN
        
        -- Add to the #tmpDeleteList, class ids that are not sources in a 
        -- relationship
        
        INSERT INTO #tmpDeleteList
        SELECT CS.ClassID AS ClassID
        FROM dbo.SMC_Meta_ClassSchemas AS CS with (NOLOCK)
        INNER JOIN dbo.SMC_Meta_WarehouseClassSchema AS WCS with (NOLOCK)
        ON CS.ClassID = WCS.ClassID
        WHERE CS.ClassID NOT IN (SELECT TMPRC.SourceClassID AS SourceClassID
                                 FROM #tmpRelationshipConstraints AS TMPRC with (NOLOCK)
                                 UNION
                                 SELECT TMPDL.ClassID AS AlreadyAddedClassID 
                                 FROM #tmpDeleteList AS TMPDL with (NOLOCK))
                                 
        SET @SaveError = @@ERROR
        
        IF (@SaveError <> 0)
        BEGIN
            GOTO Error_Exit
        END
                             
        -- Delete from #tmpRelationshipConstraints all rows where the 
        -- TargetClassID is already in the #tmpDeleteList
        
        DELETE FROM #tmpRelationshipConstraints
        WHERE TargetClassID IN (SELECT TMPDL.ClassID AS ClassID
                                FROM #tmpDeleteList AS TMPDL with (NOLOCK))
                                      
        SET @SaveError = @@ERROR
        
        IF (@SaveError <> 0)
        BEGIN
            GOTO Error_Exit
        END
        
        -- Save the count of remaining rows in #tmpRelationshipConstraints
        --
        
        SELECT @SaveRowCount = COUNT(*) FROM #tmpRelationshipConstraints with (NOLOCK)
        
    END
    
    -- Add the remaining classes from the class schemas table that have
    -- not been added
    
    INSERT INTO #tmpDeleteList
    SELECT CS.ClassID AS ClassID
    FROM dbo.SMC_Meta_ClassSchemas AS CS with (NOLOCK)
    INNER JOIN dbo.SMC_Meta_WarehouseClassSchema AS WCS with (NOLOCK)
    ON CS.ClassID = WCS.ClassID
    WHERE CS.ClassID NOT IN (SELECT TMPDL.ClassID AS ClassID
                             FROM #tmpDeleteList AS TMPDL with (NOLOCK))


    SET @SaveError = @@ERROR

    IF (@SaveError <> 0)
    BEGIN
        GOTO Error_Exit
    END
        
    -- From #tmpDeleteList, eliminate the classes that need no grooming
    
    DELETE FROM #tmpDeleteList 
    WHERE ClassID IN (SELECT WCS.ClassID AS ClassID
                      FROM dbo.SMC_Meta_WarehouseClassSchema AS WCS with (NOLOCK)
                      WHERE WCS.MustBeGroomed IS NULL
                      OR    WCS.MustBeGroomed = 0)

    SET @SaveError = @@ERROR

    IF (@SaveError <> 0)
    BEGIN
        GOTO Error_Exit
    END

    
    --
    -- Iterate through the ordered list of tables to be groomed and construct
    -- the delete statement for each of them, and execute the delete.
    --
    
    DECLARE CursorGroomTable CURSOR LOCAL FOR
            SELECT TMPDL.ClassID AS ClassID
            FROM #tmpDeleteList AS TMPDL with (NOLOCK)
            ORDER BY TMPDL.DeleteOrder ASC

    OPEN CursorGroomTable
    FETCH NEXT FROM CursorGroomTable INTO @ClassID
    WHILE @@fetch_status = 0
    BEGIN
        
        -- Reset variables
        
        SET @GroomTableName = N''
        SET @GroomColumnName = N''
        SET @GroomDays = 0
        SET @Command = N''
        SET @Dependency = N''        
        
        -- Get the name of the table to groom
        -- Get the name of the column on which to apply the groom criteria
        -- Get the number of days to groom
        
        SELECT @GroomTableName = CS.ViewName, 
               @GroomColumnName = CP.PropertyName, 
               @GroomDays = WCS.GroomDays --select CS.ViewName,CP.PropertyName,WCS.GroomDays
        FROM dbo.SMC_Meta_WarehouseClassProperty AS WCP with (NOLOCK)
        INNER JOIN dbo.SMC_Meta_ClassProperties AS CP with (NOLOCK)
        ON WCP.ClassPropertyID = CP.ClassPropertyID
        INNER JOIN dbo.SMC_Meta_WarehouseClassSchema AS WCS with (NOLOCK)
        ON WCS.ClassID = CP.ClassID
        INNER JOIN dbo.SMC_Meta_ClassSchemas AS CS with (NOLOCK)
        ON CS.ClassID = CP.ClassID
        WHERE WCP.IsGroomColumn = 1
        AND CP.ClassID = @ClassID
        
        SET @SaveRowCount = @@ROWCOUNT
        
        IF (@GroomTableName IS NULL  OR
            @GroomTableName = N''    OR
            @GroomColumnName IS NULL OR
            @GroomColumnName = N''   OR
            @GroomDays IS NULL       OR
            @GroomDays = 0           OR
            @SaveRowCount <> 1)
        BEGIN
            GOTO ConfigError_Exit
        END
        
                
        --
        -- Construct the delete statement that will groom the data
        --
              
        -- Initialize the delete statement with groom criteria
        
        SET @Command =
        N'REDELETE:'						+
        N'DELETE FROM '                                 +
        @GroomTableName                                 +
        N'
        WHERE '                                         +
        @GroomColumnName                                +
        N' < DATEADD(DAY, -'                            +
        CAST(@GroomDays AS NVARCHAR(20))                +
        N', GETUTCDATE())'
               
        -- Determine if this table participates as a source of a relationship

        DECLARE CursorDependency CURSOR LOCAL FOR
                SELECT CS.ViewName AS TargetClassName,
                        CP.PropertyName AS TargetFKColumnName
                FROM dbo.SMC_Meta_RelationshipConstraints AS RC with (NOLOCK)
                INNER JOIN dbo.SMC_Meta_ClassSchemas AS CS with (NOLOCK)
                ON RC.TargetClassID = CS.ClassID
                INNER  JOIN dbo.SMC_Meta_ClassProperties AS CP with (NOLOCK)
                ON RC.TargetFK = CP.ClassPropertyID
                WHERE RC.SourceClassID = @ClassID
                                       
        OPEN CursorDependency
        FETCH NEXT FROM CursorDependency INTO @TargetClassName, 
                                              @TargetFKColumnName
        WHILE @@fetch_status = 0
        BEGIN
        
            -- Construct a statement to eliminate dependent rows
            
            IF @Dependency <> N''
            BEGIN
                SET @Dependency = @Dependency         + 
                                  N'
                                  UNION'
            END
                      
            SET @Dependency = @Dependency             +
                              N'SELECT '              +
                              @TargetFKColumnName     +
                              N' FROM '               +
                              @TargetClassName + ' with (NOLOCK) '

            -- Fetch the next row
            
            FETCH NEXT FROM CursorDependency INTO @TargetClassName, 
                                                  @TargetFKColumnName
                           
        END
        CLOSE CursorDependency
        DEALLOCATE CursorDependency


        -- Update the delete statement to exclude dependent rows.
        
        IF (@Dependency IS NOT NULL AND
            @Dependency <> N'')
        BEGIN
            SET @Command = @Command                         +
                           N'
                           AND SMC_InstanceID NOT IN (
                           '                                +
                           @Dependency                      +
                           N')'
        END
        
        
        --
        -- Execute the groom statement
        --
        
        -- Note the start time
        
        SET @StartGroomTime = GETUTCDATE()
        
        -- Execute the groom command and save the result
        PRINT	'Groom Command Being Executed'
        PRINT	@Command
        
        SELECT @Command
        EXECUTE sp_executesql @Command
        SET @SaveError = @@ERROR
        
        -- Note the end time
        
        SET @EndGroomTime = GETUTCDATE()

        -- Check the groom command results
        
        IF (@SaveError <> 0)
        BEGIN
            GOTO GroomError_Exit
        END
        
        
        --
        -- Update the grooming statistics
        --
        
        DECLARE     @tmpID            UNIQUEIDENTIFIER

        SET @tmpID = NULL
                
        SELECT  @tmpID = WGI.ClassID 
        FROM dbo.SMC_Meta_WarehouseGroomingInfo AS WGI with (NOLOCK)
        WHERE WGI.ClassID = @ClassID
        
        IF (@tmpID IS NULL)
        BEGIN
            
            INSERT INTO dbo.SMC_Meta_WarehouseGroomingInfo
            (ClassID,
             StartTime,
             EndTime)
            VALUES
            (@ClassID,
             @StartGroomTime,
             @EndGroomTime)
        
        END
        ELSE
        BEGIN
        
            UPDATE dbo.SMC_Meta_WarehouseGroomingInfo
            SET StartTime = @StartGroomTime,
            EndTime = @EndGroomTime
            WHERE ClassID = @ClassID
            
        END
        
        SET @SaveError = @@ERROR
        IF (@SaveError <> 0)
        BEGIN
            GOTO GroomError_Exit
        END
        
        -- Fetch the next row
        
        FETCH NEXT FROM CursorGroomTable INTO @ClassID
        
    END
    CLOSE CursorGroomTable
    DEALLOCATE CursorGroomTable

    --
    -- Drop all the temp tables
    --
    
    DROP TABLE #tmpRelationshipConstraints
    DROP TABLE #tmpDeleteList

    --
    -- SP1 fix #50314: Reset the TransformOrGroomInProgress switch
    --
    
    SET @SaveError = 0
    GOTO Reset_Exit
    
Error_AlreadyRunning_Exit:
    -- p_GroomDatawarehouseTables will not be executed because it has detected that data is being transferred (DTS) into the warehouse and/or another grooming instance is running.
    RAISERROR (777977210, 16, 1) WITH LOG
    --RETURN @SaveError

Error_Exit:    
    -- SQL Server error %u encountered in p_GroomDatawarehouseTables.
    RAISERROR (777977202, 16, 1, @SaveError) WITH LOG
    GOTO Reset_Exit
    
GroomError_Exit:
    -- SQL Server error %u encountered in p_GroomDatawarehouseTables while grooming %s.
    RAISERROR (777977203, 16, 1, @SaveError, @GroomTableName) WITH LOG
    GOTO Reset_Exit
    
ConfigError_Exit:
    -- Configuration error encountered in p_GroomDatawarehouseTables.
    RAISERROR (777977201, 16, 1) WITH LOG
    SET @SaveError = 1
    GOTO Reset_Exit
 
Reset_Exit:   
     EXECUTE sp_releaseapplock @Resource = N'MOM.Datawarehousing.DTSPackageGenerator.exe', 
                               @LockOwner = N'Session'
     --RETURN @SaveError
            
END


GO


DELETE

SELECT	COUNT(*)	
FROM	SC_EventParameterFact_Table          
WHERE	DateTimeEventStored < DATEADD(DAY, -95, GETUTCDATE())

DELETE	
FROM	SC_EventParameterFact_View          
WHERE	DateTimeEventStored < DATEADD(DAY, -95, GETUTCDATE())



SELECT	COUNT(*) 
FROM	SC_AlertFact_Table         
WHERE	DateTimeLastModified < DATEADD(DAY, -95, GETUTCDATE())

DELETE 
FROM	SC_AlertFact_View          
WHERE	DateTimeLastModified < DATEADD(DAY, -95, GETUTCDATE())



SELECT		'SELECT	COUNT(*) FROM ' 
		+ CS.ViewName + ' WHERE	' 
		+ CP.PropertyName + ' < DATEADD(DAY, -95, GETUTCDATE())'
		,WCP.*	

FROM		dbo.SMC_Meta_WarehouseClassProperty AS WCP with (NOLOCK)
INNER JOIN	dbo.SMC_Meta_ClassProperties AS CP with (NOLOCK)
	ON	WCP.ClassPropertyID = CP.ClassPropertyID
INNER JOIN	dbo.SMC_Meta_WarehouseClassSchema AS WCS with (NOLOCK)
	ON	WCS.ClassID = CP.ClassID
INNER JOIN	dbo.SMC_Meta_ClassSchemas AS CS with (NOLOCK)
	ON	CS.ClassID = CP.ClassID
WHERE		WCP.IsGroomColumn = 1
        
        

SELECT COUNT(*) FROM SC_ComputerToComputerRuleFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_RelationshipInstanceFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_EventFact_View WHERE DateTimeStored < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_ClassInstanceFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_ComputerRuleToProcessRuleGroupFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_ProcessRuleMembershipFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_ProcessRuleToScriptFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_RelationshipAttributeInstanceFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_AlertFact_View WHERE DateTimeLastModified < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_EventParameterFact_View WHERE DateTimeEventStored < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_AlertHistoryFact_View WHERE DateTimeLastModified < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_AlertToEventFact_View WHERE DateTimeEventStored < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_ClassAttributeInstanceFact_View WHERE DateTimeOfTransfer < DATEADD(DAY, -95, GETUTCDATE())
SELECT COUNT(*) FROM SC_SampledNumericDataFact_View WHERE DateTimeAdded < DATEADD(DAY, -95, GETUTCDATE())

SET NOCOUNT ON
DROP	TABLE	#ToDel
GO
DECLARE @NumToDelete	INT
DECLARE @CMD		VarChar(8000)
DECLARE	@Timer		DateTime
DECLARE	@Duration	INT

SET	@NumToDelete = 1000

CREATE	TABLE	#ToDel
	(
	SMC_InstanceID INT PRIMARY KEY
	)

REDELETE:
TRUNCATE TABLE	#ToDel
SET	@CMD = 'SELECT TOP ' + CAST(@NumToDelete AS VarChar(50)) +' SMC_InstanceID FROM SC_SampledNumericDataFact_View WITH (NOLOCK) WHERE DateTimeAdded < DATEADD(DAY, -95, GETUTCDATE())'

SET	@Timer	= GetDate()

INSERT INTO	#ToDel
EXEC		(@CMD)

DELETE FROM SC_SampledNumericDataFact_View WHERE SMC_InstanceID IN
(SELECT SMC_InstanceID FROM #ToDel)

SELECT	@Duration = DATEDIFF(ms,@Timer,GetDate())

PRINT	'@NumToDelete = '	+ CAST(@NumToDelete As VarChar(50))
				+ '	@Duration = ' 
				+ CAST(@Duration As VarChar(50))
				+ '	PERFORMANCE = ' 
				+ CAST(CAST(@NumToDelete AS FLOAT) / (CAST(@Duration AS FLOAT)) As VarChar(50))

SET	@NumToDelete = @NumToDelete + 100

IF	@NumToDelete < 10001
	GOTO	REDELETE

GO














BACKUP log [SystemCenterReporting] with truncate_only
GO
USE [SystemCenterReporting]
GO
DBCC SHRINKFILE (N'REPLOG' , 0, TRUNCATEONLY)
GO
DBCC SHRINKFILE (N'REPLOG' , 0, NOTRUNCATE)
GO
DBCC SHRINKFILE (N'REPLOG' , 0, TRUNCATEONLY)
GO




SET NOCOUNT ON
GO

DECLARE @NumToDelete	INT
DECLARE	@Timer		DateTime
DECLARE	@Duration	INT
DECLARE @CMD		VarChar(8000)



SET	@Timer	= GetDate()

DELETE FROM SC_AlertHistoryFact_View WHERE SMC_InstanceID IN
(SELECT TOP 100 SMC_InstanceID FROM SC_AlertHistoryFact_View WITH (NOLOCK) WHERE DateTimeLastModified < DATEADD(DAY, -90, GETUTCDATE()) ORDER BY DateTimeLastModified)

SET	@NumToDelete = @@rowcount

REDELETE:
SELECT	@Duration = DATEDIFF(ms,@Timer,GetDate())

SET	@CMD = 'Deleted = '	+ CAST(@NumToDelete As VarChar(50))
				+ '	@Duration = ' 
				+ CAST(@Duration As VarChar(50))
				+ CASE WHEN @Duration < 1000 THEN'	' ELSE '' END
				+ '	PERFORMANCE = ' 
				+ CAST(CAST(@NumToDelete AS FLOAT) / (CAST(@Duration AS FLOAT)) As VarChar(50))
				
RAISERROR(@CMD,-1,-1) WITH NOWAIT

SET	@Timer	= GetDate()

DELETE FROM SC_AlertHistoryFact_View WHERE SMC_InstanceID IN
(SELECT TOP 100 SMC_InstanceID FROM SC_AlertHistoryFact_View WITH (NOLOCK) WHERE DateTimeLastModified < DATEADD(DAY, -90, GETUTCDATE()) ORDER BY DateTimeLastModified)

SET	@NumToDelete = @@rowcount

If @NumToDelete > 0 GOTO REDELETE

GO






