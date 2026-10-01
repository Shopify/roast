# How to contribute

## Things we will merge

* Bugfixes
* Performance improvements
* Features that are likely to be useful to the majority of Roast users
* Documentation updates that are concise and likely to be useful to the majority of Roast users

## Things we won't merge

* Code that introduces considerable performance degrations
* Code that touches performance-critical parts of Roast and comes without benchmarks
* Features that are not important for most people (we want to keep the core Roast code small and tidy)
* Features that can easily be implemented on top of Roast
* Code that does not include tests
* Code that breaks existing tests
* Documentation changes that are verbose, incorrect or not important to most people (we want to keep it simple and easy to understand)

## Workflow

* [Sign the CLA](https://cla.shopify.com/) if you haven't already
* Fork the Roast repository
* Create a new branch in your fork
  * For updating [Roast documentation](https://shopify.github.io/roast/), create it from `gh-pages` branch. (You can skip tests.)
* If it makes sense, add tests for your code and/or run a performance benchmark
* Make sure all tests pass (`bundle exec rake`)
* Create a pull request

## Releasing

* Bump the version in `lib/roast/version.rb`
* Update the `CHANGELOG.md` file
* Open a PR like and merge it to `main`
* Create a new release using the [GitHub UI](https://github.com/Shopify/roast/releases/new)
