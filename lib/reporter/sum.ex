defmodule Membrane.TelemetryMetrics.Reporter.Sum do
  @moduledoc false

  @spec attach(Telemetry.Metrics.Sum.t(), :ets.tid() | atom()) :: :ok | {:error, :already_exists}
  def attach(metric, ets) do
    config = %{ets: ets, measurement: metric.measurement}
    :telemetry.attach(ets, metric.event_name, &__MODULE__.handle_event/4, config)
  end

  @spec handle_event([atom(), ...], map(), map(), term()) :: :ok
  def handle_event(_event_name, measurements, metadata, config) do
    %{ets: ets, measurement: measurement} = config
    key = metadata.telemetry_metadata

    if Map.has_key?(measurements, measurement) do
      value = measurements[measurement]
      :ets.update_counter(ets, key, value, {key, 0})
    end

    :ok
  end
end
