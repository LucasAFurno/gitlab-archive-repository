A lightweight, interactive Bash script that automates archiving one or more GitLab projects via the GitLab API. Simply paste a list of project URLs, and the script will:

Load your API token securely (from GITLAB_TOKEN or a local file, with automatic prompting and safe storage)

Parse all .git URLs from your input

Batch archive each project, showing pass/fail feedback

Verify the archived status of every project

Offer auto-confirm mode for non-interactive use (-y)

Provide a help menu (-h) and customizable token file path (-t)

No extra dependencies beyond standard Unix tools (bash, curl, grep, jq, python3). Ideal for anyone who needs a quick, repeatable way to archive multiple GitLab repositories.
