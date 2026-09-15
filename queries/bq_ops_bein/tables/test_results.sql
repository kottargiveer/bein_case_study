CREATE TABLE IF NOT EXISTS `project-6e19992f-9af5-4761-8e9.bq_ops_bein.test_results` (
  test_run_ts TIMESTAMP,
  test_id STRING,
  test_name STRING,
  severity STRING,
  status STRING,
  failed_rows INT64,
  expected STRING,
  actual STRING,
  detail STRING
)
PARTITION BY DATE(test_run_ts);
