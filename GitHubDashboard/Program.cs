using System.Diagnostics;
using ConsoleTables;
using Microsoft.Extensions.Configuration;
using Octokit;

namespace GitHubDashboard;

class Program
{
    private static GitHubClient? _gitHubClient;
    private static IConfiguration? _configuration;

    static async Task Main(string[] args)
    {
        Console.WriteLine("GitHub Dashboard - Pull Requests to Review");
        Console.WriteLine("==========================================");
        Console.WriteLine();

        LoadConfiguration();

        var token = GetGitHubToken();
        if (string.IsNullOrEmpty(token))
        {
            Console.WriteLine("GitHub token not found. Please set one of the following:");
            Console.WriteLine("1. Set GITHUB_TOKEN environment variable");
            Console.WriteLine("2. Create appsettings.json with GitHub:Token value");
            Console.WriteLine("3. Pass token as command line argument: --token YOUR_TOKEN");
            return;
        }

        try
        {
            await ConnectToGitHub(token);
            await DisplayPullRequestsToReview();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
            Environment.Exit(1);
        }

        Console.WriteLine();
        Console.WriteLine("Press any key to exit...");
        Console.ReadKey();
    }

    private static void LoadConfiguration()
    {
        var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true)
            .AddEnvironmentVariables()
            .AddCommandLine(Environment.GetCommandLineArgs());

        _configuration = builder.Build();
    }

    private static string? GetGitHubToken()
    {
        // Check command line arguments
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == "--token")
            {
                return args[i + 1];
            }
        }

        // Check configuration
        return _configuration?["GitHub:Token"] ?? 
               _configuration?["GITHUB_TOKEN"] ?? 
               Environment.GetEnvironmentVariable("GITHUB_TOKEN");
    }

    private static async Task ConnectToGitHub(string token)
    {
        Console.WriteLine("Connecting to GitHub...");
        
        _gitHubClient = new GitHubClient(new ProductHeaderValue("GitHubDashboard"))
        {
            Credentials = new Credentials(token)
        };

        try
        {
            var user = await _gitHubClient.User.Current();
            Console.WriteLine($"Connected as: {user.Login} ({user.Name})");
            Console.WriteLine();
        }
        catch (AuthorizationException)
        {
            throw new Exception("Invalid GitHub token. Please check your token and try again.");
        }
    }

    private static async Task DisplayPullRequestsToReview()
    {
        Console.WriteLine("Fetching pull requests that need your review...");
        
        try
        {
            var currentUser = await _gitHubClient!.User.Current();
            
            // Search for open pull requests using a more basic approach
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
                    
                    // Check if user has write access to the repository (potential reviewer)
                    var repo = await _gitHubClient.Repository.Get(issue.Repository.Id);
                    
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
            
            if (potentialReviews.Count == 0)
            {
                Console.WriteLine("No pull requests found that might need your review.");
                
                // Show alternative - search for PRs in user's organizations
                Console.WriteLine("Searching for recent open PRs...");
                var recentPRs = searchResult.Items.Take(10).ToList();
                
                if (recentPRs.Count > 0)
                {
                    Console.WriteLine($"Found {recentPRs.Count} recent open PRs:");
                    DisplayPullRequests(recentPRs);
                }
                return;
            }

            Console.WriteLine($"Found {potentialReviews.Count} pull request(s) that might need your review:");
            Console.WriteLine();
            DisplayPullRequests(potentialReviews);
        }
        catch (Exception ex)
        {
            throw new Exception($"Failed to fetch pull requests: {ex.Message}");
        }
    }

    private static void DisplayPullRequests(IReadOnlyList<Issue> issues)
    {
        var table = new ConsoleTable("Repository", "Title", "Author", "Created", "URL");
        
        foreach (var issue in issues)
        {
            table.AddRow(
                issue.Repository.FullName,
                TruncateString(issue.Title, 50),
                issue.User.Login,
                issue.CreatedAt.ToString("MM/dd/yyyy"),
                issue.HtmlUrl
            );
        }

        table.Write();
        
        Console.WriteLine();
        Console.WriteLine("To open a pull request in your browser, enter its number (1-based index):");
        Console.Write("PR number (or press Enter to skip): ");
        
        var input = Console.ReadLine();
        if (int.TryParse(input, out int prNumber) && prNumber > 0 && prNumber <= issues.Count)
        {
            var selectedPr = issues[prNumber - 1];
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = selectedPr.HtmlUrl,
                    UseShellExecute = true
                });
            }
            catch
            {
                Console.WriteLine($"Could not open browser. Please manually navigate to: {selectedPr.HtmlUrl}");
            }
        }
    }

    private static string TruncateString(string value, int maxLength)
    {
        if (string.IsNullOrEmpty(value)) return value;
        return value.Length <= maxLength ? value : value.Substring(0, maxLength - 3) + "...";
    }
}