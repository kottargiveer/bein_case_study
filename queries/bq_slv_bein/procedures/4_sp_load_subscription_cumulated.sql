CREATE OR REPLACE PROCEDURE `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_load_subscription_cumulated`(IN ds DATE)
BEGIN
  DECLARE yesterday_ds DATE DEFAULT DATE_SUB(ds, INTERVAL 1 DAY);
  DECLARE array_size INT64 DEFAULT 90;
  DECLARE grace_days INT64 DEFAULT 30;
  DECLARE winback_days INT64 DEFAULT 90;
  DECLARE retention_days INT64 DEFAULT 180;
  DECLARE v_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_rows INT64 DEFAULT 0;
  DECLARE has_snapshot BOOL DEFAULT (
    SELECT COUNT(*) > 0
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily`
    WHERE snapshot_date IS NOT NULL AND snapshot_date = ds
  );

  BEGIN
    BEGIN TRANSACTION;

    DELETE FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date = ds;

    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated` (
      opco_code, subscription_key, subscriber_id, subscription_name, subscription_id,
      activity_array, viewer_array, mou_array,
      first_active_date, last_active_date, paid_through_date,
      churn_date, last_churn_date, last_winback_date,
      is_paying, is_in_grace, is_active_subscription, is_churned, is_in_winback_window,
      is_addition, is_new_subscription, is_winback_event, is_reacquisition_event,
      is_churn_event, is_renewal_event,
      days_since_last_active, days_since_churn, tenure_days,
      is_viewer_1d, is_viewer_7d, is_viewer_30d, is_viewer_90d,
      active_days_7d, active_days_30d, active_days_90d,
      mou_1d, mou_7d, mou_30d, mou_90d, snapshot_date)
    WITH
    yesterday AS (
      SELECT *
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
      WHERE snapshot_date IS NOT NULL AND snapshot_date = yesterday_ds
    ),
    today AS (
      SELECT *
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily`
      WHERE snapshot_date IS NOT NULL AND snapshot_date = ds
    ),
    combined AS (
      SELECT
        COALESCE(t.opco_code, y.opco_code) AS opco_code,
        COALESCE(t.subscription_key, y.subscription_key) AS subscription_key,
        COALESCE(t.subscriber_id, y.subscriber_id) AS subscriber_id,
        COALESCE(t.subscription_name, y.subscription_name) AS subscription_name,
        COALESCE(t.subscription_id, y.subscription_id) AS subscription_id,
        IF(has_snapshot, COALESCE(t.is_paying_today, 0), COALESCE(y.activity_array[SAFE_OFFSET(0)], 0)) AS is_paying,
        IF(has_snapshot, COALESCE(t.is_viewer_today, 0), 0) AS is_viewer_today,
        IF(has_snapshot, COALESCE(t.minutes_of_usage, 0.0), 0.0) AS mou_today,

        CASE
          WHEN y.activity_array IS NULL THEN [IF(has_snapshot, COALESCE(t.is_paying_today, 0), 0)]
          WHEN ARRAY_LENGTH(y.activity_array) < array_size
            THEN ARRAY_CONCAT([IF(has_snapshot, COALESCE(t.is_paying_today, 0), COALESCE(y.activity_array[SAFE_OFFSET(0)], 0))], y.activity_array)
          ELSE ARRAY_CONCAT([IF(has_snapshot, COALESCE(t.is_paying_today, 0), COALESCE(y.activity_array[SAFE_OFFSET(0)], 0))],
                 ARRAY(SELECT v FROM UNNEST(y.activity_array) v WITH OFFSET o WHERE o < array_size - 1 ORDER BY o))
        END AS activity_array,

        CASE
          WHEN y.viewer_array IS NULL THEN [IF(has_snapshot, COALESCE(t.is_viewer_today, 0), 0)]
          WHEN ARRAY_LENGTH(y.viewer_array) < array_size
            THEN ARRAY_CONCAT([IF(has_snapshot, COALESCE(t.is_viewer_today, 0), 0)], y.viewer_array)
          ELSE ARRAY_CONCAT([IF(has_snapshot, COALESCE(t.is_viewer_today, 0), 0)],
                 ARRAY(SELECT v FROM UNNEST(y.viewer_array) v WITH OFFSET o WHERE o < array_size - 1 ORDER BY o))
        END AS viewer_array,

        CASE
          WHEN y.mou_array IS NULL THEN [IF(has_snapshot, COALESCE(t.minutes_of_usage, 0.0), 0.0)]
          WHEN ARRAY_LENGTH(y.mou_array) < array_size
            THEN ARRAY_CONCAT([IF(has_snapshot, COALESCE(t.minutes_of_usage, 0.0), 0.0)], y.mou_array)
          ELSE ARRAY_CONCAT([IF(has_snapshot, COALESCE(t.minutes_of_usage, 0.0), 0.0)],
                 ARRAY(SELECT v FROM UNNEST(y.mou_array) v WITH OFFSET o WHERE o < array_size - 1 ORDER BY o))
        END AS mou_array,

        y.first_active_date AS y_first_active_date,
        y.last_active_date AS y_last_active_date,
        y.paid_through_date AS y_paid_through_date,
        y.churn_date AS y_churn_date,
        y.last_churn_date AS y_last_churn_date,
        y.last_winback_date AS y_last_winback_date,
        y.subscription_id AS y_subscription_id,
        COALESCE(y.is_churned, 0) AS y_is_churned,
        COALESCE(y.is_active_subscription, 0) AS y_is_active_subscription,
        t.paid_through_date AS t_paid_through_date,
        ds AS snapshot_date
      FROM yesterday y
      FULL OUTER JOIN today t ON y.subscription_key = t.subscription_key
    ),
    state AS (
      SELECT c.*,
        IF(is_paying = 1, snapshot_date, y_last_active_date) AS last_active_date,
        COALESCE(y_first_active_date, IF(is_paying = 1, snapshot_date, NULL)) AS first_active_date,
        COALESCE(t_paid_through_date, y_paid_through_date) AS paid_through_date,
        DATE_DIFF(snapshot_date, IF(is_paying = 1, snapshot_date, y_last_active_date), DAY) AS days_since_last_active,
        DATE_DIFF(snapshot_date, y_churn_date, DAY) AS days_since_open_churn
      FROM combined c
    ),
    flags AS (
      SELECT s.*,
        IF(is_paying = 0 AND last_active_date IS NOT NULL AND days_since_last_active BETWEEN 1 AND grace_days, 1, 0) AS is_in_grace,
        IF(is_paying = 0 AND last_active_date IS NOT NULL AND days_since_last_active > grace_days, 1, 0) AS is_churned,
        IF(is_paying = 0 AND last_active_date IS NOT NULL AND days_since_last_active > grace_days AND y_is_churned = 0, 1, 0) AS is_churn_event,
        IF(is_paying = 1 AND y_is_churned = 1 AND days_since_open_churn <= winback_days, 1, 0) AS is_winback_event,
        IF(is_paying = 1 AND y_is_churned = 1 AND days_since_open_churn > winback_days, 1, 0) AS is_reacquisition_event,
        IF(is_paying = 1 AND y_first_active_date IS NULL, 1, 0) AS is_new_subscription,
        IF(is_paying = 1 AND y_is_active_subscription = 0, 1, 0) AS is_addition,
        IF(is_paying = 1 AND y_is_active_subscription = 1 AND y_subscription_id IS NOT NULL AND subscription_id <> y_subscription_id, 1, 0) AS is_renewal_event
      FROM state s
    )
    SELECT
      opco_code, subscription_key, subscriber_id, subscription_name, subscription_id,
      activity_array, viewer_array, mou_array,
      first_active_date, last_active_date, paid_through_date,
      CASE
        WHEN is_churn_event = 1 THEN snapshot_date
        WHEN is_paying = 1 THEN NULL
        ELSE y_churn_date
      END AS churn_date,
      COALESCE(IF(is_churn_event = 1, snapshot_date, NULL), y_last_churn_date) AS last_churn_date,
      COALESCE(IF(is_winback_event = 1, snapshot_date, NULL), y_last_winback_date) AS last_winback_date,
      is_paying,
      is_in_grace,
      GREATEST(is_paying, is_in_grace) AS is_active_subscription,
      is_churned,
      IF(is_churned = 1 AND DATE_DIFF(snapshot_date, IF(is_churn_event = 1, snapshot_date, y_churn_date), DAY) <= winback_days, 1, 0) AS is_in_winback_window,
      is_addition,
      is_new_subscription,
      is_winback_event,
      is_reacquisition_event,
      is_churn_event,
      is_renewal_event,
      days_since_last_active,
      DATE_DIFF(snapshot_date, IF(is_churn_event = 1, snapshot_date, y_churn_date), DAY) AS days_since_churn,
      DATE_DIFF(snapshot_date, first_active_date, DAY) AS tenure_days,
      viewer_array[SAFE_OFFSET(0)],
      IF((SELECT SUM(v) FROM UNNEST(viewer_array) v WITH OFFSET o WHERE o < 7) > 0, 1, 0),
      IF((SELECT SUM(v) FROM UNNEST(viewer_array) v WITH OFFSET o WHERE o < 30) > 0, 1, 0),
      IF((SELECT SUM(v) FROM UNNEST(viewer_array) v) > 0, 1, 0),
      (SELECT SUM(v) FROM UNNEST(activity_array) v WITH OFFSET o WHERE o < 7),
      (SELECT SUM(v) FROM UNNEST(activity_array) v WITH OFFSET o WHERE o < 30),
      (SELECT SUM(v) FROM UNNEST(activity_array) v),
      mou_array[SAFE_OFFSET(0)],
      (SELECT SUM(v) FROM UNNEST(mou_array) v WITH OFFSET o WHERE o < 7),
      (SELECT SUM(v) FROM UNNEST(mou_array) v WITH OFFSET o WHERE o < 30),
      (SELECT SUM(v) FROM UNNEST(mou_array) v),
      snapshot_date
    FROM flags
    WHERE GREATEST(is_paying, is_in_grace) = 1 OR days_since_last_active <= retention_days;

    SET v_rows = @@row_count;
    COMMIT TRANSACTION;

    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_ops_bein.etl_run_log`
    VALUES (v_start, 'sp_load_subscription_cumulated', ds, v_rows, 'SUCCESS',
            IF(has_snapshot, NULL, 'FEED MISSING - state frozen for this date'),
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), v_start, MILLISECOND) / 1000);
  EXCEPTION WHEN ERROR THEN
    ROLLBACK TRANSACTION;
    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_ops_bein.etl_run_log`
    VALUES (v_start, 'sp_load_subscription_cumulated', ds, 0, 'FAILED', @@error.message,
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), v_start, MILLISECOND) / 1000);
    RAISE USING MESSAGE = FORMAT('sp_load_subscription_cumulated failed for %t : %s', ds, @@error.message);
  END;
END;
