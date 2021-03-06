USE [WCDS]
GO
/****** Object:  StoredProcedure [dbo].[wedVitriaDownloadStatusUpdate]    Script Date: 12/08/2011 16:33:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[wedVitriaDownloadStatusUpdate_new]
    @iDownloadId			integer,					-- NOT NULL
    @iStatusId              integer,					-- NOT NULL
    @oiErrorID		        int				= 0		OUTPUT,
    @ovchErrorMessage		varchar(256)	= ''	OUTPUT
AS


/* ---------------------------------------------------------------------------
---------------------------------------------------------------------------
--	Procedure: wedVitriaDownloadStatusUpdate
--	For: Getty Images
--
--	Dependencies:
--		wedGetErrorInfo (sp)
--
--	---------------------------------------------------------------------------------------
--	REVISION HISTORY
--	Date		Author				Comment
--	----------	-------------------	-------------------------------------------------------
--	01/19/2009 	Matthew Potter		Copied most of SQL from wedVitriaDownloadFailedUpdate
--									This proc fixes some counting issues with PA
--	09/23/2009  Steve Mayszak		Removed the dead parameters.  Fixing a bug with premium access
--									The updates do not take into account that there was only 1 detail
--									record created. If this is the second attempt at a download that 
--									failed the first time, the row would not be counted.  Other bugs
--									Include batch updates.  The method would have incremented the count
--									for pa for every item in the batch as long as one of those were
--									a pa.  This work is to add a new status for premium access (starts in pending)
--									rather than success.  And onyl updates the count if we know it has succeeded.
--									With this chnage we will create new detail records until we get our first 
--									successfull record. Meaning, if the download keeps failing, the user
--									will keep getting download detail records but after the first successful download
--									of this asset no more download detail records will be created for that user / asset combo
--	08/13/2010	Steve Mayszak		Premium access no longer chnages customers counts or download detail status
--									from delivery udpates. The customer is charged up front for the download and the status
--									message is simply used to update the transactional records status.
--
--	Parameters
--	@iDownloadId		integer		NOT NULL
--		The unique Id of this download order, orderId from the request
--  @iStatusId                      integer         NOT NULL
--      The download status, -1 means a failure occured
--		-1 is a legacy value.  current values are:
--		0 = failure
--		1 = success
--	Return Values
--	   0	Success
--	-999	Some failure; check output parameters
---------------------------------------------------------------------------
--------------------------------------------------------------------------- */
BEGIN
	-- Environmental settings
	SET NOCOUNT ON

	-- Establish constants	
	DECLARE
		@Error_Download_NotFound        varchar(50), 
		@Error_Update_Failed            varchar(50),
		@CurrentError                   varchar(50),
		@Error                          int,
		@UpdateToStatusID				int,
		@UpdateFromStatusID				int,
		@PremiumAccessSourceID			int,
		@iModifiedBy					int,
		@ProcessFailure					int

	--DEFAULT VALUES
	SELECT
		@Error_Download_NotFound        = 'Download_NotFound',
		@Error_Update_Failed            = 'Update_Failed',
		@CurrentError                   = 'Error Unspecified',
        @oiErrorId                      = 0,
        @ovchErrorMessage               = '',
		@UpdateToStatusID				= 0,
		@PremiumAccessSourceID			= 3103

	-- Get iModifiedBy for VitriaUser	
	SELECT @iModifiedBy = iIndividualID
	FROM INDIVIDUAL (nolock)
	WHERE vchUserName = 'VitriaUser'
	SELECT @iModifiedBy = ISNULL(@iModifiedBy, 1)

	-- Quit if no download records exist	
	IF NOT EXISTS(SELECT 1 FROM dbo.Download (nolock) WHERE DownloadId = @iDownloadId)
	BEGIN
		SELECT @CurrentError = @Error_Download_NotFound
		GOTO ErrorHandler
	END


	----------------------------------------------------------------------------------------------------------------
	-- Check for pior success - if so, don't change the count!
	----------------------------------------------------------------------------------------------------------------
	--Print 'Checking downloadID=' + STR(@iDownloadId) + ' with StatusID=' + STR(@iStatusId)

	-- has this download ever succeeded?
	
	Set @ProcessFailure = 1  -- Initial rule is to always process the status.
	
	-- has this download ever succeeded?
	If Exists
	(
		Select iDownloadImportId From dbo.Download_imp with (nolock)
		Where
			vchOrderId = Cast (@iDownloadId as varchar(60))
		And iStatusID = 1
	)
	Or Exists
	(
		Select DownloadId From DownloadDetail with (nolock)
		Where DownloadId = @iDownloadId And DownloadSourceId In (3104,3105)
		-- we found a failed RF Sub or Image Pack, always count it with a 950 status
	)
		Begin
			Set @ProcessFailure = 0 -- Do not process this status! 
		End
	
	--for debugging
	--Print 'ProcessFailure:'
	--Print @ProcessFailure
	----------------------------------------------------------------------------------------------------------------
	-- UPDATE Download and DownloadDetail records
	----------------------------------------------------------------------------------------------------------------
	IF @iStatusId = 1
	BEGIN
		-- Mark download as successful.  This can happen if the user refreshes the download page or has a download blocker
		-- turned on like IE default configuration.  We need to set the final status correctly, and this does it.
		SELECT @UpdateToStatusID = 950, @UpdateFromStatusID = 951	
	END
	ELSE
	BEGIN
		IF @ProcessFailure = 1
		BEGIN
			SELECT @UpdateToStatusID = 951, @UpdateFromStatusID = 950
		END
	END

	if(@UpdateToStatusID > 0) --make sure we set the update to status id, if not we are supposed to skip this update
	BEGIN
		-- update primary download record
		UPDATE Download
		SET DownloadStatusID = @UpdateToStatusID
		WHERE DownloadId = @iDownloadId
		AND DownloadStatusID = @UpdateFromStatusID

		-- update download detail rows for non premium access records
		UPDATE DownloadDetail
		SET	StatusID = @UpdateToStatusID,
			StatusModifiedBy = @iModifiedBy,
			StatusModifiedDateTime = GETDATE()
		WHERE DownloadId = @iDownloadId
		AND StatusID = @UpdateFromStatusID
		AND DownloadSourceID <> @PremiumAccessSourceID

		--update the premium access transactional records
		UPDATE dbo.PremiumAccessDownloadLog
		SET StatusUpdatedDate= GETDATE(), [Status] = @UpdateToStatusID
		WHERE DownloadId = @iDownloadId
		
	END
	IF @Error <> 0
    BEGIN
        SELECT @CurrentError = @Error_Update_Failed
        GOTO ErrorHandler
    END
	

	----------------------------------------------------------------------------------------------------------------
	-- Error handling
	----------------------------------------------------------------------------------------------------------------
    SET @Error = @@Error
    IF @Error <> 0
    BEGIN
        SELECT @CurrentError = @Error_Update_Failed
        GOTO ErrorHandler
    END

-------------------------------------------
-- Normal exit
-------------------------------------------
NormalExit:
	RETURN 0

-------------------------------------------
-- Error handler
-------------------------------------------
ErrorHandler:
	RETURN -1

END


IF OBJECT_ID('wedVitriaDownloadStatusUpdate') IS NOT NULL
    PRINT '<<< CREATED STORED PROCEDURE wedVitriaDownloadStatusUpdate >>>'
ELSE
    PRINT '<<< FAILED CREATING STORED PROCEDURE wedVitriaDownloadStatusUpdate >>>'

-----------------------------------------------------------------
GRANT EXECUTE ON dbo.wedVitriaDownloadStatusUpdate TO role_oneuser
