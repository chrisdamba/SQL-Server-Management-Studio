USE [DEPLcontrol]
GO
/****** Object:  StoredProcedure [dbo].[dpsp_ManualStart_swl]    Script Date: 10/4/2013 11:02:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[dpsp_ManualStart_swl] (@gears_id int = null
					,@SQLname sysname = null)

/*********************************************************
 **  Stored Procedure dpsp_ManualStart                  
 **  Written by Jim Wilson, Getty Images                
 **  April 09, 2009                                      
 **  
 **  This sproc will assist in manually starting deployment
 **  processes in stage and production.  
 **
 **  Input Parm(s);
 **  @gears_id - is the Gears ID for a specific request
 **
 **  @SQLname - is the SQLname (with instance) you want to start.
 **
 ***************************************************************/
  as

set nocount on

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/09/2009	Jim Wilson		New process.
--	04/29/2009	Jim Wilson		Added ckeck for status = 'manual' to update process.
--	======================================================================================


/***
Declare @gears_id int
Declare @SQLname sysname

Select @gears_id = 33739
Select @SQLname = 'servername'
--***/

-----------------  declares  ------------------

DECLARE
	 @miscprint			nvarchar(2000)
	,@update_flag			char(1)
	,@error_count			int

/*********************************************************************
 *                Initialization
 ********************************************************************/
Select @error_count = 0
Select @update_flag = 'n'




----------------------  Print the headers  ----------------------

Print  '/*******************************************************************'
Select @miscprint = '   SQL Automated Deployment Requests - Server: ' + @@servername
Print  @miscprint
Print  ' '
Select @miscprint = '-- Manual Start Process '
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


--  Verify input parms

If @gears_id is null
   begin
	Select @miscprint = 'Error: No Gears ID specified.' 
	Print  @miscprint
	Print ''

	exec dbo.dpsp_Status @report_only = 'y'

	goto label99
   end

If @SQLname is null
   begin
	Select @miscprint = 'Error: No @SQLname specified.' 
	Print  @miscprint
	Print ''

	exec dbo.dpsp_Status @gears_id = @gears_id, @report_only = 'y'

	goto label99
   end
   
If @SQLname = 'ScriptAll'
   begin
	Select	@miscprint = 'Info: @SQLname specified keyword "ScriptAll".' 
	Print	@miscprint
	Print	''
	Declare	@cmd VarChar(8000)
	SET		@cmd = ''
	select	@cmd	= @cmd 
					+ 'exec DEPLcontrol.dbo.dpsp_ManualStart @gears_id = '
					+ CAST(@gears_id AS VarChar(20))
					+ ', @SQLname = '''
					+ d.SQLname
					+ ''';'
					+ CHAR(13) + CHAR(10)
	FROM	(
			SELECT	DISTINCT
					SQLname 				
			From	dbo.Request_detail d
			WHERE	gears_id = @gears_id
				and	status = 'manual'
			) d
	PRINT (@CMD)	
	goto label99
   end   

If not exists (select 1 from dbo.request_detail where gears_id = @gears_id and SQLname = @SQLname)
   begin
	Select @miscprint = 'Error: @SQLname specified for this request (' + @SQLname + ') does not exist in this gears_id (' + convert(nvarchar(10), @gears_id) + ').' 
	Print  @miscprint
	Print ''

	exec dbo.dpsp_Status @gears_id = @gears_id, @report_only = 'y'

	goto label99
   end

If not exists (select 1 from dbo.request_detail where gears_id = @gears_id and SQLname = @SQLname and status = 'manual')
   begin
	Select @miscprint = 'Error: Status for this gears_id/SQLname is not set to ''manual''.  No action taken.' 
	Print  @miscprint
	Print ''

	exec dbo.dpsp_Status @gears_id = @gears_id, @report_only = 'y'

	goto label99
   end


	

/****************************************************************
 *                MainLine
 ***************************************************************/


update dbo.Request_detail set status = 'pending' where Gears_id = @gears_id and SQLname = @SQLname and status = 'manual'
Select @update_flag = 'y'

exec dbo.dpsp_Status @gears_id = @gears_id, @report_only = 'y'





-----------------  Finalizations  ------------------

label99:

If @update_flag = 'n'
   begin
	Print  ' '
	Print  ' '
	Select @miscprint = '--Here is a sample execute command for this sproc:'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'exec DEPLcontrol.dbo.dpsp_ManualStart @gears_id = 12345, @SQLname = ''servername\a'''
	Print  @miscprint
	Print  'go'
	Print  ' '
   end




GO
