defmodule Membrane.TelemetryMetrics do
  @moduledoc false

  @emit_events Application.compile_env(:membrane_telemetry_metrics, :emit_events, [])

  defmacro conditional_execute(func, event_name, measurmets \\ %{}, metadata \\ %{}) do
    emit? = emit_event?(event_name, @emit_events)
    do_conditional_execute(func, event_name, measurmets, metadata, emit?)
  end

  defmacro execute(event_name, measurments \\ %{}, metadata \\ %{}) do
    emit? = emit_event?(event_name, @emit_events)
    do_execute(event_name, measurments, metadata, emit?)
  end

  defmacro register_event_with_telemetry_metadata(event_name, telemetry_metadata) do
    if emit_event?(event_name, @emit_events) do
      quote do
        Membrane.TelemetryMetrics.Monitor.start(event_name, telemetry_metadata)
      end
    else
      quote do
        fn ->
          _unused = unquote(event_name)
          _unused = unquote(telemetry_metadata)
        end
      end
    end
  end

  defp emit_event?(event_name, emmitted_events) do
    case emmitted_events do
      :all -> true
      list when is_list(list) -> event_name in list
      _else -> false
    end
  end

  defp do_conditional_execute(func, event_name, measurments, metadata, true = _enable?) do
    quote do
      if unquote(func).() do
        :telemetry.execute(
          unquote(event_name),
          unquote(measurments),
          unquote(metadata)
        )
      end
    end
  end

  defp do_conditional_execute(func, event_name, measurments, metadata, false = _enable?) do
    quote do
      fn ->
        _unused = unquote(func)
        _unused = unquote(event_name)
        _unused = unquote(measurments)
        _unused = unquote(metadata)
      end
    end
  end

  defp do_execute(event_name, measurments, metadata, true = _enable?) do
    quote do
      :telemetry.execute(
        unquote(event_name),
        unquote(measurments),
        unquote(metadata)
      )
    end
  end

  defp do_execute(event_name, measurments, metadata, false = _enable?) do
    quote do
      fn ->
        _unused = unquote(event_name)
        _unused = unquote(measurments)
        _unused = unquote(metadata)
      end
    end
  end
end
