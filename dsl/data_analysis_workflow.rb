# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Multi-step Data Analysis using Chat
#
# This workflow demonstrates complex chat orchestration for business intelligence
# from CSV data. It shows how to chain multiple chat calls, pass data between
# steps, and build comprehensive analysis workflows.

config do
  chat(:analyst) do
    model("gpt-4o-mini")
    assume_model_exists(true)
  end
end

execute do
  # Step 1: Initial data overview
  chat(:overview) do
    "I have a CSV file with skateboard sales data. Please analyze the structure and provide an overview of what insights we can extract. Focus on identifying key metrics and patterns to investigate."
  end

  # Step 2: Customer segmentation analysis
  chat(:customers) do
    template("customer_analysis", {
      overview: chat!(:overview).response
    })
  end

  # Step 3: Product performance analysis
  chat(:products) do
    template("product_analysis", {
      overview: chat!(:overview).response,
      customer_insights: chat!(:customers).response
    })
  end

  # Step 4: Business recommendations
  chat(:recommendations) do
    template("business_recommendations", {
      overview: chat!(:overview).response,
      customer_analysis: chat!(:customers).response,
      product_analysis: chat!(:products).response
    })
  end

  # Step 5: Executive summary
  chat(:summary) do
    "Based on all the previous analyses, create a concise executive summary highlighting the top 3 business insights and actionable recommendations for the skateboard business."
  end
end