USE msdb;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'IndexMaintenanceNightly')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'IndexMaintenanceNightly', @delete_unused_schedule = 1;
END;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'TriggerNightlyEtl')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'TriggerNightlyEtl', @delete_unused_schedule = 1;
END;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = N'EveryNightAt0100')
BEGIN
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'EveryNightAt0100', @force_delete = 1;
END;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = N'EveryNightAt0130')
BEGIN
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'EveryNightAt0130', @force_delete = 1;
END;
GO

DECLARE @jobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'IndexMaintenanceNightly',
    @enabled = 1,
    @description = N'Rebuilds or reorganizes fragmented indexes for the TailwindOLTP sample workload.',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @jobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @jobId,
    @step_name = N'Reorganize or rebuild TailwindOLTP indexes',
    @subsystem = N'TSQL',
    @database_name = N'TailwindOLTP',
    @command = N'
SET NOCOUNT ON;
DECLARE @sql nvarchar(max) = N'''';

SELECT @sql = STRING_AGG(CONVERT(nvarchar(max),
    CASE
        WHEN avg_fragmentation_in_percent >= 30
            THEN N''ALTER INDEX '' + QUOTENAME(i.name) + N'' ON '' + QUOTENAME(s.name) + N''.'' + QUOTENAME(o.name) + N'' REBUILD;''
        WHEN avg_fragmentation_in_percent >= 10
            THEN N''ALTER INDEX '' + QUOTENAME(i.name) + N'' ON '' + QUOTENAME(s.name) + N''.'' + QUOTENAME(o.name) + N'' REORGANIZE;''
    END), CHAR(10))
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') AS ips
INNER JOIN sys.indexes AS i
    ON i.object_id = ips.object_id
   AND i.index_id = ips.index_id
INNER JOIN sys.objects AS o
    ON o.object_id = i.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE ips.page_count >= 16
  AND ips.avg_fragmentation_in_percent >= 10
  AND i.name IS NOT NULL;

IF @sql IS NOT NULL AND LEN(@sql) > 0
BEGIN
    EXEC sys.sp_executesql @sql;
END;',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'EveryNightAt0100',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 010000;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @jobId,
    @schedule_name = N'EveryNightAt0100';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @jobId,
    @server_name = N'(LOCAL)';
GO

DECLARE @jobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'TriggerNightlyEtl',
    @enabled = 1,
    @description = N'Runs the Tailwind SSIS package and records a lightweight SQL audit step.',
    @category_name = N'Data Collector',
    @owner_login_name = N'sa',
    @job_id = @jobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @jobId,
    @step_name = N'Run TailwindNightlyEtl DTSX from file system',
    @subsystem = N'SSIS',
    @command = N'/FILE "C:\Tailwind\ssis\TailwindNightlyEtl.dtsx" /CHECKPOINTING OFF /REPORTING E',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 3;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @jobId,
    @step_name = N'Run SQL audit fallback',
    @subsystem = N'TSQL',
    @database_name = N'TailwindOLTP',
    @command = N'EXEC dbo.usp_RunNightlyEtl;',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'EveryNightAt0130',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 013000;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @jobId,
    @schedule_name = N'EveryNightAt0130';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @jobId,
    @server_name = N'(LOCAL)';
GO
