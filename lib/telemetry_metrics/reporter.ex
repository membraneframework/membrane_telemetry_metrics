defmodule Membrane.TelemetryMetrics.Reporter do
  @moduledoc """
  Attaches handlers to :telemetry events based on the received list of metrics definitions.
  The attached handlers store metrics values in ETS tables.
  These values can be gotten by calling `scrape/2` function or also reset by calling `scrape_and_cleanup/2`.

  Currently supported types of metrics are:
   - `Telemetry.Metrics.Counter`
   - `Telemetry.Metrics.Sum`
   - `Telemetry.Metrics.LastValue`

  Currently supported fields of metrics definitions are: `:name`, `:event_name`, `measurement`.
  Fields `:keep`, `:reporter_options`, `tag_values`, `tags`, `:unit` and functionalities related to them are not supported yet.
  Metrics values are grouped by value related to key `:telemetry_metadata` in event `metadata`.
  """

  use GenServer

  @type reporter() :: pid() | atom()
  @type report() :: map()

  @spec start_link([metrics: [Telemetry.Metrics.t()]], GenServer.options()) ::
          GenServer.on_start()
  def start_link(init_arg, options \\ []) do
    options = Keyword.put(options, :trap_exit, true)
    GenServer.start_link(__MODULE__, init_arg, options)
  end

  @spec scrape(reporter(), non_neg_integer()) :: report()
  def scrape(reporter, timeout \\ 5000) do
    GenServer.call(reporter, :scrape, timeout)
  end

  @spec scrape_and_cleanup(reporter(), non_neg_integer()) :: report()
  def scrape_and_cleanup(reporter, timeout \\ 5000) do
    GenServer.call(reporter, :scrape_and_cleanup, timeout)
  end

  @spec stop(reporter()) :: :ok
  def stop(reporter) do
    GenServer.stop(reporter)
  end

  @impl true
  def init(init_arg) do
    metrics_data =
      Keyword.get(init_arg, :metrics, [])
      |> Enum.map(fn metric ->
        ets_table = create_ets_table()
        handler_ids = attach_handlers(metric, ets_table)

        %{
          metric: metric,
          name: Enum.join(metric.name, "."),
          ets_table: ets_table,
          handler_ids: handler_ids
        }
      end)

    {:ok, %{metrics_data: metrics_data}}
  end

  @impl true
  def handle_call(:scrape, _from, state) do
    report =
      Enum.map(state.metrics_data, fn metric_data ->
        {metric_data.name, get_metric_report(metric_data.ets_table)}
      end)
      |> Enum.map(&move_metric_down_in_report/1)
      |> merge_metrics_reports()

    {:reply, report, state}
  end

  @impl true
  def handle_call(:scrape_and_cleanup, _from, state) do
    report =
      Enum.map(state.metrics_data, fn metric_data ->
        {metric_data.name, get_metric_report_and_do_clanup(metric_data.ets_table)}
      end)
      |> Enum.map(&move_metric_down_in_report/1)
      |> merge_metrics_reports()

    {:reply, report, state}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.metrics_data, fn metric_data ->
      %{
        handler_ids: handler_ids,
        ets_table: ets_table
      } = metric_data

      Enum.each(handler_ids, &:telemetry.detach/1)
      :ets.delete(ets_table)
    end)
  end

  defp create_ets_table(),
    do: :ets.new(:metric_table, [:public, :set, {:write_concurrency, true}])

  defp attach_handlers(metric, ets_table) do
    case metric do
      %Telemetry.Metrics.Counter{} -> __MODULE__.Counter
      %Telemetry.Metrics.LastValue{} -> __MODULE__.LastValue
      %Telemetry.Metrics.Sum{} -> __MODULE__.Sum
    end
    |> apply(:attach, [metric, ets_table])
  end

  defp get_metric_report(ets_table) do
    :ets.tab2list(ets_table)
    |> aggregate_report()
  end

  defp get_metric_report_and_do_clanup(ets_table) do
    :ets.tab2list(ets_table)
    |> Enum.flat_map(fn {key, _val} -> :ets.take(ets_table, key) end)
    |> aggregate_report()
  end

  defp aggregate_report(content) do
    Enum.map(content, fn {key, value} ->
      {Enum.reverse(key), value}
    end)
    |> do_aggregate_report()
  end

  defp do_aggregate_report(content) do
    {aggregated_content, content_to_aggregate} =
      Enum.split_with(content, fn {key, _val} -> key == [] end)

    content_to_aggregate
    |> Enum.group_by(
      # key fun
      fn {[head | _tail], _val} -> head end,
      # value fun
      fn {[_head | tail], val} -> {tail, val} end
    )
    |> Enum.map(fn {key, subcontent} -> {key, do_aggregate_report(subcontent)} end)
    |> Enum.concat(aggregated_content)
  end

  defp move_metric_down_in_report({metric_name, report}) do
    Enum.map(report, fn
      {[], val} -> {metric_name, val}
      {key, sub_report} -> {key, move_metric_down_in_report({metric_name, sub_report})}
    end)
  end

  defp merge_metrics_reports(reports) do
    Enum.reduce(reports, %{}, &merge_metrics_reports/2)
  end

  defp merge_metrics_reports(report1, report2) do
    Map.merge(
      Map.new(report1),
      Map.new(report2),
      fn _key, val1, val2 -> merge_metrics_reports(val1, val2) end
    )
  end
end
