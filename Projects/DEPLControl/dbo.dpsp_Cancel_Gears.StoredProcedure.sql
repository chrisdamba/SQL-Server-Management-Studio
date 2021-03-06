USE [DEPLcontrol]
GO
/****** Object:  StoredProcedure [dbo].[dpsp_Cancel_Gears]    Script Date: 10/4/2013 11:02:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO



CREATE PROCEDURE [dbo].[dpsp_Cancel_Gears] (@gears_id int = null)

/*********************************************************
 **  Stored Procedure dpsp_Cancel_Gears                  
 **  Written by Jim Wilson, Getty Images                
 **  March 13, 2009                                      
 **  
 **  This sproc will cancell a specific Gears ticket and then
 **  delete that Gears request from the DEPLcontrol database.
 **
 **  Input Parm(s);
 **  @gears_id - is the Gears ID for a specific request
 **
 ***************************************************************/
  as
set nocount on

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/13/2009	Jim Wilson		New process.
--	======================================================================================


/***
Declare @gears_id int

Select @gears_id = 33739
--***/

-----------------  declares  ------------------

DECLARE
	 @miscprint			nvarchar(2000)
	,@charpos			int
	,@update_flag			char(1)
	,@save_start_d			nvarchar(50)
	,@save_start_t			nvarchar(50)
	,@save_start_date		datetime
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
Select @miscprint = '-- Gears Cancel and Request Delete Process '
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


--  Verify input parms

If @gears_id is null
   begin
	Select @miscprint = 'Error: No Gears ID specified.' 
	Print  @miscprint
	Print ''

	goto label99
   end

If not exists (select 1 from master.sys.databases where name = 'gears')
   begin
	Select @miscprint = 'Error: This process must be run on a SQL instance with both the Gears and DEPLcontrol databases.' 
	Print  @miscprint
	Print ''

	goto label99
   end


	

/****************************************************************
 *                MainLine
 ***************************************************************/

--  First we cancell the ticket in gears
Select @miscprint = 'CANCEL:  cancelling gears ticket ' + convert(nvarchar(20), @gears_id) + '.' 
Print  @miscprint
Print ''
EXECUTE gears.dbo.ChangeTicketStatus @Action = 1, @BuildRequestID = @gears_id, @NewStatus = 'cancelled'


--  Now we delete this request out of the request and request_detail tables.
If not exists (select 1 from dbo.request where gears_id = @gears_id)
   begin
	Select @miscprint = 'DBA WARNING: Invalid input parm for gears_id (' + convert(nvarchar(20), @gears_id) + ').  No rows for this gears_id in the Request table.' 
	Print  @miscprint
	Print ''
	Select @error_count = @error_count + 1

	goto label99
   end

--  Frist delete the detail records for the Gears ID
Select @miscprint = 'DELETE: delete from dbo.Request_detail where Gears_id = ' + convert(nvarchar(20), @gears_id)
Print  @miscprint
Print ''

delete from dbo.Request_detail where Gears_id = @gears_id


--  Now delete the main request record for this Gears ID
Select @miscprint = 'DELETE: delete from dbo.Request where Gears_id = ' + convert(nvarchar(20), @gears_id) 
Print  @miscprint
Print ''

delete from dbo.Request where Gears_id = @gears_id

If exists (select 1 from dbo.control_HL where gears_id = @gears_id)
   begin
	--  Now delete the related rows from the control_HL table for this Gears ID
	Select @miscprint = 'DELETE: delete from dbo.control_HL where Gears_id = ' + convert(nvarchar(20), @gears_id) 
	Print  @miscprint
	Print ''

	delete from dbo.control_HL where Gears_id = @gears_id
   end




-----------------  Finalizations  ------------------

label99:

--  Print out sample exection of this sproc for specific gears_id
exec dbo.dpsp_Status @report_only = 'y'

Print  ' '
Print  ' '
Select @miscprint = '--Here is a sample execute command for this sproc:'
Print  @miscprint
Print  ' '
Select @miscprint = 'exec DEPLcontrol.dbo.dpsp_Cancel_Gears @gears_id = 12345'
Print  @miscprint
Print  ' '



GO
