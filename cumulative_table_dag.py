from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator

PROJECT_ID = 'project-6e19992f-9af5-4761-8e9'
LOCATION = 'EU'


default_args = {
    'owner': 'bein',
    'depends_on_past': True,
    'email': ['airflow@example.com'],
}


def run_bigquery_proc(task_id, sql):
    return BigQueryInsertJobOperator(
        task_id=task_id,
        project_id=PROJECT_ID,
        location=LOCATION,
        configuration={
            'query': {
                'query': sql,
                'useLegacySql': False,
            }
        },
    )


with DAG(
    'cumulative_table_example_dag',
    default_args=default_args,
    description='Run OTT KPI cumulative backfill in BigQuery',
    schedule_interval='@daily',
    start_date='2022-01-01',
    catchup=False,
    tags=['bein', 'bigquery', 'ott', 'cumulative table example'],
) as dag:
    backfill_ott = run_bigquery_proc(
        'run_backfill_ott',
        f"CALL `{PROJECT_ID}.bq_slv_bein.sp_backfill_ott`(DATE '{{{{ ds }}}}', DATE '{{{{ ds }}}}');"
    )

    backfill_ott