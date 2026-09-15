CREATE TABLE IF NOT EXISTS `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily` (
  opco_code STRING NOT NULL,
  subscription_key STRING NOT NULL,
  subscriber_id STRING NOT NULL,
  subscription_name STRING,
  subscription_id STRING,
  is_paying_today INT64,
  is_viewer_today INT64,
  minutes_of_usage FLOAT64,
  subscription_start_date DATE,
  paid_through_date DATE,
  snapshot_date DATE NOT NULL
)
PARTITION BY snapshot_date
CLUSTER BY opco_code, subscription_key
OPTIONS (require_partition_filter = TRUE);
