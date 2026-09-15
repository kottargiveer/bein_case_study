CREATE OR REPLACE VIEW `project-6e19992f-9af5-4761-8e9.bq_gld_bein.vw_ott_kpi_monthly` AS
WITH base AS (
  SELECT *
  FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
  WHERE snapshot_date IS NOT NULL
),
subscriber_day AS (
  SELECT
    opco_code,
    snapshot_date,
    subscriber_id,
    MAX(is_active_subscription) AS has_active,
    MAX(is_addition) AS has_addition,
    MAX(is_churn_event) AS has_churn_event,
    MAX(is_winback_event) AS has_winback,
    SUM(mou_1d) AS mou
  FROM base
  GROUP BY 1,2,3
),
flows AS (
  SELECT
    opco_code,
    DATE_TRUNC(snapshot_date, MONTH) AS month_start,
    SUM(is_addition) AS additions,
    SUM(is_new_subscription) AS new_subscriptions,
    SUM(is_churn_event) AS subscription_churn,
    SUM(is_winback_event) AS winback_subscription,
    SUM(is_reacquisition_event) AS reacquisitions,
    SUM(is_renewal_event) AS renewals,
    SUM(mou_1d) AS minutes_of_usage
  FROM base
  GROUP BY 1,2
),
flows_subscriber AS (
  SELECT
    opco_code,
    DATE_TRUNC(snapshot_date, MONTH) AS month_start,
    COUNT(DISTINCT IF(has_addition = 1, subscriber_id, NULL)) AS unique_additions,
    COUNT(DISTINCT IF(has_churn_event = 1 AND has_active = 0, subscriber_id, NULL)) AS subscriber_churn,
    COUNT(DISTINCT IF(has_winback = 1, subscriber_id, NULL)) AS unique_winback_subscribers
  FROM subscriber_day
  GROUP BY 1,2
),
viewers AS (
  SELECT opco_code, month_start, COUNT(DISTINCT IF(month_mou >= 1.0, subscriber_id, NULL)) AS unique_viewers
  FROM (
    SELECT
      opco_code,
      DATE_TRUNC(snapshot_date, MONTH) AS month_start,
      subscriber_id,
      SUM(mou) AS month_mou
    FROM subscriber_day
    GROUP BY 1,2,3
  )
  GROUP BY 1,2
),
eom AS (
  SELECT
    opco_code,
    DATE_TRUNC(snapshot_date, MONTH) AS month_start,
    MAX(snapshot_date) AS eom_date
  FROM base
  GROUP BY 1,2
),
stocks AS (
  SELECT
    e.opco_code,
    e.month_start,
    e.eom_date,
    SUM(b.is_active_subscription) AS closing_subscriptions,
    SUM(b.is_paying) AS paying_subscriptions,
    SUM(b.is_in_grace) AS grace_subscriptions,
    COUNT(DISTINCT IF(b.is_active_subscription = 1, b.subscriber_id, NULL)) AS unique_closing_subscribers
  FROM eom e
  JOIN base b
    ON b.opco_code = e.opco_code AND b.snapshot_date = e.eom_date
  GROUP BY 1,2,3
)
SELECT
  f.opco_code,
  f.month_start,
  LAST_DAY(f.month_start, MONTH) AS month_end,
  s.eom_date AS as_of_date,
  f.additions AS additions,
  fs.unique_additions AS unique_additions,
  s.closing_subscriptions AS closing_subscriptions,
  s.unique_closing_subscribers AS unique_closing_subscribers,
  LAG(s.closing_subscriptions) OVER (PARTITION BY f.opco_code ORDER BY f.month_start) AS opening_subscriptions,
  LAG(s.unique_closing_subscribers) OVER (PARTITION BY f.opco_code ORDER BY f.month_start) AS unique_opening_subscribers,
  f.subscription_churn AS subscription_churn,
  fs.subscriber_churn AS subscriber_churn,
  f.winback_subscription AS winback_subscription,
  s.unique_closing_subscribers AS active_subscribers,
  s.closing_subscriptions AS active_subscriptions,
  v.unique_viewers AS unique_viewers,
  f.minutes_of_usage AS minutes_of_usage,
  SAFE_DIVIDE(f.minutes_of_usage, v.unique_viewers) AS average_viewing_time,
  f.new_subscriptions,
  f.reacquisitions,
  f.renewals,
  fs.unique_winback_subscribers,
  s.paying_subscriptions,
  s.grace_subscriptions,
  SAFE_DIVIDE(f.subscription_churn, LAG(s.closing_subscriptions) OVER (PARTITION BY f.opco_code ORDER BY f.month_start)) AS subscription_churn_rate,
  s.closing_subscriptions - (
    LAG(s.closing_subscriptions) OVER (PARTITION BY f.opco_code ORDER BY f.month_start)
    + f.additions - f.subscription_churn
  ) AS roll_forward_variance
FROM flows f
JOIN flows_subscriber fs USING (opco_code, month_start)
JOIN viewers v USING (opco_code, month_start)
JOIN stocks s USING (opco_code, month_start);
