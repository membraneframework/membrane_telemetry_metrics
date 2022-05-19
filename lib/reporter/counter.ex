defmodule Membrane.TelemetryMetrics.Reporter.Counter do
  @moduledoc false

  alias Membrane.TelemetryMetrics.Utils

  @spec attach(Telemetry.Metrics.Counter.t(), :ets.tid() | atom()) ::
          :ok | {:error, :already_exists}
  def attach(metric, ets) do
    :telemetry.attach(ets, metric.event_name, &__MODULE__.handle_event/4, %{ets: ets})
    Utils.attach_cleanup_handler(metric.event_name, ets)
  end

  @spec handle_event([atom(), ...], map(), map(), term()) :: :ok
  def handle_event(_event_name, _measurements, metadata, %{ets: ets}) do
    key = metadata.telemetry_metadata
    :ets.update_counter(ets, key, 1, {key, 0})
    :ok
  end
end
