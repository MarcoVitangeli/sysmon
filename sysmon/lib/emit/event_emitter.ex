defmodule Sysmon.Emit.EventEmitter do
  use GenServer
  require Logger
  
  @buffer_size 100
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, {0, :queue.new}}
  end

  def handle_cast({:store, events}, {curr_size, queue}) when is_list(events) when is_integer(curr_size) do
    len = length(events)
    {new_queue, new_size} = if @buffer_size <= curr_size+len and !:queue.is_empty(queue), do: {flush(queue), 0}, else: {queue, curr_size}

    Logger.info("BUFFER_SIZE: #{new_size+len}")

    with_item = :queue.in(events, new_queue)

    {:noreply, {new_size+len, with_item}}
  end

  def handle_call(:flush, {size, queue}) do
    flush(queue)
    {:reply, size, {0, :queue.new}}
  end

  defp flush(queue, stream \\ []) do
    Logger.info("STARTING TO FLUSH STREAM")
    case :queue.out(queue) do
      {:empty, _} -> 
        send_batch(stream |> Enum.to_list)
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
