CREATE OR REPLACE EXTERNAL TABLE `project-6e19992f-9af5-4761-8e9.bq_lnd_bein.opco_raw_subscribers`
(

  snapshot_date            STRING  OPTIONS(description="Raw snapshot date as delivered (e.g. 4/1/2024)"),
  subscription_id          STRING  OPTIONS(description="Billing instance id; CHANGES on renewal/return"),
  subscription_name        STRING  OPTIONS(description="Product name, e.g. RECURRING. Durable across returns"),
  subscriber_id            STRING  OPTIONS(description="Customer id; stable across subscriptions"),
  subscription_start_date  STRING  OPTIONS(description="Raw subscription start date"),
  subscription_end_date    STRING  OPTIONS(description="Raw paid-through date; rolls forward while active"),
  minutes_of_usage         STRING  OPTIONS(description="Raw minutes watched on snapshot_date")
)
OPTIONS (
  format                        = 'CSV',
  uris                          = ['gs://bein-ott-landing/opco_raw_subscribers/*'],
  skip_leading_rows             = 1,
  field_delimiter               = ',',
  quote                         = '"',
);