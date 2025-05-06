# Seeds for sample huddls
alias Huddlz.Huddls.Huddl
alias Huddlz.Huddls.Generators.HuddlGenerator
alias Huddlz.Accounts.Generators.UserGenerator

# Check if huddls already exist
{:ok, existing_huddls} = Ash.read(Huddl)

if Enum.empty?(existing_huddls) do
  IO.puts("Creating sample huddls...")
  
  # Create random hosts
  host1 = UserGenerator.user() |> Ash.Generator.generate()
  host2 = UserGenerator.user() |> Ash.Generator.generate()
  host3 = UserGenerator.user() |> Ash.Generator.generate()
  host4 = UserGenerator.user() |> Ash.Generator.generate()
  
  # Create 20 huddls distributed among hosts using generate_many
  huddls1 = HuddlGenerator.huddl(host: host1) |> Ash.Generator.generate_many(5)
  huddls2 = HuddlGenerator.huddl(host: host2) |> Ash.Generator.generate_many(5)
  huddls3 = HuddlGenerator.huddl(host: host3) |> Ash.Generator.generate_many(5)
  huddls4 = HuddlGenerator.huddl(host: host4) |> Ash.Generator.generate_many(5)
  
  IO.puts("Created #{length(huddls1) + length(huddls2) + length(huddls3) + length(huddls4)} sample huddls!")
else
  IO.puts("Huddls already exist, skipping seed data creation")
end