defmodule Twitch.Eventsub do
  use WebSockex
  @rest_url "http://127.0.0.1:8080/"
  @ws_url "ws://127.0.0.1:8080/ws"
  @my_clientid "er74mamcsw4il4ctkzvzrznnj9t2w1"
  @my_userid "818716685"

  defstruct [
    :auth_token,
    :subscribed,
    :on_welcome,
    :session_id,
    on_deathbed: false,
  ]

  def start_link(opts) do
    url = Keyword.get(opts, :resume_url, @ws_url)
    on_welcome = Keyword.get(opts, :on_welcome, nil)
    subscribed = Keyword.has_key?(opts, :resume_url)
    
    IO.inspect({"Twitch.Eventsub", :start_link, opts})
    state = %__MODULE__{
      auth_token: Twitch.Auth.get(),
      on_welcome: on_welcome,
      subscribed: subscribed
    }
    conn = make_conn(url, state)
    WebSockex.start_link(conn, __MODULE__, state, opts)
  end

  @impl true
  def handle_frame({:text, json}, state) do
    case Poison.decode(json) do
      {:ok, map} -> handle_json_frame(map, state)
      _ -> {:ok, state}
    end
  end

  defp handle_json_frame(%{"metadata" => metadata, "payload" => payload}, state) do
    handle(metadata, payload, state)
  end

  defp handle(%{"message_type" => "session_keepalive"}, _, state) do
    {:ok, state}
  end
  defp handle(%{"message_type" => "session_welcome"}, %{"session" => %{"id" => session_id}}, %__MODULE__{}=state) do
    if state.on_welcome != nil do
      try do
        state.on_welcome.()
      rescue
        err -> IO.inspect({:caught, err})
      catch
        err -> IO.inspect({:caught, err})
      end
    end

    if state.subscribed == false do
      headers = make_headers(state)
      transport = %{
        "method" => "websocket",
        "session_id" => session_id}

      subscribe("channel.follow", "2", %{
        "broadcaster_user_id" => @my_userid,
        "moderator_user_id" => @my_userid,
      }, transport, headers) |> IO.inspect

      subscribe("channel.raid", "1", %{
        "to_broadcaster_user_id" => @my_userid,
      }, transport, headers) |> IO.inspect
    end

    {:ok, %{state | session_id: session_id, subscribed: true, on_welcome: nil}}
  end
  defp handle(%{"message_type" => "notification"}=msg, payload, state) do
    handle_notification(msg, payload, state)
  end
  defp handle(%{"message_type" => "session_reconnect"}, payload, state) do
    handle_reconnect(payload, state)
  end
  defp handle(msg, payload, state) do
    IO.inspect({"unhandled message", msg, payload, state})
    {:ok, state}
  end

  defp handle_notification(%{"subscription_type" => "channel.follow"}, %{"event" => %{"user_name" => name}}, state) do
    Hub.cast({:notification, {:followed, name}})
    {:ok, state}
  end
  defp handle_notification(%{"subscription_type" => "channel.raid"}, payload, state) do
    Hub.cast({:notification, {
      :raid,
      payload["event"]["from_broadcaster_user_name"],
      payload["event"]["viewers"]
    }})
    {:ok, state}
  end
  defp handle_notification(msg, payload, state) do
    IO.inspect({"unhandled notification", msg, payload, state})
    {:ok, state}
  end

  defp handle_reconnect(%{"session" => %{"reconnect_url" => url}}, state) do
    Twitch.Eventsub.Supervisor.reconnect_soon(url)
    {:ok, %{state | on_deathbed: true}}
  end

  defp subscribe(topic, version, condition, transport, headers) do
     body = %{
      "type" => topic,
      "version" => version,
      "condition" => condition,
      "transport" => transport,
    }
    HTTPoison.post(@rest_url <> "eventsub/subscriptions", Poison.encode!(body), headers)
  end

  defp make_conn(url, state) do
    headers = make_headers(state)
    WebSockex.Conn.new(url, extra_headers: headers)
  end

  defp make_headers(%{auth_token: token}) do
    [ "Authorization": "Bearer #{token}",
      "Client-Id": @my_clientid,
      "Content-Type": "application/json"
    ]
  end
end
