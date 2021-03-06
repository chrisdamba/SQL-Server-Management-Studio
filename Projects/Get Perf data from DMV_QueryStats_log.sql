


SELECT		MONTH([rundate]) [Month]
		,DATEPART(week,[rundate]) [Week]
		,DAY([rundate]) [Day]
		,DATENAME(weekday,[rundate]) [WeekDay]
		,DATEPART(hour,[rundate]) [Hour]
		,SUM([delta_worker_time]) [worker_time]
		,SUM([delta_elapsed_time]) [elapsed_time]
		,SUM([delta_physical_reads]) [physical_reads]
		,SUM([delta_logical_reads]) [logical_reads]
		,SUM([delta_logical_writes]) [logical_writes]
		,SUM([execution_count]) [execution_count]
FROM		[dbaperf].[dbo].[DMV_QueryStats_log]
--WHERE		[rundate] > Getdate()-130
GROUP BY	MONTH([rundate])
		,DATEPART(week,[rundate])
		,DAY([rundate])
		,DATENAME(weekday,[rundate])
		,DATEPART(hour,[rundate]) 
--WITH ROLLUP
ORDER BY	1,2,3,4,5


