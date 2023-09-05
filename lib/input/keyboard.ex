defmodule Getch do
  def init(report_to) do
    Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof])
    loop(nil, report_to)
  end

  def loop(_, report_to) do
    receive do
      {_port, {:data, data}} ->
        data
        |> translate
        |> report(report_to)
        |> loop(report_to)
      :quit -> IO.puts("\r\nbye\r")
      _ -> IO.puts("what??")
    end
  end

  defp report(key, dest) do
    send(dest, {:keypress, key})
    key
  end

  defp translate("\d"),    do: :backspace
  defp translate("\r"),    do: :enter
  defp translate("\t"),    do: :tab
  defp translate("\e"),    do: :escape
  defp translate("\e[A"),  do: :arrow_up
  defp translate("\e[B"),  do: :arrow_down
  defp translate("\e[C"),  do: :arrow_right
  defp translate("\e[D"),  do: :arrow_left
  defp translate("\e[F"),  do: :end
  defp translate("\e[H"),  do: :home
  defp translate("\e[3~"), do: :delete
  defp translate("\e[5~"), do: :pg_up
  defp translate("\e[6~"), do: :pg_dn
  defp translate(key),     do: key
end

defmodule Input.Keyboard do
  defp handle({:keypress, "a"}, count), do: count + 1
  defp handle({:keypress, "b"}, count), do: count - 1
  defp handle({:keypress, _}, count), do: count

  defp render(count) do
    IO.write(" \rcount: #{count}")
    count
  end

  defp loop(n, _child) when n >= 5 do
    #send(child, :quit) # TODO I _may not_ be responsible for the termination of my children
    IO.puts("(parent) bye!")
  end

  defp loop(count, child) do
    receive do
      msg ->
        msg
        |> handle(count)
        |> render
        |> loop(child)
    end
  end

  def foo() do
    parent = self()
    IO.puts("press A to incr, B to decr. Reach 5 to end")
    child = spawn(fn -> Getch.init(parent) end)
    Process.monitor(child)
    loop(0, child)
  end
end
