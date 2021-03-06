CREATE VIEW	RSP_Data
/****************************************************************************
<CommentHeader>
	<VersionControl>
 		<DatabaseName>DeployMaster</DatabaseName>				
		<SchemaName>dbo</SchemaName>
		<ObjectType>View</ObjectType>
		<ObjectName>RSP_Data</ObjectName>
		<Version>1.0.0</Version>
		<Build Number="" Application="" Branch=""/>
		<Created By="Steve Ledridge" On="3/14/2011"/>
		<Modifications>
			<Mod By="" On="" Reason=""/>
			<Mod By="" On="" Reason=""/>
		</Modifications>
	</VersionControl>
	<Purpose>Clean Values from RSPprocessing Table</Purpose>
	<Description></Description>
	<Dependencies>
		<Object Type="Table" Schema="dbo" Name="RSPprocessing" VersionCompare="" Version=""/>
	</Dependencies>
	<Parameters>
		<Parameter Type="" Name="" Desc=""/>
	</Parameters>
	<Permissions>
		<Perm Type="" Priv="" To="" With=""/>
	</Permissions>
</CommentHeader>
*****************************************************************************/
AS
SELECT		REPLACE(REPLACE([RSPApplicationList],'/p:ApplicationList=',''),'"','')		AS [Application]
		,REPLACE(REPLACE(Substring([RSPfilename],7,len([RSPfilename])-10)
		  ,REPLACE(REPLACE([RSPApplicationList],'/p:ApplicationList=','')
		  ,'"',''),''),'_','')								AS [Branch]
		,REPLACE([RSPversion],'/p:Version=','')						AS [Version]
		,REPLACE([RSPMajorversion],'/p:MajorVersion=','')				AS [Version_Major]
		,REPLACE([RSPMinorversion],'/p:MinorVersion=','')				AS [Version_Minor]
		,RIGHT([RSPBuildnum],CHARINDEX('_',REVERSE([RSPBuildnum]))-1)			AS [Build]
		,[CreateDate]
		,[InWorkDate]
		,[CompletedDate]
FROM		[dbo].[RSPprocessing]
GO



