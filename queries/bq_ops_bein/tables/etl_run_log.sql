CREATE TABLE IF NOT EXISTS `project-6e19992f-9af5-4761-8e9.bq_ops_bein.etl_run_log` (
  run_ts TIMESTAMP,
  proc_name STRING,
  ds DATE,
  rows_affected INT64,
  status STRING,
  message STRING,
  duration_sec FLOAT64
)
PARTITION BY DATE(run_ts);
