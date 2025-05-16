alias Huddlz.Communities.Huddl
alias Huddlz.Communities.Generators.HuddlGenerator
alias Huddlz.Accounts.Generators.UserGenerator

# Check if huddlz already exist
{:ok, existing_huddlz} = Ash.read(Huddl)

if Enum.empty?(existing_huddlz) do
  IO.puts("Creating sample huddlz...")
  
  # Create random hosts
  host1 = UserGenerator.user() |> Ash.Generator.generate()
  host2 = UserGenerator.user() |> Ash.Generator.generate()
  host3 = UserGenerator.user() |> Ash.Generator.generate()
  host4 = UserGenerator.user() |> Ash.Generator.generate()
  
  # Create 20 huddlz distributed among hosts using generate_many
  huddl1 = HuddlGenerator.huddl(host: host1) |> Ash.Generator.generate_many(5)
  huddl2 = HuddlGenerator.huddl(host: host2) |> Ash.Generator.generate_many(5)
  huddl3 = HuddlGenerator.huddl(host: host3) |> Ash.Generator.generate_many(5)
  huddl4 = HuddlGenerator.huddl(host: host4) |> Ash.Generator.generate_many(5)
  
  IO.puts("Created #{length(huddl1) + length(huddl2) + length(huddl3) + length(huddl4)} sample huddls!")
else
  IO.puts("Huddlz already exist, skipping seed data creation")
end
