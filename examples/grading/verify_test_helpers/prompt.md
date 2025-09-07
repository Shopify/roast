Now identify custom test helpers used in this test for the following purpose:

1. Analyzing if they are used correctly
2. Understanding test code that has had significant chunks of implementation abstracted away into helpers
3. Fully understanding custom assertions that are not included by default in Ruby on Rails or part of your base knowledge

Your grep tool function is vital for this work. It provides 4 lines of context before and after the matching line.

For example, if you call `grep(string: "def assert_sql")`, the output will include:

```
.test/support/helpers/sql_assertions.rb-101-    end
.test/support/helpers/sql_assertions.rb-102-    result
.test/support/helpers/sql_assertions.rb-103-  end
.test/support/helpers/sql_assertions.rb-104-
.test/support/helpers/sql_assertions.rb:105:  def assert_sql(*patterns_to_match, **kwargs, &block)
.test/support/helpers/sql_assertions.rb-106-    mysql_only_test!
.test/support/helpers/sql_assertions.rb-107-
.test/support/helpers/sql_assertions.rb-108-    result = T.let(nil, T.nilable(T::Boolean))
.test/support/helpers/sql_assertions.rb-109-    counter = ActiveRecord::SQLCounter.new(**kwargs)
```

Unfortunately, many test helper methods are undocumented. In those cases (like the example above) the pre-context will be junk. However, there are a number of helper methods that do have very specific and narrow use cases, and those do tend to be well-documented. In those cases, you should use `read_file` to be able to read the full documentation.

For example, here is the result of calling `grep(string: "def assert_sql_events")`

```
.test/support/helpers/externals_helper.rb-93-  # @example Logs events in the list that did not occur
.test/support/helpers/externals_helper.rb-94-  #   expected_queries = { "Shop Load" => 1, "User Load" => 1 }
.test/support/helpers/externals_helper.rb-95-  #   # Fails and reports that User Load occured 0 times instead of expected 1
.test/support/helpers/externals_helper.rb-96-  #   assert_sql_events(expected_queries) { Shop.current_or_find(shop.id) }
.test/support/helpers/externals_helper.rb:97:  def assert_sql_events(expected_events, &block)
.test/support/helpers/externals_helper.rb-98-    mysql_only_test!
.test/support/helpers/externals_helper.rb-99-
.test/support/helpers/externals_helper.rb-100-    mysql_events = ExternalsCollector.new(&block).events
.test/support/helpers/externals_helper.rb-101-      .select { |e| e.first == :mysql }
```

Notice that the documentation for the `assert_sql_events` method is cutoff. Use your `read_file` tool function to get the whole test helper source code and gain better understanding of how it is intended to be used, with the side benefit of also being able to see how it is implemented.

Note: You will undoubtedly already be familiar with some of Minitest and RSpec's built-in helpers. There is no need to search for those, since they are packaged as gems you won't find them anyway.

DO NOT FORGET TO PREPEND `def` TO YOUR QUERY TO FIND A METHOD DEFINITION INSTEAD OF USAGES, otherwise you may bring back a very large and useless result set!!!

Once you are done understanding the custom test helpers used in the test file, analyze and report on whether it seems like any of the helpers are:

1. Used incorrectly
2. Used unnecessarily
3. Any other problem related to the use of helper methods

Where possible, use your best judgment to make recommendations for how to fix problems that you find, but ONLY related to test helpers.

Note: You are only being used to help find problems so it is not necessary to report on correct usage of helpers or to make positive comments.
