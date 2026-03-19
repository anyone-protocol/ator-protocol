import subprocess
import os

# Find all files that are just pure renames, and undo the renames from "anon" to "tor"
git_find_renames_command = ["git", "--no-pager", "diff", "--name-status", "--diff-filter=R", "last-commit-before-fork...main"]
output = subprocess.check_output(git_find_renames_command)
output_lines = output.decode("utf-8").splitlines()
if not output_lines:
  print("No renamed files found.")
num_pure_renames = 0
for line in output_lines:
  split_line = line.split("\t")
  if len(split_line) == 3:
    status, old_path, new_path = split_line
    similarity_index = int(status[1:])
    if similarity_index != 100:
      print(f"Skipping {old_path} -> {new_path} because similarity index is {similarity_index}%")
      continue
    os.rename(new_path, old_path)
    num_pure_renames += 1
print(f"Renamed {num_pure_renames} files back to their original names.")
