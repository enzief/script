# Testing Patterns

**Analysis Date:** 2026-08-05

## Test Framework

**Status:** Not detected

**Current State:**
- No testing framework installed or configured
- No test files exist (no `*.test.sh`, `*.spec.sh`, or `test/` directories)
- No test runner configured (not using `bats`, `shunit2`, `pytest`, etc.)
- All testing is manual

## Manual Testing Approach

**How Scripts Are Currently Tested:**
- Scripts are designed to be invoked directly from shell with various argument combinations
- Each script has built-in help text describing usage and behavior
  - Access via: `./script.zsh -h` or `./script.zsh --help`
  - Example: `number-pages.zsh` lines 7-44 contain comprehensive usage documentation

**Script Help Text Locations:**
- `number-pages.zsh` - Lines 7-44: Shows all options, arguments, output formats, examples
- `list-missing-pages.zsh` - No help text; inline comments only
- `retain-dir-struct-*.zsh` - Echo-based usage messages (e.g., lines 5-6, 8-9)
- `rename-remote-files-*.zsh` - Echo-based usage messages (e.g., lines 7-8)

## Run Commands

**Typical Invocation:**
```bash
./script-name.zsh [options] [arguments]
```

**Validation Methods:**
- Scripts exit with code 0 on success, 1 on error
- Check exit code in bash: `./script.zsh && echo "Success" || echo "Failed"`
- Error messages written to stderr: `script.zsh 2>&1 | grep "Error"`

## Test File Organization

**Not Applicable:** No test files present in codebase

**If Tests Were to Be Added:**
- Location: `tests/` directory at repo root
- Naming: `test-<script-name>.sh` (e.g., `test-number-pages.sh`)
- Or co-located: `<script-name>.test.sh` in same directory as script

## Recommended Testing Framework

**For ZSH/Shell Scripts:**

**Option 1: BATS (Bash Automated Testing System)**
- Designed for shell scripts
- Uses clear test syntax: `@test "description" { ... }`
- Good for: Unit tests and integration tests of shell behavior
- Installation: `npm install -g bats` or package manager

**Option 2: ShUnit2**
- Unit testing framework modeled after xUnit
- Uses functions like `assertEquals`, `assertTrue`, etc.
- Good for: Testing shell functions
- Lighter-weight than BATS

**Option 3: Manual + assert script**
- Write simple shell functions to validate output
- No external dependencies
- Good for: Small test suites where overhead isn't worth it

## Patterns for Adding Tests

**Pattern 1: Test Script Exit Codes**
```bash
# Test number-pages with invalid chapter
./dev/manga/number-pages.zsh -n abc nonexistent_dir 2>/dev/null
if [[ $? -eq 1 ]]; then
    echo "PASS: Rejects invalid start page"
else
    echo "FAIL: Should reject invalid start page"
fi
```

**Pattern 2: Test Argument Validation**
```bash
# Test list-missing-pages with missing arguments
./dev/local-filesys/list-missing-pages.zsh 2>&1 | grep -q "Usage:"
if [[ $? -eq 0 ]]; then
    echo "PASS: Shows usage on missing args"
else
    echo "FAIL: Should show usage"
fi
```

**Pattern 3: Test File Output**
```bash
# Create temporary directory for test
tmpdir=$(mktemp -d)
./dev/manga/number-pages.zsh -n 1 "$tmpdir" test_chapter

# Verify output files exist
if [[ -f "$tmpdir/001_01.jpg" ]]; then
    echo "PASS: Output file created"
else
    echo "FAIL: Expected output file"
fi

# Cleanup
rm -rf "$tmpdir"
```

## What to Test

### High Priority (Core Functionality)

**number-pages.zsh:**
- [ ] Rejects non-numeric start page
- [ ] Rejects non-numeric chapter number
- [ ] Fails gracefully if directory doesn't exist
- [ ] Fails if no images found
- [ ] Fails if `identify` command not available
- [ ] Correctly detects double pages (width > height)
- [ ] Generates correct page number padding
- [ ] Abbreviates second page number correctly for double pages
- [ ] Applies suffix correctly when provided

**list-missing-pages.zsh:**
- [ ] Fails if less than 2 arguments provided
- [ ] Correctly extracts 3-digit chapter numbers
- [ ] Counts images in directories correctly
- [ ] Reports correct differences between versions
- [ ] Handles directories with no images

**retain-dir-struct-1.zsh:**
- [ ] Creates target directory if missing
- [ ] Generates correct SHA256 hashes
- [ ] Preserves directory structure in shadow
- [ ] Handles filenames with spaces and special chars

**retain-dir-struct-2-sorted.zsh:**
- [ ] Builds correct hash->path mapping
- [ ] Matches files based on hash
- [ ] Copies shadow files to new structure
- [ ] Reports unmatched files

**retain-dir-struct-3-find-sorted.zsh:**
- [ ] Builds correct file hash index
- [ ] Finds matching files by hash
- [ ] Handles missing files gracefully

**rename-remote-files-1-match-remote.zsh:**
- [ ] Requires rclone to be available
- [ ] Fetches remote manifest successfully
- [ ] Matches local files by size
- [ ] Creates shadow files with correct metadata
- [ ] Moves files to sync directory structure
- [ ] Handles unmatched files

**rename-remote-files-2-rename-local.zsh:**
- [ ] Reads shadow file variables correctly
- [ ] Moves files back to original locations
- [ ] Recreates original directory structure

### Medium Priority (Error Conditions)

- [ ] Scripts handle missing arguments gracefully
- [ ] Scripts handle invalid directory paths
- [ ] Scripts handle permission errors
- [ ] Scripts handle disk space issues (if applicable)

### Low Priority (Edge Cases)

- [ ] Filenames with spaces
- [ ] Filenames with special characters
- [ ] Very long filenames
- [ ] Symlinks (if supported)
- [ ] Hidden files

## Mocking & Fixtures

**External Commands (Not Currently Mocked):**
- `identify` - ImageMagick command for image dimensions
- `rclone` - Remote file sync tool
- `sha256sum` - Hash computation
- `find`, `grep`, `awk`, `jq` - Standard utilities

**How to Mock (If Tests Were Added):**

**Mock identify command:**
```bash
# Create fake identify that returns fixed dimensions
mock_identify() {
    case "$3" in
        test_image.jpg) echo "1200 900" ;; # landscape (double page)
        test_image2.jpg) echo "800 1200" ;; # portrait (single page)
        *) echo "0 0" ;; # error
    esac
}
```

**Mock rclone command:**
```bash
# Return fixed JSON structure
mock_rclone_lsjson() {
    cat <<'EOF'
[
  {"Path": "file1.jpg", "Size": 102400, "IsDir": false},
  {"Path": "file2.jpg", "Size": 204800, "IsDir": false}
]
EOF
}
```

## Fixtures and Test Data

**Test Directory Structure (If Tests Were Added):**
```
tests/
├── fixtures/
│   ├── images/
│   │   ├── landscape.jpg   (width > height)
│   │   ├── portrait.jpg    (height > width)
│   │   └── square.jpg      (width == height)
│   ├── data/
│   │   ├── v1/             (test directory structure)
│   │   ├── v2/
│   │   └── shadow/
│   └── config/
│       └── test.env        (config for remote tests)
└── [test files]
```

**Data Requirements:**
- Small test images (use ImageMagick to create)
- Sample directory structures with known file counts
- Hash-to-path mappings for shadow map tests

## Coverage

**Requirements:** Not enforced; no coverage tool configured

**Observation:** No coverage measurement tool present (not using `kcov`, `simplecov`, etc.)

**If Coverage Were to Be Added:**
- Recommend using `kcov` for shell script coverage
- Target: All major code paths tested
- Minimum acceptable: 70% for critical scripts

## Types of Tests Needed

### Unit Tests (Script Functions)

**Example: Testing `get_chap_num` function**
```bash
# Test valid 3-digit chapter number
result=$(get_chap_num "ch042_page1.jpg")
[[ "$result" == "042" ]] && echo "PASS" || echo "FAIL"

# Test chapter in middle of string
result=$(get_chap_num "manga_123_extra.jpg")
[[ "$result" == "123" ]] && echo "PASS" || echo "FAIL"

# Test no chapter found
result=$(get_chap_num "no_numbers_here.jpg")
[[ -z "$result" ]] && echo "PASS" || echo "FAIL"
```

### Integration Tests (Full Script Behavior)

**Example: Testing number-pages.zsh end-to-end**
```bash
# Setup
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir"
touch "$tmpdir/test1.jpg" "$tmpdir/test2.jpg"

# Run script
./dev/manga/number-pages.zsh -n 1 "$tmpdir" 99

# Verify output
expected_files=("$tmpdir/099_01.jpg" "$tmpdir/099_02.jpg")
for f in "${expected_files[@]}"; do
    [[ -f "$f" ]] || echo "FAIL: $f not found"
done

# Cleanup
rm -rf "$tmpdir"
```

### Validation Tests (Input/Output Constraints)

**Example: Testing argument validation**
```bash
# Should reject non-numeric chapter
./dev/manga/number-pages.zsh -c abc . 2>&1 | grep -q "Error"
[[ $? -eq 0 ]] && echo "PASS" || echo "FAIL"

# Should show help
./dev/manga/number-pages.zsh -h 2>&1 | grep -q "Usage"
[[ $? -eq 0 ]] && echo "PASS" || echo "FAIL"
```

## Common Patterns

**Async Testing:** Not applicable (no async operations in shell scripts)

**Error Testing:**
```bash
# Test error handling when file doesn't exist
./script.zsh nonexistent_file 2>&1 | grep -q "Error"
test_result=$?
[[ $test_result -eq 0 ]] && echo "PASS: Error caught" || echo "FAIL"

# Verify exit code
./script.zsh nonexistent_file >/dev/null 2>&1
[[ $? -eq 1 ]] && echo "PASS: Exit 1" || echo "FAIL"
```

**Output Verification:**
```bash
# Capture stdout
output=$(./script.zsh arg 2>&1)
if echo "$output" | grep -q "expected text"; then
    echo "PASS: Output contains expected text"
else
    echo "FAIL: Output missing expected text"
fi
```

**File Existence:**
```bash
# After script runs, verify file was created
./script.zsh
if [[ -f expected_output_file ]]; then
    echo "PASS: Output file created"
else
    echo "FAIL: Output file not created"
fi
```

## CI/CD Integration

**Current State:** No CI/CD configured (no GitHub Actions, GitLab CI, etc.)

**Recommendations for Adding Tests:**
1. Create `tests/run-all.sh` that executes all test scripts
2. Add pre-commit hook to run tests
3. Configure GitHub Actions (if using GitHub):
   ```yaml
   name: Test
   on: [push, pull_request]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v2
         - name: Run tests
           run: bash tests/run-all.sh
   ```

---

*Testing analysis: 2026-08-05*
