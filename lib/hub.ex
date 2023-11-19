defmodule Hub do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: :hub)
  end

  @impl true
  def init(nil) do
    {:ok, _tref1} = :timer.send_interval(:timer.seconds(60), :tick)
    {:ok, Model.make(create_initial_reminders: true)}
  end

  @impl true
  def handle_cast({:monitor_please, pid}, state) do
    Process.monitor(pid)
    {:noreply, state}
  end
  def handle_cast(event, state) do
    Model.update(state, event)
    |> effective_render
    |> noreply
  end

  defp effective_render(%Model{}=model) when model.no_renders, do: model
  defp effective_render(%Model{}=model) do
    case View.render(model) do
      %Model{}=m -> m
      _          -> model
    end
  end

  @impl true
  def handle_call(msg, _from, state) do
    resp = Model.ask(msg, state)
    {:reply, resp, state}
  end

  @impl true
  def handle_info(:tick, state), do: handle_cast(:tick, state)
  def handle_info(msg, state) do
    {:noreply, Model.log(msg, state)}
  end

  def tick(), do: GenServer.cast(:hub, :tick)
  def task_disband(), do: GenServer.cast(:hub, :task_disband)
  def get_cur_task(), do: GenServer.call(:hub, :task_get_cur)
  def refresh(), do: GenServer.cast(:hub, :refresh)
  def mode(val), do: GenServer.cast(:hub, {:mode, val})
  def log(msg), do: GenServer.cast(:hub, {:log, msg})
  def cast(msg), do: GenServer.cast(:hub, msg)
  def call(msg), do: GenServer.call(:hub, msg)

  def monitor_please(pid), do: GenServer.cast(:hub, {:monitor_please, pid})

  defp noreply(x), do: {:noreply, x}
end
