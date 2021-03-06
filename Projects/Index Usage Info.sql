SELECT COALESCE(T1.[database_id],T1.[database_id]) [database_id]
      ,COALESCE(T1.[object_id],T1.[object_id]) [object_id]
      ,COALESCE(T1.[index_id],T1.[index_id]) [index_id]
      ,T1.[user_seeks]
      +T1.[user_scans]
      +T1.[user_lookups] AS [reads]
      ,T1.[user_updates] as [Writes]
      ,(([user_seeks]+[user_scans]+[user_lookups])*100.00)/([user_seeks]+[user_scans]+[user_lookups]+[user_updates]) AS ReadPct
      ,(([user_updates])*100.00)/([user_seeks]+[user_scans]+[user_lookups]+[user_updates]) AS WritePct
      ,T2.row_lock_count
      ,T2.page_lock_count
      ,T2.leaf_allocation_count 
      +T2.nonleaf_allocation_count AS [Splits]
      
  FROM [WCDS].[sys].[dm_db_index_usage_stats] T1
  LEFT JOIN [WCDS].[sys].[dm_db_index_operational_stats](DB_ID(),NULL,NULL,NULL)T2
  ON T1.[database_id]=T2.[database_id]
  AND T1.[object_id]=T2.[object_id]
  AND T1.[index_id]=T2.[index_id]
  WHERE ([user_seeks]+[user_scans]+[user_lookups]+[user_updates]) > 0
  AND T1.Database_id = DB_ID()
ORDER BY 10 desc

