# Azure DevOps Advanced Security Work Item Creator - Configuration Template
#
# Copy this file to 'config.ps1' and customize the values for your environment.
# Then dot-source it in your scripts: . .\config.ps1

# Azure DevOps Configuration
$AzureDevOpsConfiguration = @{
    # Default Azure DevOps PAT (alternatively use AZURE_DEVOPS_PAT environment variable)
    PAT = $env:AZURE_DEVOPS_PAT
    
    # Default organization and project settings
    DefaultOrganization = "your-organization"
    DefaultProject = "your-project"
    
    # API settings
    MaxRetries = 3
    RetryDelay = 5  # seconds
    ApiVersion = "7.1-preview.1"
}

# Work Item Configuration
$WorkItemConfiguration = @{
    # Default work item type
    DefaultType = "Bug"  # Can be "Bug", "Task", "User Story", "Epic", etc.
    
    # Default assignment settings
    DefaultAssignee = ""  # Leave empty for unassigned, or specify email/display name
    
    # Default area and iteration paths
    DefaultAreaPath = ""  # e.g., "MyProject\Security"
    DefaultIterationPath = ""  # e.g., "MyProject\Sprint 1"
    
    # Custom field mappings (if your organization uses custom fields)
    CustomFields = @{
        # Example: Map severity to a custom field
        # "Custom.SecuritySeverity" = "Severity"
    }
}

# Priority Mapping
$PriorityMapping = @{
    # Customize priority assignment based on Advanced Security severity levels
    High = @(
        "critical",
        "high"
    )
    Medium = @(
        "medium"
    )
    Low = @(
        "low"
    )
}

# Severity Mapping for Work Items
$SeverityMapping = @{
    critical = "1 - Critical"
    high = "2 - High"
    medium = "3 - Medium"
    low = "4 - Low"
}

# Repository Configuration
$RepositoryConfiguration = @{
    # Include specific repositories (leave empty to include all)
    IncludeRepositories = @()  # e.g., @("repo1", "repo2")
    
    # Exclude specific repositories
    ExcludeRepositories = @()  # e.g., @("test-repo", "archived-repo")
    
    # Include resolved alerts in processing
    IncludeResolvedAlerts = $false
}

# Output Configuration
$OutputConfiguration = @{
    # Default output format
    DefaultFormat = "Console"  # Console, JSON, CSV
    
    # CSV export settings
    CsvPath = ".\exports\"
    CsvFilePattern = "SecretScanningFindings_{Organization}_{Project}_{Date}.csv"
    
    # Logging settings
    EnableLogging = $true
    LogPath = ".\logs\"
    LogFilePattern = "SecretScanning_{Date}.log"
    LogLevel = "Info"  # Debug, Info, Warning, Error
}

# Notification Configuration
$NotificationConfiguration = @{
    # Email notifications (requires additional setup)
    Email = @{
        Enabled = $false
        SmtpServer = ""
        Port = 587
        UseSsl = $true
        From = ""
        To = @()
        Subject = "Azure DevOps Secret Scanning Alerts - Work Items Created"
    }
    
    # Slack notifications (requires webhook URL)
    Slack = @{
        Enabled = $false
        WebhookUrl = $env:SLACK_WEBHOOK_URL
        Channel = "#security"
        Username = "Advanced Security Bot"
    }
    
    # Microsoft Teams notifications
    Teams = @{
        Enabled = $false
        WebhookUrl = $env:TEAMS_WEBHOOK_URL
    }
}

# Advanced Configuration
$AdvancedConfiguration = @{
    # Skip work item creation for specific secret types/patterns
    SkipSecretTypes = @()  # e.g., @("Test secrets", "Generic secrets")
    
    # Custom tags to add to all work items
    CustomTags = @("automated", "advanced-security", "secret-scanning")
    
    # Rate limiting (requests per minute for Azure DevOps API)
    RateLimitPerMinute = 60
    
    # Retry configuration
    MaxRetries = 3
    RetryDelay = 5
    
    # Batch processing
    BatchSize = 10
    ProcessBatchDelay = 2  # seconds between batches
    
    # Work item template customization
    WorkItemTemplate = @{
        TitlePrefix = "Secret Found: "
        DescriptionTemplate = "Advanced Security secret scanning has detected a {SecretType} in the repository."
        IncludeRemediationSteps = $true
        IncludeDirectLinks = $true
    }
}

# Function to validate configuration
function Test-Configuration {
    $errors = @()
    
    # Check required Azure DevOps configuration
    if (-not $AzureDevOpsConfiguration.PAT -and -not $env:AZURE_DEVOPS_PAT) {
        $errors += "Azure DevOps PAT not configured. Set AzureDevOpsConfiguration.PAT or AZURE_DEVOPS_PAT environment variable."
    }
    
    if (-not $AzureDevOpsConfiguration.DefaultOrganization) {
        $errors += "AzureDevOpsConfiguration.DefaultOrganization not configured"
    }
    
    if (-not $AzureDevOpsConfiguration.DefaultProject) {
        $errors += "AzureDevOpsConfiguration.DefaultProject not configured"
    }
    
    # Validate work item configuration
    if (-not $WorkItemConfiguration.DefaultType) {
        $errors += "WorkItemConfiguration.DefaultType not configured"
    }
    
    # Create required directories
    $directories = @(
        $OutputConfiguration.CsvPath,
        $OutputConfiguration.LogPath
    )
    
    foreach ($dir in $directories | Where-Object { $_ }) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Verbose "Created directory: $dir"
            }
            catch {
                $errors += "Failed to create directory: $dir"
            }
        }
    }
    
    if ($errors.Count -gt 0) {
        Write-Warning "Configuration validation failed:"
        $errors | ForEach-Object { Write-Warning "  - $_" }
        return $false
    }
    
    Write-Verbose "Configuration validation passed."
    return $true
}

# Function to get configuration values with fallbacks
function Get-ConfigValue {
    param(
        [string]$ConfigPath,
        [object]$DefaultValue = $null
    )
    
    $pathParts = $ConfigPath -split '\.'
    $current = $this
    
    foreach ($part in $pathParts) {
        if ($current -and $current.ContainsKey($part)) {
            $current = $current[$part]
        } else {
            return $DefaultValue
        }
    }
    
    return $current
}

# Export configuration for use in other scripts
Export-ModuleMember -Variable AzureDevOpsConfiguration, WorkItemConfiguration, PriorityMapping, SeverityMapping, RepositoryConfiguration, OutputConfiguration, NotificationConfiguration, AdvancedConfiguration
Export-ModuleMember -Function Test-Configuration, Get-ConfigValue