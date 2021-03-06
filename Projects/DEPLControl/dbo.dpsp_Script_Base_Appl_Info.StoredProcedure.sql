USE [DEPLcontrol]
GO
/****** Object:  StoredProcedure [dbo].[dpsp_Script_Base_Appl_Info]    Script Date: 10/4/2013 11:02:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[dpsp_Script_Base_Appl_Info]

 
/***************************************************************
 **  Stored Procedure dpsp_Script_Base_Appl_Info                 
 **  Written by Jim Wilson, Getty Images                
 **  February 23, 2009                                      
 **
 **  This procedure creates a file that is used to populate the 
 **  base_appl_info table in the DEPLcontrol database.  This table 
 **  is used by the DEPL Request Driven process.
 ***************************************************************/
  as
set nocount on

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	02/23/2009	Jim Wilson		New process
--	03/11/2009	Jim Wilson		Removed SQL instances with DEPLstatus = 'n'
--	10/08/2009	Jim Wilson		Added code for new environments.
--	01/05/2009	Jim Wilson		Added support for new moddate column and conditional inserts.
--	05/13/2010	Jim Wilson		Repointed to dbacentral DB.
--	======================================================================================


Declare	 
	 @miscprint			nvarchar(4000)
	,@save_servername		sysname

DECLARE
	 @cu11Parent_name		sysname
	,@cu11App_name			sysname
	,@cu11SQLname			sysname
	,@cu11ENVname			sysname
	,@cu11ENVnum			sysname
	,@cu11DomainName		sysname
	,@cu11BaselineFolder		sysname
	,@cu11DBname			sysname
	,@cu11Active			nvarchar(10)
	,@cu11push_to_nxt		nchar(1)
	,@cu11BaselineServerName	sysname
	,@cu11moddate   		datetime
	,@cu11Companion_DBname		sysname
	,@cu11ApplName			sysname

----------------  initial values  -------------------

Select @save_servername = @@servername


--  Create table variable
declare @servernames table (SQLName sysname
			    ,DBName sysname
			    ,ENVname sysname
			    ,ENVnum sysname
			    ,DomainName sysname
			    ,BaselineFolder sysname
			    ,BaselineServername sysname
			)

declare @servernames2 table (SQLName sysname
			    ,DBName sysname
			    ,ENVname sysname
			    ,ENVnum sysname
			    ,DomainName sysname
			    ,BaselineFolder sysname
			    ,BaselineServername sysname
			)


/****************************************************************
 *                MainLine
 ***************************************************************/

----------------------  Main header  ----------------------
Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Script DATA for Table ''DEPLcontrol.dbo.Base_Appl_Info'' Process'  
Print  @miscprint
Select @miscprint = 'Created From Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '
Select @miscprint = 'Use DEPLcontrol' 
Print @miscprint
Print 'go'
Print ' '


--  Capture data from the DBA_DBinfo table
insert @servernames select d.SQLName, d.DBName, d.ENVname, d.ENVnum, s.DomainName, d.BaselineFolder, d.BaselineServername 
		From dbacentral.dbo.DBA_DBinfo d, dbacentral.dbo.DBA_Serverinfo s
		where s.SQLname = d.SQLname
		  and s.DEPLstatus = 'y'
		  and d.DEPLstatus = 'y'
		  and d.DBName in (select DBname from dbo.db_sequence)
		  and s.active = 'y'

insert @servernames2 select d.SQLName, d.DBName, d.ENVname, d.ENVnum, s.DomainName, d.BaselineFolder, d.BaselineServername 
		From dbacentral.dbo.DBA_DBinfo d, dbacentral.dbo.DBA_Serverinfo s
		where s.SQLname = d.SQLname
		  and s.DEPLstatus = 'y'
		  and d.DEPLstatus = 'y'
		  and d.DBName in (select DBname from dbo.db_sequence)
		  and s.active = 'y'

If (select count(*) from @servernames) > 0
   begin
	start_output:

	Select @cu11SQLName = (select top 1 SQLName from @servernames order by SQLName)
	Select @cu11DBname = (select top 1 DBname from @servernames where SQLName = @cu11SQLname)
	Select @cu11ENVname = (select ENVname from @servernames where SQLName = @cu11SQLname and DBname = @cu11DBname)
	Select @cu11ENVnum = (select ENVnum from @servernames where SQLName = @cu11SQLname and DBname = @cu11DBname)
	Select @cu11DomainName = (select DomainName from @servernames where SQLName = @cu11SQLname and DBname = @cu11DBname)
	Select @cu11BaselineServerName = (select BaselineServerName from @servernames where SQLName = @cu11SQLname and DBname = @cu11DBname)
	Select @cu11ApplName = @cu11BaselineFolder
    
	If exists (select 1 from dbacentral.dbo.DBA_DBinfo where SQLname = @cu11SQLName and DBname = @cu11DBname and DEPLstatus = 'n')
	   begin
		goto skip_output
	   end

	Select @cu11Companion_DBname = ''
	If @cu11DBname in ('priceupdate', 'dataextract', 'AdminDB', 'DataLogDB')
	   begin
		Select @cu11Companion_DBname = (select top 1 companionDB_name 
						from dbo.db_BaseLocation 
						where db_name = @cu11DBname 
						and companionDB_name in (select DBname from @servernames2 where SQLName = @cu11SQLName)
						order by companionDB_name)

		Select @cu11BaselineFolder = (select top 1 RSTRfolder 
						from dbo.db_BaseLocation 
						where db_name = @cu11DBname 
						and companionDB_name = @cu11Companion_DBname
						)

		Select @cu11ApplName = @cu11BaselineFolder
	   end
	Else
	   begin
		Select @cu11BaselineFolder = (select top 1 RSTRfolder from dbo.db_BaseLocation where db_name = @cu11DBname)
		Select @cu11ApplName = @cu11BaselineFolder
	   end

	If @cu11DBname = 'ProductCatalog'
	   begin
		If @cu11ENVname in ('dev', 'test', 'alpha', 'beta', 'candidate', 'prodsupport') and @cu11BaselineFolder not like '%sfp%'
		   begin
			Select @cu11BaselineFolder = 'pc_sfp'
		   end
		Else If (@cu11ENVname like '%stage%' or @cu11ENVname like '%load%') and @cu11BaselineFolder not like '%full%'
		   begin
			Select @cu11BaselineFolder = 'pc_full'
		   end
	   end

	
	Select @miscprint = 'If not exists (select 1 from dbo.Base_Appl_Info where DBname = ''' + @cu11DBname + ''' and SQLname = ''' + @cu11SQLName + ''' and ENVnum = ''' + @cu11ENVnum + ''' and Domain = ''' + @cu11DomainName + ''')' + char(13)+char(10)
	Select @miscprint = @miscprint + '   begin' + char(13)+char(10)
	Select @miscprint = @miscprint + '      Insert into dbo.Base_Appl_Info (DBname, CompanionDB_name, APPLname, BASEfolder, SQLname, baseline_srvname, ENVnum, Domain, moddate)' + char(13)+char(10)
	Select @miscprint = @miscprint + '         values (''' + @cu11DBname + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '                 ''' + @cu11Companion_DBname + ''',' + char(13)+char(10) 
	Select @miscprint = @miscprint + '                 ''' + @cu11ApplName + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '                 ''' + @cu11BaselineFolder + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '                 ''' + @cu11SQLName + ''',' + char(13)+char(10) 
	Select @miscprint = @miscprint + '                 ''' + @cu11BaselineServerName + ''',' + char(13)+char(10) 
	Select @miscprint = @miscprint + '                 ''' + @cu11ENVnum + ''',' + char(13)+char(10) 
	Select @miscprint = @miscprint + '                 ''' + @cu11DomainName + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '                  getdate())' + char(13)+char(10)
	Select @miscprint = @miscprint + '   end' + char(13)+char(10)
	Select @miscprint = @miscprint + 'Else' + char(13)+char(10)
	Select @miscprint = @miscprint + '   begin' + char(13)+char(10)
	Select @miscprint = @miscprint + '      Update dbo.Base_Appl_Info set moddate = getdate()' + char(13)+char(10)
	Select @miscprint = @miscprint + '      where DBname = ''' + @cu11DBname + '''' + char(13)+char(10)
	Select @miscprint = @miscprint + '      and SQLname = ''' + @cu11SQLName + '''' + char(13)+char(10)
	Select @miscprint = @miscprint + '      and ENVnum = ''' + @cu11ENVnum + '''' + char(13)+char(10)
	Select @miscprint = @miscprint + '      and Domain = ''' + @cu11DomainName + '''' + char(13)+char(10)
	Select @miscprint = @miscprint + '   end' + char(13)+char(10)

	Print @miscprint
	Print 'go'
	Print ' '


	skip_output:

	--  Remove this record from @servernames and go to the next
	delete from @servernames where SQLname = @cu11SQLname and ENVnum = @cu11ENVnum and DBname = @cu11DBname
	If (select count(*) from @servernames) > 0
	   begin
		goto start_output
	   end
   end


-----------------------------------------------------------------------------------------------------------------
--  Finalization  -----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

label99:

Select @miscprint = 'Delete from dbo.Base_Appl_Info where moddate < getdate()-8' 
Print @miscprint
Print 'go'
Print ' '


--send email if we have old rows not being updated
Print 'declare @save_date datetime'
Print 'declare @save_subject sysname'
Print ''
Print 'Select @save_subject = ''DEPLcontrol Base_Appl_Info Error from server '' + @@servername'
Print 'select @save_date = dateadd(hh, 23, getdate()-1)'
Print ''
Print 'if exists (select * from DEPLcontrol.dbo.Base_Appl_Info where moddate < @save_date)'
Print '   begin'
Print '      EXEC dbaadmin.dbo.dbasp_sendmail' 
Print '      @recipients = ''jwilson.getty@gmail.com'',' 
Print '      @subject = @save_subject,'
Print '      @message = ''Rows with non-current moddate exist in the Base_Appl_Info table'''
Print '   end'
Print 'go'
Print ' '



Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Script DATA for Table ''DEPLcontrol.dbo.Base_Appl_Info'' Process Complete'  
Print  @miscprint
Print  '************************************************************************/'




GO
