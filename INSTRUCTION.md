# INSTRUCTION.md - Beginner's Guide to `awesome-function-calling`

Welcome! This guide assumes you have **never** used a terminal, Git, Visual Studio Code, or Python before. Follow it top to bottom and you'll go from "empty computer" to comfortably browsing and using this repository.

> **A quick, important note before you start:**
> `awesome-function-calling` is a **documentation and reference repository** - a curated set of Markdown guides explaining how function calling / tool calling works across OpenAI, Claude, and Gemini. It is **not** a software application you install and run. There's no server to start, no `.env` file to configure, and no API keys required just to use it. This guide will still walk you through every tool a beginner needs (Python, Git, VS Code, terminal basics), because they're useful skills and because the optional "local preview server" step in Section 9 uses Python. But don't be surprised that there's no "app" launching - reading this guide will make sense of that.

---

## Table of Contents

1. [Installing Python](#1-installing-python)
2. [Installing Git](#2-installing-git)
3. [Installing Visual Studio Code](#3-installing-visual-studio-code)
4. [Recommended VS Code Extensions](#4-recommended-vs-code-extensions)
5. [Opening the Project](#5-opening-the-project)
6. [What's a Terminal? What's a Virtual Environment?](#6-whats-a-terminal-whats-a-virtual-environment)
7. [Creating and Activating a Virtual Environment (Optional)](#7-creating-and-activating-a-virtual-environment-optional)
8. [Installing Dependencies](#8-installing-dependencies)
9. [Running / Viewing the Project](#9-running--viewing-the-project)
10. [Using Every Feature of This Repo](#10-using-every-feature-of-this-repo)
11. [Testing](#11-testing)
12. [Troubleshooting](#12-troubleshooting)
13. [FAQ](#13-faq)
14. [Common Mistakes](#14-common-mistakes)
15. [Security Recommendations](#15-security-recommendations)
16. [Next Learning Steps](#16-next-learning-steps)

---

## 1. Installing Python

Python is a programming language. You don't strictly *need* it to read this repository, but it's useful for two things: (a) trying out the code snippets shown in the docs, and (b) optionally running a local "preview server" in Section 9.

1. Go to **https://www.python.org/downloads/**
2. Click the big yellow **"Download Python"** button (it auto-detects your OS).
3. **Windows:** Run the installer. On the very first screen, **check the box that says "Add python.exe to PATH"** at the bottom - this is the single most common thing beginners forget, and skipping it causes most "python is not recognized" errors later.
4. **macOS:** Run the downloaded `.pkg` installer and click through with default options.
5. Confirm it worked: open a terminal (see Section 6 if you're not sure what that is) and type:
   ```
   python --version
   ```
   On macOS you may need `python3 --version` instead. You should see something like `Python 3.12.x`.

## 2. Installing Git

Git is a tool for downloading (cloning) and tracking changes to code/documentation projects like this one.

1. Go to **https://git-scm.com/downloads**
2. Download the installer for your OS and run it.
3. **Windows:** Accept all the default options during install - they're fine for beginners.
4. **macOS:** If you have Xcode Command Line Tools, Git may already be installed. The installer will tell you if it's already present.
5. Confirm it worked:
   ```
   git --version
   ```
   You should see something like `git version 2.4x.x`.

## 3. Installing Visual Studio Code

VS Code is a free code/text editor - think of it as a much more powerful version of Notepad, built for reading and writing code and Markdown.

1. Go to **https://code.visualstudio.com/**
2. Click **Download** for your operating system.
3. Run the installer with default settings.
4. Open VS Code once to confirm it launches.

## 4. Recommended VS Code Extensions

Extensions add features to VS Code. Open the **Extensions** panel (the four-squares icon on the left sidebar, or `Ctrl+Shift+X` / `Cmd+Shift+X`), search for, and install:

| Extension | Why you need it |
|---|---|
| **Markdown All in One** | Adds a live preview, table of contents generation, and formatting shortcuts for the many `.md` files in this repo. |
| **Markdown Preview Enhanced** (optional) | Nicer rendering for Markdown, including Mermaid-style diagrams if you add any later. |
| **Python** (by Microsoft) | Syntax highlighting and IntelliSense if you try running/editing any of the Python code snippets shown in the docs. |
| **GitLens** (optional) | Adds helpful Git history/blame info directly in the editor - useful once you start making your own changes. |

## 5. Opening the Project

1. **Download the project.** If you received it as a `.zip` file, right-click it and choose **"Extract All"** (Windows) or double-click it (macOS) to unzip it into a folder.
2. **Open it in VS Code:**
   - Open VS Code.
   - Go to **File -> Open Folder...** (macOS: **File -> Open...**).
   - Select the extracted `awesome-function-calling` folder.
3. You should now see the file tree on the left: `README.md`, and folders like `openai/`, `claude/`, `gemini/`, `templates/`, etc.

## 6. What's a Terminal? What's a Virtual Environment?

- **Terminal**: a text-based way to give your computer commands, instead of clicking icons. VS Code has one built in: open it with **Terminal -> New Terminal** in the top menu, or the shortcut `` Ctrl+` `` (backtick).
- **Virtual environment**: an isolated, self-contained space for a Python project's dependencies, so they don't clash with other Python projects on your machine. Think of it as a separate, clean toolbox just for one project.

## 7. Creating and Activating a Virtual Environment (Optional)

This repository has **no Python package to install**, so a virtual environment isn't required to *use* it. It's only useful if you want to experiment with the code snippets shown in the docs (e.g., the `jsonschema` validation example in the root `README.md`). If you'd like to try that:

**Windows (in the VS Code terminal):**
```
python -m venv venv
venv\Scripts\activate
```

**macOS (in the VS Code terminal):**
```
python3 -m venv venv
source venv/bin/activate
```

You'll know it worked because your terminal prompt will now show `(venv)` at the start of the line.

## 8. Installing Dependencies

This repository does not ship a `requirements.txt` because there is no application to install - it's documentation only. If you're experimenting with a specific code snippet from one of the guides (e.g. the JSON Schema validation example) and it uses a library like `jsonschema`, install just that library inside your activated virtual environment:

```
pip install jsonschema
```

Repeat with whatever library name the snippet you're trying imports.

## 9. Running / Viewing the Project

There is no app to "run." Here are your three options, from simplest to most involved:

**Option A - Just read it in VS Code (simplest, no setup):**
Click any `README.md` file in the file tree on the left, then press `Ctrl+Shift+V` (Windows) or `Cmd+Shift+V` (macOS) to open a rendered Markdown preview.

**Option B - Read it directly on GitHub (if it's hosted there):**
GitHub automatically renders `README.md` files, including the folder structure, links, and code blocks - no setup needed at all.

**Option C - Serve it locally as a mini static site (optional, for convenience):**
If you'd like to browse all the docs through your web browser instead of file-by-file in an editor, the included startup scripts (`Start App.bat` for Windows, `Start App (Mac).command` for macOS) will start a simple local web server using Python's built-in `http.server` module and open it in your browser automatically. Double-click the relevant script for your OS after completing Sections 1-5 above. Note this just serves the raw files (Markdown will show as plain text, not rendered, since there's no Markdown renderer built into `http.server`) - Options A and B give you nicer formatted reading.

## 10. Using Every Feature of This Repo

This repo's "features" are its content, organized as follows:

- **Root `README.md`** - start here. Covers function calling, tool calling, structured outputs, JSON Schema, validation, and provider-specific behavior (OpenAI, Claude, Gemini), plus streaming, parallel tool calls, security, and production best practices.
- **`openai/`, `claude/`, `gemini/`** - deep dives into each provider's tool-calling API.
- **`json-output/`, `structured-output/`** - patterns for constraining model output to a schema.
- **`tool-calling/`** - the general, provider-agnostic tool-calling lifecycle.
- **Tool example folders** (`weather/`, `calendar/`, `email/`, `sql/`, `excel/`, `github/`, `filesystem/`, `web-search/`, `pdf/`, `math/`, `translation/`) - each is a complete worked example of a single tool definition, following the same 10-section format (Overview, Architecture, JSON Schema, Tool Definition, Input, Output, Example Request/Response, Error Handling, Best Practices).
- **`examples/`** - multi-tool orchestration examples.
- **`templates/`** - copy-paste starting points (`tool-definition-template.md`, `error-handling-template.md`, `json-schema-template.json`) for defining your own tools.

To "use" any of it: open the relevant `README.md`, read the section, and copy the JSON Schema / code snippets into your own project as a starting point.

## 11. Testing

There's no application logic to unit-test. To "test" that you've set everything up correctly:

1. Confirm `python --version` and `git --version` both return version numbers (Sections 1-2).
2. Confirm you can open and preview a Markdown file in VS Code (Section 9, Option A).
3. If you tried Option C, confirm your browser opened to `http://localhost:8000` (or similar) and shows the file listing.

## 12. Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `'python' is not recognized as an internal or external command` (Windows) | Python wasn't added to PATH during install | Re-run the Python installer, choose "Modify," and check "Add python.exe to PATH." |
| `python: command not found` (macOS) | Use `python3` instead - macOS often only aliases `python3` by default | Try `python3 --version` |
| Markdown preview button does nothing / looks unstyled | Markdown All in One extension not installed | Revisit Section 4 |
| Double-clicking `Start App.bat` closes instantly | An error occurred before the "pause" - this is why the script keeps the window open on error; if it still closes instantly, right-click -> Edit and run the commands manually in a terminal to see the error | See Section 15 of the script comments, or open a terminal and run the same commands line-by-line |
| macOS says the `.command` file "cannot be opened because it is from an unidentified developer" | macOS Gatekeeper security feature | Right-click the file -> **Open** -> confirm in the dialog (only needs to be done once) |
| `Permission denied` running the `.command` file on macOS | The file isn't marked executable | In Terminal: `chmod +x "Start App (Mac).command"` |

## 13. FAQ

**Q: Do I need an OpenAI/Anthropic/Google API key to use this repo?**
A: No. This repo is documentation about how those APIs' tool-calling features work; it doesn't call any live API itself.

**Q: Is there a `main.py` or entry point I'm missing?**
A: No - there genuinely isn't one. This is intentional; see the note at the top of this guide.

**Q: Can I contribute my own tool example?**
A: Yes, conceptually - follow the existing 10-section format used by folders like `weather/` or `sql/`, and use `templates/tool-definition-template.md` as your starting point.

**Q: Why does the repo mention FastAPI / servers / APIs in the docs but I can't find that code?**
A: Those are explanatory examples *about* how tool calling works in general-purpose backends, not code that ships in this repo.

## 14. Common Mistakes

- Trying to `pip install -r requirements.txt` - this file doesn't exist here, because there's nothing to install.
- Looking for a `.env` file to add API keys to - not needed; this repo doesn't call any APIs.
- Expecting `Start App.bat` / `Start App (Mac).command` to launch a graphical application - they open a local file browser for the docs, not a GUI app.
- Forgetting to check "Add to PATH" during the Python install on Windows (see Troubleshooting).
- Editing files directly in the folder without using Git to track changes, then losing track of what was modified - if you plan to make ongoing edits, learn `git status`, `git diff`, and `git commit` early.

## 15. Security Recommendations

- This repo, as-is, contains no secrets and requires no credentials - there's nothing to protect *within* it.
- If you copy code snippets from these docs into your **own** project that does call live APIs, follow the repo's own advice in the root `README.md`'s Security section: never hard-code API keys in source files, use environment variables loaded from a `.env` file that is listed in `.gitignore`, and apply the principle of least privilege to any credentials you create.
- Before publishing your own fork or extension of this repo publicly, double-check with `git status` and a manual file review that you haven't accidentally added a real `.env` file, credentials, or personal data.

## 16. Next Learning Steps

1. Read the root `README.md` fully - it's the best single overview of function/tool calling across providers.
2. Pick one provider (OpenAI, Claude, or Gemini) matching what you're building with, and read that folder in depth.
3. Try copying the `templates/tool-definition-template.md` and `templates/json-schema-template.json` into a scratch file and filling them in for a tool idea of your own (e.g., a "get stock price" tool).
4. Once comfortable, try wiring up a real, minimal example: pick one provider's SDK, define one simple tool (like the `weather/` example), and get a working request/response round-trip using a free-tier or trial API key from that provider.
5. Come back to the **Security** and **Production Best Practices** sections of the root README before deploying anything with real side effects (sending emails, writing to a database, etc.).
