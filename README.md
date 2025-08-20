# GitHub Secret Scanning Work Item Creator

This repository contains PowerShell scripts that integrate GitHub's Secret Scanning API with work item systems to automatically create work items for security findings.

## Scripts Overview

### 1. `Get-SecretScanningFindings.ps1`
The main script that retrieves secret scanning findings from a GitHub repository and formats them for work item creation.

**Features:**
- Fetches secret scanning alerts using GitHub API
- Supports multiple output formats (Console, JSON, CSV)
- Includes file names and direct links to findings
- Prioritizes findings based on secret type
- Comprehensive error handling and logging

### 2. `Create-WorkItemsFromSecrets.ps1`
An extension script that creates actual work items in various systems.

**Supported Systems:**
- GitHub Issues
- Azure DevOps (Work Items)
- Console output (for testing)

## Prerequisites

- PowerShell 5.1 or later
- GitHub Personal Access Token with `security_events` scope
- For Azure DevOps integration: Azure DevOps PAT with work item creation permissions

## Quick Start

### Basic Usage - View Findings

```powershell
# View secret scanning findings in console
.\Get-SecretScanningFindings.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -GitHubToken "ghp_xxxxxxxxxxxx"

# Export findings to JSON
.\Get-SecretScanningFindings.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -OutputFormat "JSON"

# Export findings to CSV
.\Get-SecretScanningFindings.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -OutputFormat "CSV"
```

### Create Work Items

```powershell
# Create GitHub Issues
.\Create-WorkItemsFromSecrets.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -GitHubToken "ghp_xxxxxxxxxxxx" -WorkItemSystem "GitHubIssues"

# Create Azure DevOps Work Items
.\Create-WorkItemsFromSecrets.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -GitHubToken "ghp_xxxxxxxxxxxx" -WorkItemSystem "AzureDevOps" -AzureDevOpsOrganization "myorg" -AzureDevOpsProject "myproject" -AzureDevOpsPAT "xxxxxxxxxx"

# Test output to console
.\Create-WorkItemsFromSecrets.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -GitHubToken "ghp_xxxxxxxxxxxx" -WorkItemSystem "Console"
```

## Authentication Setup

### GitHub Token
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Create a new token with the `security_events` scope
3. Use the token with the `-GitHubToken` parameter or set the `GITHUB_TOKEN` environment variable

### Azure DevOps PAT
1. Go to Azure DevOps → User settings → Personal access tokens
2. Create a new token with "Work Items (read & write)" permissions
3. Use with the `-AzureDevOpsPAT` parameter

## Output Examples

### Console Output
```
Alert #1: Secret Found: GitHub Personal Access Token
  Repository: myorg/myrepo
  File: config/settings.json:15
  Secret Type: GitHub Personal Access Token
  State: open
  Priority: High
  GitHub URL: https://github.com/myorg/myrepo/security/secret-scanning/1
  Created: 2023-12-01T10:30:00Z
  Tags: security, secret-scanning, github_personal_access_token

  Work Item Description:
  Secret scanning has detected a GitHub Personal Access Token in the repository.
  File affected: config/settings.json
  Direct link to finding: https://github.com/myorg/myrepo/security/secret-scanning/1

  Recommended Actions:
  1. Review the secret in file: config/settings.json
  2. Remove or rotate the exposed secret
  3. Update any systems using this secret
  4. Mark the alert as resolved in GitHub
```

### JSON Output
```json
[
  {
    "AlertNumber": 1,
    "Title": "Secret Found: GitHub Personal Access Token",
    "Description": "Secret scanning has detected a GitHub Personal Access Token in the repository.",
    "SecretType": "GitHub Personal Access Token",
    "State": "open",
    "FileName": "config/settings.json",
    "LineNumber": 15,
    "GitHubAlertUrl": "https://github.com/myorg/myrepo/security/secret-scanning/1",
    "CreatedAt": "2023-12-01T10:30:00Z",
    "UpdatedAt": "2023-12-01T10:30:00Z",
    "Repository": "myorg/myrepo",
    "Priority": "High",
    "Tags": ["security", "secret-scanning", "github_personal_access_token"]
  }
]
```

## Work Item Content

When creating work items, each item includes:

- **Title**: Descriptive title with secret type
- **Description**: Detailed description with remediation steps
- **File Information**: Exact file path and line number
- **Direct Link**: URL to the GitHub security alert
- **Priority**: Automatically assigned based on secret type
- **Tags**: Relevant tags for categorization
- **Remediation Steps**: Step-by-step instructions for resolution

## Error Handling

The scripts include comprehensive error handling for common scenarios:

- Invalid or insufficient GitHub tokens
- Repository not found or access denied
- Secret scanning not enabled
- API rate limiting
- Network connectivity issues

## Customization

### Adding New Work Item Systems

To add support for a new work item system:

1. Add the system to the `ValidateSet` in `Create-WorkItemsFromSecrets.ps1`
2. Add required parameters for authentication
3. Create a new function following the pattern `New-[SystemName]WorkItem`
4. Add the case to the switch statement in the main execution

### Modifying Priority Logic

Edit the priority assignment in the `Format-FindingsForWorkItems` function:

```powershell
Priority = switch ($alert.secret_type) {
    { $_ -match '(password|private.*key|secret.*key|token)' } { 'High' }
    { $_ -match '(api.*key|access.*key)' } { 'Medium' }
    default { 'Low' }
}
```

## Troubleshooting

### Common Issues

1. **"Access denied" error**: Ensure your GitHub token has the `security_events` scope
2. **"Repository not found"**: Verify repository name and that secret scanning is enabled
3. **No alerts found**: The repository may not have any secret scanning alerts, or they may all be resolved
4. **Azure DevOps work item creation fails**: Check that your PAT has sufficient permissions

### Debug Mode

Run scripts with `-Verbose` parameter for detailed logging:

```powershell
.\Get-SecretScanningFindings.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -Verbose
```

## Security Considerations

- Store tokens securely and never commit them to source control
- Use environment variables for tokens when possible
- Regularly rotate access tokens
- Review and audit work items created for sensitive information

## Contributing

When contributing to this project:

1. Follow PowerShell best practices
2. Include comprehensive error handling
3. Add parameter validation
4. Update documentation for new features
5. Test with various repository scenarios

## License

This project is provided as-is for demonstration purposes. Modify and adapt as needed for your organization's requirements.