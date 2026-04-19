#!/usr/bin/env node

import { existsSync } from "node:fs"
import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

const readOnlyTools = new Set(["Read", "Grep", "Glob"])
const reasoningEffortMap = {
  minimal: "low",
  low: "low",
  medium: "medium",
  high: "high",
  max: "xhigh",
}

const scriptPath = fileURLToPath(import.meta.url)
const scriptDirectory = path.dirname(scriptPath)
const repoRoot = path.dirname(scriptDirectory)

const options = {
  source: path.join(repoRoot, ".claude", "agents"),
  output: path.join(repoRoot, ".codex", "agents"),
  dryRun: false,
}

const argumentsList = process.argv.slice(2)

for (let index = 0; index < argumentsList.length; index += 1) {
  const argument = argumentsList[index]

  if (argument === "--dry-run") {
    options.dryRun = true
  } else if (argument === "--source") {
    index += 1
    options.source = path.resolve(repoRoot, argumentsList[index])
  } else if (argument.startsWith("--source=")) {
    options.source = path.resolve(repoRoot, argument.slice("--source=".length))
  } else if (argument === "--output") {
    index += 1
    options.output = path.resolve(repoRoot, argumentsList[index])
  } else if (argument.startsWith("--output=")) {
    options.output = path.resolve(repoRoot, argument.slice("--output=".length))
  } else {
    throw new Error(`Unknown argument: ${argument}`)
  }
}

await mkdir(options.output, { recursive: true })

const sourceEntries = await readdir(options.source, { withFileTypes: true })
const agentFiles = sourceEntries
  .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
  .map((entry) => entry.name)
  .sort()
const expectedOutputFiles = new Set(agentFiles.map((file) => file.replace(/\.md$/u, ".toml")))
const outputEntries = await readdir(options.output, { withFileTypes: true })
const staleOutputFiles = outputEntries
  .filter((entry) => entry.isFile() && entry.name.endsWith(".toml") && !expectedOutputFiles.has(entry.name))
  .map((entry) => entry.name)
  .sort()

const results = []

for (const agentFile of agentFiles) {
  const sourcePath = path.join(options.source, agentFile)
  const outputPath = path.join(options.output, agentFile.replace(/\.md$/u, ".toml"))
  const sourceContent = await readFile(sourcePath, "utf8")
  const { frontmatter, body } = parseAgentMarkdown(sourceContent, sourcePath)
  const nextContent = renderCodexAgent(frontmatter, body)
  const previousContent = existsSync(outputPath) ? await readFile(outputPath, "utf8") : null
  const changed = previousContent !== nextContent

  if (changed && !options.dryRun) {
    await writeFile(outputPath, nextContent)
  }

  results.push({
    name: frontmatter.name,
    outputPath,
    changed,
  })
}

for (const staleFile of staleOutputFiles) {
  const stalePath = path.join(options.output, staleFile)

  if (!options.dryRun) {
    await rm(stalePath)
  }

  results.push({
    name: staleFile,
    outputPath: stalePath,
    changed: true,
    removed: true,
  })
}

for (const result of results) {
  const status = result.removed
    ? options.dryRun
      ? "would remove"
      : "removed"
    : result.changed
      ? options.dryRun
        ? "would write"
        : "wrote"
      : "unchanged"
  console.log(`${status}: ${result.name} -> ${result.outputPath}`)
}

function parseAgentMarkdown(sourceContent, sourcePath) {
  const match = sourceContent.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/u)

  if (match) {
    const frontmatter = {}
    const frontmatterLines = match[1].split("\n").filter((line) => line.trim().length > 0)

    for (const line of frontmatterLines) {
      const separatorIndex = line.indexOf(":")

      if (separatorIndex >= 0) {
        const key = line.slice(0, separatorIndex).trim()
        const value = line.slice(separatorIndex + 1).trim()
        frontmatter[key] = stripWrappingQuotes(value)
      } else {
        throw new Error(`Invalid frontmatter line in ${sourcePath}: ${line}`)
      }
    }

    if (frontmatter.name) {
      if (frontmatter.description) {
        return {
          frontmatter,
          body: match[2].trim(),
        }
      }

      throw new Error(`Missing required field "description" in ${sourcePath}`)
    }

    throw new Error(`Missing required field "name" in ${sourcePath}`)
  }

  throw new Error(`Expected YAML frontmatter in ${sourcePath}`)
}

function stripWrappingQuotes(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1)
  }

  return value
}

function parseList(value) {
  if (!value) {
    return []
  }

  if (value.startsWith("[") && value.endsWith("]")) {
    return value
      .slice(1, -1)
      .split(",")
      .map((item) => stripWrappingQuotes(item.trim()))
      .filter(Boolean)
  }

  return value
    .split(",")
    .map((item) => stripWrappingQuotes(item.trim()))
    .filter(Boolean)
}

function renderCodexAgent(frontmatter, body) {
  const tools = parseList(frontmatter.tools)
  const nicknameCandidates = parseList(frontmatter.codex_nickname_candidates)
  const sandboxMode =
    frontmatter.codex_sandbox_mode ||
    (tools.length > 0 && tools.every((tool) => readOnlyTools.has(tool)) ? "read-only" : null)
  const model = frontmatter.codex_model || null
  const reasoningEffort =
    frontmatter.codex_reasoning_effort || reasoningEffortMap[frontmatter.effort] || null
  const lines = [
    `name = ${toTomlString(frontmatter.name)}`,
    `description = ${toTomlString(frontmatter.description)}`,
  ]

  if (model) {
    lines.push(`model = ${toTomlString(model)}`)
  }

  if (reasoningEffort) {
    lines.push(`model_reasoning_effort = ${toTomlString(reasoningEffort)}`)
  }

  if (sandboxMode) {
    lines.push(`sandbox_mode = ${toTomlString(sandboxMode)}`)
  }

  if (nicknameCandidates.length > 0) {
    lines.push(`nickname_candidates = ${toTomlArray(nicknameCandidates)}`)
  }

  lines.push(`developer_instructions = ${toTomlMultilineString(body)}`)

  return `${lines.join("\n")}\n`
}

function toTomlString(value) {
  return JSON.stringify(value)
}

function toTomlArray(values) {
  return `[${values.map((value) => toTomlString(value)).join(", ")}]`
}

function toTomlMultilineString(value) {
  return `"""\n${value.replaceAll('"""', '\\"\\"\\"')}\n"""`
}
