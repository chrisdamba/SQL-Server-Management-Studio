USE [DEPLcontrol]
GO
/****** Object:  Table [dbo].[Request_detail]    Script Date: 10/4/2013 11:02:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Request_detail](
	[reqdet_id] [int] IDENTITY(1,1) NOT NULL,
	[Gears_id] [int] NOT NULL,
	[Status] [sysname] NULL,
	[DBname] [sysname] NULL,
	[APPLname] [sysname] NULL,
	[SQLname] [sysname] NULL,
	[Domain] [sysname] NULL,
	[BASEfolder] [sysname] NULL,
	[Process] [sysname] NULL,
	[ProcessType] [sysname] NULL,
	[ProcessDetail] [sysname] NULL,
	[ModDate] [datetime] NULL
) ON [PRIMARY]

GO
/****** Object:  Index [IX_clust_Request_detail]    Script Date: 10/4/2013 11:02:05 AM ******/
CREATE NONCLUSTERED INDEX [IX_clust_Request_detail] ON [dbo].[Request_detail]
(
	[Gears_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Request_detail]  WITH CHECK ADD  CONSTRAINT [FK_Request_detail_Gears] FOREIGN KEY([Gears_id])
REFERENCES [dbo].[Request] ([Gears_id])
GO
ALTER TABLE [dbo].[Request_detail] CHECK CONSTRAINT [FK_Request_detail_Gears]
GO
