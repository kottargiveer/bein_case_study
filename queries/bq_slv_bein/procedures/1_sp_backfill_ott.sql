CREATE OR REPLACE PROCEDURE `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_backfill_ott`(
  IN start_date DATE,
  IN end_date DATE)
BEGIN
  DECLARE d DATE DEFAULT start_date;
  WHILE d <= end_date DO
    CALL `project-6e19992f-9af5-4761-8e9.bq_slv_bein.sp_run_ott_pipeline`(d);
    SET d = DATE_ADD(d, INTERVAL 1 DAY);
  END WHILE;
END;