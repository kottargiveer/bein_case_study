CREATE OR REPLACE VIEW `project-6e19992f-9af5-4761-8e9.bq_gld_bein.vw_subscription_lifecycle_events` AS
SELECT
  snapshot_date AS event_date,
  opco_code,
  subscriber_id,
  subscription_key,
  subscription_id,
  CASE
    WHEN is_new_subscription = 1 THEN 'NEW'
    WHEN is_winback_event = 1 THEN 'WINBACK'
    WHEN is_reacquisition_event = 1 THEN 'REACQUISITION'
    WHEN is_churn_event = 1 THEN 'CHURN'
    WHEN is_renewal_event = 1 THEN 'RENEWAL'
  END AS event_type,
  last_active_date,
  churn_date,
  last_churn_date,
  last_winback_date,
  days_since_last_active,
  days_since_churn,
  tenure_days,
  mou_1d,
  mou_7d,
  mou_30d,
  active_days_30d
FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
WHERE snapshot_date IS NOT NULL
  AND (is_new_subscription + is_winback_event + is_reacquisition_event + is_churn_event + is_renewal_event) > 0;
