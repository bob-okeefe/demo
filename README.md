# GitHub Dashboard

A console application that shows you all outstanding Pull Requests that you need to review.

## Features

- Fetches pull requests that might need your review
- Displays them in a clean table format
- Allows you to open PRs directly in your browser
- Supports multiple authentication methods
- Fallback to show recent open PRs if no specific review requests found

## Prerequisites

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
export GITHUB_TOKEN=your_token_here
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

The application will:
1. Connect to GitHub using your token
2. Search for pull requests that might need your review
3. Display them in a table format
4. Allow you to select a PR number to open it in your browser

## Sample Output

```
GitHub Dashboard - Pull Requests to Review
==========================================

Connecting to GitHub...
Connected as: username (Your Name)

Fetching pull requests that need your review...
Found 3 pull request(s) that might need your review:

 ---------------------------------------------------------------
 | Repository    | Title                | Author   | Created    | URL                           |
 ---------------------------------------------------------------
 | user/repo1    | Fix authentication   | john     | 12/15/2023 | https://github.com/user/...  |
 | user/repo2    | Add new feature      | jane     | 12/14/2023 | https://github.com/user/...  |
 | org/project   | Update documentation | bob      | 12/13/2023 | https://github.com/org/...   |
 ---------------------------------------------------------------

To open a pull request in your browser, enter its number (1-based index):
PR number (or press Enter to skip): 1
```

## Building for Distribution

To create a self-contained executable:

```bash
dotnet publish -c Release -r win-x64 --self-contained
```

This creates an executable in `bin/Release/net8.0/win-x64/publish/` that can run without .NET installed.

## Limitations

- The application uses a simplified approach to identify PRs that might need review
- GitHub's API rate limits may apply (60 requests per hour without authentication, 5000 with)
- Some private repositories may not be accessible depending on your token permissions

## Troubleshooting

**"Invalid GitHub token"**: Make sure your token has the correct permissions and hasn't expired.

**"No pull requests found"**: This is normal if there are no PRs currently requiring your review. The app will show recent open PRs as an alternative.

**Rate limit errors**: Wait for the rate limit to reset or ensure you're using an authenticated token.