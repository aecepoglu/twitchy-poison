defmodule Getch do
  def start do 
    spawn(&init/0)
    :timer.sleep(:infinity)
  end

  def init do
    Logger.configure(level: :critical)
    IO.puts("This is a demo of a basic 'getch' for elixir.")
    IO.puts("It uses 'tty_sl` to read keys and special characters like arrow_up, etc.")
    IO.puts("Press 'x' or 'q' to exit.")
    Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof])
    loop()
  end

  def loop do
    IO.write("\rPRESS ANY KEY> ")
    receive do
      {_port, {:data, data}} ->
        data |> translate |> handle_key |> loop
      _ ->
        loop()
    end
  end

  def terminate do 
    IO.puts("\rBYE\r")
    System.halt()
  end

  def loop("x"), do: terminate()
  def loop("q"), do: terminate()

  def loop(_), do: loop()

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

  defp handle_key(key), do: display(key)

  defp display(key) when is_atom(key) do 
    IO.puts("-atom>:#{key}<")
    key
  end

  defp display(key) do 
    IO.puts("- key>#{key}<")
    key
  end
end

defmodule Input.Keyboard do
  def foo() do
    IO.puts "reading 1 char"
    Getch.start()
  end
end
