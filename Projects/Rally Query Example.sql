:Connect SEAPSQLBOB
USE RallyRpt

/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [RallyStoryId]
      ,[StoryTitle]
      ,[StorySize]
      ,[StoryCreatedDate]
      ,[TeamName]
      ,[RallyNotes]
      ,[BacklogTotalWorkingDays]
      ,[DefinedTotalWorkingDays]
      ,[InProgressTotalWorkingDays]
      ,[CompletedTotalWorkingDays]
      ,[AcceptedTotalWorkingDays]
      ,[DeliveredTotalWorkingDays]
  FROM [RallyRpt].[dbo].[vw_AcceptedStories]


  WHERE [TeamName] Like '%TS MS SQL Team%'

  GO