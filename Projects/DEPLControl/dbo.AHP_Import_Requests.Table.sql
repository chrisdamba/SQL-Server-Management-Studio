USE [DEPLcontrol]
GO
/****** Object:  Table [dbo].[AHP_Import_Requests]    Script Date: 10/4/2013 11:02:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AHP_Import_Requests](
	[ahp_irid] [int] IDENTITY(1,1) NOT NULL,
	[Request_id] [int] NOT NULL,
	[Request_Type] [sysname] NULL,
	[Request_Status] [sysname] NULL,
	[BuildLabel] [sysname] NOT NULL,
	[ProjectName] [sysname] NULL,
	[ReleaseNum] [sysname] NULL,
	[TargetSQLname] [sysname] NULL,
	[DBname] [nvarchar](500) NULL,
	[BaseName] [sysname] NULL,
	[Buildnum] [sysname] NULL,
	[CreateDate] [datetime] NOT NULL,
	[Request_start] [datetime] NULL,
	[Request_complete] [datetime] NULL,
	[Request_Notes] [nvarchar](500) NULL
) ON [PRIMARY]

GO
