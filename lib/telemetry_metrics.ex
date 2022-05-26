defmodule Membrane.TelemetryMetrics do
  @moduledoc """
  Defines macros for executing telemetry events and registering processes with events.
  Provided macros evalueates to meaningful code or to nothing, depending on config values, in order to achieve performance boost, when specific event or whole telemetry is not in use.
  """

  @enabled Application.compile_env(:membrane_telemetry_metrics, :enabled, false)
  @events Application.compile_env(:membrane_telemetry_metrics, :events, :all)

  @doc """
  Evaluates to conditional call to `:telemetry.execute/3` or to nothing, depending on if specific event is enabled in config file.
  If event is enabled, `:telemetry.execute/3` will be executed only if value returned by call to `func` will be truthly.
  """
  defmacro conditional_execute(func, event_name, measurmets \\ %{}, metadata \\ %{}) do
    emit? = emit_event?(event_name)
    do_conditional_execute(func, event_name, measurmets, metadata, emit?)
  end

  @doc """
  Evaluates to call to `:telemetry.execute/3` or to nothing, depending on if specific event is enabled in config file.
  """
  defmacro execute(event_name, measurments \\ %{}, metadata \\ %{}) do
    emit? = emit_event?(event_name)
    do_execute(event_name, measurments, metadata, emit?)
  end

  @doc """
  Evalueates to call to `Membrane.TelemetryMetrics.Monitor.start/3` or to nothing, depending on if specific event is enabled in config file.
  Should be called in every process, that will execute event linked with metric aggregated by some instance of `Membrane.TelemetryMetrics.Reporter`.
  """
  defmacro register_event_with_telemetry_metadata(event_name, telemetry_metadata) do
    if emit_event?(event_name) do
      quote do
        Membrane.TelemetryMetrics.Monitor.start(
          unquote(event_name),
          unquote(telemetry_metadata)
        )
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

  defp emit_event?(event) do
    cond do
      not @enabled -> false
      @events == :all -> true
      is_list(@events) -> event in @events
      true -> false
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
