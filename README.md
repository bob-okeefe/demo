# GitHub Dashboard

A Windows Forms application that shows you all outstanding Pull Requests that you need to review.

## Features

- **Windows Forms GUI**: Modern Windows desktop interface with DataGridView display
- Fetches pull requests that might need your review
- Displays them in a sortable, selectable table format
- Allows you to open PRs directly in your browser with a button click
- Supports multiple authentication methods
- Fallback to show recent open PRs if no specific review requests found
- Real-time status updates and error handling

## Prerequisites

- **Windows operating system** (Windows Forms requires Windows)
- .NET 8.0 or later
- GitHub Personal Access Token with appropriate permissions

## Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/bob-okeefe/demo.git
   cd demo/GitHubDashboard
   ```

2. **Restore dependencies**
   ```bash
   dotnet restore
   ```

3. **Build the application**
   ```bash
   dotnet build
   ```

## Authentication

You need a GitHub Personal Access Token to use this application. You can provide it in three ways:

### Option 1: Environment Variable
```bash
set GITHUB_TOKEN=your_token_here
dotnet run
```

### Option 2: Configuration File
Create or edit `appsettings.json`:
```json
{
  "GitHub": {
    "Token": "your_token_here"
  }
}
```

### Option 3: Command Line Argument
```bash
dotnet run -- --token your_token_here
```

### Option 4: Enter in Application
You can also enter your token directly in the application's text field when it starts.

## Creating a GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Click "Generate new token (classic)"
3. Give it a descriptive name
4. Select the following scopes:
   - `repo` (Full control of private repositories)
   - `read:org` (Read org and team membership)
5. Click "Generate token"
6. Copy the token immediately (you won't see it again)

## Usage

Run the application:
```bash
dotnet run
```

The Windows Forms application will open with:
1. **Token Input**: Enter your GitHub token (or it will auto-populate from environment/config)
2. **Connect Button**: Click to authenticate with GitHub
3. **Status Display**: Shows connection status and progress
4. **Pull Requests Grid**: Displays PRs in a sortable table with columns for Repository, Title, Author, Created date, and URL
5. **Refresh Button**: Reload the pull requests list
6. **Open Selected PR Button**: Opens the selected PR in your default browser

## Application Interface

The main window includes:
- **GitHub Token field**: Masked input for your personal access token
- **Connect button**: Establishes connection to GitHub API
- **Status label**: Shows current operation status and connection info
- **Pull Requests grid**: Displays PRs in columns (Repository, Title, Author, Created, URL)
- **Refresh button**: Reloads the PR list
- **Open Selected PR button**: Opens the selected PR in your browser

## Building for Distribution

To create a self-contained Windows executable:

```bash
dotnet publish -c Release -r win-x64 --self-contained
```

This creates an executable in `bin/Release/net8.0-windows/win-x64/publish/` that can run on Windows without .NET installed.

For other Windows architectures:
```bash
# For 32-bit Windows
dotnet publish -c Release -r win-x86 --self-contained

# For ARM64 Windows
dotnet publish -c Release -r win-arm64 --self-contained
```

## Limitations

- **Windows Only**: This is a Windows Forms application and requires Windows to build and run
- The application uses a simplified approach to identify PRs that might need review
- GitHub's API rate limits may apply (60 requests per hour without authentication, 5000 with)
- Some private repositories may not be accessible depending on your token permissions

## Troubleshooting

**"Invalid GitHub token"**: Make sure your token has the correct permissions and hasn't expired.

**"No pull requests found"**: This is normal if there are no PRs currently requiring your review. The app will show recent open PRs as an alternative.

**Rate limit errors**: Wait for the rate limit to reset or ensure you're using an authenticated token.

**Build errors on non-Windows**: This application requires Windows to build and run due to Windows Forms dependency.