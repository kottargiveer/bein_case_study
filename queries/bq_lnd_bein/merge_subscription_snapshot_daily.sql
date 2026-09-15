MERGE `bq_brz_bein.subscription_snapshot_daily` T
USING (
  SELECT snapshot_date, opco_code, subscription_id, subscription_name, subscriber_id,
         subscription_start_date, subscription_end_date, minutes_of_usage
  FROM `bq_lnd_bein.opco_raw_subscribers_vw`
) S
ON  1=1
AND T.snapshot_date is not null
AND T.snapshot_date   = S.snapshot_date
AND T.opco_code       = S.opco_code
AND T.subscriber_id = S.subscriber_id
AND T.subscription_id = S.subscription_id
WHEN MATCHED THEN UPDATE SET
      subscription_name       = S.subscription_name,
      subscriber_id           = S.subscriber_id,
      subscription_start_date = S.subscription_start_date,
      subscription_end_date   = S.subscription_end_date,
      minutes_of_usage        = S.minutes_of_usage
WHEN NOT MATCHED THEN INSERT ROW
;