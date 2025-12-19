defmodule JQL do
  @moduledoc """
  JQL is an Elixir DSL for writing Atlassian Jira Query Language expressions.

  ## Features

  * Compile-time validation of queries
  * Query composition
  * Syntax highlighting

  ## Examples

  ### Compound queries

      iex> query = JQL.query(:status == "Done" and :created >= {:days, -5}, order_by: {:desc, :updated})
      iex> to_string(query)
      ~S[status = Done and created >= -5d order by updated desc]

  ### Query Composition

  ```elixir
  query = JQL.query(:status == "Done")

  if created_after = opts[:created_after] do
    JQL.query(query, :created >= ^created_after)
  else
    query
  end
  ```
  """

  defstruct query: [], order_by: []

  @doc false
  def new({query, order_by}) do
    new(query: query, order_by: order_by)
  end

  def new(values) do
    struct!(__MODULE__, values)
  end

  @doc """
  DSL for expressing a JQL query as elixir terms

      iex> jql = JQL.query(:project == "tvl" and Organizations in ["TV Labs", "ITV"])
      iex> to_string(jql)
      ~S[project = tvl and Organizations in ("TV Labs", ITV)]
  """
  defmacro query(expression) do
    {query, order_by} = parse_expression(expression)

    quote bind_quoted: [query: query, order_by: order_by] do
      JQL.new({query, order_by})
    end
  end

  @doc """
  DSL for epxressing writing elixir terms with a trailing order_by

      iex> jql = JQL.query(:project == "tvl", order_by: :created)
      iex> to_string(jql)
      ~S[project = tvl order by created]
  """
  defmacro query(one, two) do
    one = parse_expression(one)
    two = parse_expression(two)

    quote bind_quoted: [one: one, two: two] do
      JQL.join(
        JQL.new(one),
        JQL.new(two)
      )
    end
  end

  @doc """
  Appends a JQL expression to an existing query

      iex> jql = JQL.query(:project == "tvl")
      iex> to_string(JQL.where(jql, :status == "Done"))
      ~S[project = tvl and status = Done]

  Order by supported too

      iex> jql = JQL.query(:project == "tvl" and :status == "Done")
      iex> to_string(JQL.where(jql, order_by: :created_at))
      ~S[project = tvl and status = Done order by created_at]

  """
  defmacro where(query, expression) do
    extension = parse_expression(expression)

    quote bind_quoted: [query: query, extension: extension] do
      JQL.join(%JQL{} = query, JQL.new(extension))
    end
  end

  @doc """
  Concatenates two query expressions

  Queries will be joined together with an `and` expression
  """
  def join(%__MODULE__{} = one, %__MODULE__{} = two) do
    query =
      if one.query == [] or two.query == [] do
        one.query ++ two.query
      else
        [{:and, simplify_query(one.query), simplify_query(two.query)}]
      end

    %__MODULE__{query: query, order_by: one.order_by ++ two.order_by}
  end

  @doc """
  Allows for writing `field was in (value1, value2)` type expressions
  """
  defmacro was_in(query, field, values) do
    was_in = {:{}, [], [:was_in, parse_fragment(field), parse_fragment(values)]}

    quote bind_quoted: [query: query, was_in: was_in] do
      JQL.join(%JQL{} = query, JQL.new(query: [was_in]))
    end
  end

  defp simplify_query([one]), do: one
  defp simplify_query(other), do: other

  defp parse_expression(expression) do
    {query, order_by} =
      expression
      |> List.wrap()
      |> Enum.reduce({[], []}, fn
        {:order_by, _} = fragment, {query, order_by} ->
          {query, [parse_order_by(fragment) | order_by]}

        fragment, {query, order_by} ->
          {[parse_fragment(fragment) | query], order_by}
      end)

    {Enum.reverse(query), Enum.reverse(order_by)}
  catch
    {clause, reason} ->
      raise JQL.InvalidExpressionException,
        expression: expression,
        clause: clause,
        reason: reason
  end

  defp parse_fragment({:__aliases__, _meta, [atom]}) do
    Atom.to_string(atom)
  end

  defp parse_fragment({:==, _meta, [left, right]}) do
    {:{}, [], [:equals, parse_fragment(left), parse_fragment(right)]}
  end

  defp parse_fragment({:and, _meta, [left, right]}) do
    {:{}, [], [:and, parse_fragment(left), parse_fragment(right)]}
  end

  defp parse_fragment({:or, _meta, [left, right]}) do
    {:{}, [], [:or, parse_fragment(left), parse_fragment(right)]}
  end

  defp parse_fragment({:in, _meta, [left, right]}) do
    {:{}, [], [:includes, parse_fragment(left), parse_fragment(right)]}
  end

  defp parse_fragment({:not, _, [{:in, _, [left, right]}]}) do
    {:{}, [], [:excludes, parse_fragment(left), parse_fragment(right)]}
  end

  defp parse_fragment({atom, _meta, nil} = clause) when is_atom(atom) do
    throw_invalid_variable(clause)
  end

  defp parse_fragment({operator, _meta, [left, right]}) when operator in [:<, :<=, :>, :>=] do
    {:{}, [], [operator, parse_fragment(left), process_comparison_value(right)]}
  end

  defp parse_fragment(value) when is_atom(value) or is_binary(value) do
    value
  end

  defp parse_fragment(list) when is_list(list) do
    Enum.map(list, &parse_fragment/1)
  end

  defp parse_fragment({:^, _, [{_, _, nil} = var]}) do
    quote do
      Kernel.var!(unquote(var))
    end
  end

  defp parse_fragment({:-, _meta, _} = negation) do
    negation
  end

  defp parse_fragment({:sigil_w, _, _} = fragment) do
    fragment
  end

  defp parse_fragment(expression) do
    throw({expression, "not supported"})
  end

  defp parse_order_by({:order_by, order_by}) do
    case order_by do
      {direction, value} when direction in [:desc, :asc] ->
        {:{}, [], [direction, parse_order_by_fragment(value)]}

      value ->
        parse_order_by_fragment(value)
    end
  end

  defp parse_order_by_fragment(list) when is_list(list) do
    Enum.map(list, &parse_order_by_fragment/1)
  end

  defp parse_order_by_fragment({direction, identifier}) when direction in [:asc, :desc] do
    {direction, parse_identifier(identifier)}
  end

  defp parse_order_by_fragment(identifier) do
    parse_identifier(identifier)
  end

  defp parse_identifier(atom) when is_atom(atom), do: atom

  defp parse_identifier({atom, _, nil} = clause) when is_atom(atom) do
    throw_invalid_variable(clause)
  end

  defp parse_identifier({:^, _, [{_, _, nil} = var]}) do
    quote do
      Kernel.var!(unquote(var))
    end
  end

  defp process_comparison_value(value) do
    case value do
      {unit, variable} when unit in [:days] ->
        {unit, parse_fragment(variable)}

      {:^, _, [{_, _, nil} = var]} ->
        quote do
          Kernel.var!(unquote(var))
        end
    end
  end

  defp throw_invalid_variable(clause) do
    reason = "use atoms or Module syntax for identifiers. To inject a variable, use ^"
    throw({clause, reason})
  end

  defimpl String.Chars do
    def to_string(jql) do
      query = query_to_list(jql.query)
      order_by = order_by_to_list(jql.order_by)

      IO.iodata_to_binary([query, order_by])
    end

    defp query_to_list(query) do
      Enum.map(query, &fragment_to_list/1)
    end

    @infix [
      :and,
      :or,
      :includes,
      :excludes,
      :equals,
      :was_in,
      :<,
      :<=,
      :>,
      :>=
    ]
    defp fragment_to_list({infix, left, right}) when infix in @infix do
      operator =
        case infix do
          :includes -> "in"
          :excludes -> "not in"
          :equals -> "="
          :was_in -> "was in"
          other -> Atom.to_string(other)
        end

      [fragment_to_list(left), " ", operator, " ", fragment_to_list(right)]
    end

    defp fragment_to_list(list) when is_list(list) do
      list = list |> Enum.map(&fragment_to_list/1) |> Enum.intersperse(", ")
      ["(", list, ")"]
    end

    defp fragment_to_list(binary) when is_binary(binary) do
      if String.contains?(binary, " ") do
        ["\"", binary, "\""]
      else
        [binary]
      end
    end

    defp fragment_to_list(atom) when is_atom(atom) do
      [Atom.to_string(atom)]
    end

    defp fragment_to_list(number) when is_integer(number) do
      [Integer.to_string(number)]
    end

    defp fragment_to_list(number) when is_float(number) do
      [Float.to_string(number)]
    end

    defp fragment_to_list({:days, number}) do
      "#{number}d"
    end

    defp order_by_to_list([]), do: []

    defp order_by_to_list(value) do
      case value do
        {direction, value} ->
          [" order by ", Enum.map(value, &order_by_fragment_to_list/1), " ", direction]

        value ->
          [" order by ", Enum.map(value, &order_by_fragment_to_list/1)]
      end
    end

    defp order_by_fragment_to_list(list) when is_list(list) do
      list |> Enum.map(&order_by_fragment_to_list/1) |> Enum.intersperse([", "])
    end

    defp order_by_fragment_to_list({direction, identifier}) do
      [Kernel.to_string(identifier), " ", Atom.to_string(direction)]
    end

    defp order_by_fragment_to_list(identifier) do
      [Kernel.to_string(identifier)]
    end
  end
end
