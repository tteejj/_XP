# ALCAR Screen Layout Concepts - Beyond LazyGit

## The Core Problem You're Solving
You want screens that are **aware of each other** and **react to context**. Not just filters, but a living workspace where selecting a project immediately updates tasks, time entries, and related files across all visible panes. Think of it as a **context-driven workspace** rather than isolated screens.

## Concept 1: The Context Cascade
```
┌─────────────────────────────────────────────────────────────────────┐
│ :new task  :commit  :time 2h  :switch proj                        │ **1 Command Palette
├─────────────────────────────────────────────────────────────────────┤
│[Dashboard][*Tasks*][Time][Files][Git]                             │ **2 Active Workspaces
├────────────┬────────────────────────┬───────────────────────────────┤
│ CONTEXT    │    FOCUS               │    RELATED                   │
│ ┌────────┐ │ ┌──────────────────┐  │ ┌─────────────────────────┐ │
│ │Project │ │ │Task: Fix login   │  │ │Recent Files:          │ │
│ │> Web   │ │ │                  │  │ │ > auth.js (2h ago)    │ │
│ │  Mobile│ │ │Status: Active    │  │ │ > login.vue (3h ago)  │ │
│ └────────┘ │ │Time: 2.5h        │  │ └─────────────────────────┘ │
│            │ │                  │  │ ┌─────────────────────────┐ │
│ ┌────────┐ │ │Related:          │  │ │Git Status:            │ │
│ │Filter  │ │ │- auth.js        │  │ │ M auth.js             │ │
│ │☑ Active│ │ │- login.vue      │  │ │ M login.vue           │ │
│ │☐ Done  │ │ │- tests/auth.*   │  │ └─────────────────────────┘ │
│ │☐ Later │ │ │                  │  │ ┌─────────────────────────┐ │
│ └────────┘ │ └──────────────────┘  │ │Time Today: 4.2h      │ │
│            │ ┌──────────────────┐  │ │This Task: 2.5h       │ │
│ ┌────────┐ │ │[Quick Actions]   │  │ │This Week: 32h        │ │
│ │Smart   │ │ │□ Complete Task   │  │ └─────────────────────────┘ │
│ │Groups  │ │ │□ Start Timer     │  │                             │
│ │> Today │ │ │□ Add Note        │  │                             │
│ │  Urgent│ │ │□ Link File       │  │                             │
│ │  Review│ │ └──────────────────┘  │                             │
│ └────────┘ │                        │                             │
├────────────┴────────────────────────┴───────────────────────────────┤
│ Working on: Fix login | Web Project | 2.5h elapsed | Git: 2 modified│ **5 Status
├─────────────────────────────────────────────────────────────────────┤
│ > _                                                                 │ **6 Input (when needed)
└─────────────────────────────────────────────────────────────────────┘

KEY INSIGHT: Everything cascades from context. Select "Web Project" and:
- Tasks filter to Web only
- Recent files show Web project files
- Git status shows only Web repo
- Time tracking knows you're on Web
```

## Concept 2: The Workspace Matrix
```
┌─────────────────────────────────────────────────────────────────────┐
│ alcar> workspace save "morning-standup"                             │
├─────────────────────────────────────────────────────────────────────┤
│ [Planning] [*Coding*] [Review] [Standup]                   Ctrl+Tab │
├─────────────────────────────────────────────────────────────────────┤
│         │ PROJECT │        │ TASK        │                          │
│ 09:00 ├─────────┤ 09:15 ├─────────────┤ 10:00      11:00         │
│   ●    │  Web    │   ●    │ Fix login   │    ○         ○          │ Timeline
│   │    │         │   │    │             │    │         │          │
├───┴────┴─────────┴───┴────┴─────────────┴────┴─────────┴──────────┤
│ PROJECT: Web App          │ TASKS               │ CONSOLE/PREVIEW  │
│ ├─ src/                  │ ☑ Setup auth       │ $ npm test       │
│ │  ├─ auth/              │ ⚡ Fix login bug    │ ✓ auth.test.js   │
│ │  │  ├─ login.js       │ ☐ Add remember me  │ ✗ login.test.js  │
│ │  │  └─ auth.js        │ ☐ OAuth integrate  │   Error: line 42 │
│ │  └─ components/        │                    │                  │
│ └─ tests/                │ [Create Task] [+]  │ [Run] [Debug]    │
├──────────────────────────┴────────────────────┴──────────────────┤
│ ▼ Quick Context Switch                                            │
│ ┌─────────┐ ┌──────────┐ ┌───────────┐ ┌──────────┐            │
│ │ Project │ │   Task   │ │   File    │ │  Branch  │            │
│ │ > Web   │ │ > Login  │ │ > auth.js │ │ > fix/   │            │
│ │   API   │ │   Auth   │ │   test.js │ │   main   │            │
│ └─────────┘ └──────────┘ └───────────┘ └──────────┘            │
├───────────────────────────────────────────────────────────────────┤
│ Context: Web > Fix login | Timer: 0:45 | Changes: 2 files        │
└───────────────────────────────────────────────────────────────────┘

KEY INSIGHT: Workspaces are saved contexts. "Standup" workspace shows timeline + tasks.
"Coding" workspace shows files + tests. Switch contexts, switch entire layout.
```

## Concept 3: The Flow State
```
┌─────────────────────────────────────────────────────────────────────┐
│ alcar://flow/web-project/login-fix                          ▼ Share│
├─────────────────────────────────────────────────────────────────────┤
│     BREADCRUMB                        SPOTLIGHT                     │
│ ┌─────────────────┐          ┌──────────────────────┐             │
│ │Web > Auth > Fix │          │ 🔍 Focusing on:      │             │
│ └─────────────────┘          │    login.js:142      │             │
│                              └──────────────────────┘             │
│ PERIPHERAL                    MAIN STAGE                SUPPORT    │
│ ┌──────────┐      ┌─────────────────────────┐    ┌─────────────┐ │
│ │Related:  │      │login.js                 │    │□ Run tests  │ │
│ │          │      │142│ if (user.auth) {    │    │□ Check logs │ │
│ │auth.js   │      │143│   // BUG: This     │    │□ Git blame  │ │
│ │  L42 ●   │ <--> │144│   validateToken(); │<-->│□ Find refs  │ │
│ │  L156    │      │145│ }                   │    │□ Time: 45m  │ │
│ │          │      │                         │    │             │ │
│ │session.js│      │[Edit] [Test] [Commit]  │    │◆ Notes:     │ │
│ │  L23     │      └─────────────────────────┘    │  Token can  │ │
│ └──────────┘                                      │  be null    │ │
│                   ┌─────────────────────────┐    └─────────────┘ │
│ ┌──────────┐      │Test Output:             │    ┌─────────────┐ │
│ │History:  │      │✗ login() should validate│    │Next:        │ │
│ │          │      │  Expected: true         │    │□ Add null   │ │
│ │12:45 View│      │  Received: undefined    │    │  check      │ │
│ │12:42 Edit│      └─────────────────────────┘    │□ Update test│ │
│ │12:30 Test│                                      └─────────────┘ │
│ └──────────┘                                                       │
├─────────────────────────────────────────────────────────────────────┤
│ Smart: "validateToken might need null check" | Suggest | Explain   │
└─────────────────────────────────────────────────────────────────────┘

KEY INSIGHT: Everything flows around your current focus. Related code appears
in peripheral. Actions appear in support. History tracks your path.
```

## Concept 4: The Living Dashboard
```
┌─────────────────────────────────────────────────────────────────────┐
│ ALCAR | Connected: GitLab, Jira, Slack              | 14:32 ⚡Live │
├─────────────────────────────────────────────────────────────────────┤
│ MISSION CONTROL              │ FIELD WORK                           │
│ ┌──────────────────────────┐ │ ┌──────────────────────────────────┐│
│ │▼ Web Project       ✓3 ⚠1│ │ │Current Task: Fix login bug       ││
│ │  Sprint 14         ████░│ │ │                                  ││
│ │  Due: 2 days            │ │ │Resources          Status         ││
│ │                         │ │ │> auth.js    ━━━━━━━━━━━━━━ 70%  ││
│ │  ▶ Fix login bug   45m │ │ │  session.js ━━━━━━━━━━━━━━ 70%  ││
│ │  ▷ Add OAuth       0m  │ │ │  test/auth  ━━━━━━━━━━━━━━ 85%  ││
│ │  ▷ Update docs     0m  │ │ │                                  ││
│ └──────────────────────────┘ │ │Dependencies       Health         ││
│ ┌──────────────────────────┐ │ │✓ Database.connect     ●         ││
│ │▼ API Project      ✓5 ⚠0│ │ │⚠ AuthService.validate ●         ││
│ │  Sprint 14         █████│ │ │✓ Config.loaded        ●         ││
│ │  On Track               │ │ └──────────────────────────────────┘│
│ └──────────────────────────┘ ├────────────────────────────────────┤
│                              │ INTELLIGENCE                        │
│ PULSE                        │ ┌──────────────────────────────────┐│
│ ┌──────────────────────────┐ │ │💡 Similar issue fixed in commit  ││
│ │ Team Activity      ⟲ 30s│ │ │   a4f2b: "Handle null tokens"    ││
│ │ Jake: Pushed auth fix   │ │ │                                  ││
│ │ Sara: Reviewing PR #42  │ │ │🔗 Related: PR #38 touched this   ││
│ │ CI: Build passing ✓     │ │ │                                  ││
│ └──────────────────────────┘ │ │📊 This code: 3 bugs last month  ││
│                              │ └──────────────────────────────────┘│
├──────────────────────────────┴────────────────────────────────────┤
│ ⚡ Jake fixed similar issue | View | Apply | Chat                  │
└─────────────────────────────────────────────────────────────────────┘

KEY INSIGHT: Live connections to external services. Real-time team activity.
AI-powered suggestions based on history. Everything updates as you work.
```

## The Core Principles

### 1. **Context is King**
- Your current project/task selection ripples through ALL visible panes
- No more navigating to see related info - it's already there
- Smart grouping of related items (files, commits, tests, docs)

### 2. **Workspaces are States**
- Save entire layouts as workspaces: "Morning Review", "Deep Coding", "PR Review"
- Each workspace remembers what panes are open, their sizes, and their filters
- Quick switch between mental contexts

### 3. **Everything is Connected**
- Select a task → see its files, time spent, related commits
- Open a file → see tasks mentioning it, last editors, test status
- Change project → entire workspace adapts

### 4. **Time is Visible**
- Timeline view shows when you worked on what
- Automatic time tracking based on active context
- Visual "heat map" of activity

### 5. **Intelligence Built In**
- Learn from your patterns (you always open these 3 files together)
- Suggest related items based on history
- Connect to external services for live updates

## Implementation Ideas

### Phase 1: Context Awareness
- Modify existing panels to share a "context bus"
- When project changes, broadcast to all panels
- Each panel subscribes to relevant context changes

### Phase 2: Workspace Persistence
- Save/restore entire screen layouts
- Quick switcher for saved workspaces
- Auto-save current state

### Phase 3: Live Connections
- Plugin system for external services
- Real-time updates from Git, CI/CD, team chat
- Activity feed from team members

### Phase 4: Intelligent Suggestions
- Track user patterns
- Suggest files, tasks, commands based on context
- "Smart groups" that update dynamically

## Why This Matters

Current approach: Navigate between isolated screens
This approach: **Everything you need is already visible and reacts to your focus**

It's not about having more panels or better filters. It's about creating a **living workspace** that understands your intent and brings relevant information to you automatically.

## Concept 1 v2: The ALCAR Context Cascade
```
┌─────────────────────────────────────────────────────────────────────┐
│ :task new  :time start  :note add  :file open              [MainMenu]│ Command/Navigation
├─────────────────────────────────────────────────────────────────────┤
│[*Projects*][Tasks][Time][Notes][Files][Commands]          Tab →     │ Context-aware screens
├────────────┬────────────────────────┬───────────────────────────────┤
│ PROJECTS   │    PROJECT DETAILS      │    PROJECT TOOLS             │
│ ┌────────┐ │ ┌──────────────────┐  │ ┌─────────────────────────┐ │
│ │> PMC001│ │ │PMC001-WebPortal  │  │ │Tasks (5 active):      │ │
│ │  ABC123│ │ │                  │  │ │> Fix login bug   🔴   │ │
│ │  XYZ789│ │ │ID1: CAA-2024-001 │  │ │  Add OAuth      ⚡    │ │
│ │  DEF456│ │ │ID2: REQ-5547     │  │ │  Update docs    🟡    │ │
│ └────────┘ │ │                  │  │ │  Review PR#42   🟢    │ │
│            │ │Assigned: 01/15   │  │ │  Deploy v2.1    ⚪    │ │
│ ┌────────┐ │ │Due: 02/28        │  │ └─────────────────────────┘ │
│ │Status  │ │ │BF: 01/20         │  │ ┌─────────────────────────┐ │
│ │☑ Active│ │ │                  │  │ │Project Files:         │ │
│ │☐ Closed│ │ │Hours: 127.5/200  │  │ │📁 C:\PMC001\         │ │
│ │☐ On Hold│ │ │Progress: ████░   │  │ │ ├─ docs\             │ │
│ └────────┘ │ │                  │  │ │ ├─ src\              │ │
│            │ │Paths:            │  │ │ └─ tests\            │ │
│ ┌────────┐ │ │CAA: \\srv\PMC001 │  │ └─────────────────────────┘ │
│ │Quick   │ │ │REQ: \\req\5547   │  │ ┌─────────────────────────┐ │
│ │Filters │ │ │T20: \\t20\001    │  │ │Quick Commands:        │ │
│ │> My Work│ │ │                  │  │ │[n] New task          │ │
│ │  Due<7d │ │ │[Enter] Open →    │  │ │[t] Start timer       │ │
│ │  Updated│ │ └──────────────────┘  │ │[e] Edit project      │ │
│ └────────┘ │                        │ │[o] Open in explorer  │ │
│            │ ┌──────────────────┐  │ │[r] Recent files      │ │
│ [+ New]    │ │Recent Activity:  │  │ └─────────────────────────┘ │
│            │ │• Task completed  │  │ ┌─────────────────────────┐ │
│            │ │  "Setup auth"    │  │ │Time This Week:        │ │
│            │ │• Note added 2h   │  │ │Mon ████░ 6.5h        │ │
│            │ │• File: auth.js   │  │ │Tue ███░░ 4.2h        │ │
│            │ └──────────────────┘  │ │Today █░░░ 2.1h       │ │
│            │                        │ └─────────────────────────┘ │
├────────────┴────────────────────────┴───────────────────────────────┤
│ PMC001-WebPortal | 5 tasks | 127.5h used | Due in 38 days         │ Status bar
├─────────────────────────────────────────────────────────────────────┤
│ > _                                                                 │ Input (context: project)
└─────────────────────────────────────────────────────────────────────┘

When you press ENTER on PMC001:
```
┌─────────────────────────────────────────────────────────────────────┐
│ < Back to Projects | PMC001-WebPortal                     [MainMenu]│
├─────────────────────────────────────────────────────────────────────┤
│[Projects][*Tasks*][Time][Notes][Files][Commands]          Tab →     │ All filtered to PMC001
├────────────┬────────────────────────┬───────────────────────────────┤
│ TASK LIST  │    TASK DETAILS        │    TASK ACTIONS              │
│ PMC001 ▼   │ ┌──────────────────┐  │ ┌─────────────────────────┐ │
│ ┌────────┐ │ │Fix login bug     │  │ │Related Files:         │ │
│ │> Active │ │ │                  │  │ │ auth.js (modified)    │ │
│ │  Today  │ │ │Status: InProgress│  │ │ login.vue (open)      │ │
│ │  This Wk│ │ │Priority: High 🔴 │  │ │ auth.test.js         │ │
│ │  All    │ │ │Progress: 70%    │  │ └─────────────────────────┘ │
│ └────────┘ │ │                  │  │ ┌─────────────────────────┐ │
│            │ │Time: 4.5h total  │  │ │Git (filtered):        │ │
│ Tasks:     │ │Today: 2.1h       │  │ │ M src/auth.js        │ │
│ ┌────────┐ │ │                  │  │ │ M src/login.vue      │ │
│ │🔴 Fix   │ │ │Due: Tomorrow     │  │ │ ? test/auth.test.js  │ │
│ │  login  │ │ │                  │  │ └─────────────────────────┘ │
│ │⚡ OAuth │ │ │Description:      │  │ ┌─────────────────────────┐ │
│ │🟡 Docs  │ │ │Users can't login │  │ │Actions:               │ │
│ │🟢 PR#42 │ │ │with SSO enabled. │  │ │[Enter] Open editor    │ │
│ │⚪ Deploy│ │ │Check token valid.│  │ │[t] Toggle timer       │ │
│ └────────┘ │ │                  │  │ │[c] Complete task      │ │
│            │ │Tags: #auth #bug  │  │ │[n] Add note           │ │
│ Sub-tasks: │ │                  │  │ │[s] Create subtask     │ │
│ ┌────────┐ │ │Parent: none      │  │ │[l] Link file          │ │
│ │☑ Debug  │ │ │                  │  │ └─────────────────────────┘ │
│ │☐ Fix    │ │ │[Edit] [Delete]   │  │ ┌─────────────────────────┐ │
│ │☐ Test   │ │ └──────────────────┘  │ │Project Context:       │ │
│ └────────┘ │ ┌──────────────────┐  │ │PMC001 - WebPortal     │ │
│            │ │Activity Log:     │  │ │CAA: \\srv\PMC001     │ │
│ [+ Task]   │ │• Started 09:30   │  │ │5 tasks, 2 urgent     │ │
│            │ │• Note added 10:15│  │ └─────────────────────────┘ │
│            │ │• Paused 11:00    │  │                             │
│            │ └──────────────────┘  │                             │
├────────────┴────────────────────────┴───────────────────────────────┤
│ PMC001 > Fix login bug | Timer: ⏸ 2:07:34 | High Priority         │
└─────────────────────────────────────────────────────────────────────┘

Tab through context-aware tools:
[Time]: Shows ONLY PMC001 time entries
[Notes]: Opens text editor with PMC001\notes.md
[Files]: File browser starting at C:\PMC001\
[Commands]: Project-specific scripts and shortcuts
```

## Key Features of v2:

### 1. **Project-Centric Navigation**
- Select project → Everything filters to that context
- Project details show ALCAR-specific fields (ID1, ID2, paths, dates)
- Quick stats: tasks, hours, progress

### 2. **Context-Aware Tools**
- Each tab shows ONLY data for selected project:
  - Tasks: Filtered task list with statuses
  - Time: Time entries for this project
  - Notes: Project-specific notes file
  - Files: File browser rooted at project path
  - Commands: Project-specific actions

### 3. **Progressive Disclosure**
- Project list → Project details → Task details
- Each level maintains context from previous
- Back navigation preserves state

### 4. **Smart Defaults**
- Input line context changes (project commands vs task commands)
- Quick keys change based on current view
- Most common actions always visible

### 5. **Visual Indicators**
- 🔴 High priority / Urgent
- ⚡ In progress / Active
- 🟡 Medium priority / Warning
- 🟢 Low priority / Good
- ⚪ Not started / Planned

### 6. **Integration Points**
- Git status filtered to project files
- Time tracking tied to current task
- File browser knows project root
- Commands can be project-specific scripts



######V3
● Ah yes, I understand now! You're talking about the command menu screens (like
  "press A for Add, press N for New") vs the vim-style :command input I created
  without being asked. Let me discuss ideas for making the v2 ProjectContextScreen
  and the overall system MORE powerful:

  V2 ProjectContextScreen Enhancement Ideas

  1. Make It Actually Functional

  Currently it's mostly a shell. To make it powerful:

  Project Pane:
  @@SHOW THE PROJECT DETAILS - LOOK AT THE INFO I ADD FOR PROJECTS. THATS WHAT I WANT TO SEE
  @@add things like the project health,budget/hrs, quick stats and colour coding, sure
  @@BUT LOOK AT WHAT I ACTUALLY NEED, NOT SOME MADE UP ASSUMED NEEDS
  @@in ~/Downloads 
  - Show project health indicators (overdue, on-track, at-risk)
  - Display budget/hours remaining visually
  - Quick stats: active tasks, blockers, recent activity
  - Color coding for project status

  Task Details:
  @@I DONT WANT TIMERS. I JUST NEED TO SHOW THE TASKS AND SUBTASKS AND SELECTING ONE 
  @@WILL bring up the detailed task info
  @@the rest of these ideas wont help or be pertinent to my needs
  - Show task dependencies and blockers
  - Display attachments/linked files
  - Show task history/activity log
  - Quick timer controls right in the view

  Context Tools:
  @@do not need file watcher, git integration, probably dont need recent clipboard history
  @@the quick script/commands ARE needed. I envisioned something like the command palette. the commands i need are ususlly short text strings (@commands for caseware idea). i want to make retrieval easy, so tags pr other ways to organize them would be helpful and view them. not sure how to do that. ideas?
  @@the commandpalette sort of way or something else. once a command selected, it needs to be copied to the clipboard. 
  
  - Live file watcher showing recently modified project files
  - Git integration showing uncommitted changes
  - Quick access to project-specific scripts/commands
  - Recent clipboard history for the project

  2. Multi-Screen Layouts

  ┌─────────┬─────────┬─────────┐
  │Projects │  Tasks  │  Timer  │  <- Multiple screens at once
  │ List    │  Grid   │ Running │
  ├─────────┴─────────┴─────────┤
  │     Unified Status Bar       │
  └─────────────────────────────┘

  3. Smart Context Switching

  - When you select a project, ALL panes update
  - Breadcrumb navigation (Project > Task > Subtask)
  - "Workspace memory" - remembers your view per project
  - Quick context switcher (like Alt+Tab for projects)

  Command Screen Enhancements

  1. Context-Aware Commands

  Instead of static menus, commands change based on context:
  In Project View:
  [N] New Project  [E] Edit  [A] Archive  [T] Tasks  [R] Reports

  In Task View:
  [N] New Task  [C] Complete  [T] Timer  [D] Dependencies  [A] Assign

  2. Command Palettes at Multiple Levels

  - Global commands (always available)
  - Context commands (based on current screen)
  - Object commands (based on selected item)
  - Quick actions (learned from your patterns)
@@quick commands seems difficult and therefore unneccessary right now


  3. Visual Command Feedback

  Show command previews or confirmations:
  Press [D] to Delete Task...
  ┌─────────────────────────┐
  │ Delete "Fix login bug"? │
  │ This will also delete:  │
  │ - 3 time entries        │
  │ - 2 attachments         │
  │ [Y]es  [N]o            │
  └─────────────────────────┘

  Navigation Improvements

  1. Reverse Tab (Shift+Tab)

  - Add proper modifier key support
  - Could detect Shift+Tab in the input handler
  - Alternative: use [ and ] for prev/next
@@[] probably better and maybe / for the commands not :? what is feasibility of having user defined keys? so i can try different layouts - maybe try vim hjkl, etc,etc 



  2. Screen Ordering & Customization

  # In settings or config:
  $ScreenOrder = @(
      "ProjectContext",
      "Tasks",
      "TimeTracking",
      "Git"
  )

  # Or even layouts:
  $Layouts = @{
      "Development" = @("Tasks", "Git", "Files")
      "Planning" = @("Projects", "Kanban", "Calendar")
      "Review" = @("Time", "Reports", "Tasks")
  }
@@great, why not a simple dialog or screen for user to do that in program?

  3. Quick Jump Navigation

  - Number keys jump to specific screens (1-9)
  - Bookmark frequently used views
  - "Pin" screens to always be accessible
@@dont need bookmark, but the rest is good

  Information Density Ideas

  1. Sparklines and Mini-Charts

  Project A ████████░░ 80% │ ▁▃▅▇█▅▃ │ 5 tasks
  Project B ███░░░░░░░ 30% │ ▇▅▃▁▁▃▅ │ 12 tasks

  2. Inline Previews

  Hover or select to see quick previews without navigating:
  > Task: Fix login │ Preview: User reports SSO failing
    Task: Add API  │ when company domain is used...

  3. Status Densification

  Pack more info into status bars:
  [P:WebPortal|T:5/12|H:45.5/100|Git:3M|Timer:02:15:33|CPU:12%|MEM:1.2G]
@@probably not helpful for me, but maybe as i use more. dont implement, but note its possible


  Integration Ideas
@@NO OUTSIDE INTEGRATION, none of 1,2,3 right now
  1. Live External Data

  - Pull from JIRA/GitLab/GitHub APIs
  - Show CI/CD pipeline status
  - Display team member activity
  - Show calendar events

  2. Smart Suggestions

  - "You usually work on auth.js when fixing login bugs"
  - "This task is similar to #142 (2 hours)"
  - "Sara is also working on this module"

  3. Workflow Automation

  - Auto-create tasks from git commits
  - Start timer when opening certain files
  - Generate time reports automatically
  - Link files to tasks by usage patterns

  The "MORE" Factor

  To truly make it MORE, we need:

  1. Depth - Each screen should reveal layers of information
  2. Context - Everything connects and updates together
  3. Speed - Keyboard shortcuts for everything
  4. Intelligence - Learn patterns and suggest actions
  5. Integration - Connect to external tools/services
  6. Customization - Let users define their workflows

  What aspects excite you most? Should we focus on making the v2 screen truly
  powerful first, or improve navigation/commands across the board?


