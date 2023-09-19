defmodule TodoTest do
  use ExUnit.Case
  import Todo
  test "string" do
    right = empty()
    |> add(%Todo{label: "1"})
    |> add(%Todo{label: "2"})
    |> del
    |> add(%Todo{label: "3"})
    |> strings(40, color: false)

    left = [
      "  [ ] 3",
      "  [ ] 1"
    ]

    assert left == right
  end

  test "long lines fold" do
    right = empty()
    |> add(%Todo{label: "hii"})
    |> add(%Todo{label: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen"})
    |> add(%Todo{label: "bye"})
    |> join
    |> add(%Todo{label: "ungrouped"})
    |> strings(40, color: false)

    left = [
      "  [ ] ungrouped",
      "╭ [ ] bye",
      "│ [ ] one two three four five six seven ",
      "│     eight nine ten eleven twelve thirt",
      "│     een fourteen fifteen sixteen seven",
      "╰     teen",
      "  [ ] hii",
    ]
    assert left == right
  end

  test "mark_done" do
    right = empty()
    |> add(%Todo{label: "one"})
    |> add(%Todo{label: "two"})
    |> add(%Todo{label: "three"})
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
