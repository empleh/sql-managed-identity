using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

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
    public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequest req)
    {
        _logger.LogInformation("C# HTTP trigger function processed a request.");

        bool canConnect = false;
        try
        {
            canConnect = await _db.Database.CanConnectAsync();
        }
        catch (System.Exception ex)
        {
            _logger.LogError(ex, "Database connection check failed");
            canConnect = false;
        }

        var message = $"Connected: {canConnect}";
        return new OkObjectResult(message);
    }

}