CREATE OR REPLACE PROCEDURE `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_run_ott_pipeline`(IN ds DATE)
BEGIN
  CALL `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_load_subscription_daily`(ds);
  CALL `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_load_subscription_cumulated`(ds);
  CALL `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_backfill_ott_kpi_daily`(ds, ds);
END;
