USE [DEPLcontrol]
GO
/****** Object:  StoredProcedure [dbo].[DBA_Dashboard_GearsRunningTicketStatus_Reader]    Script Date: 04/11/2012 09:22:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[DBA_Dashboard_GearsRunningTicketStatus_Reader]
	(
	@TicketID		INT = null
	,@Verbose		BIT = 0
	,@KillUpdater	BIT = 0
	)
AS
BEGIN	
	SET NOCOUNT ON

	declare @rc int
	declare @object int
	declare @src varchar(255)
	declare @desc varchar(255)
	declare @osql_cmd varchar(1000)
	DECLARE	@StartUpdater bit
	SET		@StartUpdater = 0
	
	IF @TicketID IS NULL
	BEGIN
		PRINT 'Checking for Unmonitored Tickets.'
	
		SELECT	TOP 1 @TicketID = Gears_ID
		FROM	[DEPLcontrol].[dbo].[Request]
		WHERE	[Status] = 'in-work'
			AND	Gears_ID NOT IN	(
								SELECT		[TicketID]
								FROM		dbo.DBA_Dashboard_GearsRunningTicketStatus 
								WHERE		[TicketID] = @TicketID
										AND	[Complete] = 0
								)
		
		IF	@TicketID IS NOT NULL
		BEGIN
			PRINT 'Assigning Ticket ' + CAST(@TicketID AS VarChar(50))
			SET		@StartUpdater = 1
		END
	END
	ELSE
	BEGIN
		PRINT 'Checking Ticket ' + CAST(@TicketID AS VarChar(50))
		
		IF NOT EXISTS	(SELECT 1 FROM dbo.DBA_Dashboard_GearsRunningTicketStatus WHERE [TicketID] = @TicketID and Complete = 0)
			SET		@StartUpdater = 1
		ELSE
			PRINT 'Updater Already Running'
	END

	IF @StartUpdater = 1
		BEGIN
			PRINT 'Running Updater'
			-- create shell object 
			exec @rc = sp_oacreate 'wscript.shell', @object out

			set @osql_cmd = 'osql -E -dDEPLcontrol -SSEAPSQLDBA01 -Q"deplcontrol.dbo.DBA_Dashboard_GearsRunningTicketStatus_Updater ' + CAST(@TicketID AS VarChar(50)) + ',' + CAST(@Verbose AS Char(1))

			Print 'use method'
			exec sp_oamethod @object,
						 'run',
						 @desc OUTPUT,
						 @osql_cmd

			print 'destroy object'
			exec sp_oadestroy @object
		END
	ELSE IF @KillUpdater = 1
		BEGIN
			INSERT INTO dbo.DBA_Dashboard_GearsRunningTicketStatus (TicketID,Code,Complete,StatusDate,StatusMessage) 
			SELECT		@TicketID
						,'KILL'
						,0
						,GETDATE()
						,'Signal Killing of Job Monitor for Ticket #'+CAST(@TicketID AS VarChar(50))
		END	
			
	SELECT	[StatusDate]
			, REPLACE([StatusMessage],CHAR(13)+CHAR(10),'<BR>') AS [StatusMessage]
			,[Link]
			,[Code] 
	FROM dbo.DBA_Dashboard_GearsRunningTicketStatus 
	WHERE ([TicketID] = @TicketID) 
	ORDER BY [GRTStatusID]

END
GO 
