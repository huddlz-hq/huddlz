# Register scenarios only when this test file is selected, so focused ExUnit
# runs do not execute the entire behavior suite as a side effect of setup.
Cucumber.compile_features!()
