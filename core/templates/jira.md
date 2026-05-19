---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
---

# Jira Configuration & Story Template

## Project Configuration

Place this section in `draft/jira.md` in your project to configure Jira integration.

```yaml
# Jira Project Configuration
project_key: PROJ # Jira project key (required)
board_id: 123 # Board ID for sprint assignment (optional)
epic_link_field: customfield_10014 # Custom field ID for epic link (varies by instance)
story_points_field: customfield_10028 # Custom field ID for story points (optional)
default_issue_type: Story # Default issue type for tasks
default_priority: Medium # Default priority level
labels: # Labels to apply to all created issues
  - draft
```

---

# Jira Story Template (Minimal)

## Summary
[Brief, descriptive title]

## Description

```
h3. Description:

Problem Statement:
[Describe the current problem or pain point]

 * [Pain point 1]
 * [Pain point 2]
 * [Pain point 3]

Solution:
[Describe the proposed solution at a high level]

Key Features:
 # [Feature Category 1]

 * [Feature detail 1]
 * [Feature detail 2]

 # [Feature Category 2]

 * [Feature detail 1]
 * [Feature detail 2]

Benefits:
 * [Benefit 1]: [Quantifiable impact]
 * [Benefit 2]: [Quantifiable impact]

Use Cases:
 * [Use case 1]
 * [Use case 2]
 * [Use case 3]
```

## Acceptance Criteria

```
- [ ] [Criterion 1: Specific, testable requirement]
- [ ] [Criterion 2: Specific, testable requirement]
- [ ] [Criterion 3: Specific, testable requirement]
```

## Required Fields

### Standard Fields
- **Issue Type:** Story
- **Priority:** Medium
- **Components:** [Component name]
- **Fix Version/s:** [Version or master]

### People
- **Assignee:** [Your email]
- **Product Owner:** [PO email]
- **Tech Lead:** [Tech lead email]
- **Scrum Master:** [Scrum master email]

### Team
- **Developers:** [List developer emails]
- **Reviewers:** [List reviewer emails]

### Story Details
- **Story Points:** [1/2/3/5/8/13]
- **Work Type:** Operational Excellence
- **Sub-Team:** [Sub-team name]
- **Organization:** R&D

### Development Status
- **Development Status:** Not-Started

### Security
- **Requires Security Review:** Yes/No
- **Security Review Status:** Review Needed

### Quality Gates
- [ ] Tasks complete
- [ ] Functional Testing complete
- [ ] 100% code unit tested or Automated
- [ ] Acceptance criteria met
- [ ] i18n impact review

### Other
- **Risk Assessment:** Toss Up
- **Priority Level:** Normal
- **Category:** Uncategorized
- **Roadmap:** Future
