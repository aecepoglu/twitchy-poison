defmodule TwitchyPoison.Supervisor do
  @moduledoc false

  use Application

  def list_children("repl"), do: []
  def list_children("test"), do: []
  def list_children("dev") do
    [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Input.Socket.accept("/tmp/goldfish.sock") end},
        restart: :permanent
      ),
      Input.Keyboard,
      Input.TimeTicker,
      TwitchyPoison
    ]
  end

  @impl true
  def start(_type, _args) do
    children = list_children(System.fetch_env!("MIX_ENV"))
    opts = [strategy: :one_for_one, name: TwitchyPoison.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
