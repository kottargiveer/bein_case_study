CREATE TABLE IF NOT EXISTS `project-6e19992f-9af5-4761-8e9.bq_brz_bein.subscription_snapshot_daily` (
  opco_code STRING,
  subscriber_id STRING,
  subscription_name STRING,
  subscription_id STRING,
  subscription_start_date DATE,
  subscription_end_date DATE,
  minutes_of_usage FLOAT64,
  snapshot_date DATE NOT NULL
)
PARTITION BY snapshot_date
CLUSTER BY opco_code, subscriber_id, subscription_name;
