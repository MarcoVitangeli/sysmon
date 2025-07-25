defmodule SysmonApi.Repo.Migrations.CreateMetrics do
  use Ecto.Migration

  def change do
    create table(:metrics, primary_key: false) do
      add :metric_id, :uuid, primary_key: true
      add :container_id, :string
      add :metric_name, :string
      add :metric_type, :string
      add :metric_value, :decimal
      add :ingestion_time, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
