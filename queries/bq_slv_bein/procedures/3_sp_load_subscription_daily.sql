CREATE OR REPLACE PROCEDURE `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_load_subscription_daily`(IN ds DATE)
BEGIN
  DECLARE v_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_rows INT64 DEFAULT 0;

  BEGIN
    BEGIN TRANSACTION;

    DELETE FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily`
    WHERE snapshot_date IS NOT NULL AND snapshot_date = ds;

    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily` (
      opco_code, subscription_key, subscriber_id, subscription_name, subscription_id,
      is_paying_today, is_viewer_today, minutes_of_usage,
      subscription_start_date, paid_through_date, snapshot_date)
    WITH src AS (
      SELECT
        CAST(opco_code AS STRING) AS opco_code,
        CAST(subscriber_id AS STRING) AS subscriber_id_str,
        CAST(subscription_name AS STRING) AS subscription_name,
        CAST(subscription_id AS STRING) AS subscription_id_str,
        subscription_start_date,
        subscription_end_date,
        COALESCE(minutes_of_usage, 0.0) AS minutes_of_usage
      FROM `project-6e19992f-9af5-4761-8e9.bq_brz_bein.subscription_snapshot_daily`
      WHERE snapshot_date IS NOT NULL
        AND snapshot_date = ds
        AND subscriber_id IS NOT NULL
        AND subscription_name IS NOT NULL
    )
    SELECT
      opco_code,
      CONCAT(opco_code, '|', subscriber_id_str, '|', subscription_name),
      subscriber_id_str,
      subscription_name,
      ARRAY_AGG(subscription_id_str ORDER BY subscription_start_date DESC, subscription_id_str DESC LIMIT 1)[OFFSET(0)],
      1,
      IF(SUM(minutes_of_usage) >= 1.0, 1, 0),
      SUM(minutes_of_usage),
      MIN(subscription_start_date),
      MAX(subscription_end_date),
      ds
    FROM src
    GROUP BY opco_code, subscriber_id_str, subscription_name;

    SET v_rows = @@row_count;
    COMMIT TRANSACTION;

    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_ops_bein.etl_run_log`
    VALUES (v_start, 'sp_load_subscription_daily', ds, v_rows,
            IF(v_rows = 0, 'SKIPPED', 'SUCCESS'),
            IF(v_rows = 0, 'No source rows (feed missing or genuine zero)', NULL),
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), v_start, MILLISECOND) / 1000);
  EXCEPTION WHEN ERROR THEN
    ROLLBACK TRANSACTION;
    INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_ops_bein.etl_run_log`
    VALUES (v_start, 'sp_load_subscription_daily', ds, 0, 'FAILED', @@error.message,
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), v_start, MILLISECOND) / 1000);
    RAISE USING MESSAGE = FORMAT('sp_load_subscription_daily failed for %t : %s', ds, @@error.message);
  END;
END;
