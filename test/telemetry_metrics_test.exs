defmodule Membrane.TelemetryMetrics.Test do
  use ExUnit.Case, async: true

  require Membrane.TelemetryMetrics

  alias Membrane.TelemetryMetrics.Reporter

  test "Scrape from reporter with empty metrics list" do
    {:ok, reporter} = Reporter.start_link(metrics: [])

    assert %{} == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter without executed events" do
    metric = Telemetry.Metrics.counter("counter", event_name: [:event])
    {:ok, reporter} = Reporter.start_link(metrics: [metric])

    assert %{} == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter with few executed events" do
    metrics = [
      Telemetry.Metrics.counter("counter", event_name: [:event]),
      Telemetry.Metrics.sum("sum", event_name: [:event], measurement: :number),
      Telemetry.Metrics.last_value("last_value", event_name: [:event], measurement: :number)
    ]

    {:ok, reporter} = Reporter.start_link(metrics: metrics)

    Membrane.TelemetryMetrics.register_event_with_telemetry_metadata([:event], [])

    for number <- [-5, 1, 15, 100, 32, 2] do
      Membrane.TelemetryMetrics.execute([:event], %{number: number}, %{telemetry_metadata: []})
    end

    assert %{
             "counter" => 6,
             "sum" => 145,
             "last_value" => 2
           } == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end
end
