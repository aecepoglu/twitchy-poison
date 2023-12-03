defmodule IRC.Room do
  use GenServer

  defstruct [:id,
             tracks: false,
             chat: CircBuf.make(1024, {"", "-", []}),
             users: %{},
             unread: 0,
             ]

  def start_link(id, opts \\ []) do
    GenServer.start_link(__MODULE__, id, opts)
  end

  @impl true
  def init(id, opts \\ []) do
    tracks = Keyword.get(opts, :tracks, id == "whimsicallymade") # TODO hardcoded
    {:ok, %__MODULE__{id: id, tracks: tracks}}
  end

  @impl true
  def handle_cast({:record_chat, user, msg, badges}, state), do: {:noreply, record_chat(state, {user, msg, badges})}
  def handle_cast({:add_user, user_id}, state), do: {:noreply, add_user(state, user_id)}
  def handle_cast({:remove_user, user_id}, state), do: {:noreply, remove_user(state, user_id)}
  def handle_cast({:tracks, b}, state), do: {:noreply, %{state | tracks: b}}

  @impl true
  def handle_call(:get, _, state) do
    {:reply, state, state}
  end
  def handle_call(:users, _, state) do
    {:reply, state.users, state}
  end
  def handle_call({:peek, num}, _, state) do
    {:reply, peek(state, num), state}
  end
  def handle_call({:render_and_read, size, opts}, _, state) do
    {lines, unread} = render_and_count(state, size, opts)
    reply = {lines, unread, state.unread - unread}
    {:reply, reply, %{state | unread: unread}}
  end
  def handle_call(:list_users, _, state) do
    {:reply, Map.keys(state.users), state}
  end
  def handle_call({:log_user, user_id}, _, state) do
    {:reply, log_user(state, user_id), state}
  end

  def render_and_read(addr, {_,_}=size, opts) do
    {_lines, _unread, _read} = GenServer.call(addr, {:render_and_read, size, opts})
  end

  def record_chat(%__MODULE__{}=room, {a, b}) do
    record_chat(room, {a, b, []})
  end
  def record_chat(%__MODULE__{chat: c}=room, {userid, _, _}=msg) do
    %{room | chat: CircBuf.add(c, msg),
             unread: room.unread + 1 }
    |> track_user(userid)
  end
  def record_chat(addr, user, msg, badges \\ []) do
    GenServer.cast(addr, {:record_chat, user, msg, badges})
  end

  def add_user(%__MODULE__{users: u}=room, user_id) do
    t = Time.utc_now()
    %{room | users: Map.put(u, user_id, {0, t})}
  end
  def add_user(addr, user_id) do
    GenServer.cast(addr, {:add_user, user_id})
  end

  def remove_user(%__MODULE__{users: u}=room, user_id) do
    %{room | users: Map.delete(u, user_id)}
  end
  def remove_user(addr, user_id) do
    GenServer.cast(addr, {:remove_user, user_id})
  end

  def peek(%__MODULE__{chat: c}, count) do
    CircBuf.take(c, count)
    |> Enum.map(fn x ->
      case x do
        {nil, txt}     -> txt
        {nil, txt, _}  -> txt
        {user, txt}    -> "#{user}: #{txt}"
        {user, txt, _} -> "#{user}: #{txt}"
      end
    end)
  end
  def peek(addr, count) do
    GenServer.call(addr, {:peek, count})
  end

  def users(addr) do
    GenServer.call(addr, :users)
  end

  # this is just public for the moment so I can test it easier
  def render_and_count(%__MODULE__{}=room, {width, height}, opts) do
    {new_lines, unread} = if Keyword.get(opts, :skip_unread, false) do
      {[], room.unread}
    else
      get_unread_lines(room.chat, room.unread, {width, height}, opts)
    end
    old_lines = get_old_lines(room.chat, room.unread, {width, height - length(new_lines)}, opts)
    {old_lines ++ new_lines, unread}
  end

  defp get_unread_lines(chat, unread, {width, height}, opts) do
    d_unread = 1
    token = "+"

    f = fn {user, message, badges}, {lines, unread} ->
      color = Keyword.get(badges, :color, nil)

      newlines = wrapped(color, user, message, opts, width - 1)
      |> Enum.map(& token <> &1)
      if unread <= 0 || length(lines) + length(newlines) > height do
        {lines, unread}
      else
        newlines_ = Enum.reverse(newlines)
        {:continue, {newlines_ ++ lines, unread - d_unread}}
      end
    end
    {lines, unread} = CircBuf.reduce_while(chat, {[], unread}, f, offset: unread, step: -1)
    {Enum.reverse(lines), unread}
  end

  defp get_old_lines(chat, unread, {width, height}, opts) do
    token = " "

    f = fn {user, message, badges}, lines ->
      color = Keyword.get(badges, :color, nil)

      newlines = wrapped(color, user, message, opts, width - 1)
      |> Enum.map(& token <> &1)
      if length(lines) + length(newlines) > height do
        lines
      else
        newlines_ = newlines
        {:continue, newlines_ ++ lines}
      end
    end
    _lines = CircBuf.reduce_while(chat, [], f, offset: unread + 1, step: 1)
  end

  defp wrapped(color, user, message, opts, width) do
    opts_ = Keyword.put(opts, :first_indentation, String.length(user))

    lines1 = user
    |> String.Wrap.wrap(width, opts)
    |> Enum.map(& colored(&1, color))

    lines2 = ""  <> ": " <> message
    |> String.Wrap.wrap(width, opts_)

    zip(lines1, lines2, [])
  end

  defp colored(txt, nil), do: txt
  defp colored(txt, color), do: color <> txt <> IO.ANSI.default_color()

  defp zip([h1 | t1], [h2 | t2], acc), do: zip(t1, t2, [(h1 <> h2) | acc])
  defp zip([],        t2,        acc), do: Enum.reverse(acc) ++ t2

  def log_user(%__MODULE__{}=room, user_id) do
    room.chat
    |> CircBuf.to_list()
    |> Enum.filter(fn {u,_,_} -> u == user_id end)
    |> Enum.map(fn {_,msg,_} -> msg end)
  end
  def log_user(addr, user_id) do
    GenServer.call(addr, {:log_user, user_id})
  end

  defp track_user(%__MODULE__{          tracks: false}=room, _), do: room
  defp track_user(%__MODULE__{users: users, tracks: true}=room, userid) do
    t = Time.utc_now()
    users_ = Map.update(users, userid, {1, t}, fn {n, _} -> {n + 1, t} end)
    %{room | users: users_}
  end
end
