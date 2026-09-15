# BEIN OTT KPI Pipeline

This repository contains a BigQuery-based OTT KPI pipeline implementation for BEIN, including bronze, silver, gold, and operational layers, along with the Airflow DAG used to trigger the daily cumulative backfill.

## Project purpose

The codebase builds a medallion-style data pipeline for OTT subscription and usage metrics, with the following intent:

- ingest and normalize daily subscription snapshots
- aggregate daily and cumulative state per subscription
- generate KPI fact tables and dashboard-friendly views
- validate the pipeline with control checks and test fixtures
- run the process from Airflow using BigQuery stored procedures

---

## Repository structure

```text
codebase/
├── README.md
├── cumulative_table_dag.py
├── images/
│   ├── Bein Data Platform Architecture.png
│   ├── Bein-ERD.png
│   └── cumulative_table_design.jpg
├── queries/
    ├── bq_brz_bein/
    │   └── subscription_snapshot_daily.sql
    ├── bq_gld_bein/
    │   ├── vw_ott_kpi_daily.sql
    │   ├── vw_ott_kpi_monthly.sql
    │   └── vw_subscription_lifecycle_events.sql
    ├── bq_lnd_bein/
    │   ├── tables/
    │   │   └── opco_raw_subscribers.sql
    │   └── views/
    │       └── opco_raw_subscribers_vw.sql
    ├── bq_ops_bein/
    │   ├── sp_test_ott_pipeline.sql
    │   └── tables/
    │       ├── etl_run_log.sql
    │       ├── test_expected_events.sql
    │       └── test_results.sql
    └── bq_slv_bein/
        ├── procedures/
        │   ├── 1_sp_backfill_ott.sql
        │   ├── 2_sp_run_ott_pipeline.sql
        │   ├── 3_sp_load_subscription_daily.sql
        │   ├── 4_sp_load_subscription_cumulated.sql
        │   └── 5_sp_backfill_ott_kpi_daily.sql
        └── tables/
            ├── ott_kpi_daily.sql
            ├── subscription_cumulated.sql
            └── subscription_daily.sql

```

---

## Core files

### Airflow orchestration
- `cumulative_table_dag.py`  
  Runs the daily pipeline via BigQuery job execution using stored procedures.

### Bronze layer
- `queries/bq_brz_bein/subscription_snapshot_daily.sql`  
  Source table definition for daily subscription snapshot data.

### Silver layer
- `queries/bq_slv_bein/tables/subscription_daily.sql`  
  Daily subscription-level table.
- `queries/bq_slv_bein/tables/subscription_cumulated.sql`  
  Stateful cumulative subscription view, used for lifecycle tracking.
- `queries/bq_slv_bein/procedures/3_sp_load_subscription_daily.sql`  
  Loads daily subscription data.
- `queries/bq_slv_bein/procedures/4_sp_load_subscription_cumulated.sql`  
  Builds cumulative metrics and lifecycle flags.
- `queries/bq_slv_bein/procedures/2_sp_run_ott_pipeline.sql`  
  Orchestrates the pipeline run for a given date.
- `queries/bq_slv_bein/procedures/5_sp_backfill_ott_kpi_daily.sql`  
  Rebuilds KPI fact data over a date range.

### Gold layer
- `queries/bq_gld_bein/vw_ott_kpi_daily.sql`  
  Daily KPI view.
- `queries/bq_gld_bein/vw_ott_kpi_monthly.sql`  
  Monthly KPI summary view.
- `queries/bq_gld_bein/vw_subscription_lifecycle_events.sql`  
  Event-centric view for lifecycle transitions.

### Ops / validation layer
- `queries/bq_ops_bein/sp_test_ott_pipeline.sql`  
  Automated validation procedure for data quality and reconciliation.
- `queries/bq_ops_bein/tables/etl_run_log.sql`  
  Stores execution logging.
- `queries/bq_ops_bein/tables/test_results.sql`  
  Stores validation outcomes.
- `queries/bq_ops_bein/tables/test_expected_events.sql`  
  Stores expected lifecycle event fixtures.

---

## Typical workflow

1. Load or refresh the bronze dataset.
2. Run the silver daily population procedure.
3. Build cumulative subscription state.
4. Generate KPI facts for gold reporting.
5. Run the automated test procedure.
6. Validate business metrics and control checks.

The DAG in `cumulative_table_dag.py` is designed to trigger this flow in Airflow using BigQuery stored procedures.

---

## Notes

- This repository is structured around a medallion-style warehouse pattern.
- SQL is intended to be executed in a BigQuery project environment with the required datasets and permissions.
- Files under `queries/` are the main reusable SQL assets for the data pipeline.
- The `images/` directory contains architecture and schema references for the solution.

---
