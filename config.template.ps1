# GitHub Secret Scanning Work Item Creator - Configuration Template
#
# Copy this file to 'config.ps1' and customize the values for your environment.
# Then dot-source it in your scripts: . .\config.ps1

# GitHub Configuration
$GitHubConfiguration = @{
    # Default GitHub token (alternatively use GITHUB_TOKEN environment variable)
    Token = $env:GITHUB_TOKEN
    
    # Default repository settings
    DefaultOwner = "your-org"
    
    # API settings
    MaxRetries = 3
    RetryDelay = 5  # seconds
}

# Work Item System Configurations
$WorkItemSystems = @{
    # GitHub Issues Configuration
    GitHubIssues = @{
        Enabled = $true
        Token = $env:GITHUB_TOKEN  # Can be same as main GitHub token
        Labels = @("security", "secret-scanning", "automated")
        AssignDefaultUsers = $false
        DefaultAssignees = @()  # Add usernames if needed
    }
    
    # Azure DevOps Configuration
    AzureDevOps = @{
        Enabled = $false
        Organization = "your-organization"
        Project = "your-project"
        PAT = $env:AZURE_DEVOPS_PAT
        WorkItemType = "Bug"  # or "Task", "User Story", etc.
        AreaPath = ""  # Optional: specific area path
        IterationPath = ""  # Optional: specific iteration
        DefaultAssignee = ""  # Optional: default assignee email
    }
    
    # Jira Configuration (for future extension)
    Jira = @{
        Enabled = $false
        BaseUrl = "https://your-company.atlassian.net"
        Username = ""
        ApiToken = $env:JIRA_API_TOKEN
        ProjectKey = "SEC"
        IssueType = "Bug"
        DefaultAssignee = ""
    }
}

# Priority Mapping
$PriorityMapping = @{
    # Customize priority assignment based on secret types
    High = @(
        "password",
        "private.*key",
        "secret.*key", 
        "github.*token",
        "aws.*secret",
        "azure.*key"
    )
    Medium = @(
        "api.*key",
        "access.*key",
        "client.*secret"
    )
    Low = @(
        "webhook",
        "generic.*secret"
    )
}

# Output Configuration
$OutputConfiguration = @{
    # Default output format
    DefaultFormat = "Console"  # Console, JSON, CSV
    
    # CSV export settings
    CsvPath = ".\exports\"
    CsvFilePattern = "SecretScanningFindings_{Owner}_{Repo}_{Date}.csv"
    
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
        Subject = "Secret Scanning Alerts - Work Items Created"
    }
    
    # Slack notifications (requires webhook URL)
    Slack = @{
        Enabled = $false
        WebhookUrl = $env:SLACK_WEBHOOK_URL
        Channel = "#security"
        Username = "Secret Scanner Bot"
    }
    
    # Microsoft Teams notifications
    Teams = @{
        Enabled = $false
        WebhookUrl = $env:TEAMS_WEBHOOK_URL
    }
}

# Advanced Configuration
$AdvancedConfiguration = @{
    # Include resolved alerts in processing
    IncludeResolvedAlerts = $false
    
    # Skip work item creation for specific secret types
    SkipSecretTypes = @()
    
    # Custom tags to add to all work items
    CustomTags = @("automated", "security-scan")
    
    # Rate limiting (requests per minute)
    RateLimitPerMinute = 60
    
    # Retry configuration
    MaxRetries = 3
    RetryDelay = 5
    
    # Batch processing
    BatchSize = 10
    ProcessBatchDelay = 2  # seconds between batches
}

# Function to validate configuration
function Test-Configuration {
    $errors = @()
    
    # Check required GitHub configuration
    if (-not $GitHubConfiguration.Token -and -not $env:GITHUB_TOKEN) {
        $errors += "GitHub token not configured. Set GitHubConfiguration.Token or GITHUB_TOKEN environment variable."
    }
    
    # Check enabled work item systems
    $enabledSystems = $WorkItemSystems.Keys | Where-Object { $WorkItemSystems[$_].Enabled }
    
    foreach ($system in $enabledSystems) {
        switch ($system) {
            'AzureDevOps' {
                $config = $WorkItemSystems.AzureDevOps
                if (-not $config.Organization) { $errors += "AzureDevOps.Organization not configured" }
                if (-not $config.Project) { $errors += "AzureDevOps.Project not configured" }
                if (-not $config.PAT -and -not $env:AZURE_DEVOPS_PAT) { $errors += "AzureDevOps.PAT not configured" }
            }
            'Jira' {
                $config = $WorkItemSystems.Jira
                if (-not $config.BaseUrl) { $errors += "Jira.BaseUrl not configured" }
                if (-not $config.Username) { $errors += "Jira.Username not configured" }
                if (-not $config.ApiToken -and -not $env:JIRA_API_TOKEN) { $errors += "Jira.ApiToken not configured" }
            }
        }
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

# Export configuration for use in other scripts
Export-ModuleMember -Variable GitHubConfiguration, WorkItemSystems, PriorityMapping, OutputConfiguration, NotificationConfiguration, AdvancedConfiguration
Export-ModuleMember -Function Test-Configuration