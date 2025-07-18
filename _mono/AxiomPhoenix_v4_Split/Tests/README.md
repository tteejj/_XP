# Axiom-Phoenix Testing Framework

Comprehensive automated testing for the Axiom-Phoenix v4.0 TUI framework.

## Overview

This testing framework provides multiple levels of testing to ensure code quality, performance, and reliability:

- **Unit Tests** - Test individual components in isolation
- **Integration Tests** - Test component interactions and service wiring
- **Performance Tests** - Benchmark rendering and memory usage
- **End-to-End Tests** - Test complete user workflows

## Quick Start

### Prerequisites

- PowerShell 7.0+
- Pester 5.0+ (auto-installed by test runner)

### Running Tests

```powershell
# Run all tests
./Run-Tests.ps1

# Run specific test types
./Run-Tests.ps1 -TestType Unit
./Run-Tests.ps1 -TestType Integration
./Run-Tests.ps1 -TestType Performance

# Run with detailed output
./Run-Tests.ps1 -Verbosity Detailed

# Generate HTML report
./Run-Tests.ps1 -GenerateReport

# Run tests matching pattern
./Run-Tests.ps1 -TestPattern "*Button*"

# Run with specific output format
./Run-Tests.ps1 -OutputFormat JUnitXml -OutputFile TestResults.xml
```

## Test Structure

```
Tests/
├── Unit/                 # Unit tests for individual components
│   ├── Base/            # Core framework components
│   ├── Components/      # UI components
│   └── Services/        # Service classes
├── Integration/         # Integration tests
├── Performance/         # Performance benchmarks
├── E2E/                # End-to-end tests
└── README.md           # This file
```

## Test Categories

### Unit Tests

Test individual components in isolation:

- **TuiCell Tests** - Basic cell operations, property changes, validation
- **TuiBuffer Tests** - Buffer operations, reading/writing, resizing
- **ServiceContainer Tests** - Dependency injection, service lifecycle
- **Button Tests** - UI component behavior, input handling, rendering
- **Configuration Tests** - Settings validation, file operations

Example:
```powershell
# Run only unit tests
./Run-Tests.ps1 -TestType Unit

# Run specific component tests
./Run-Tests.ps1 -TestPattern "*TuiCell*"
```

### Integration Tests

Test how components work together:

- **Service Wiring** - Dependency injection across multiple services
- **Error Handling** - Error boundaries and recovery strategies
- **Screen Navigation** - Navigation between different screens

Example:
```powershell
# Run integration tests
./Run-Tests.ps1 -TestType Integration
```

### Performance Tests

Benchmark critical performance metrics:

- **Rendering Performance** - Frame rate simulation, buffer operations
- **Buffer Pooling** - Memory optimization, object reuse
- **Memory Usage** - Allocation patterns, garbage collection

Performance targets:
- Frame rendering: <16.67ms (60 FPS)
- Buffer operations: <100ms for typical operations
- Memory efficiency: Pool hit rate >70%

Example:
```powershell
# Run performance benchmarks
./Run-Tests.ps1 -TestType Performance -GenerateReport
```

## Writing Tests

### Unit Test Example

```powershell
Describe "Component Tests" {
    Context "When creating component" {
        It "Should initialize correctly" {
            $component = [MyComponent]::new("Test")
            $component.Name | Should -Be "Test"
        }
    }
    
    Context "When handling input" {
        BeforeEach {
            $component = [MyComponent]::new("Test")
        }
        
        It "Should process valid input" {
            $result = $component.HandleInput($validInput)
            $result | Should -Be $true
        }
    }
}
```

### Performance Test Example

```powershell
It "Should render efficiently" {
    $iterations = 1000
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    for ($i = 0; $i -lt $iterations; $i++) {
        $component.Render()
    }
    
    $stopwatch.Stop()
    $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
    
    Write-Host "Render time: $($stopwatch.ElapsedMilliseconds)ms for $iterations renders"
}
```

### Integration Test Example

```powershell
It "Should wire dependencies correctly" {
    $container = [ServiceContainer]::new()
    $container.Register("Logger", $logger)
    $container.Register("DataService", $dataService)
    
    $service = $container.GetService("DataService")
    $service.Logger | Should -Be $logger
}
```

## Test Runner Options

### Basic Options

- `-TestType` - Which tests to run (All, Unit, Integration, Performance, E2E)
- `-OutputFormat` - Output format (Console, Detailed, NUnitXml, JUnitXml)
- `-Verbosity` - Output verbosity (Silent, Minimal, Normal, Detailed, Diagnostic)

### Filtering Options

- `-TestPattern` - Run tests matching pattern
- `-Tag` - Run tests with specific tags
- `-FailFast` - Stop on first failure

### Output Options

- `-OutputFile` - Save results to file
- `-GenerateReport` - Generate HTML report
- `-ShowProgress` - Show test progress

### Advanced Options

- `-Parallel` - Run tests in parallel
- `-WhatIf` - Show what would run without executing

## Continuous Integration

Tests run automatically on:

- Push to main/develop branches
- Pull requests
- Daily scheduled runs

The CI pipeline includes:

1. **Multi-platform testing** (Windows, Linux, macOS)
2. **Code coverage analysis**
3. **Performance benchmarking**
4. **Security scanning** (PSScriptAnalyzer)
5. **Integration testing**

## Performance Benchmarks

Key performance metrics tracked:

| Operation | Target | Measured |
|-----------|--------|----------|
| Single character write | <1ms | Tracked |
| Full screen render | <16.67ms | Tracked |
| Buffer pool hit rate | >70% | Tracked |
| Memory allocation | <1MB growth | Tracked |

## Troubleshooting

### Common Issues

1. **Pester not found**
   ```powershell
   Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0
   ```

2. **Tests fail due to missing dependencies**
   - Ensure you're running from the project root
   - Check that all framework files are present

3. **Performance tests fail**
   - Run on a clean system
   - Close other applications
   - Check system resources

### Debug Mode

Run tests with diagnostic output:
```powershell
./Run-Tests.ps1 -Verbosity Diagnostic
```

View test discovery:
```powershell
./Run-Tests.ps1 -WhatIf
```

## Contributing

When adding new features:

1. **Write tests first** (TDD approach)
2. **Include all test types** (unit, integration, performance)
3. **Update benchmarks** if performance-critical
4. **Document test requirements** in code comments

### Test Naming Conventions

- Test files: `*.Tests.ps1`
- Test classes: `ComponentName.Tests.ps1`
- Performance tests: Include timing assertions
- Integration tests: Test realistic scenarios

### Code Coverage

Aim for:
- **Unit tests**: >90% coverage
- **Integration tests**: Cover all service interactions
- **Performance tests**: Cover all critical paths

## Resources

- [Pester Documentation](https://pester.dev/)
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/testing/)
- [GitHub Actions for PowerShell](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-powershell)

---

*For questions or issues with the testing framework, please create an issue in the project repository.*