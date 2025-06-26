using System.Diagnostics;
using Microsoft.Extensions.Configuration;
using Octokit;

namespace GitHubDashboard;

public partial class MainForm : Form
{
    private GitHubClient? _gitHubClient;
    private IConfiguration? _configuration;
    private List<Issue> _currentPullRequests = new();

    // UI Controls
    private TextBox _tokenTextBox = null!;
    private Button _connectButton = null!;
    private System.Windows.Forms.Label _statusLabel = null!;
    private DataGridView _pullRequestsGrid = null!;
    private Button _refreshButton = null!;
    private Button _openPrButton = null!;

    public MainForm()
    {
        InitializeComponent();
        LoadConfiguration();
        LoadTokenFromSources();
    }

    private void InitializeComponent()
    {
        Text = "GitHub Dashboard - Pull Requests to Review";
        Size = new Size(1000, 600);
        StartPosition = FormStartPosition.CenterScreen;

        // Token input section
        var tokenLabel = new System.Windows.Forms.Label
        {
            Text = "GitHub Token:",
            Location = new Point(10, 15),
            Size = new Size(100, 23)
        };

        _tokenTextBox = new TextBox
        {
            Location = new Point(120, 12),
            Size = new Size(400, 23),
            UseSystemPasswordChar = true
        };

        _connectButton = new Button
        {
            Text = "Connect",
            Location = new Point(530, 11),
            Size = new Size(80, 25)
        };
        _connectButton.Click += ConnectButton_Click;

        // Status label
        _statusLabel = new System.Windows.Forms.Label
        {
            Text = "Enter your GitHub token and click Connect",
            Location = new Point(10, 50),
            Size = new Size(800, 23),
            ForeColor = Color.Blue
        };

        // Pull requests grid
        _pullRequestsGrid = new DataGridView
        {
            Location = new Point(10, 85),
            Size = new Size(960, 400),
            AllowUserToAddRows = false,
            AllowUserToDeleteRows = false,
            ReadOnly = true,
            SelectionMode = DataGridViewSelectionMode.FullRowSelect,
            MultiSelect = false,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill
        };

        // Setup grid columns
        _pullRequestsGrid.Columns.Add("Repository", "Repository");
        _pullRequestsGrid.Columns.Add("Title", "Title");
        _pullRequestsGrid.Columns.Add("Author", "Author");
        _pullRequestsGrid.Columns.Add("Created", "Created");
        _pullRequestsGrid.Columns.Add("Url", "URL");

        // Buttons
        _refreshButton = new Button
        {
            Text = "Refresh",
            Location = new Point(10, 500),
            Size = new Size(80, 30),
            Enabled = false
        };
        _refreshButton.Click += RefreshButton_Click;

        _openPrButton = new Button
        {
            Text = "Open Selected PR",
            Location = new Point(100, 500),
            Size = new Size(120, 30),
            Enabled = false
        };
        _openPrButton.Click += OpenPrButton_Click;

        // Add controls to form
        Controls.AddRange(new Control[]
        {
            tokenLabel, _tokenTextBox, _connectButton,
            _statusLabel, _pullRequestsGrid,
            _refreshButton, _openPrButton
        });
    }

    private void LoadConfiguration()
    {
        var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true)
            .AddEnvironmentVariables()
            .AddCommandLine(Environment.GetCommandLineArgs());

        _configuration = builder.Build();
    }

    private void LoadTokenFromSources()
    {
        // Check command line arguments
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == "--token")
            {
                _tokenTextBox.Text = args[i + 1];
                return;
            }
        }

        // Check configuration
        var token = _configuration?["GitHub:Token"] ?? 
                   _configuration?["GITHUB_TOKEN"] ?? 
                   Environment.GetEnvironmentVariable("GITHUB_TOKEN");

        if (!string.IsNullOrEmpty(token))
        {
            _tokenTextBox.Text = token;
        }
    }

    private async void ConnectButton_Click(object? sender, EventArgs e)
    {
        var token = _tokenTextBox.Text.Trim();
        if (string.IsNullOrEmpty(token))
        {
            MessageBox.Show("Please enter a GitHub token.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        _connectButton.Enabled = false;
        _statusLabel.Text = "Connecting to GitHub...";
        _statusLabel.ForeColor = Color.Blue;

        try
        {
            await ConnectToGitHub(token);
            _statusLabel.Text = $"Connected successfully!";
            _statusLabel.ForeColor = Color.Green;
            _refreshButton.Enabled = true;
            
            // Automatically load pull requests
            await LoadPullRequests();
        }
        catch (Exception ex)
        {
            _statusLabel.Text = $"Connection failed: {ex.Message}";
            _statusLabel.ForeColor = Color.Red;
        }
        finally
        {
            _connectButton.Enabled = true;
        }
    }

    private async Task ConnectToGitHub(string token)
    {
        _gitHubClient = new GitHubClient(new ProductHeaderValue("GitHubDashboard"))
        {
            Credentials = new Credentials(token)
        };

        try
        {
            var user = await _gitHubClient.User.Current();
            Text = $"GitHub Dashboard - Connected as: {user.Login} ({user.Name})";
        }
        catch (AuthorizationException)
        {
            throw new Exception("Invalid GitHub token. Please check your token and try again.");
        }
    }

    private async void RefreshButton_Click(object? sender, EventArgs e)
    {
        await LoadPullRequests();
    }

    private async Task LoadPullRequests()
    {
        if (_gitHubClient == null) return;

        _refreshButton.Enabled = false;
        _statusLabel.Text = "Fetching pull requests...";
        _statusLabel.ForeColor = Color.Blue;

        try
        {
            var currentUser = await _gitHubClient.User.Current();
            
            // Search for open pull requests
            var searchRequest = new SearchIssuesRequest()
            {
                Type = IssueTypeQualifier.PullRequest,
                State = ItemState.Open
            };

            var searchResult = await _gitHubClient.Search.SearchIssues(searchRequest);
            
            // Filter for pull requests where the user might need to review
            var potentialReviews = new List<Issue>();
            
            foreach (var issue in searchResult.Items.Take(50)) // Limit to first 50 for performance
            {
                try
                {
                    // Get detailed PR information
                    var pr = await _gitHubClient.PullRequest.Get(issue.Repository.Id, issue.Number);
                    
                    // Skip own PRs
                    if (pr.User.Login == currentUser.Login)
                        continue;
                        
                    // Add to potential reviews if it's not the user's own PR
                    potentialReviews.Add(issue);
                }
                catch
                {
                    // Skip PRs we can't access
                    continue;
                }
            }
            
            _currentPullRequests = potentialReviews;

            if (potentialReviews.Count == 0)
            {
                _statusLabel.Text = "No pull requests found that might need your review. Showing recent open PRs...";
                _statusLabel.ForeColor = Color.Orange;
                
                // Show alternative - recent PRs
                var recentPRs = searchResult.Items.Take(10).ToList();
                _currentPullRequests = recentPRs;
                DisplayPullRequests(recentPRs);
            }
            else
            {
                _statusLabel.Text = $"Found {potentialReviews.Count} pull request(s) that might need your review";
                _statusLabel.ForeColor = Color.Green;
                DisplayPullRequests(potentialReviews);
            }

            _openPrButton.Enabled = _currentPullRequests.Count > 0;
        }
        catch (Exception ex)
        {
            _statusLabel.Text = $"Failed to fetch pull requests: {ex.Message}";
            _statusLabel.ForeColor = Color.Red;
        }
        finally
        {
            _refreshButton.Enabled = true;
        }
    }

    private void DisplayPullRequests(List<Issue> issues)
    {
        _pullRequestsGrid.Rows.Clear();
        
        foreach (var issue in issues)
        {
            var row = new DataGridViewRow();
            row.CreateCells(_pullRequestsGrid);
            
            row.Cells[0].Value = issue.Repository.FullName;
            row.Cells[1].Value = TruncateString(issue.Title, 80);
            row.Cells[2].Value = issue.User.Login;
            row.Cells[3].Value = issue.CreatedAt.ToString("MM/dd/yyyy");
            row.Cells[4].Value = issue.HtmlUrl;
            
            row.Tag = issue; // Store the issue object for later use
            
            _pullRequestsGrid.Rows.Add(row);
        }
    }

    private void OpenPrButton_Click(object? sender, EventArgs e)
    {
        if (_pullRequestsGrid.SelectedRows.Count == 0)
        {
            MessageBox.Show("Please select a pull request to open.", "No Selection", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        var selectedRow = _pullRequestsGrid.SelectedRows[0];
        if (selectedRow.Tag is Issue issue)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = issue.HtmlUrl,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Could not open browser: {ex.Message}\n\nURL: {issue.HtmlUrl}", 
                    "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    private static string TruncateString(string value, int maxLength)
    {
        if (string.IsNullOrEmpty(value)) return value;
        return value.Length <= maxLength ? value : value.Substring(0, maxLength - 3) + "...";
    }
}