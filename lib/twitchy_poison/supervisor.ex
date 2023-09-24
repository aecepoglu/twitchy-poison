defmodule TwitchyPoison.Supervisor do
  @moduledoc false

  use Application

  def list_children(_hide_deps=true), do: [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> Input.Socket.listen(4444, :port) end},
        restart: :permanent
      )
    ]
  def list_children(_hide_deps=false) do
    [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> Input.Socket.listen("/tmp/goldfish.sock", :filepath, rmfile: true) end},
        restart: :permanent
      ),
      Input.Keyboard,
      Hub,
      Chore,
    ]
  end

  @impl true
  def start(_type, _args) do
    children = Application.get_env(:twitchy_poison, :hide_deps, true)
    |> list_children()

    opts = [strategy: :one_for_one, name: TwitchyPoison.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
