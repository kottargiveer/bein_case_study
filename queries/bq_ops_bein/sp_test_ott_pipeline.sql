CREATE OR REPLACE PROCEDURE `project-6e19992f-9af5-4761-8e9.bq_ops_bein.sp_test_ott_pipeline`(
  IN start_date DATE,
  IN end_date DATE)
BEGIN
  DECLARE t0 TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE fail_cnt INT64;

  DELETE FROM `project-6e19992f-9af5-4761-8e9.bq_ops_bein.test_results`
  WHERE DATE(test_run_ts) = CURRENT_DATE();

  INSERT INTO `project-6e19992f-9af5-4761-8e9.bq_ops_bein.test_results`
  WITH
  t01 AS (
    SELECT COUNT(*) AS bad
    FROM (
      SELECT snapshot_date, subscription_key
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily`
      WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
      GROUP BY 1,2 HAVING COUNT(*) > 1
    )
  ),
  t02 AS (
    SELECT COUNT(*) AS bad
    FROM (
      SELECT snapshot_date, subscription_key
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
      WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
      GROUP BY 1,2 HAVING COUNT(*) > 1
    )
  ),
  t03 AS (
    SELECT COUNT(*) AS bad
    FROM (
      SELECT COALESCE(s.snapshot_date, d.snapshot_date) AS sd
      FROM (
        SELECT snapshot_date,
               COUNT(DISTINCT CONCAT(CAST(opco_code AS STRING), '|', CAST(subscriber_id AS STRING), '|', subscription_name)) AS k,
               ROUND(SUM(COALESCE(minutes_of_usage, 0.0)), 4) AS m
        FROM `project-6e19992f-9af5-4761-8e9.bq_brz_bein.subscription_snapshot_daily`
        WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
          AND subscriber_id IS NOT NULL AND subscription_name IS NOT NULL
        GROUP BY 1
      ) s
      FULL OUTER JOIN (
        SELECT snapshot_date, COUNT(*) AS k, ROUND(SUM(minutes_of_usage), 4) AS m
        FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily`
        WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
        GROUP BY 1
      ) d ON s.snapshot_date = d.snapshot_date
      WHERE COALESCE(s.k, -1) <> COALESCE(d.k, -1)
         OR ABS(COALESCE(s.m, 0) - COALESCE(d.m, 0)) > 0.0001
    )
  ),
  t04 AS (
    SELECT COUNT(*) AS bad
    FROM (
      SELECT COALESCE(d.snapshot_date, c.snapshot_date) AS sd
      FROM (
        SELECT snapshot_date, COUNT(*) AS k
        FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily`
        WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
        GROUP BY 1
      ) d
      FULL OUTER JOIN (
        SELECT snapshot_date, SUM(is_paying) AS k
        FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
        WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
        GROUP BY 1
      ) c ON d.snapshot_date = c.snapshot_date
      WHERE COALESCE(d.k, 0) <> COALESCE(c.k, 0)
    )
  ),
  t05 AS (
    SELECT COUNTIF(ARRAY_LENGTH(activity_array) > 90 OR ARRAY_LENGTH(activity_array) < 1
      OR ARRAY_LENGTH(activity_array) <> ARRAY_LENGTH(viewer_array)
      OR ARRAY_LENGTH(activity_array) <> ARRAY_LENGTH(mou_array)) AS bad
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
  ),
  t06 AS (
    SELECT COUNTIF((is_paying = 1 AND is_in_grace = 1)
      OR (is_paying = 1 AND is_churned = 1)
      OR (is_in_grace = 1 AND is_churned = 1)
      OR (is_churn_event = 1 AND is_active_subscription = 1)
      OR (is_winback_event = 1 AND is_addition = 0)
      OR (is_reacquisition_event = 1 AND is_addition = 0)
      OR (is_winback_event = 1 AND is_reacquisition_event = 1)
      OR days_since_last_active < 0 OR subscription_key IS NULL) AS bad
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
  ),
  t07 AS (
    SELECT COUNTIF(ABS(COALESCE(c.mou_1d, 0) - COALESCE(d.minutes_of_usage, 0)) > 0.0001) AS bad
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated` c
    LEFT JOIN `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily` d
      ON c.subscription_key = d.subscription_key AND c.snapshot_date = d.snapshot_date
    WHERE c.snapshot_date IS NOT NULL AND c.snapshot_date BETWEEN start_date AND end_date AND c.is_paying = 1
  ),
  t08 AS (
    SELECT COUNTIF(ABS(c.mou_30d - COALESCE((
      SELECT SUM(d.minutes_of_usage)
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_daily` d
      WHERE d.snapshot_date IS NOT NULL
        AND d.subscription_key = c.subscription_key
        AND d.snapshot_date BETWEEN DATE_SUB(c.snapshot_date, INTERVAL 29 DAY) AND c.snapshot_date
    ), 0)) > 0.001) AS bad
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated` c
    WHERE c.snapshot_date IS NOT NULL AND c.snapshot_date = end_date
  ),
  t09 AS (
    SELECT COUNTIF(variance <> 0) AS bad
    FROM (
      SELECT snapshot_date,
             SUM(is_active_subscription) - (
               LAG(SUM(is_active_subscription)) OVER (ORDER BY snapshot_date)
               + SUM(is_addition) - SUM(is_churn_event)
             ) AS variance
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
      WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
      GROUP BY snapshot_date
    )
    WHERE snapshot_date > start_date
  ),
  t10 AS (
    SELECT COUNT(*) AS bad
    FROM UNNEST(GENERATE_DATE_ARRAY(start_date, end_date)) dd
    LEFT JOIN (
      SELECT DISTINCT snapshot_date
      FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
      WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
    ) c ON c.snapshot_date = dd
    WHERE c.snapshot_date IS NULL
  ),
  t11 AS (
    SELECT COUNTIF(is_churned = 1 AND churn_date IS NULL) AS bad
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date
  ),
  exp AS (
    SELECT *
    FROM `project-6e19992f-9af5-4761-8e9.bq_ops_bein.test_expected_events`
    WHERE event_date BETWEEN start_date AND end_date
  ),
  actual_events AS (
    SELECT subscriber_id, snapshot_date AS event_date, 'NEW' AS event_type
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date AND is_new_subscription = 1
    UNION ALL
    SELECT subscriber_id, snapshot_date, 'CHURN'
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date AND is_churn_event = 1
    UNION ALL
    SELECT subscriber_id, snapshot_date, 'WINBACK'
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date AND is_winback_event = 1
    UNION ALL
    SELECT subscriber_id, snapshot_date, 'REACQUISITION'
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date AND is_reacquisition_event = 1
    UNION ALL
    SELECT subscriber_id, snapshot_date, 'RENEWAL'
    FROM `project-6e19992f-9af5-4761-8e9.bq_slv_bein.subscription_cumulated`
    WHERE snapshot_date IS NOT NULL AND snapshot_date BETWEEN start_date AND end_date AND is_renewal_event = 1
  ),
  t12 AS (
    SELECT COUNTIF(a.subscriber_id IS NULL OR e.subscriber_id IS NULL) AS bad,
           STRING_AGG(IF(a.subscriber_id IS NULL OR e.subscriber_id IS NULL,
             FORMAT('%s|%t|%s|%s',
               COALESCE(e.subscriber_id, a.subscriber_id),
               COALESCE(e.event_date, a.event_date),
               COALESCE(e.event_type, a.event_type),
               IF(a.subscriber_id IS NULL, 'MISSING', 'UNEXPECTED')), NULL) LIMIT 50) AS detail
    FROM exp e
    FULL OUTER JOIN actual_events a
      ON e.subscriber_id = a.subscriber_id AND e.event_date = a.event_date AND e.event_type = a.event_type
  )
  SELECT t0, 'T01', 'daily grain unique', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t01
  UNION ALL SELECT t0, 'T02', 'cumulated grain unique', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t02
  UNION ALL SELECT t0, 'T03', 'source -> daily reconciliation', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t03
  UNION ALL SELECT t0, 'T04', 'daily rows = SUM(is_paying) (feed-gap tolerant)', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t04
  UNION ALL SELECT t0, 'T05', 'array integrity', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t05
  UNION ALL SELECT t0, 'T06', 'state-machine integrity', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t06
  UNION ALL SELECT t0, 'T07', 'mou_1d = daily fact', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t07
  UNION ALL SELECT t0, 'T08', 'mou_30d = independent 30d recompute', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t08
  UNION ALL SELECT t0, 'T09', 'roll-forward identity', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t09
  UNION ALL SELECT t0, 'T10', 'no missing calendar day', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t10
  UNION ALL SELECT t0, 'T11', 'is_churned has churn_date', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), NULL FROM t11
  UNION ALL SELECT t0, 'T12', 'golden lifecycle events', 'ERROR', IF(bad = 0, 'PASS', 'FAIL'), bad, '0', CAST(bad AS STRING), detail FROM t12;

  SET fail_cnt = (
    SELECT COUNT(*)
    FROM `project-6e19992f-9af5-4761-8e9.bq_ops_bein.test_results`
    WHERE DATE(test_run_ts) = CURRENT_DATE() AND status = 'FAIL' AND severity = 'ERROR'
  );

  IF fail_cnt > 0 THEN
    RAISE USING MESSAGE = FORMAT('OTT TESTS FAILED: %d assertions. See bq_ops_bein.test_results', fail_cnt);
  END IF;
END;
