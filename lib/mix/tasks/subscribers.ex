defmodule Mix.Tasks.Subscribers do
  @moduledoc """
  module doc
  """
  @shortdoc "short doc"
  @requirements ["app.start"]

  @directory "~/note/logs/followers/" |> Path.expand

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    followers = list_followers()
    followers_data = format(followers)

    path = "#{@directory}/#{DateTime.utc_now() |> DateTime.to_unix}"
    File.write(path, followers_data)
    Mix.shell().info(followers_data)
    Mix.shell().info("saved to #{path}")

    # list_prev_followers() # TODO
  end

  defp diff(prev_list, new_list) do
    nil
  end

  defp list_prev_followers() do
    case File.ls(@directory) do
      {:ok, [_|_]=list} ->
        list
        |> Enum.sort()
        |> List.first
        |> then(& Path.join(@directory, &1))
        |> read_followers_file()
      err ->
        IO.inspect(err)
        []
    end
  end

  defp read_followers_file(path) do
    File.read!(path)
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&deserialise/1)
  end

  defp list_followers() do
    my_userid = "818716685"
    auth_token = Twitch.Auth.get()
    headers = Twitch.Eventsub.make_headers(%{auth_token: auth_token})

    Twitch.Request.channels_followers(my_userid, headers)
    |> Enum.map(fn %{"user_id" => id, "followed_at" => t, "user_login" => login, "user_name" => name} ->
        %{user_id: id,
          followed_at: t,
          user_login: login,
          user_name: name}
        end)
  end

  defp format(list) when is_list(list) do
    list
    |> Enum.map(&serialise /1)
    |> Enum.join("\n")
  end

  defp serialise(%{user_id: id, followed_at: t, user_login: login, user_name: name}) do
    [id, login, name, t]
    |> Enum.join("\t")
  end

  defp deserialise(str) do
    [id, login, name, t] = String.split(str, "\t")
    %{user_id: id, followed_at: t, user_login: login, user_name: name}
  end
end
