Cucumber.compile_features!(
  features: ["test/browser/features/**/*.feature"],
  steps: ["test/browser/steps/**/*.exs"],
  support: ["test/browser/support/**/*.exs"]
)
