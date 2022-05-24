defmodule Membrane.TelemetryMetrics.Utils do
  @moduledoc false

  @cleanup_event_prefix :__do_cleanup

  @spec attach_metric_handler([atom(), ...], :telemetry.handler_function(), %{
          ets: :ets.tid() | atom()
        }) :: [reference()]
  def attach_metric_handler(event_name, handler_function, %{ets: ets} = config) do
    handler_id = make_ref()
    :telemetry.attach(handler_id, event_name, handler_function, config)

    cleanup_handler_id = make_ref()

    :telemetry.attach(
      cleanup_handler_id,
      cleanup_event_name(event_name),
      &__MODULE__.handle_ets_cleanup/4,
      %{ets: ets}
    )

    [handler_id, cleanup_handler_id]
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
