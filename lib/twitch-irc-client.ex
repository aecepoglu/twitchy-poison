defmodule IRC.Badge do
  @hex "0123456789ABCDEF" |> String.graphemes |> Enum.with_index |> Map.new

  def parse(str) do
      str
      |> String.split(";")
      |> Enum.map(& String.split(&1, "="))
      |> Enum.map(&identify/1)
      |> Enum.filter(& &1 != nil)
  end

  defp identify(["color", x]), do: {:color, color_hex_to_decimal(x)}
  defp identify(["first-msg", x]), do: {:first, str_to_bool(x)}
  defp identify(["returning-chatter", x]), do: {:returning, str_to_bool(x)}
  defp identify(["display-name", x]), do: {:name, x}
  defp identify(_), do: nil

  defp str_to_bool("0"), do: false
  defp str_to_bool("1"), do: true

  defp color_hex_to_decimal("#" <> str) do
    String.graphemes(str)
    |> Enum.map(&@hex[&1])
    |> Enum.chunk_every(2)
    |> Enum.map(fn [a, b] -> a * 16 + b |> to_string end)
    |> then(& ["38", "2" | &1])
    |> Enum.join(";")
    |> then(& "\e[#{&1}m")
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
  def handle_call({:fetch, {_,_}=id}, _, {pids, _}=state) do
    {:reply, Map.fetch(pids, id), state}
  end
  def handle_call(:list, _, {pids, _}=state), do: {:reply, Map.keys(pids), state}

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_or_create({_,_}=id), do: GenServer.call(__MODULE__, {:get_or_create, id})
  def fetch({_,_}=id), do: GenServer.call(__MODULE__, {:fetch, id})
  def list(), do: GenServer.call(__MODULE__, :list)
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
    {:ok, first} = :gen_tcp.recv(client, 0)
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

  @bots MapSet.new([":commanderroot", "smallstreamersdiscord_"])

  def start_link(_name, opts) do
    oauth_token = Twitch.Auth.get()
    nickname = "whimsicallymade"
    {:ok, pid} = WebSockex.start_link("ws://irc-ws.chat.twitch.tv:80", __MODULE__, %{}, opts)
    [ "CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands",
      "PASS oauth:#{oauth_token}",
      "NICK #{nickname}",
    ]
    |> Enum.each(fn x -> :ok = WebSockex.send_frame(pid, {:text, x}) end)

    {:ok, pid}
  end

  @impl true
  def handle_frame({:text, "PING " <> _}, state), do: {:reply, {:text, "PONG :tmi.twitch.tv"}, state}
  def handle_frame({:text, msg}, state) do
    lines = msg
    |> String.split("\r\n")
    |> Enum.map(& String.split(&1, " "))

    {replies, state_} = Enum.reduce(lines, {[], state},
      fn x, {replies, state_} ->
        {reply, state__} = incoming(x, state_)
        {[reply | replies], state__}
      end)
    case {Enum.filter(replies, & &1 != nil), state_} do
      {[], s} -> {:ok, s}
      {r,  s} -> r_ = r |> Enum.map(& &1 <> "\r\n")
                        |> Enum.join()
                 IO.inspect({"reply", r_})
                 {:reply, {:text, r_}, s}
    end
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

  defp incoming([userid, "PRIVMSG", ("#" <> room) | words], state) do
    incoming(["", userid, "PRIVMSG", room | words], state)
  end
  defp incoming([_badge, _userid, "PRIVMSG", room, ":!hello"], state) do
    {"PRIVMSG #{room} :world", state}
  end
  defp incoming([badge, userid, "PRIVMSG", ("#" <> room) | words], state) do
    txt = case words do
      [":" <> h | t] -> [h | t]
      _ -> []
    end |> Enum.map(&Chat.censor/1)
        |> Enum.join(" ")

    id = {"twitch", room}

    id
    |> IRC.RoomRegistry.get_or_create
    |> IRC.Room.record_chat(username(userid), txt, IRC.Badge.parse(badge))

    Hub.cast({:received_chat_msg, id})
    {nil, state}
  end
  defp incoming([userid, "JOIN", "#" <> room], state) do
    if !MapSet.member?(@bots, userid) do
      {"twitch", room}
      |> IRC.RoomRegistry.get_or_create
      |> IRC.Room.add_user(username(userid))
    end
    {nil, state}
  end
  defp incoming([userid, "PART", "#" <> room], state) do
    id = {"twitch", room}
    
    case IRC.RoomRegistry.fetch(id) do
      {:ok, pid} -> GenServer.cast(pid, {:remove_user, username(userid)})
      _ -> nil
    end
    {nil, state}
  end
  defp incoming([_, _, "ROOMSTATE", _room], state), do: {nil, state}
  defp incoming([_, _, "USERSTATE", _room], state), do: {nil, state}
  defp incoming([_, _, "GLOBALUSERSTATE"], state), do: {nil, state}
  defp incoming([""], state), do: {nil, state}
  defp incoming([], state), do: {nil, state}
  defp incoming(list, state) do
    txt = Enum.join(list, " ")
    {"twitch", "-"}
    |> IRC.RoomRegistry.get_or_create
    |> IRC.Room.record_chat("-", txt)
    {nil, state}
  end
  defp username(str) do
    case String.split(str, "!") do
      [(":" <> h)| _] -> h
      [ h        | _] -> h
      _              -> str
    end
  end
end

defmodule Chat do
  @cuss """
  javascript
""" |> String.trim |> String.split |> MapSet.new

  def censor("NotLikeThis"), do: "x.x"
  def censor(word) do
    if MapSet.member?(@cuss, word) do
      word |> String.length() |> Geometry.hor_line('*')
    else
      word
    end
  end
end
