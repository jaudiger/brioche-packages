# Get project metadata
mut project = $env.project
  | from json

# Retrieve the latest release information from GitHub
# Include GitHub Token if present (for increased rate limits)
mut gh_headers = []
if ($env.GITHUB_TOKEN? | default "") != "" {
  $gh_headers ++= [Authorization $'Bearer ($env.GITHUB_TOKEN)']
}

let releaseInfo = http get --headers $gh_headers $'https://api.github.com/repos/($env.repoOwner)/($env.repoName)/releases/latest'

# Extract the version
let tagName = $releaseInfo
  | get tag_name

let parsedTagName = $tagName
  | parse --regex $env.matchTag
if ($parsedTagName | length) == 0 {
  error make { msg: $'Latest release tag ($tagName) did not match regex ($env.matchTag)' }
}

mut version = $parsedTagName.0.version?
if $version == null {
  error make { msg: $'Regex ($env.matchTag) did not include version when matching latest release tag ($tagName)' }
}

if $env.normalizeVersion == "true" {
  $version = $version
    | str replace --all --regex "(-|_)" "."
}

$project = $project
  | update version $version

if ($project | get extra?.versionDash?) != null {
  let $versionDash = $version
    | str replace --all "." "-"

  $project = $project
    | update extra.versionDash $versionDash
}

if ($project | get extra?.versionUnderscore?) != null {
  let $versionUnderscore = $version
    | str replace --all "." "_"

  $project = $project
    | update extra.versionUnderscore $versionUnderscore
}

# Extract the release date (if needed by the project)
if ($project | get extra?.releaseDate?) != null {
  let $createdDate = $releaseInfo
    | get created_at
    | into datetime
    | format date "%Y-%m-%d"

  $project = $project
    | update extra.releaseDate $createdDate
}

# Return back the project metadata encoded as JSON
$project
  | to json
