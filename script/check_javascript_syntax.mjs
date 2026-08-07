import { spawnSync } from "node:child_process"
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const copiedController = "app/javascript/controllers/rails_table_preferences_controller.js"

function normalizePackageTarget(target) {
  return target.replace(/^\.\//, "")
}

function collectExportTargets(value, targets = new Set()) {
  if (typeof value === "string") {
    const target = normalizePackageTarget(value)
    if (target.endsWith(".js")) targets.add(target)
    return targets
  }

  if (value && typeof value === "object" && !Array.isArray(value)) {
    Object.values(value).forEach((nestedValue) => collectExportTargets(nestedValue, targets))
  }

  return targets
}

const packageJson = JSON.parse(readFileSync(path.join(repoRoot, "package.json"), "utf8"))
const syntaxTargets = [copiedController, ...collectExportTargets(packageJson.exports)].sort()

syntaxTargets.forEach((target) => {
  const absoluteTarget = path.join(repoRoot, target)
  if (!existsSync(absoluteTarget)) {
    throw new Error(`JavaScript syntax target is missing: ${target}`)
  }

  const result = spawnSync(process.execPath, ["--check", absoluteTarget], {
    cwd: repoRoot,
    encoding: "utf8"
  })

  if (result.status !== 0) {
    process.stdout.write(result.stdout || "")
    process.stderr.write(result.stderr || "")
    throw new Error(`JavaScript syntax check failed: ${target}`)
  }

  console.log(`JavaScript syntax ok: ${target}`)
})

await verifyPackageImportResolution()

async function verifyPackageImportResolution() {
  const sandboxRoot = mkdtempSync(path.join(os.tmpdir(), "rails-table-preferences-import-"))

  try {
    const packageRoot = path.join(sandboxRoot, "node_modules", packageJson.name)
    mkdirSync(packageRoot, { recursive: true })
    writeFileSync(
      path.join(packageRoot, "package.json"),
      `${JSON.stringify({
        name: packageJson.name,
        version: packageJson.version,
        type: packageJson.type,
        exports: packageJson.exports
      }, null, 2)}\n`
    )
    cpSync(path.join(repoRoot, "app", "javascript"), path.join(packageRoot, "app", "javascript"), { recursive: true })
    normalizeSandboxRelativeImports(packageRoot)
    writeStimulusStub(path.join(sandboxRoot, "node_modules", "@hotwired", "stimulus"))

    const smokeModule = path.join(sandboxRoot, "smoke.mjs")
    writeFileSync(smokeModule, packageImportSmokeSource(packageJson.name))

    await import(pathToFileURL(smokeModule).href)
    console.log(`JavaScript package import resolution ok: ${packageJson.name}`)
    console.log(`JavaScript package import resolution ok: ${packageJson.name}/controller`)
  } finally {
    rmSync(sandboxRoot, { recursive: true, force: true })
  }
}

function normalizeSandboxRelativeImports(packageRoot) {
  const controllerEntry = path.join(packageRoot, "app", "javascript", "rails_table_preferences", "controller.js")
  const source = readFileSync(controllerEntry, "utf8")
  const normalizedSource = source.replace(
    "from \"../controllers/rails_table_preferences_controller\"",
    "from \"../controllers/rails_table_preferences_controller.js\""
  )

  if (normalizedSource === source) {
    throw new Error("Package import smoke could not normalize the controller entrypoint import")
  }

  writeFileSync(controllerEntry, normalizedSource)
}

function writeStimulusStub(stubRoot) {
  mkdirSync(stubRoot, { recursive: true })
  writeFileSync(
    path.join(stubRoot, "package.json"),
    `${JSON.stringify({ name: "@hotwired/stimulus", version: "0.0.0-smoke", type: "module", exports: "./index.js" }, null, 2)}\n`
  )
  writeFileSync(
    path.join(stubRoot, "index.js"),
    `export class Controller {\n  static targets = []\n  static values = {}\n\n  dispatch(name, options = {}) {\n    return { name, ...options }\n  }\n}\n`
  )
}

function packageImportSmokeSource(packageName) {
  return `
import packageRootDefault, { RailsTablePreferencesController as namedController } from ${JSON.stringify(packageName)}
import controllerDefault from ${JSON.stringify(`${packageName}/controller`)}

const imports = {
  packageRootDefault,
  namedController,
  controllerDefault
}

for (const [name, value] of Object.entries(imports)) {
  if (typeof value !== "function") {
    throw new Error("Expected " + name + " to resolve to a controller class, got " + typeof value)
  }

  if (typeof value.prototype.showAllEditorColumns !== "function") {
    throw new Error("Expected " + name + " to expose showAllEditorColumns")
  }
}

if (packageRootDefault !== namedController) {
  throw new Error("Package root default and named RailsTablePreferencesController export diverged")
}
`
}
