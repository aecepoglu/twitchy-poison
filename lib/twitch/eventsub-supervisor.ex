defmodule Twitch.Eventsub.Supervisor do
  use DynamicSupervisor
  Supervisor

  def start_link(init_arg) do
    #TODO set max_children = 2
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def eventsub(opts \\ []) do
    child_spec = {Twitch.Eventsub, opts}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def reconnect_soon(url) do
    [{_, old_pid, _, _}] = Supervisor.which_children(__MODULE__)
    f = fn ->
      IO.inspect({:terminating, old_pid})
      DynamicSupervisor.terminate_child(__MODULE__, old_pid)
    end
    {:ok, _pid} = eventsub(resume_url: url, on_welcome: f)
  end
end
