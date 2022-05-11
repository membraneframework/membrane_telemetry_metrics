defmodule Membrane.TelemetryMetrics.Reporter.Counter do
  @moduledoc false

  @spec attach(Telemetry.Metrics.Counter.t(), :ets.tid() | atom()) ::
          :ok | {:error, :already_exists}
  def attach(metric, ets) do
    :telemetry.attach(ets, metric.event_name, &handle_event/4, %{ets: ets})
  end

  defp handle_event(_event_name, _measurements, metadata, %{ets: ets}) do
    key = metadata.telemetry_metadata
    :ets.update_counter(ets, key, 1, {key, 0})
    :ok
  end
end
