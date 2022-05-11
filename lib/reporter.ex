defmodule Membrane.TelemetryMetrics.Reporter do
  @moduledoc false

  use GenServer

  alias Membrane.TelemetryMetrics.Reporter.{Counter, LastValue, Sum}

  @type reporter() :: pid()
  @type report() :: map()

  @spec start_link(list(), GenServer.options()) :: GenServer.on_start()
  def start_link(init_arg, options \\ []) do
    GenServer.start_link(__MODULE__, init_arg, options)
  end

  @spec scrape(reporter(), non_neg_integer()) :: report()
  def scrape(reporter, timeout \\ 5000) do
    GenServer.call(reporter, :scrape, timeout)
  end

  @impl true
  def init(init_arg) do
    metrics = init_arg[:metrics]
    ets_tables = Enum.map(metrics, &attach_handler_and_get_ets/1)
    {:ok, %{metrics: metrics, ets_tables: ets_tables}}
  end

  @impl true
  def handle_call(:scrape, _from, state) do
    report = Enum.map(state.ets_tables, fn ets -> {ets, get_metric_report(ets)} end)
    {:reply, report, state}
  end

  defp attach_handler_and_get_ets(metric) do
    ets_name =
      Enum.join(metric.name, ".")
      |> String.to_atom()

    ets = :ets.new(ets_name, [:named_table, :public, :set, {:write_concurrency, true}])

    case metric do
      %Telemetry.Metrics.Counter{} -> Counter.attach(metric, ets)
      %Telemetry.Metrics.LastValue{} -> LastValue.attach(metric, ets)
      %Telemetry.Metrics.Sum{} -> Sum.attach(metric, ets)
    end

    ets
  end

  defp get_metric_report(ets_table) do
    :ets.tab2list(ets_table)
    |> Enum.map(fn {key, value} -> {Enum.reverse(key), value} end)
    |> aggregate_report()
  end

  defp aggregate_report(content) do
    aggregated_content = Enum.filter(content, fn {key, _val} -> key == [] end)
    content_to_aggregate = Enum.filter(content, fn {key, _val} -> key != [] end)

    content_to_aggregate
    |> Enum.group_by(
      # key fun
      fn {[head | _tail], _val} -> head end,
      # value fun
      fn {[_head | tail], val} -> {tail, val} end
    )
    |> Enum.map(fn {key, subcontent} -> {key, aggregate_report(subcontent)} end)
    |> Enum.concat(aggregated_content)
  end
end
