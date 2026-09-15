CREATE OR REPLACE PROCEDURE `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_backfill_ott_kpi_daily`(
  IN start_date DATE,
  IN end_date DATE)
BEGIN
  DECLARE v_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_rows INT64 DEFAULT 0;

  BEGIN
    BEGIN TRANSACTION;

    DELETE FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.ott_kpi_daily`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date;

    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_slv_bein.ott_kpi_daily` (
      opco_code, additions, unique_additions, new_subscriptions, winback_subscriptions,
      reacquisition_subscriptions, renewal_subscriptions, subscription_churn, subscriber_churn,
      closing_subscriptions, unique_closing_subscribers, paying_subscriptions, grace_subscriptions,
      active_subscriptions, active_subscribers, unique_viewers_1d, unique_viewers_7d, unique_viewers_30d,
      minutes_of_usage_1d, minutes_of_usage_7d, minutes_of_usage_30d,
      avg_viewing_time_1d, avg_viewing_time_7d, avg_viewing_time_30d, snapshot_date)
    WITH snap AS (
      SELECT *
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
      WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
    ),
    subscriber_day AS (
      SELECT
        opco_code,
        snapshot_date,
        subscriber_id,
        MAX(is_active_subscription) AS has_active,
        MAX(is_addition) AS has_addition,
        MAX(is_churn_event) AS has_churn_event,
        MAX(is_viewer_1d) AS viewed_1d,
        MAX(is_viewer_7d) AS viewed_7d,
        MAX(is_viewer_30d) AS viewed_30d
      FROM snap
      GROUP BY 1,2,3
    ),
    m_sub AS (
      SELECT
        opco_code,
        snapshot_date,
        SUM(is_addition) AS additions,
        SUM(is_new_subscription) AS new_subscriptions,
        SUM(is_winback_event) AS winback_subscriptions,
        SUM(is_reacquisition_event) AS reacquisition_subscriptions,
        SUM(is_renewal_event) AS renewal_subscriptions,
        SUM(is_churn_event) AS subscription_churn,
        SUM(is_paying) AS paying_subscriptions,
        SUM(is_in_grace) AS grace_subscriptions,
        SUM(is_active_subscription) AS active_subscriptions,
        SUM(mou_1d) AS mou_1d,
        SUM(mou_7d) AS mou_7d,
        SUM(mou_30d) AS mou_30d
      FROM snap
      GROUP BY 1,2
    ),
    m_subr AS (
      SELECT
        opco_code,
        snapshot_date,
        COUNT(DISTINCT IF(has_addition = 1, subscriber_id, NULL)) AS unique_additions,
        COUNT(DISTINCT IF(has_churn_event = 1 AND has_active = 0, subscriber_id, NULL)) AS subscriber_churn,
        COUNT(DISTINCT IF(has_active = 1, subscriber_id, NULL)) AS active_subscribers,
        COUNT(DISTINCT IF(viewed_1d = 1, subscriber_id, NULL)) AS unique_viewers_1d,
        COUNT(DISTINCT IF(viewed_7d = 1, subscriber_id, NULL)) AS unique_viewers_7d,
        COUNT(DISTINCT IF(viewed_30d = 1, subscriber_id, NULL)) AS unique_viewers_30d
      FROM subscriber_day
      GROUP BY 1,2
    )
    SELECT
      s.opco_code,
      s.additions,
      u.unique_additions,
      s.new_subscriptions,
      s.winback_subscriptions,
      s.reacquisition_subscriptions,
      s.renewal_subscriptions,
      s.subscription_churn,
      u.subscriber_churn,
      s.active_subscriptions,
      u.active_subscribers,
      s.paying_subscriptions,
      s.grace_subscriptions,
      s.active_subscriptions,
      u.active_subscribers,
      u.unique_viewers_1d,
      u.unique_viewers_7d,
      u.unique_viewers_30d,
      s.mou_1d,
      s.mou_7d,
      s.mou_30d,
      SAFE_DIVIDE(s.mou_1d, u.unique_viewers_1d),
      SAFE_DIVIDE(s.mou_7d, u.unique_viewers_7d),
      SAFE_DIVIDE(s.mou_30d, u.unique_viewers_30d),
      s.snapshot_date
    FROM m_sub s
    JOIN m_subr u USING (opco_code, snapshot_date);

    SET v_rows = @@row_count;
    COMMIT TRANSACTION;

    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_ops_bein.etl_run_log`
    VALUES (v_start, 'sp_backfill_ott_kpi_daily', end_date, v_rows, 'SUCCESS',
            FORMAT('range %t..%t', start_date, end_date),
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), v_start, MILLISECOND) / 1000);
  EXCEPTION WHEN ERROR THEN
    ROLLBACK TRANSACTION;
    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_ops_bein.etl_run_log`
    VALUES (v_start, 'sp_backfill_ott_kpi_daily', end_date, 0, 'FAILED', @@error.message,
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), v_start, MILLISECOND) / 1000);
    RAISE USING MESSAGE = FORMAT('sp_backfill_ott_kpi_daily failed: %s', @@error.message);
  END;
END;
