USE [DEPLcontrol]
GO
/****** Object:  UserDefinedFunction [dbo].[ISOWeek]    Script Date: 10/4/2013 11:02:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ISOWeek] 
( 
    @dt SMALLDATETIME 
) 
RETURNS TINYINT 
AS 
BEGIN 
    DECLARE @ISOweek TINYINT 
 
    SET @ISOweek = DATEPART(WEEK,@dt)+1 
        -DATEPART(WEEK,RTRIM(YEAR(@dt))+'0104') 
 
    IF @ISOweek = 0 
    BEGIN 
        SET @ISOweek = dbo.ISOweek 
        ( 
            RTRIM(YEAR(@dt)-1)+'12'+RTRIM(24+DAY(@dt)) 
        ) + 1 
    END 
 
    IF MONTH(@dt) = 12 AND DAY(@dt)-DATEPART(DW,@dt) >= 28 
    BEGIN 
        SET @ISOweek=1 
    END 
 
    RETURN(@ISOweek) 
END 

GO
