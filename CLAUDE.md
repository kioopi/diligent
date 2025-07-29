# CLAUDE.md - Development Guidelines for Diligent

This document provides specific guidelines for Claude Code when working on the Diligent project. These standards ensure consistent, high-quality code and proper development practices.

## Development Philosophy

**Diligent follows strict Test-Driven Development (TDD):**
- 🔴 **Red**: Write a failing test first
- 🟢 **Green**: Write minimal code to make it pass  
- 🔧 **Refactor**: Clean up and improve the code

**Never write code without a failing test first.** This is non-negotiable.

## Quality Standards

### Code Quality Requirements
- **Modular**: Functions and modules have single responsibilities
- **Testable**: All code can be unit tested in isolation
- **DRY**: Don't Repeat Yourself - extract common functionality
- **Well-Architected**: Follow the patterns established in `planning/03-Architecture-overview.md`
- **Maintainable**: Code should be easy to understand and modify

### Test Coverage
- Maintain **≥60% test coverage** (enforced by CI)
- Strive for **≥80% coverage** on core functionality
- Test edge cases and error conditions
- Use descriptive test names that explain behavior

## Mandatory Development Workflow

### Before Writing Any Code

1. **Understand the requirement** by reading relevant planning documents
2. **Write a failing test** that describes the expected behavior
3. **Run tests** to confirm the test fails (`make test`)
4. Only then write the minimal code to make the test pass

### After Writing Code

**Always run this sequence after any code change:**

```bash
make test    # Tests must pass
make lint    # No linting errors allowed
make fmt     # Code must be properly formatted
```

**Never commit code that fails any of these checks.**

### Feature Development Process

1. **Plan**: Update relevant docs in `planning/` if architecture changes
2. **Test**: Write failing tests first (TDD Red phase)
3. **Implement**: Write minimal code (TDD Green phase) 
4. **Refactor**: Clean up code (TDD Refactor phase)
5. **Verify**: Run `make test lint fmt`
6. **Document**: Update `README.md`, `docs/`, and planning docs as needed

## Code Organization Standards

### Module Structure
```lua
-- Module header with clear purpose
local module_name = {}

-- Private functions (local)
local function private_helper()
  -- implementation
end

-- Public interface
function module_name.public_function()
  -- implementation
end

return module_name
```

### Test Structure
```lua
local assert = require("luassert")
local module_name = require("module_name")

describe("Module Name", function()
  describe("public_function", function()
    it("should handle normal case", function()
      -- Test normal behavior
    end)
    
    it("should handle edge case", function()
      -- Test edge cases
    end)
    
    it("should handle error conditions", function()
      -- Test error handling
    end)
  end)
end)
```

### Error Handling
- Use explicit error checking, not exceptions
- Return `nil, error_message` for functions that can fail
- Always test error conditions
- Provide meaningful error messages

## Architecture Guidelines

### Follow the Established Architecture
Refer to `planning/03-Architecture-overview.md` for:
- Component responsibilities
- Data flow patterns
- Interface contracts
- External dependencies

### Dependency Management
- Keep dependencies minimal and well-justified
- Update `diligent-scm-0.rockspec` for runtime dependencies
- Update `diligent-dev-scm-0.rockspec` for development dependencies
- Document why each dependency is needed

### API Design
- Design APIs from the user's perspective first
- Write tests for the public API before implementation
- Keep interfaces simple and consistent
- Use clear, descriptive function names

## Documentation Standards

### Keep Documentation Current
**Always update these when making changes:**

- `README.md` - For user-facing changes
- `docs/developer-guide.md` - For development process changes
- Planning documents in `planning/` - For architectural changes
- Code comments for complex logic (but prefer self-documenting code)

### Documentation Review Checklist
- [ ] Is the change reflected in user documentation?
- [ ] Are architectural changes documented in planning/?
- [ ] Are breaking changes clearly noted?
- [ ] Are examples updated if APIs changed?

## Code Review Standards

### Self-Review Checklist
Before requesting review, verify:

- [ ] All tests pass (`make test`)
- [ ] No linting errors (`make lint`)
- [ ] Code is properly formatted (`make fmt`)
- [ ] Test coverage is adequate
- [ ] Documentation is updated
- [ ] Code follows TDD (tests written first)
- [ ] Code is modular and testable
- [ ] No code duplication
- [ ] Error cases are handled and tested

### Review Focus Areas
When reviewing code, pay attention to:

- **Architecture**: Does it fit the established patterns?
- **Testability**: Can each function be easily unit tested?
- **Modularity**: Are responsibilities clearly separated?
- **Error Handling**: Are failure modes properly handled?
- **Documentation**: Is the change properly documented?

## Project-Specific Guidelines

### Lua Style
- Follow existing code style (2-space indentation, etc.)
- Use `local` for all variables unless global is needed
- Prefer explicit over implicit
- Use meaningful variable names

### AwesomeWM Integration
- Keep AwesomeWM-specific code isolated in modules
- Test AwesomeWM integration with mocks/stubs
- Don't assume AwesomeWM APIs - test they exist first

### CLI Development
- Always validate user input
- Provide helpful error messages
- Test CLI commands end-to-end
- Follow Unix conventions (exit codes, etc.)

## Common Patterns

### Testing with Mocks
```lua
-- Example of testing with dependency injection
local function create_service(deps)
  deps = deps or {}
  local awesome_client = deps.awesome_client or require("awesome_client")
  
  return {
    send_command = function(cmd)
      return awesome_client.send(cmd)
    end
  }
end
```

### Error Handling Pattern
```lua
local function safe_operation(input)
  if not input then
    return nil, "input is required"
  end
  
  local result, err = risky_operation(input)
  if not result then
    return nil, "operation failed: " .. (err or "unknown error")
  end
  
  return result
end
```

## Quality Gates

### Pre-Commit
- All tests pass
- No linting errors
- Code is formatted
- Documentation is updated

### Pre-Push
- Full test suite passes
- Code coverage ≥60%
- All quality checks pass
- Architecture documents updated if needed

### Pre-Release
- Full regression testing
- Documentation review
- Performance testing (if applicable)
- Security review (if applicable)

## Tools and Automation

### Available Commands
```bash
make check     # Verify development environment
make test      # Run tests with coverage
make lint      # Run code linting
make fmt       # Format code
make fmt-check # Check if code is formatted
make install   # Install via LuaRocks
make clean     # Clean generated files
```

### CI/CD Integration
- GitHub Actions runs on all PRs
- Tests run on multiple Lua versions (5.3, 5.4)
- Quality gates must pass before merge
- Coverage reports are generated

## Troubleshooting

### Common Issues
- **Tests can't find modules**: Check `.busted` configuration
- **Linting errors**: Run `make lint` for details
- **Formatting issues**: Run `make fmt` to fix
- **Coverage too low**: Add more test cases

### Getting Help
1. Check `docs/developer-guide.md`
2. Review planning documents
3. Run `./scripts/check-dev-tools.sh` for environment issues
4. Check existing issues on GitHub

## Contributing Standards

### Pull Request Requirements
- [ ] Follows TDD (tests written first)
- [ ] All quality checks pass
- [ ] Documentation updated
- [ ] Architectural consistency maintained
- [ ] No breaking changes without discussion

### Commit Message Format
```
type(scope): brief description

Detailed explanation if needed.

- Specific changes made
- Why the changes were needed
- Any breaking changes or migration notes
```

Examples:
- `feat(cli): add project status command`
- `fix(tests): resolve module loading issue`
- `docs(readme): update installation instructions`

---

## Remember: Quality First

**This project prioritizes quality over speed.** It's better to take time to do things right than to rush and create technical debt. When in doubt:

1. Write a test first
2. Keep it simple
3. Document the decision
4. Ask for review

**The goal is to create a maintainable, well-tested, and well-documented codebase that serves as an example of quality Lua development.**