defmodule SysmonApi.MetricsTest do
  use SysmonApi.DataCase

  alias SysmonApi.Metrics

  describe "metrics" do
    alias SysmonApi.Metrics.Metric

    import SysmonApi.MetricsFixtures

    @invalid_attrs %{metric_id: nil, container_id: nil, metric_name: nil, metric_value: nil, ingestion_time: nil}

    test "list_metrics/0 returns all metrics" do
      metric = metric_fixture()
      assert Metrics.list_metrics() == [metric]
    end

    test "get_metric!/1 returns the metric with given id" do
      metric = metric_fixture()
      assert Metrics.get_metric!(metric.id) == metric
    end

    test "create_metric/1 with valid data creates a metric" do
      valid_attrs = %{metric_id: "7488a646-e31f-11e4-aace-600308960662", container_id: "some container_id", metric_name: "some metric_name", metric_value: "120.5", ingestion_time: ~D[2025-07-23]}

      assert {:ok, %Metric{} = metric} = Metrics.create_metric(valid_attrs)
      assert metric.metric_id == "7488a646-e31f-11e4-aace-600308960662"
      assert metric.container_id == "some container_id"
      assert metric.metric_name == "some metric_name"
      assert metric.metric_value == Decimal.new("120.5")
      assert metric.ingestion_time == ~D[2025-07-23]
    end

    test "create_metric/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Metrics.create_metric(@invalid_attrs)
    end

    test "update_metric/2 with valid data updates the metric" do
      metric = metric_fixture()
      update_attrs = %{metric_id: "7488a646-e31f-11e4-aace-600308960668", container_id: "some updated container_id", metric_name: "some updated metric_name", metric_value: "456.7", ingestion_time: ~D[2025-07-24]}

      assert {:ok, %Metric{} = metric} = Metrics.update_metric(metric, update_attrs)
      assert metric.metric_id == "7488a646-e31f-11e4-aace-600308960668"
      assert metric.container_id == "some updated container_id"
      assert metric.metric_name == "some updated metric_name"
      assert metric.metric_value == Decimal.new("456.7")
      assert metric.ingestion_time == ~D[2025-07-24]
    end

    test "update_metric/2 with invalid data returns error changeset" do
      metric = metric_fixture()
      assert {:error, %Ecto.Changeset{}} = Metrics.update_metric(metric, @invalid_attrs)
      assert metric == Metrics.get_metric!(metric.id)
    end

    test "delete_metric/1 deletes the metric" do
      metric = metric_fixture()
      assert {:ok, %Metric{}} = Metrics.delete_metric(metric)
      assert_raise Ecto.NoResultsError, fn -> Metrics.get_metric!(metric.id) end
    end

    test "change_metric/1 returns a metric changeset" do
      metric = metric_fixture()
      assert %Ecto.Changeset{} = Metrics.change_metric(metric)
    end
  end
end
