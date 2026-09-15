CREATE OR REPLACE VIEW bq_lnd_bein.opco_raw_subscribers_vw AS
SELECT
  snapshot_date,
  'TOD' as opco_code,
  subscription_id,
  subscription_name,
  subscriber_id,
  subscription_start_date,
  subscription_end_date,
  IFNULL(round(cast(minutes_of_usage as bignumeric),2), 0) AS minutes_of_usage,   -- Bronze stores 0, matching source semantics
FROM bq_lnd_bein.opco_raw_subscribers;