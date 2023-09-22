defmodule TodoTest do
  use ExUnit.Case
  import Todo
  test "string" do
    right = empty()
    |> add(%Todo{label: "1"}, :push_out)
    |> add(%Todo{label: "2"}, :push_out)
    |> del
    |> add(%Todo{label: "3"}, :push_out)
    |> strings(40, color: false)

    left = [
      "  ○ 3",
      "  ○ 1"
    ]

    assert left == right
  end

  test "long lines fold" do
    right = empty()
    |> add(%Todo{label: "hii"}, :push_out)
    |> add(%Todo{label: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen"}, :push_out)
    |> add(%Todo{label: "bye"}, :push_out)
    |> join
    |> add(%Todo{label: "ungrouped"}, :push_out)
    |> strings(40, color: false)

    left = [
      "  ○ ungrouped",
      "╭ ○ bye",
      "│ ○ one two three four five six seven ei",
      "│   ght nine ten eleven twelve thirteen ",
      "╰   fourteen fifteen sixteen seventeen",
      "  ○ hii",
    ]
    assert left == right
  end

  test "mark_done" do
    right = empty()
    |> add(%Todo{label: "one"}, :push_out)
    |> add(%Todo{label: "two"}, :push_out)
    |> add(%Todo{label: "three"}, :push_out)
    |> join
    |> mark_done!

    expected = [
      [ %Todo{             label: "two"},
        %Todo{done?: true, label: "three"},
      ],
      %Todo{             label: "one"},
    ]
    assert right == expected
  end

  test "join eagerly" do
    created = empty()
    |> add(%Todo{label: "one"}, :push_out)
    |> add(%Todo{label: "two"}, :push_out)
    |> add(%Todo{label: "three"}, :push_out)
    |> join
    |> join
    |> add(%Todo{label: "four"}, :push_out)
    |> add(%Todo{label: "five"}, :push_out)
    |> add(%Todo{label: "six"}, :push_out)
    |> join_eager
    |> add(%Todo{label: "seven"}, :push_out)
    |> add(%Todo{label: "eight"}, :push_out)
    |> add(%Todo{label: "nine"}, :push_out)
    |> join_eager
    |> strings(40)

    expected = [
      "╭ ○ nine",
      "│ ○ eight",
      "╰ ○ seven",
      "╭ ○ six",
      "│ ○ five",
      "╰ ○ four",
      "╭ ○ three",
      "│ ○ two",
      "╰ ○ one",
    ]
    assert expected == created
  end

  test "mark_done rotates tasks" do
    t1 = %Todo{label: "one"}
    t2 = %Todo{label: "two"}
    t3 = %Todo{label: "three", done?: true}

    assert [t2, t3, %{t1 | done?: true}] == mark_done!([t1, t2, t3])
  end
end

defmodule TodoParserTest do
  use ExUnit.Case
  import Todo.Parser, only: [parse: 1]

  test "strings go as is" do
    assert parse("what is this?") == %{label: "what is this?", hook: nil}
  end
  test "empty string" do
    assert parse("") == %{label: "", hook: nil}
  end
  test "todobqn hook" do
    assert parse("who what when todobqn:something here") == %{label: "who what when here", hook: [todobqn: "something"]}
  end
end
