defmodule IRC.Room do
  use GenServer

  defstruct [:id,
             names: [],
             chat: CircBuf.make(1024, {"", "-"}),
             ]

  @impl true
  def init(id) do
    {:ok, %__MODULE__{id: id}}
  end

  @impl true
  def handle_cast({:record, user, msg}, state) do
    {:noreply, record_chat(state, {user, msg})}
  end

  @impl true
  def handle_call(:get, _, state) do
    {:reply, state, state}
  end
  def handle_call({:peek, num}, _, state) do
    {:reply, peek(state, num), state}
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, id)
  end

  def record_chat(%__MODULE__{chat: c}=room, {_, _}=msg) do
    %{room | chat: CircBuf.add(c, msg)}
  end

  def peek(%__MODULE__{chat: c}, count) do
    CircBuf.take(c, count)
    |> Enum.map(fn x ->
      case x do
        {nil, txt} -> txt
        {user, txt} -> "#{user}: #{txt}"
      end
    end)
  end

  def render(%__MODULE__{chat: c}, {width, height}) do
    CircBuf.reduce_while(c, [],
      fn {user, message}, acc ->
        lines = user <> ": " <> message
        |> String.Wrap.wrap_at(width)
        if length(acc) + length(lines) > height do
          acc
        else
          {:continue, acc ++ lines} #TODO fails if data has :continue
        end
      end
    )
    |> Enum.reverse()
  end
end

defmodule IRC.RoomRegistry do
  use GenServer
  @impl true
  def init(nil) do
    {:ok, {%{}, %{}}}
  end

  @impl true
  def handle_call({:get_or_create, {_, room}=id}, _from, {pids, refs}) do
    if Map.has_key?(pids, id) do
      pid = Map.fetch!(pids, id)
      {:reply, pid, {pids, refs}}
    else
      {:ok, pid} = IRC.Room.start_link(room)
      ref = Process.monitor(pid)
      pids_ = Map.put(pids, id, pid)
      refs_ = Map.put(refs, pid, ref)
      {:reply, pid, {pids_, refs_}}
    end
  end
  def handle_call({:get, {_,_}=id}, _, {pids, _}=state) do
    {:reply, Map.fetch(pids, id), state}
  end
  def handle_call(:list, _, {pids, _}=state), do: {:reply, Map.keys(pids), state}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def get(pid, {_,_}=id), do: GenServer.call(pid, {:get, id})
end

defmodule OAuthServer do
  @redirport 3456

  def navigate() do
    roles = ["moderator:read:followers", "chat:read", "chat:edit"]
    clientid = "er74mamcsw4il4ctkzvzrznnj9t2w1"
    url = %URI{
      scheme: "https",
      host: "id.twitch.tv",
      path: "/oauth2/authorize",
    }
    |> URI.append_query("response_type=token")
    |> URI.append_query("client_id=#{clientid}")
    |> URI.append_query("redirect_uri=http://localhost:#{@redirport}")
    |> URI.append_query("scope=" <> Enum.join(roles, "+"))
    |> URI.to_string()
    System.cmd("firefox", [url])
  end

  def listen() do
    opts = [:binary,
            packet: :line,
            active: false,
            reuseaddr: true
            ]
    {:ok, sock} = :gen_tcp.listen(@redirport, opts)
    {:ok, client} = :gen_tcp.accept(sock)
    {:ok, _first} = :gen_tcp.recv(client, 0)
    :ok = send_redir_response(client)
    :ok = :gen_tcp.close(client)
    {:ok, client} = :gen_tcp.accept(sock)
    {:ok, auth_token} = recv_auth_token(client)
    send_html_response(client, "<script>window.close()</script>I am done. You can close the tab.")
    :ok = :gen_tcp.close(client)
    :ok = :gen_tcp.close(sock)
    {:ok, auth_token}
  end

  defp send_html_response(client, body) do
    :gen_tcp.send(client, """
HTTP/1.1 200 OK
Date: #{Time.utc_now()}
Content-Type: text/html
Content-Length: #{String.length(body)}

#{body}
""")
  end

  defp send_redir_response(client) do
    body = """
<script>if(location.hash.includes('#')){
window.location.href=location.hash.replace('#','?')}</script> Redirecting...
"""
    send_html_response(client, body)
  end

  defp recv_auth_token(client) do
    {:ok, first} = :gen_tcp.recv(client, 0) |> IO.inspect()
    ["GET", path | _] = String.split(first)
    {:ok, %URI{}=uri} = URI.new(path)
    case URI.decode_query(uri.query) do
      %{"access_token" => x} -> {:ok, x}
      _                      -> {:error, "unable to find auth token"}
    end
  end

  def whatever() do
    navigate()
    listen()
  end
end

defmodule Twitch.IrcClient do
  # TODO this is very close to being a generic IRC client
  #      move the twitch specific stuff elsewhere and make it so
  use WebSockex

  def start_link(opts) do
    oauth_token = Twitch.Auth.get()
    nickname = "whimsicallymade"
    resp = {:ok, pid} = WebSockex.start_link("ws://irc-ws.chat.twitch.tv:80", __MODULE__, %{}, opts)
    # :ok = WebSockex.send_frame(pid, {:text, "CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands"})
    :ok = WebSockex.send_frame(pid, {:text, "PASS oauth:#{oauth_token}"})
    :ok = WebSockex.send_frame(pid, {:text, "NICK #{nickname}"})
    resp
  end

  @impl true
  def handle_frame({:text, "PING " <> _}, state), do: {:reply, {:text, "PONG :tmi.twitch.tv"}, state}
  def handle_frame({:text, msg}, state) do
    lines = msg
    |> String.split("\r\n")
    |> Enum.map(& String.split(&1, " "))

    state_ = Enum.reduce(lines, state, &incoming/2)
    {:ok, state_}
  end
  def handle_frame({type, msg}, state) do
    IO.puts "Received Message - Type: #{inspect type} -- Message: #{inspect msg}"
    {:ok, state}
  end

  @impl true
  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts "Sending #{type} frame with payload: #{msg}"
    {:reply, frame, state}
  end

  defp incoming([_badges, userid, "PRIVMSG", room | words], state) do
    incoming([userid, "PRIVMSG", room | words], state)
  end
  defp incoming([userid, "PRIVMSG", room | words], state) do
    ":" <> txt = Enum.join(words, " ")
    id = {"twitch", room}
    pid = GenServer.call(:rooms, {:get_or_create, id})
    Hub.cast({:received_chat_msg, id})
    GenServer.cast(pid, {:record, username(userid), txt})
    state
  end
  defp incoming([_userid, "JOIN", _room], state), do: state
  defp incoming([_userid, "PART", _room], state), do: state
  defp incoming([_, _, "ROOMSTATE", _room], state), do: state
  defp incoming([_, _, "USERSTATE", _room], state), do: state
  defp incoming([_, _, "GLOBALUSERSTATE"], state), do: state
  defp incoming([""], state), do: state
  defp incoming([], state), do: state
  defp incoming(list, state) do
    IO.inspect(list)
    state
  end
  defp username(str) do
    case String.split(str, "!") do
      [h | _] -> h
      _ -> str
    end
  end

  def foo() do
    #{:ok, auth_token} = OAuthServer.whatever()
    #nickname = "whimsicallymade"
    #pid = Twitch.IrcClient.init(auth_token, nickname)
    #:ok = WebSockex.send_frame(pid, {:text, "JOIN #aysart"})
    #:ok = WebSockex.send_frame(pid, {:text, "PART #aysart"})
  end
end
