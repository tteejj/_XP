# MCP Tools Requirements for NCurses Migration

## What is MCP?

MCP (Model Context Protocol) is Anthropic's system for enabling Claude to interact with external tools and systems. For the PMC Terminal v5 migration, specific tools would greatly enhance efficiency and reliability.

## Current MCP Tools Available

### ✅ Already Configured (In Use)
1. **filesystem** - Read/write files, create directories
2. **sequential-thinking** - Complex problem analysis
3. **textEditor** - Advanced file editing with undo
4. **artifacts** - Create sharable code artifacts
5. **web_search** - Look up documentation
6. **repl** - Execute JavaScript (limited use for PowerShell)

## Required MCP Tools for Optimal Migration

### 🔧 PowerShell-Specific Tools (NEEDED)

#### 1. **PowerShell Syntax Validator**
```yaml
name: powershell-validator
description: Validate PowerShell syntax without execution
capabilities:
  - Syntax checking
  - Module dependency resolution
  - Class inheritance validation
  - Parameter type checking
```

**Where to find**: 
- GitHub: `anthropic-community/mcp-powershell-validator` (hypothetical)
- Alternative: Create using PowerShell AST parser

#### 2. **PowerShell Test Runner**
```yaml
name: powershell-test
description: Execute PowerShell Pester tests in isolated runspace
capabilities:
  - Run test files
  - Capture output
  - Performance profiling
  - Mock support
```

**Where to find**:
- Could be built using `powershell-server` as base
- Wrap Pester framework for MCP

#### 3. **Diff Viewer**
```yaml
name: diff-tool
description: Compare file versions with visual output
capabilities:
  - Side-by-side comparison
  - Inline diff
  - Syntax highlighting
  - Change statistics
```

**Where to find**:
- GitHub: `modelcontextprotocol/mcp-diff-tool`
- Or integrate with git diff

### 📦 How to Install MCP Tools

#### Method 1: Using npx (Recommended)
```bash
# Install MCP CLI
npm install -g @anthropic/mcp

# Add a tool
npx @anthropic/mcp install github:owner/mcp-tool-name

# Configure in Claude Desktop
# Edit: %APPDATA%\Claude\config.json (Windows)
```

#### Method 2: Manual Configuration
```json
{
  "mcpServers": {
    "powershell-validator": {
      "command": "node",
      "args": ["C:\\tools\\mcp-powershell-validator\\index.js"],
      "env": {
        "POWERSHELL_PATH": "pwsh.exe"
      }
    }
  }
}
```

## Building Custom MCP Tools

### Basic MCP Tool Structure
```javascript
// index.js
import { MCPServer } from '@anthropic/mcp';

const server = new MCPServer({
  name: 'powershell-helper',
  version: '1.0.0',
  description: 'PowerShell development tools'
});

server.addTool({
  name: 'validate-syntax',
  description: 'Validate PowerShell syntax',
  parameters: {
    code: { type: 'string', required: true }
  },
  handler: async ({ code }) => {
    // Implementation
    const result = await validatePowerShell(code);
    return { valid: result.valid, errors: result.errors };
  }
});

server.start();
```

### PowerShell Validation Implementation
```javascript
async function validatePowerShell(code) {
  const { exec } = require('child_process');
  const util = require('util');
  const execAsync = util.promisify(exec);
  
  try {
    const script = `
      $ErrorActionPreference = 'Stop'
      try {
        [scriptblock]::Create(@'
${code}
'@)
        Write-Output "VALID"
      } catch {
        Write-Output "ERROR: $_"
      }
    `;
    
    const { stdout } = await execAsync(
      `pwsh -NoProfile -Command "${script.replace(/"/g, '\\"')}"`
    );
    
    return {
      valid: stdout.includes('VALID'),
      errors: stdout.includes('ERROR') ? stdout : null
    };
  } catch (error) {
    return { valid: false, errors: error.message };
  }
}
```

## Existing MCP Tools Repositories

### Official Anthropic Resources
- **Documentation**: https://modelcontextprotocol.io/
- **GitHub Organization**: https://github.com/modelcontextprotocol
- **Example Servers**: https://github.com/modelcontextprotocol/servers

### Community Tools
- **Awesome MCP**: https://github.com/coleam00/awesome-mcp
- **MCP Gallery**: Search for community-built tools
- **Discord**: MCP community for tool sharing

### Relevant Existing Tools

1. **filesystem-server** (Already integrated)
   - GitHub: `modelcontextprotocol/servers/filesystem`
   
2. **git-server** (Useful for diff/history)
   - GitHub: `modelcontextprotocol/servers/git`
   - Could help with checkpoint management

3. **shell-server** (Could run PowerShell)
   - GitHub: `modelcontextprotocol/servers/shell`
   - Needs configuration for PowerShell

## Quick Setup for Migration

### Step 1: Install Base Tools
```bash
# Install git MCP server for diff capabilities
npx @anthropic/mcp install @modelcontextprotocol/server-git

# Install shell server for PowerShell execution
npx @anthropic/mcp install @modelcontextprotocol/server-shell
```

### Step 2: Configure for PowerShell
```json
{
  "mcpServers": {
    "git": {
      "command": "node",
      "args": ["...path-to-git-server"],
      "env": {
        "REPO_PATH": "C:\\Users\\jhnhe\\Documents\\GitHub\\_XP"
      }
    },
    "powershell": {
      "command": "node", 
      "args": ["...path-to-shell-server"],
      "env": {
        "SHELL": "pwsh.exe",
        "WORKING_DIR": "C:\\Users\\jhnhe\\Documents\\GitHub\\_XP"
      }
    }
  }
}
```

## Minimal Tool Set for Migration Success

If you can only add ONE tool, prioritize:

**Git MCP Server** - Provides:
- Diff viewing between checkpoints
- Commit history tracking
- Branch management for safe experimentation
- Revert capabilities

This, combined with the existing filesystem tools, would cover 80% of the migration needs.

## Alternative: PowerShell-Based Validation

If MCP tools aren't available, we can use the filesystem tool to create PowerShell validation scripts:

```powershell
# Create this as: tools/validate-component.ps1
param(
    [string]$ComponentPath,
    [string]$TestScenario
)

try {
    # Load component
    Import-Module $ComponentPath -Force
    
    # Run syntax validation
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $ComponentPath, 
        [ref]$null, 
        [ref]$null
    )
    
    # Execute test scenario
    $result = & $TestScenario
    
    # Output structured result
    @{
        Valid = $true
        Component = $ComponentPath
        TestResult = $result
    } | ConvertTo-Json
} catch {
    @{
        Valid = $false
        Component = $ComponentPath
        Error = $_.Exception.Message
    } | ConvertTo-Json
}
```

Then I can create and read these validation scripts using the filesystem tool.