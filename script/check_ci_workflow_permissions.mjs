import { readFileSync } from "node:fs"

const workflowPath = ".github/workflows/ci.yml"
const workflowSource = readFileSync(workflowPath, "utf8").replace(/\r\n?/g, "\n")

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function assertIncludes(source, needle, label) {
  assert(source.includes(needle), `${label}: missing ${needle}`)
}

function topLevelWorkflowPermissions(source) {
  const match = source.match(/^permissions:\n(?<body>(?:  [a-z-]+: .+\n)+)/m)
  assert(match, `${workflowPath} must declare top-level GITHUB_TOKEN permissions`)
  return match.groups.body
}

const permissionsBlock = topLevelWorkflowPermissions(workflowSource)

assertIncludes(
  permissionsBlock,
  "  contents: read\n",
  `${workflowPath} top-level workflow permissions`
)

assert(
  !/^  contents: write$/m.test(permissionsBlock),
  `${workflowPath} must not request write contents permission for CI jobs`
)

assert(
  !/^  pull-requests: write$/m.test(permissionsBlock),
  `${workflowPath} must not request pull request write permission for CI jobs`
)

console.log("Checked CI workflow read-only GITHUB_TOKEN permissions.")
