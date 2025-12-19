defmodule JQLTest do
  use ExUnit.Case, async: true

  require JQL

  doctest JQL

  describe "query/1" do
    test "basic" do
      assert query = JQL.query("project" == "TVL")
      assert query == %JQL{query: [{:equals, "project", "TVL"}]}

      assert query = JQL.query(:project == "TVL")
      assert query == %JQL{query: [{:equals, :project, "TVL"}]}

      assert query = JQL.query(:project == "TVL")
      assert query == %JQL{query: [{:equals, :project, "TVL"}]}

      assert query = JQL.query(:project == TVL)
      assert query == %JQL{query: [{:equals, :project, "TVL"}]}
    end

    test "variable interpoation" do
      my_project = "TV Labs"
      assert query = JQL.query(:project == ^my_project)
      assert query == %JQL{query: [{:equals, :project, "TV Labs"}]}

      my_project = "Crazy"
      assert query = JQL.query(:project in [^my_project])
      assert query == %JQL{query: [{:includes, :project, ["Crazy"]}]}
    end

    test "and" do
      my_project = "TV Labs"
      assert query = JQL.query(:project == ^my_project and "Organizations" == "Customer")

      assert query == %JQL{
               query: [
                 {:and, {:equals, :project, "TV Labs"}, {:equals, "Organizations", "Customer"}}
               ]
             }

      assert query = JQL.query(:project == Cool and "Organizations" == "Customer")

      assert query == %JQL{
               query: [
                 {:and, {:equals, :project, "Cool"}, {:equals, "Organizations", "Customer"}}
               ]
             }
    end

    test "in" do
      assert query = JQL.query(:status in ["Done", "Canceled"])
      assert query == %JQL{query: [{:includes, :status, ["Done", "Canceled"]}]}

      assert query = JQL.query(Organizations in ["TVL", "Other"])
      assert query == %JQL{query: [{:includes, "Organizations", ["TVL", "Other"]}]}

      assert query = JQL.query(Organizations in ~w(TVL Other))
      assert query == %JQL{query: [{:includes, "Organizations", ["TVL", "Other"]}]}
    end

    test "not in" do
      assert query = JQL.query(:status not in ["Done", "Canceled"])
      assert query == %JQL{query: [{:excludes, :status, ["Done", "Canceled"]}]}
    end

    test "<" do
      assert query = JQL.query(:created < {:days, -5})
      assert query == %JQL{query: [{:<, :created, {:days, -5}}]}
    end

    test "<=" do
      assert query = JQL.query(:created <= {:days, -5})
      assert query == %JQL{query: [{:<=, :created, {:days, -5}}]}
    end

    test ">" do
      assert query = JQL.query(:created > {:days, -5})
      assert query == %JQL{query: [{:>, :created, {:days, -5}}]}
    end

    test ">=" do
      assert query = JQL.query(:created >= {:days, -5})
      assert query == %JQL{query: [{:>=, :created, {:days, -5}}]}
    end

    test "comparison with interpolation" do
      days = 22
      assert query = JQL.query(:created >= {:days, ^days})
      assert query == %JQL{query: [{:>=, :created, {:days, 22}}]}

      days = -22
      assert query = JQL.query(:created >= {:days, ^days})
      assert query == %JQL{query: [{:>=, :created, {:days, -22}}]}
    end

    test "order by" do
      assert query = JQL.query(order_by: :queried_at)
      assert query == %JQL{order_by: [:queried_at]}

      assert query = JQL.query(order_by: {:desc, :created_at})
      assert query == %JQL{order_by: [{:desc, :created_at}]}

      assert query = JQL.query(order_by: {:asc, :created_at})
      assert query == %JQL{order_by: [{:asc, :created_at}]}

      assert query = JQL.query([:status == "Done", order_by: {:desc, :created_at}])
      assert query == %JQL{query: [{:equals, :status, "Done"}], order_by: [desc: :created_at]}

      assert query =
               JQL.query([
                 :project == "TVL" and :status == "Done",
                 order_by: {:desc, :created_at}
               ])

      assert query == %JQL{
               query: [{:and, {:equals, :project, "TVL"}, {:equals, :status, "Done"}}],
               order_by: [desc: :created_at]
             }
    end
  end

  describe "query/2" do
    test "can take two fragments" do
      assert query =
               JQL.query(:status == Done and Organizations == "TVL", order_by: {:desc, :created})

      assert query == %JQL{
               query: [{:and, {:equals, :status, "Done"}, {:equals, "Organizations", "TVL"}}],
               order_by: [desc: :created]
             }
    end
  end

  describe "where/2" do
    test "can take an existing query and a fragment" do
      jql = JQL.query(:status == "Done")
      assert query = JQL.where(jql, :created >= {:days, -1})

      assert query == %JQL{
               query: [{:and, {:equals, :status, "Done"}, {:>=, :created, {:days, -1}}}]
             }
    end
  end

  describe "join/2" do
    test "it can concatenate queries" do
      one = JQL.query(:status == "Done")
      two = JQL.query(:project == "tvl")

      assert JQL.join(one, two) == JQL.query(:status == "Done" and :project == "tvl")
    end

    test "it is a noop if the query is empty" do
      query = JQL.query([:status == "Done", order_by: :created_at])
      empty = JQL.new([])
      assert JQL.join(query, empty) == query
    end
  end

  describe "to_string/1" do
    test "basic queries" do
      assert to_string(JQL.query(:project == "TVL")) == ~S[project = TVL]

      project = "TV Labs"
      assert to_string(JQL.query(:project == ^project)) == ~S[project = "TV Labs"]

      assert to_string(JQL.query(:project == "TVL" and :status == "Done")) ==
               ~S[project = TVL and status = Done]

      assert to_string(JQL.query(:status in ["Done", "Finished"])) ==
               ~S[status in (Done, Finished)]

      assert to_string(JQL.query("Request Type" == "Report a bug")) ==
               ~S["Request Type" = "Report a bug"]
    end

    test "comparisons with dates" do
      assert to_string(JQL.query(:created_at >= {:days, -5})) == ~S[created_at >= -5d]
    end

    test "with order bys" do
      assert to_string(
               JQL.query([
                 :status in ["Done", "Finished"] and :type == "Feature",
                 order_by: :created_at
               ])
             ) ==
               ~S[status in (Done, Finished) and type = Feature order by created_at]

      assert to_string(JQL.query([:status == "Done", order_by: {:desc, :created_at}])) ==
               ~S[status = Done order by created_at desc]

      assert to_string(JQL.query([:status == "Done", order_by: {:asc, :created_at}])) ==
               ~S[status = Done order by created_at asc]

      assert to_string(
               JQL.query([:status == "Done", order_by: [{:asc, :created_at}, {:desc, :status}]])
             ) ==
               ~S[status = Done order by created_at asc, status desc]
    end
  end

  describe "was_in" do
    test "allows for simple 'was_in' expressions" do
      query = JQL.was_in(JQL.query(:status == "Done"), :status, ["Invalid", "Nope"])

      assert to_string(query) == ~S[status = Done and status was in (Invalid, Nope)]
    end

    test "can use variable interpolation" do
      field = "status"
      states = ["Invalid", "Nope"]
      query = JQL.was_in(JQL.query(:status == "Done"), ^field, ^states)

      assert to_string(query) == ~S[status = Done and status was in (Invalid, Nope)]
    end
  end

  describe "exceptions" do
    test "variables are not allowed as identifiers" do
      message = """
      Invalid JQL expression:

          status == Done

      Clause:

          status

      Reason:

          use atoms or Module syntax for identifiers. To inject a variable, use ^
      """

      assert_raise JQL.InvalidExpressionException, message, fn ->
        Code.eval_string("JQL.query(status == Done)", [], __ENV__)
      end
    end

    test "variables are not allowed as identifiers in order by" do
      message = """
      Invalid JQL expression:

          [order_by: created]

      Clause:

          created

      Reason:

          use atoms or Module syntax for identifiers. To inject a variable, use ^
      """

      assert_raise JQL.InvalidExpressionException, message, fn ->
        Code.eval_string("JQL.query(:status == Done, order_by: created)", [], __ENV__)
      end
    end
  end
end
