defmodule SysmonApi.Metrics.Metric do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:metric_id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :metric_id}
  @derive {Jason.Encoder, only: [
    :metric_id,
    :container_id,
    :metric_name,
    :metric_value,
    :metric_type,
    :ingestion_time,
    :inserted_at,
    :updated_at
  ]}
  schema "metrics" do
    field :container_id, :string
    field :metric_name, :string
    field :metric_value, :decimal
    field :metric_type, :string
    field :ingestion_time, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [:container_id, :metric_name, :metric_value, :metric_type, :ingestion_time])
    |> validate_required([:container_id, :metric_name, :metric_value, :metric_type, :ingestion_time])
  end
end
