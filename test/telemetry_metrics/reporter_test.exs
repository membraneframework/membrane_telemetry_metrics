defmodule Membrane.TelemetryMetrics.Reporter.Test do
  use ExUnit.Case, async: true

  require Membrane.TelemetryMetrics

  alias Membrane.TelemetryMetrics.Reporter

  test "Scrape from reporter with empty metrics list" do
    {:ok, reporter} = Reporter.start_link([])

    assert %{} == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter without executed events" do
    metric = Telemetry.Metrics.counter("counter", event_name: [:event])
    {:ok, reporter} = Reporter.start_link([metric])

    assert %{} == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter with few executed events and empty label" do
    metrics = [
      Telemetry.Metrics.counter("counter", event_name: [:event]),
      Telemetry.Metrics.sum("sum", event_name: [:event], measurement: :number),
      Telemetry.Metrics.last_value("last_value", event_name: [:event], measurement: :number)
    ]

    {:ok, reporter} = Reporter.start_link(metrics)

    Membrane.TelemetryMetrics.register([:event], [])

    for number <- [-5, 1, 15, 100, 32, 2] do
      Membrane.TelemetryMetrics.execute([:event], %{number: number}, %{}, [])
    end

    assert %{
             "counter" => 6,
             "sum" => 145,
             "last_value" => 2
           } == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter with few executed events and single value of label" do
    metrics = [
      Telemetry.Metrics.counter("counter", event_name: [:event]),
      Telemetry.Metrics.sum("sum", event_name: [:event], measurement: :number),
      Telemetry.Metrics.last_value("last_value", event_name: [:event], measurement: :number)
    ]

    {:ok, reporter} = Reporter.start_link(metrics)

    Membrane.TelemetryMetrics.register([:event], id: 1)

    for number <- [-5, 1, 15, 100, 32, 2] do
      Membrane.TelemetryMetrics.execute([:event], %{number: number}, %{}, id: 1)
    end

    assert %{{:id, 1} => %{"counter" => 6, "sum" => 145, "last_value" => 2}} ==
             Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter with few executed events and expected reporter with nested structure" do
    metrics = [
      Telemetry.Metrics.counter("counter", event_name: [:event]),
      Telemetry.Metrics.sum("sum", event_name: [:event], measurement: :number),
      Telemetry.Metrics.last_value("last_value", event_name: [:event], measurement: :number)
    ]

    {:ok, reporter} = Reporter.start_link(metrics)

    labels = [[id: 1], [sub_id: "A", id: 2], [sub_id: "B", id: 2]]

    for label <- labels, do: Membrane.TelemetryMetrics.register([:event], label)

    for number <- [-5, 1, 15, 100, 32, 2], label <- labels do
      Membrane.TelemetryMetrics.execute([:event], %{number: number}, %{}, label)
    end

    assert %{
             {:id, 1} => %{"counter" => 6, "last_value" => 2, "sum" => 145},
             {:id, 2} => %{
               {:sub_id, "A"} => %{"counter" => 6, "last_value" => 2, "sum" => 145},
               {:sub_id, "B"} => %{"counter" => 6, "last_value" => 2, "sum" => 145}
             }
           } ==
             Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter with few executed events with different labels" do
    metrics = [
      Telemetry.Metrics.counter("counter_a", event_name: [:event_a]),
      Telemetry.Metrics.counter("counter_b", event_name: [:event_b])
    ]

    {:ok, reporter} = Reporter.start_link(metrics)

    labels = [[id: 1], [id: 2], [id: 3]]

    for label <- labels, do: Membrane.TelemetryMetrics.register([:event], label)

    for {event, labels} <- [{[:event_a], [[id: 1], [id: 2]]}, {[:event_b], [[id: 2], [id: 3]]}] do
      for label <- labels do
        Membrane.TelemetryMetrics.execute(event, %{}, %{}, label)
      end
    end

    assert %{
             {:id, 1} => %{"counter_a" => 1},
             {:id, 2} => %{"counter_a" => 1, "counter_b" => 1},
             {:id, 3} => %{"counter_b" => 1}
           } == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter with nested expected report structure, with metrics values at different levels" do
    metrics = [
      Telemetry.Metrics.counter("counter_a", event_name: [:event_a]),
      Telemetry.Metrics.counter("counter_b", event_name: [:event_b])
    ]

    {:ok, reporter} = Reporter.start_link(metrics)

    labels = [
      [id: 1],
      [sub_id: "A", id: 1],
      [sub_id: "B", id: 1],
      [sub_sub_id: :a, sub_id: "A", id: 1],
      [id: 2],
      [sub_id: "A", id: 2],
      [sub_sub_id: :a, sub_id: "A", id: 2],
      [sub_sub_id: :a, sub_id: "A", id: 3]
    ]

    for label <- labels, do: Membrane.TelemetryMetrics.register([:event], label)

    for label <- labels, event <- [[:event_a], [:event_b]], _i <- 1..10 do
      Membrane.TelemetryMetrics.execute(event, %{}, %{}, label)
    end

    assert %{
             {:id, 1} => %{
               {:sub_id, "A"} => %{
                 {:sub_sub_id, :a} => %{"counter_a" => 10, "counter_b" => 10},
                 "counter_a" => 10,
                 "counter_b" => 10
               },
               {:sub_id, "B"} => %{"counter_a" => 10, "counter_b" => 10},
               "counter_a" => 10,
               "counter_b" => 10
             },
             {:id, 2} => %{
               {:sub_id, "A"} => %{
                 {:sub_sub_id, :a} => %{"counter_a" => 10, "counter_b" => 10},
                 "counter_a" => 10,
                 "counter_b" => 10
               },
               "counter_a" => 10,
               "counter_b" => 10
             },
             {:id, 3} => %{
               {:sub_id, "A"} => %{
                 {:sub_sub_id, :a} => %{"counter_a" => 10, "counter_b" => 10}
               }
             }
           } == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end

  test "Scrape from reporter, while different processes are emitting events and dying" do
    metrics = [
      Telemetry.Metrics.counter("counter", event_name: [:event])
    ]

    {:ok, reporter} = Reporter.start_link(metrics)
    parent = self()

    [{:ok, task_1}, {:ok, task_2}] =
      for label <- [[id: 1], [id: 2]] do
        Task.start(fn ->
          Membrane.TelemetryMetrics.register([:event], label)

          receive do
            :emit_event ->
              Membrane.TelemetryMetrics.execute([:event], %{}, %{}, label)
              send(parent, :event_emitted)
          end

          receive do
            :stop -> :ok
          end
        end)
      end

    Process.monitor(task_1)
    Process.monitor(task_2)

    assert %{} == Reporter.scrape(reporter)

    send(task_1, :emit_event)

    receive do
      :event_emitted -> :ok
    end

    assert %{{:id, 1} => %{"counter" => 1}} == Reporter.scrape(reporter)

    send(task_2, :emit_event)

    receive do
      :event_emitted -> :ok
    end

    assert %{
             {:id, 1} => %{"counter" => 1},
             {:id, 2} => %{"counter" => 1}
           } == Reporter.scrape(reporter)

    send(task_1, :stop)

    receive do
      {:DOWN, _ref, _process, ^task_1, _reason} -> :ok
    end

    Process.sleep(100)

    assert %{{:id, 2} => %{"counter" => 1}} == Reporter.scrape(reporter)

    send(task_2, :stop)

    receive do
      {:DOWN, _ref, _process, ^task_2, _reason} -> :ok
    end

    Process.sleep(100)

    assert %{} == Reporter.scrape(reporter)

    Reporter.stop(reporter)
  end
end
