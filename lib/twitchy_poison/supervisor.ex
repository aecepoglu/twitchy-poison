defmodule TwitchyPoison.Supervisor do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Input.Socket.accept("/tmp/goldfish.sock") end},
        restart: :permanent
      ),
      Input.Keyboard,
      TwitchyPoison
    ]

    opts = [strategy: :one_for_one, name: TwitchyPoison.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
