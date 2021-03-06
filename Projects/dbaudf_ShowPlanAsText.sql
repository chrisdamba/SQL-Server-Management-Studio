USE [dbaperf]
GO
CREATE Function [dbo].[dbaudf_ShowPlanAsText]
(@doc xml)
returns nVarChar(max)
AS
Begin

DECLARE @hdoc int

DECLARE @nodenestlist TABLE (id INT, nestLevel INT,lastChild INT,spacer nvarchar(2000))
DECLARE @linelocation TABLE (columnNumber INT)
DECLARE	@plan TABLE 
	(
	[id] [bigint] NULL,
	[parentid] [bigint] NULL,
	[nodetype] [int] NULL,
	[localname] [nvarchar](4000) NULL,
	[prefix] [nvarchar](4000) NULL,
	[namespaceuri] [nvarchar](4000) NULL,
	[datatype] [nvarchar](4000) NULL,
	[prev] [bigint] NULL,
	[text] nvarchar(max) NULL
	)

--Create an internal representation of the XML document.
EXEC sp_xml_preparedocument @hdoc OUTPUT, @doc

INSERT INTO	@Plan
SELECT		* 
FROM		OPENXML (@hdoc, '/')

-- Remove the internal representation.
exec sp_xml_removedocument @hdoc

DECLARE @id			INT	
	,@parentid		INT
	,@nodetype		INT
	,@localname		nVarChar(255)
	,@prefix		nVarChar(50)
	,@namespaceuri		nVarChar(255)
	,@datatype		nVarChar(50)
	,@prev			INT
	,@text			nVarChar(max)
	,@nestLevel		INT
	,@OutputString		nVarChar(max)
	,@nodeindent		int
	,@LastChild		Int
	,@lastSpacer		nVarChar(2000)
	,@nextSpacer		nVarChar(2000)
	,@parentsLastChild	INT
	,@MaxGroupLength	INT

DECLARE	@Char_Space		nChar(1)
	,@Char_Vert		nChar(1)
	,@Char_Horiz		nChar(1)
	,@Char_Corner_TL	nChar(1)
	,@Char_Corner_TR	nChar(1)
	,@Char_Corner_BL	nChar(1)
	,@Char_Corner_BR	nChar(1)
	,@Char_T_L		nChar(1)
	,@Char_T_R		nChar(1)
	,@Char_T_T		nChar(1)
	,@Char_T_B		nChar(1)
		

SELECT	@Char_Space		= NCHAR([dbaadmin].[dbo].[HexToInt] ('00A0'))
	,@Char_Vert		= NCHAR([dbaadmin].[dbo].[HexToInt] ('2502'))
	,@Char_Horiz		= NCHAR([dbaadmin].[dbo].[HexToInt] ('2500'))
	,@Char_Corner_TL	= NCHAR([dbaadmin].[dbo].[HexToInt] ('2518'))
	,@Char_Corner_TR	= NCHAR([dbaadmin].[dbo].[HexToInt] ('2514'))
	,@Char_Corner_BL	= NCHAR([dbaadmin].[dbo].[HexToInt] ('2510'))
	,@Char_Corner_BR	= NCHAR([dbaadmin].[dbo].[HexToInt] ('250C'))
	,@Char_T_L		= NCHAR([dbaadmin].[dbo].[HexToInt] ('2524'))
	,@Char_T_R		= NCHAR([dbaadmin].[dbo].[HexToInt] ('251C'))
	,@Char_T_T		= NCHAR([dbaadmin].[dbo].[HexToInt] ('2534'))
	,@Char_T_B		= NCHAR([dbaadmin].[dbo].[HexToInt] ('252C'))

			
SET @PlanOutput = N''	
DECLARE test_cursor CURSOR
FOR
SELECT * FROM @Plan
OPEN test_cursor
FETCH NEXT FROM test_cursor INTO @id,@parentid,@nodetype,@localname,@prefix,@namespaceuri,@datatype,@prev,@text
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		SELECT	@LastChild		= MAX(id) FROM @Plan WHERE parentid =  @id
		SELECT	@nestLevel		= COALESCE(nestlevel,-1) +1
			,@lastSpacer		= COALESCE(spacer,N'')
			,@parentsLastChild	= COALESCE(lastChild,0)
		FROM	@nodenestlist 
		WHERE	id = @parentid
		
		IF	@nodetype = 2 
			SET @nextSpacer = COALESCE(@lastSpacer,N'') + @Char_Space+CASE WHEN @ID < @parentsLastChild THEN @Char_T_R ELSE @Char_Corner_TR END+@Char_Horiz+@Char_Horiz
		ELSE
		BEGIN
			If	@id < @parentsLastChild
				SET @nextSpacer = COALESCE(@lastSpacer,N'') + @Char_Space+@Char_Vert+@Char_Space+@Char_Space  --N' ▕  '
			ELSE
				SET @nextSpacer = COALESCE(@lastSpacer,N'') + @Char_Space+@Char_Space+@Char_Space+@Char_Space --N'    '
		END
		
		INSERT INTO	@nodenestlist 
				(id,nestLevel,lastChild,spacer) 
		Values		(@id,@nestLevel,@LastChild,@nextSpacer)
		
		If		@nodetype = 1 
		BEGIN
			If @nestLevel > 0
			SET	@lastSpacer	= COALESCE(@lastSpacer,N'') + @Char_Space+CASE WHEN @ID < @parentsLastChild THEN @Char_T_R ELSE @Char_Corner_TR END+@Char_Horiz+@Char_Horiz
			SET	@OutputString	= REPLACE(REPLACE(REPLACE(@lastSpacer,@Char_Corner_TR,@Char_Vert),@Char_T_R,@Char_Vert),@Char_Horiz,@Char_Space) + @Char_Corner_BR +REPLICATE(@Char_Horiz,LEN(COALESCE(@localname,N'')))+@Char_Corner_BL+ CHAR(10)
						+ @lastSpacer + @Char_T_L + COALESCE(@localname,N'')+@Char_Vert+ CHAR(10)
						+ REPLACE(REPLACE(REPLACE(@lastSpacer,@Char_Corner_TR,@Char_Space),@Char_T_R,@Char_Vert),@Char_Horiz,@Char_Space) + @Char_Corner_TR +REPLICATE(@Char_Horiz,LEN(COALESCE(@localname,N'')))+@Char_Corner_TL
			SET	@PlanOutput	= @PlanOutput + COALESCE(@OutputString,'') + CHAR(13) + CHAR(10)
		END
		
		If		@nodetype = 2 
		BEGIN
			If @nestLevel > 0
			SET	@lastSpacer	= COALESCE(@lastSpacer,N'') + @Char_Space+CASE WHEN @ID < @parentsLastChild THEN @Char_T_R ELSE @Char_Corner_TR END+@Char_Horiz+@Char_Horiz
			SELECT	@MaxGroupLength	= MAX(LEN(localname)) FROM @Plan WHERE parentid =  @parentid and nodeType = 2
			SET	@OutputString	= @lastSpacer + LEFT(COALESCE(@localname,N'')+REPLICATE(@Char_Space,@MaxGroupLength),@MaxGroupLength) + @Char_Space+N':'+@Char_Space 
		END

		If		@nodetype = 3 
		BEGIN
			SET	@lastSpacer	= REPLACE(REPLACE(REPLACE(COALESCE(@lastSpacer,N''),@Char_Corner_TR,@Char_Space),@Char_Horiz,@Char_Space),@Char_T_R,@Char_Vert) + REPLICATE(@Char_Space,@MaxGroupLength+2)
			SET	@OutputString	= @OutputString + REPLACE(COALESCE(@text,''),CHAR(10),CHAR(10)+ @lastSpacer) 
			SET	@PlanOutput	= @PlanOutput + COALESCE(@OutputString,N'') + CHAR(13) + CHAR(10)
		END
		--PRINT	@OutputString
	END
	FETCH NEXT FROM test_cursor INTO @id,@parentid,@nodetype,@localname,@prefix,@namespaceuri,@datatype,@prev,@text
END

CLOSE test_cursor
DEALLOCATE test_cursor

IF @PrintOutput = 1
BEGIN
	DECLARE @Marker1 bigint, @Marker2 bigint
	SET	@Marker1 = 0

	PrintMore:
		--EXPECTING TO BREAK ON CR&LF

	SET	@Marker2 = CHARINDEX(CHAR(13),@PlanOutput,@Marker1 + 3500)
	IF	@Marker2 = 0
		SET @Marker2 = LEN(@PlanOutput)

	SET	@OutputString = SUBSTRING(@PlanOutput,@Marker1,@Marker2-@Marker1)
	PRINT	@OutputString

	SET	@Marker1 = @Marker2 + 2 -- USE +2 instead of + 1 to STRIP CRLF

	If	@Marker2 < LEN(@PlanOutput)
		GOTO PrintMore
END	
IF @SelectOutput = 1
	SELECT @PlanOutput AS [PlanOutput]
GO