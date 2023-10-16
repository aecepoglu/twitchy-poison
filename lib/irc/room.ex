defmodule IRC.Room do
  use GenServer

  defstruct [:id,
             chat: CircBuf.make(1024, {"", "-", []}),
             users: MapSet.new(),
             unread: 0,
             ]

  @impl true
  def init(id) do
    {:ok, %__MODULE__{id: id}}
  end

  @impl true
  def handle_cast({:record_chat, user, msg, badges}, state), do: {:noreply, record_chat(state, {user, msg, badges})}
  def handle_cast({:add_user, user_id}, state), do: {:noreply, add_user(state, user_id)}
  def handle_cast({:remove_user, user_id}, state), do: {:noreply, remove_user(state, user_id)}

  @impl true
  def handle_call(:get, _, state) do
    {:reply, state, state}
  end
  def handle_call({:peek, num}, _, state) do
    {:reply, peek(state, num), state}
  end
  def handle_call({:render_and_read, size, opts}, _, state) do
    reply = {_, unread} = render_and_count(state, size, opts)
    {:reply, reply, %{state | unread: unread}}
  end
  def handle_call(:list_users, _, state) do
    {:reply, MapSet.to_list(state.users), state}
  end
  def handle_call({:log_user, user_id}, _, state) do
    {:reply, log_user(state, user_id), state}
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, id)
  end

  def render_and_read(pid, {_,_}=size, opts) when is_pid(pid) do
    {_lines, _unread} = GenServer.call(pid, {:render_and_read, size, opts})
  end

  def record_chat(pid, user, msg, badges \\ []) when is_pid(pid) do
    GenServer.cast(pid, {:record_chat, user, msg, badges})
  end
  def record_chat(%__MODULE__{}=room, {a, b}) do
    record_chat(room, {a, b, []})
  end
  def record_chat(%__MODULE__{chat: c}=room, {_, _, _}=msg) do
    %{room | chat: CircBuf.add(c, msg),
             unread: room.unread + 1}
  end

  def add_user(pid, user_id) when is_pid(pid) do
    GenServer.cast(pid, {:add_user, user_id})
  end
  def add_user(%__MODULE__{users: u}=room, user_id) do
    %{room | users: MapSet.put(u, user_id)}
  end

  def remove_user(pid, user_id) when is_pid(pid) do
    GenServer.cast(pid, {:remove_user, user_id})
  end
  def remove_user(%__MODULE__{users: u}=room, id) do
    %{room | users: MapSet.put(u, id)}
  end

  def peek(pid, count) when is_pid(pid) do
    GenServer.call(pid, {:peek, count})
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

  # this is just public for the moment so I can test it easier
  def render_and_count(%__MODULE__{chat: c, unread: unread0}, {width, height}, opts) do
    skip = if Keyword.get(opts, :skip_unread, false) do unread0 else 0 end
    {lines, unread_} = CircBuf.reduce_while(c, {[], unread0 - skip}, [skip: skip],
      fn {user, message, badges}, {lines, unread} ->
        color = Keyword.get(badges, :color, nil)
        token = if unread > 0 do "+" else " " end

        newlines = wrapped(color, user, message, opts, width - 1)
        |> Enum.reverse
        |> Enum.map(& token <> &1)
        if length(lines) + length(newlines) > height do
          {lines, unread}
        else
          {:continue, {lines ++ newlines,
                       unread - 1}} #TODO fails if data has :continue
        end
      end
    )
    {Enum.reverse(lines), skip + max(0, unread_)}
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

  def log_user(pid, user_id) when is_pid(pid) do
    GenServer.call(pid, {:log_user, user_id})
  end
  def log_user(%__MODULE__{}=room, user_id) do
    room.chat
    |> CircBuf.to_list()
    |> Enum.filter(fn {u,_,_} -> u == user_id end)
    |> Enum.map(fn {_,msg,_} -> msg end)
  end
end
