# AGENTS.md

## Overview

minimal-project is a Node.js application that prints "Hello world".

## Language & Tools

- Language: JavaScript
- Runtime: Node.js
- Entry point: `index.js`
- Package manager: npm

## Commands

- `npm start` — Run the application (`node index.js`)

## Project Structure

```
index.js       — Main entry point
package.json   — npm manifest
```

## Conventions

- Single-file project with no dependencies
- No build step required
- All logic lives in `index.js`

## For Agents

- To run the project: `npm start`
- To modify behavior, edit `index.js`
- No test suite exists — verify changes by running `npm start` and checking output
