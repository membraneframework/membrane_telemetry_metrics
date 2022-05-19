defmodule Membrane.TelemetryMetrics.Utils do
  @moduledoc false

  @cleanup_event_prefix :__do_cleanup

  @spec attach_cleanup_handler([atom(), ...], :ets.tid() | atom()) :: :ok
  def attach_cleanup_handler(base_event_name, ets) do
    event_name = cleanup_event_name(base_event_name)
    :telemetry.attach(make_ref(), event_name, &__MODULE__.handle_ets_cleanup/4, %{ets: ets})
  end

  @spec cleanup_event_name([atom(), ...]) :: [atom(), ...]
  def cleanup_event_name(base_event_name) do
    [@cleanup_event_prefix | base_event_name]
  end

  @spec handle_ets_cleanup([atom(), ...], map(), map(), term()) :: :ok
  def handle_ets_cleanup(_event_name, _mesaurements, metadata, %{ets: ets}) do
    with %{telemetry_metadata: key} <- metadata do
      :ets.delete(ets, key)
    end

    :ok
  end
end
