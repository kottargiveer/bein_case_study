CREATE OR REPLACE VIEW `project-6e19992f-9af5-4761-8e9.bq_gld_bein.vw_ott_kpi_daily` AS
SELECT
  snapshot_date,
  DATE_TRUNC(snapshot_date, WEEK(MONDAY)) AS week_start,
  DATE_TRUNC(snapshot_date, MONTH) AS month_start,
  DATE_TRUNC(snapshot_date, QUARTER) AS quarter_start,
  opco_code,
  additions,
  unique_additions,
  closing_subscriptions,
  unique_closing_subscribers,
  LAG(closing_subscriptions) OVER (PARTITION BY opco_code ORDER BY snapshot_date) AS opening_subscriptions,
  LAG(unique_closing_subscribers) OVER (PARTITION BY opco_code ORDER BY snapshot_date) AS unique_opening_subscribers,
  subscription_churn,
  subscriber_churn,
  winback_subscriptions AS winback_subscription,
  active_subscribers,
  active_subscriptions,
  unique_viewers_1d AS unique_viewers,
  minutes_of_usage_1d AS minutes_of_usage,
  avg_viewing_time_1d AS average_viewing_time,
  new_subscriptions,
  reacquisition_subscriptions,
  renewal_subscriptions,
  paying_subscriptions,
  grace_subscriptions,
  unique_viewers_7d,
  unique_viewers_30d,
  minutes_of_usage_7d,
  minutes_of_usage_30d,
  avg_viewing_time_7d,
  avg_viewing_time_30d,
  closing_subscriptions - (
    LAG(closing_subscriptions) OVER (PARTITION BY opco_code ORDER BY snapshot_date)
    + additions - subscription_churn
  ) AS roll_forward_variance
FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.ott_kpi_daily`
WHERE snapshot_date IS NOT NULL;
