using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace FunctionApp;

public class HealthCheck
{
    private readonly ILogger<HealthCheck> _logger;
    private readonly AppDbContext _db;

    public HealthCheck(ILogger<HealthCheck> logger, AppDbContext db)
    {
        _logger = logger;
        _db = db;
    }

    [Function("HealthCheck")]
    public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest req)
    {
        _logger.LogInformation("C# HTTP trigger function processed a request.");

        bool canConnect = false;
        var errMessage = string.Empty;
        try
        {
            canConnect = await _db.Database.CanConnectAsync();
        }
        catch (System.Exception ex)
        {
            _logger.LogError(ex, "Database connection check failed");
            canConnect = false;
            errMessage = ex.Message;
        }

        var message = $"Connected: {canConnect}|{Environment.NewLine}" +
                      $"With connection string: {_db.Database.GetConnectionString()}|{Environment.NewLine}" +
                      $"Environment: {Environment.GetEnvironmentVariable("AZURE_FUNCTIONS_ENVIRONMENT")}|{Environment.NewLine}" +
                      $"Error Message: {errMessage}|{Environment.NewLine}";
        return new OkObjectResult(message);
    }

}