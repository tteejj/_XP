# AXIOM Enhanced Implementation Plan
## Strategic Analysis & Improvements

### Current State Assessment
After analyzing the codebase and existing upgrade work:

1. **Good Progress Made:**
   - Panic Handler (Phase 1) ✅ - Provides safety net
   - Service Container (Phase 2) ✅ - Enables dependency injection
   - Action Service (Phase 3 partial) ✅ - Backend complete

2. **Critical Issues Remain:**
   - Still using dot-sourcing in run.ps1 with manual load order
   - No PowerShell module manifests (.psd1 files)
   - Dependency graph is implicit and fragile
   - Module caching issues persist
   - Parse-time errors likely when components reference each other

### Enhanced AXIOM Strategy

#### Core Principle: "Module-First Architecture"
Every logical unit becomes a proper PowerShell module with:
- Its own directory
- A module manifest (.psd1) declaring dependencies
- Zero `using module` statements in .psm1 files
- Explicit exports via manifest

#### Implementation Phases (Revised)

**Phase 0: Infrastructure & Tooling** (NEW)
- Create module generation tools
- Build dependency analyzer
- Set up testing framework
- Create migration scripts

**Phase 1: Core Primitives Modularization**
- Convert TuiCell/TuiBuffer to proper module
- Create manifest with no dependencies
- Test in isolation

**Phase 2: Base Classes Modularization**
- UIElement, Component, Panel, Screen
- Declare dependency on tui-primitives
- Handle class inheritance properly

**Phase 3: Service Layer Modularization**
- Convert each service to module
- Declare inter-service dependencies
- Maintain backward compatibility

**Phase 4: Component Library Modularization**
- Convert UI components
- Declare dependencies on base classes
- Enable individual component testing

**Phase 5: Screen Modularization**
- Convert screens to modules
- Declare component dependencies
- Test screen isolation

**Phase 6: Master Module Assembly**
- Create PMCTerminal.psd1 master manifest
- Declare high-level dependencies
- Remove run.ps1 dot-sourcing

### Success Factors Added

1. **Incremental Migration**
   - Keep old system working during transition
   - Module-by-module conversion
   - Parallel testing of both systems

2. **Dependency Mapping Tool**
   - Analyze current implicit dependencies
   - Generate manifest RequiredModules
   - Detect circular dependencies

3. **Testing at Each Step**
   - Each module tested in isolation
   - Integration tests after each phase
   - Performance benchmarking

4. **Documentation Standard**
   - Each module gets README.md
   - Dependency rationale documented
   - Public API clearly defined

### Risk Mitigation

1. **Parse-Time Errors**
   - Solution: Strict dependency ordering via manifests
   - Test: Load each module in clean session

2. **Class Inheritance Issues**
   - Solution: Base classes in separate modules
   - Test: Verify inheritance chain works

3. **Performance Concerns**
   - Solution: Module caching, lazy loading
   - Test: Benchmark startup times

4. **Breaking Changes**
   - Solution: Compatibility shim module
   - Test: Existing code continues working

### Implementation Order (Refined)

1. Build tooling and analyze dependencies
2. Create module templates and standards
3. Convert bottom-up (primitives → classes → components → screens)
4. Test each layer exhaustively
5. Create master module
6. Deprecate old loading system

### Success Metrics

- Zero parse-time errors
- All modules loadable in isolation
- Startup time < 2 seconds
- All existing functionality preserved
- Each module has passing tests

This enhanced plan addresses the core architectural issues while maintaining stability and providing clear path forward.
