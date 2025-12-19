defmodule JQL.InvalidExpressionException do
  defexception [:expression, :clause, :reason]

  def exception(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end

  def message(exception) do
    """
    Invalid JQL expression:

        #{Macro.to_string(exception.expression)}

    Clause:

        #{Macro.to_string(exception.clause)}

    Reason:

        #{exception.reason}
    """
  end
end
