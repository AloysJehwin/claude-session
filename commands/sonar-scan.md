# sonar-scan

Fetch SonarQube coverage, duplications, and quality report for a PR.

## Usage
```
/sonar-scan <pr-url-or-pr-number>
```

## Examples
```
/sonar-scan https://github.com/your-org/your-repo/pull/42
/sonar-scan 42
```

## Configuration (required before use)

Set these in your environment or replace the placeholders below:

| Variable | Description |
|---|---|
| `SONAR_HOST` | Your SonarQube server URL (e.g. `https://sonar.example.com`) |
| `SONAR_TOKEN` | SonarQube user token (generate at `$SONAR_HOST/account/security`) |
| `SONAR_COMPONENT` | Project component key from SonarQube (e.g. `com.example:my-project`) |

## Instructions

When this skill is invoked, do the following:

1. **Extract the PR number** from the argument (parse from URL if a full URL is given).

2. **Set variables** (replace with your values or read from env):
   - `SONAR_HOST=<your-sonar-host>`
   - `SONAR_COMPONENT=<your-component-key>`
   - `SONAR_TOKEN=<your-sonar-token>`
   - `PR=<extracted pr number>`

3. **Run all four curl calls in parallel** using the Bash tool:

   **a) Overall coverage metrics:**
   ```bash
   curl -s -u "$SONAR_TOKEN:" \
     "$SONAR_HOST/api/measures/component?component=$SONAR_COMPONENT&metricKeys=coverage,new_coverage,line_coverage,new_line_coverage,branch_coverage,new_branch_coverage,uncovered_lines,new_uncovered_lines&pullRequest=$PR"
   ```

   **b) File-level coverage breakdown:**
   ```bash
   curl -s -u "$SONAR_TOKEN:" \
     "$SONAR_HOST/api/measures/component_tree?component=$SONAR_COMPONENT&metricKeys=new_uncovered_lines,new_uncovered_conditions,new_coverage&pullRequest=$PR&ps=50&qualifiers=FIL"
   ```

   **c) Duplications:**
   ```bash
   curl -s -u "$SONAR_TOKEN:" \
     "$SONAR_HOST/api/duplications/show?key=$SONAR_COMPONENT&pullRequest=$PR"
   ```

   **d) Issues (bugs, code smells, vulnerabilities) on new code:**
   ```bash
   curl -s -u "$SONAR_TOKEN:" \
     "$SONAR_HOST/api/issues/search?componentKeys=$SONAR_COMPONENT&pullRequest=$PR&resolved=false&ps=50"
   ```

4. **Parse and present the report** in this format:

---

## SonarQube Report — PR #<N>

### Coverage (New Code)
| Metric | New Code | Overall |
|--------|----------|---------|
| Coverage | X% | X% |
| Line Coverage | X% | X% |
| Branch Coverage | X% | X% |
| Uncovered Lines | X | X |

### Files with Coverage Gaps (New Code)
List only files where `new_uncovered_lines > 0` OR `new_uncovered_conditions > 0`, sorted by worst coverage first:
| File | Uncovered Lines | Uncovered Branches | Coverage |
|------|-----------------|--------------------|----------|

### Duplications
List any duplicate blocks found (file, line ranges, size).

### Issues
List bugs, vulnerabilities, and code smells on new code grouped by severity.

---

5. **After presenting the report**, ask:
   > "Want me to fix any of these? I can address coverage gaps, duplications, or issues."
