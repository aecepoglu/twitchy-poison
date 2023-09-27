defmodule TwitchyPoison.Supervisor do
  @moduledoc false
  @common [
      {DynamicSupervisor, name: IRC.Supervisor, strategy: :one_for_one},
      {Twitch.Auth, name: :twitch_auth},
      {IRC, name: :irc_hub},
  ]

  use Application


  def list_children(:test), do: @common ++ [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> Input.Socket.listen(4444, :port) end},
        restart: :permanent
      )
    ]
  def list_children(m) when m in [:dev, :prod] , do: @common ++ [
      {Task.Supervisor, name: Input.Socket.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> Input.Socket.listen("/tmp/goldfish.sock", :filepath, rmfile: true) end},
        restart: :permanent
      ),
      # Input.Keyboard,
      Hub,
      Chore,
    ]
  def list_children(:repl), do: @common

  @impl true
  def start(_type, _args) do
    children = Application.get_env(:twitchy_poison, :environment, :prod)
    |> list_children()

    opts = [strategy: :one_for_one, name: TwitchyPoison.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
