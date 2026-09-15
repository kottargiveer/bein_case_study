CREATE TABLE IF NOT EXISTS `project-6e19992f-9af5-4761-8e9.bq_slv_bein.ott_kpi_daily` (
  opco_code STRING NOT NULL,
  additions INT64,
  unique_additions INT64,
  new_subscriptions INT64,
  winback_subscriptions INT64,
  reacquisition_subscriptions INT64,
  renewal_subscriptions INT64,
  subscription_churn INT64,
  subscriber_churn INT64,
  closing_subscriptions INT64,
  unique_closing_subscribers INT64,
  paying_subscriptions INT64,
  grace_subscriptions INT64,
  active_subscriptions INT64,
  active_subscribers INT64,
  unique_viewers_1d INT64,
  unique_viewers_7d INT64,
  unique_viewers_30d INT64,
  minutes_of_usage_1d FLOAT64,
  minutes_of_usage_7d FLOAT64,
  minutes_of_usage_30d FLOAT64,
  avg_viewing_time_1d FLOAT64,
  avg_viewing_time_7d FLOAT64,
  avg_viewing_time_30d FLOAT64,
  snapshot_date DATE NOT NULL
)
PARTITION BY snapshot_date
CLUSTER BY opco_code
OPTIONS (require_partition_filter = FALSE);
