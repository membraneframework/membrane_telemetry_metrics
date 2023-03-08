defmodule Membrane.TelemetryMetrics.Monitor do
  @moduledoc false

  require Membrane.TelemetryMetrics

  alias Membrane.TelemetryMetrics.Utils

  @spec start(:telemetry.event_name(), Membrane.TelemetryMetrics.label()) :: {:ok, pid()}
  def start(event_name, label) do
    if :ets.whereis(__MODULE__) == :undefined do
      try do
        :ets.new(__MODULE__, [:public, :set, :named_table])
      rescue
        _error in ArgumentError -> :ignored
      end
    end

    self = self()

    case :ets.lookup(__MODULE__, self) do
      [] ->
        pid =
          Process.spawn(
            __MODULE__,
            :run,
            [self(), [event_name], [label]],
            []
          )

        :ets.insert(__MODULE__, {self, pid})

        {:ok, pid}

      [{^self, pid} | _] ->
        send(pid, {event_name, label})
        {:ok, pid}
    end
  end

  @spec run(pid() | atom(), :telemetry.event_name(), Membrane.TelemetryMetrics.label()) :: :ok
  def run(monitored_process, event_names, labels) do
    Process.monitor(monitored_process)
    handle_events(monitored_process, event_names, labels)
  end

  defp handle_events(monitored_process, event_names, labels) do
    receive do
      {:DOWN, _ref, _process, ^monitored_process, _reason} ->
        event_names
        |> Enum.zip(labels)
        |> Enum.each(fn {event_name, label} ->
          event_name
          |> Utils.cleanup_event_name()
          |> Membrane.TelemetryMetrics.execute(%{}, %{}, label)
        end)

        :ok

      {event_name, label} ->
        handle_events(monitored_process, [event_name | event_names], [label | labels])
    end
  end
end
