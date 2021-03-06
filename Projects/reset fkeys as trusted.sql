SELECT object_name(parent_object_id) As TableName, * 
FROM sys.foreign_keys 
WHERE IS_NOT_TRUSTED = 1
ORDER BY TableName, [name]
GO

ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT Individual_iJobTitleCategoryJobTitleRelID_fk
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT Individual_iOrgTypeCategoryOrgTypeRelID_fk
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT Individual_vchEmailLanguageCode_fk
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualBillTo_FK
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualCountry_FK
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualMailTo_FK
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualOffice_FK
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualOrigSystem_FK
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualShipTo_FK
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualStatus_FK
ALTER TABLE [Individual] WITH CHECK CHECK CONSTRAINT IndividualType_FK
GO

UPDATE STATISTICS [Individual] WITH FULLSCAN
GO





DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS
GO
exec sp_msforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all'
GO
exec sp_msforeachtable 'UPDATE STATISTICS ? WITH FULLSCAN'
GO


