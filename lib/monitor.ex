defmodule Membrane.TelemetryMetrics.Monitor do
  @moduledoc false

  require Membrane.TelemetryMetrics

  alias Membrane.TelemetryMetrics
  alias Membrane.TelemetryMetrics.Utils

  @spec start([atom(), ...], [{atom(), any()}]) :: {:ok, pid()}
  def start(event_name, telemetry_metadata) do
    pid =
      Process.spawn(
        __MODULE__,
        :run,
        [self(), event_name, telemetry_metadata],
        []
      )

    {:ok, pid}
  end

  @spec run(pid() | atom(), [atom(), ...], [{atom(), any()}]) :: :ok
  def run(monitored_process, event_name, telemetry_metadata) do
    Process.monitor(monitored_process)

    receive do
      {:DOWN, _ref, _process, ^monitored_process, _reason} ->
        TelemetryMetrics.execute(
          Utils.cleanup_event_name(event_name),
          %{},
          %{telemetry_metadata: telemetry_metadata}
        )
    end

    :ok
  end
end
