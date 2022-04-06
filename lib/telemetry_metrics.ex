defmodule Membrane.TelemetryMetrics do
  @moduledoc false

  @enable_all_events Application.compile_env(
                       :membrane_telemetry_matrics,
                       :enable_all_events,
                       true
                     )
  @enabled_events Application.compile_env(:membrane_telemetry_matrics, :enabled_events, [])

  defmacro conditional_execute(func, event_name, measurmets \\ %{}, metadata \\ %{}) do
    enable? = @enable_all_events or Enum.member?(event_name, @enabled_events)
    do_conditional_execute(func, event_name, measurmets, metadata, enable?)
  end

  defmacro execute(event_name, measurments \\ %{}, metadata \\ %{}) do
    enable? = @enable_all_events or Enum.member?(event_name, @enabled_events)
    do_execute(event_name, measurments, metadata, enable?)
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
      # A hack to suppress the 'unused variable' warnings

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
