defmodule TwitchyPoison.Supervisor do
  @moduledoc false
  @common [
      {DynamicSupervisor, name: IRC.Supervisor, strategy: :one_for_one},
      Twitch.Eventsub.Supervisor,
      Twitch.Auth,
      {Registry, keys: :unique, name: Registry.IRC},
      #{Backup, [:hourglass_backup, Progress.Hourglass.make(), name: :hourglass_backup]},
      #{Backup, [:todo_backup, Todo.empty(), name: :todo_backup]},
  ]

  use Application

  def list_children(:test), do: @common ++ [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> Input.Socket.listen(4444, :port) end},
        restart: :permanent
      )
    ]
  def list_children(m) when m in [:dev, :prod] do
    socket_path = Application.fetch_env!(:twitchy_poison, :socket_path)
    @common ++ [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> Input.Socket.listen(socket_path, :filepath, rmfile: true) end},
        restart: :permanent
      ),
      Hub,
    ]
  end
  def list_children(:repl), do: @common

  @impl true
  def start(_type, _args) do
    children = Application.get_env(:twitchy_poison, :environment, :prod)
    |> list_children()

    opts = [strategy: :one_for_one, name: TwitchyPoison.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
