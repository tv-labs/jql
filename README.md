# JQL

An Ecto-like DSL for the [Jira Query Language](https://support.atlassian.com/jira-service-management-cloud/docs/use-advanced-search-with-jira-query-language-jql/)

> [!WARNING]
> This library is currently experimental. It will have bugs, the API may completely change, and error messages may be obtuse. Use at your own risk.

## Example

``` elixir
days = -7
JQL.query(:status == Done and :created >= {:days, ^days})
```

## Roadmap

- [x] Remove the variable-like syntax e.g. `JQL.query(status == "Done")` in favor of `JQL.query(:status == "Done")`
- [x] Improve error messages when syntax is invalid
- [ ] Figure out a way to override operator associativity (Elixir AST will not contain parenthesis)
- [ ] Provide stronger guarantees for accepting valid query fragments (We currently allow you to write invalid queries)

## Installation

```elixir
def deps do
  [
    {:jql, "~> 0.0.1"}
  ]
end
```
