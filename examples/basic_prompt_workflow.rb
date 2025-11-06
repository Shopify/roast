# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Business Intelligence from CSV Data
#
# This example demonstrates how to structure a multi-step analysis workflow
# using external prompt files for maintainability and reusability.

config do
  agent do
    provider :claude
    model "haiku"
  end
end

execute do
  # Step 1: Initial data analysis
  agent(:analyze_data) { template("csv_analysis") }

  # Step 2: Geographic analysis
  agent(:customer_locations) { template("customer_locations") }

  # Step 3: Product performance analysis
  agent(:product_analysis) { template("product_popularity") }

  # Step 4: Business recommendations
  agent(:summary) { template("business_summary") }
end