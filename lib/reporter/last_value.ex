defmodule Membrane.TelemetryMetrics.Reporter.LastValue do
  @moduledoc false

  @spec attach(Telemetry.Metrics.LastValue.t(), :ets.tid() | atom()) ::
          :ok | {:error, :already_exists}
  def attach(metric, ets) do
    config = %{ets: ets, measurement: metric.measurement}
    :telemetry.attach(ets, metric.event_name, &handle_event/4, config)
  end

  defp handle_event(_event_name, measurements, metadata, config) do
    %{ets: ets, measurement: measurement} = config
    :ets.insert(ets, {metadata.telemetry_metadata, measurements[measurement]})
    :ok
  end
end
