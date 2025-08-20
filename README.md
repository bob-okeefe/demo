# Azure DevOps Advanced Security Work Item Creator

This repository contains PowerShell scripts that integrate Azure DevOps Advanced Security secret scanning with Azure DevOps work items to automatically create work items for security findings.

## Scripts Overview

### 1. `Get-SecretScanningFindings.ps1`
The main script that retrieves secret scanning findings from Azure DevOps Advanced Security and formats them for work item creation.

**Features:**
- Fetches secret scanning alerts using Azure DevOps Advanced Security API
- Supports multiple output formats (Console, JSON, CSV)
- Includes file names and direct links to findings
- Prioritizes findings based on severity
- Comprehensive error handling and logging

### 2. `Create-WorkItemsFromSecrets.ps1`
An extension script that creates Azure DevOps work items for each secret scanning finding.

**Features:**
- Creates detailed work items with remediation steps
- Supports various work item types (Bug, Task, User Story, etc.)
- Automatic assignment and area/iteration path configuration
- Rich formatting with direct links to security alerts

## Prerequisites

- PowerShell 5.1 or later
- Azure DevOps organization with Advanced Security enabled
- Azure DevOps Personal Access Token with:
  - Advanced Security (read) permissions
  - Work Items (read & write) permissions

## Quick Start

### Basic Usage - View Findings

```powershell
# View secret scanning findings in console
.\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxxxxxxxxxxx"

# View findings for specific repository
.\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -Repository "myrepo" -PersonalAccessToken "xxxxxxxxxxxx"

# Export findings to JSON
.\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -OutputFormat "JSON"

# Export findings to CSV
.\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -OutputFormat "CSV"
```

### Create Work Items

```powershell
# Create work items for all repositories in project
.\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxxxxxxxxxxx"

# Create work items for specific repository
.\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -Repository "myrepo" -PersonalAccessToken "xxxxxxxxxxxx"

# Create Tasks instead of Bugs and assign to specific user
.\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxxxxxxxxxxx" -WorkItemType "Task" -AssignTo "user@company.com"

# Specify area and iteration paths
.\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxxxxxxxxxxx" -AreaPath "MyProject\Security" -IterationPath "MyProject\Sprint 1"
```

## Authentication Setup

### Azure DevOps Personal Access Token
1. Go to Azure DevOps → User settings → Personal access tokens
2. Create a new token with the following permissions:
   - **Advanced Security (read)** - Required to read secret scanning alerts
   - **Work Items (read & write)** - Required to create work items
3. Use the token with the `-PersonalAccessToken` parameter or set the `AZURE_DEVOPS_PAT` environment variable

## Output Examples

### Console Output
```
Alert #1: Secret Found: Azure Service Principal Secret
  Organization/Project: myorg/myproject
  Repository: myrepo
  File: config/appsettings.json:25
  Secret Type: Azure Service Principal Secret
  State: active
  Severity: high
  Priority: High
  Alert URL: https://dev.azure.com/myorg/myproject/_security/alerts/1
  Created: 2023-12-01T10:30:00Z
  Tags: security, secret-scanning, advanced-security

  Work Item Description:
  Advanced Security secret scanning has detected a Azure Service Principal Secret in the repository.
  File affected: config/appsettings.json
  Direct link to finding: https://dev.azure.com/myorg/myproject/_security/alerts/1

  Recommended Actions:
  1. Review the secret in file: config/appsettings.json
  2. Remove or rotate the exposed secret
  3. Update any systems using this secret
  4. Mark the alert as resolved in Azure DevOps
```

### JSON Output
```json
[
  {
    "AlertId": "abc123def456",
    "AlertNumber": 1,
    "Title": "Secret Found: Azure Service Principal Secret",
    "Description": "Advanced Security secret scanning has detected a Azure Service Principal Secret in the repository.",
    "SecretType": "Azure Service Principal Secret",
    "State": "active",
    "FileName": "config/appsettings.json",
    "LineNumber": 25,
    "Repository": "myrepo",
    "AlertUrl": "https://dev.azure.com/myorg/myproject/_security/alerts/1",
    "CreatedAt": "2023-12-01T10:30:00Z",
    "UpdatedAt": null,
    "Severity": "high",
    "Priority": "High",
    "Tags": ["security", "secret-scanning", "advanced-security"]
  }
]
```

## Work Item Content

When creating work items, each item includes:

- **Title**: Descriptive title with secret type
- **Description**: Detailed description with remediation steps
- **File Information**: Exact file path and line number
- **Direct Link**: URL to the Azure DevOps Advanced Security alert
- **Priority**: Automatically assigned based on severity level
- **Severity**: Security severity from Advanced Security
- **Tags**: Relevant tags for categorization
- **Assignment**: Optional assignment to specific team members
- **Area/Iteration**: Optional organization into project areas and iterations
- **Remediation Steps**: Step-by-step instructions for resolution

## Error Handling

The scripts include comprehensive error handling for common scenarios:

- Invalid or insufficient Azure DevOps PAT
- Project not found or access denied
- Advanced Security not enabled
- API rate limiting
- Network connectivity issues

## Customization

### Adding New Work Item Types

The script supports any work item type available in your Azure DevOps project:

```powershell
# Use different work item types
.\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxx" -WorkItemType "Task"
.\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxx" -WorkItemType "User Story"
.\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxx" -WorkItemType "Epic"
```

### Modifying Priority Logic

Edit the priority assignment in the `Format-FindingsForWorkItems` function:

```powershell
Priority = switch ($alert.severity) {
    'critical' { 'High' }
    'high' { 'High' }
    'medium' { 'Medium' }
    'low' { 'Low' }
    default { 'Medium' }
}
```

### Organization-Specific Configuration

You can create organization-specific configurations by setting default values:

```powershell
# Set organization defaults
$DefaultOrganization = "myorg"
$DefaultProject = "security"
$DefaultWorkItemType = "Bug"
$DefaultAreaPath = "Security\SecretScanning"
```

## Troubleshooting

### Common Issues

1. **"Access denied" error**: Ensure your Azure DevOps PAT has both 'Advanced Security' read and 'Work Items' read/write permissions
2. **"Project not found"**: Verify organization and project names are correct
3. **"Advanced Security not enabled"**: Ensure GitHub Advanced Security for Azure DevOps is enabled for your organization
4. **No alerts found**: The project may not have any active secret scanning alerts
5. **Work item creation fails**: Check that the work item type exists in your project and your PAT has sufficient permissions

### Debug Mode

Run scripts with `-Verbose` parameter for detailed logging:

```powershell
.\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -Verbose
```

### Testing the Integration

Use the console output mode to test without creating actual work items:

```powershell
# Test with a specific repository first
.\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -Repository "myrepo" -OutputFormat "Console"
```

## Security Considerations

- Store PATs securely and never commit them to source control
- Use environment variables for tokens when possible: `$env:AZURE_DEVOPS_PAT`
- Regularly rotate access tokens according to your organization's security policy
- Review and audit work items created for sensitive information
- Consider using Azure Key Vault or similar for token management in production
- Limit PAT permissions to only what is required (Advanced Security read + Work Items read/write)

## Advanced Usage

### Batch Processing Multiple Projects

```powershell
# Process multiple projects
$projects = @("project1", "project2", "project3")
foreach ($project in $projects) {
    .\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project $project -PersonalAccessToken $env:AZURE_DEVOPS_PAT
}
```

### Integration with CI/CD Pipelines

You can integrate these scripts into Azure DevOps pipelines for automated work item creation:

```yaml
- task: PowerShell@2
  displayName: 'Create Work Items from Secret Scanning Findings'
  inputs:
    filePath: 'scripts/Create-WorkItemsFromSecrets.ps1'
    arguments: '-Organization "$(System.TeamFoundationCollectionUri)" -Project "$(System.TeamProject)" -PersonalAccessToken "$(System.AccessToken)"'
```

## Contributing

When contributing to this project:

1. Follow PowerShell best practices
2. Include comprehensive error handling
3. Add parameter validation
4. Update documentation for new features
5. Test with various Azure DevOps project scenarios
6. Ensure compatibility with different Advanced Security configurations

## License

This project is provided as-is for demonstration purposes. Modify and adapt as needed for your organization's requirements.

## Additional Resources

- [Azure DevOps Advanced Security Documentation](https://docs.microsoft.com/en-us/azure/devops/repos/security/)
- [Azure DevOps REST API Reference](https://docs.microsoft.com/en-us/rest/api/azure/devops/)
- [Azure DevOps Work Items API](https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)