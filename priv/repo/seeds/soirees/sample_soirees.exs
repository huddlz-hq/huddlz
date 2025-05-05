# Seeds for sample soirees
alias Huddlz.Soirees.Soiree
alias Huddlz.Soirees.Generators.SoireeGenerator
alias Huddlz.Accounts.Generators.UserGenerator

# Check if soirees already exist
{:ok, existing_soirees} = Ash.read(Soiree)

if Enum.empty?(existing_soirees) do
  IO.puts("Creating sample soirées...")
  
  # Create random hosts
  host1 = UserGenerator.user() |> Ash.Generator.generate()
  host2 = UserGenerator.user() |> Ash.Generator.generate()
  
  # Create soirées for each host using generate_many
  soirees1 = SoireeGenerator.soiree(host: host1) |> Ash.Generator.generate_many(5)
  soirees2 = SoireeGenerator.soiree(host: host2) |> Ash.Generator.generate_many(5)
  
  IO.puts("Created #{length(soirees1) + length(soirees2)} sample soirées!")
else
  IO.puts("Soirées already exist, skipping seed data creation")
end