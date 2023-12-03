defmodule ChatBot do
  def reply(room, "hello") do
    "PRIVMSG #{room} :world"
  end
  def reply(_, _), do: nil
end

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

  defp color_hex_to_decimal(""), do: IO.ANSI.default_color()
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

defmodule Twitch.IrcClient do
  # TODO this is very close to being a generic IRC client
  #      move the twitch specific stuff elsewhere and make it so
  use WebSockex

  @my_chan "twitch"
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

  defp incoming([_badge, _userid, "PRIVMSG", room, ":!" <> txt], state) do
    {ChatBot.reply(room, txt), state}
  end

  defp incoming([badge, userid, "PRIVMSG", ("#" <> room) | words], state) do
    txt = case words do
      [":" <> h | t] -> [h | t]
      _ -> []
    end |> Enum.map(&ChatMsg.censor/1)
        |> Enum.join(" ")

    id = {@my_chan, room}

    id
    |> IRC.via
    |> IRC.Room.record_chat(username(userid), txt, IRC.Badge.parse(badge))

    Hub.cast({:received_chat_msg, id})
    {nil, state}
  end

  defp incoming([userid, "JOIN", "#" <> room], state) do
    if !MapSet.member?(@bots, userid) do

      {@my_chan, room}
      |> IRC.via
      |> IRC.Room.add_user(username(userid))
    end
    {nil, state}
  end

  defp incoming([userid, "PART", "#" <> room], state) do
    id = {@my_chan, room}

    id
    |> IRC.via
    |> IRC.Room.remove_user(username(userid))

    {nil, state}
  end

  defp incoming([_, _, "ROOMSTATE", _room], state), do: {nil, state}
  defp incoming([_, _, "USERSTATE", _room], state), do: {nil, state}
  defp incoming([_, _, "GLOBALUSERSTATE"], state), do: {nil, state}
  defp incoming([""], state), do: {nil, state}
  defp incoming([], state), do: {nil, state}

  defp incoming(list, state) do
    txt = Enum.join(list, " ")

    {@my_chan, "-"}
    |> IRC.via
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

defmodule ChatMsg do
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
