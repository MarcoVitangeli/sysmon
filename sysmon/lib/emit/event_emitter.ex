defmodule Sysmon.Emit.EventEmitter do
  use GenServer
  require Logger

  @buffer_size 100

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    :timer.send_interval(20_000, self(), :try_flush)
    {:ok, {DateTime.utc_now(), 0, :queue.new()}}
  end

  def handle_cast({:store, events}, {_, curr_size, queue})
      when is_list(events)
      when is_integer(curr_size) do
    len = length(events)

    {new_queue, new_size} =
      if @buffer_size <= curr_size + len and !:queue.is_empty(queue),
        do: {flush(queue), 0},
        else: {queue, curr_size}

    Logger.info("BUFFER_SIZE: #{new_size + len}")

    with_item = :queue.in(events, new_queue)

    {:noreply, {DateTime.utc_now(), new_size + len, with_item}}
  end

  def handle_info(:try_flush, {last_check_time, size, queue}) do
    due_time = DateTime.add(last_check_time, 5, :minute)
    now = DateTime.utc_now()

    {new_check_time, new_queue} =
      if !:queue.is_empty(queue) and DateTime.compare(due_time, now) == :lt do
        flush(queue)
        {now, :queue.new()}
      else
        {last_check_time, queue}
      end

    {:noreply, {new_check_time, size, new_queue}}
  end

  defp flush(queue, stream \\ []) do
    Logger.info("STARTING TO FLUSH STREAM")

    case :queue.out(queue) do
      {:empty, _} ->
        send_batch(stream |> Enum.to_list())
        Logger.info("END STREAM FLUSH")
        :queue.new()

      {{:value, item}, rest} ->
        new_stream = Stream.concat([item, stream])
        flush(rest, new_stream)
    end
  end

  defp send_batch(data) do
    Logger.info("STARTING TO SEND BATCH OF EVENTS")

    case Req.post("http://localhost:4000/api/metrics/batch", json: %{metrics: data}) do
      {:ok, resp} -> Logger.info("Batch sent, request finished with status code #{resp.status}}")
      {:error, e} -> Logger.info("ERROR while sending batch of metrics: #{e}")
    end
  end
end
