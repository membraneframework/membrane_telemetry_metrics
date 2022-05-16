defmodule Membrane.TelemetryMetrics.Reporter.LastValue do
  @moduledoc false

  @spec attach(Telemetry.Metrics.LastValue.t(), :ets.tid() | atom()) ::
          :ok | {:error, :already_exists}
  def attach(metric, ets) do
    config = %{ets: ets, measurement: metric.measurement}
    :telemetry.attach(ets, metric.event_name, &__MODULE__.handle_event/4, config)
  end

  @spec handle_event([atom(), ...], map(), map(), term()) :: :ok
  def handle_event(_event_name, measurements, metadata, config) do
    %{ets: ets, measurement: measurement} = config

    if Map.has_key?(measurements, measurement) do
      :ets.insert(ets, {metadata.telemetry_metadata, measurements[measurement]})
    end

    :ok
  end
end
