using Microsoft.EntityFrameworkCore;
using RccMigration.LateFee;

var builder = WebApplication.CreateBuilder(args);

var lateFeeConnectionString = builder.Configuration.GetConnectionString("LateFeeDb")
    ?? throw new InvalidOperationException(
        "Connection string 'LateFeeDb' is not configured. Set it via " +
        "'dotnet user-secrets set \"ConnectionStrings:LateFeeDb\" \"...\"' " +
        "for local development, or the ConnectionStrings__LateFeeDb " +
        "environment variable elsewhere. It is never read from a file " +
        "checked into source control.");

builder.Services.AddDbContext<LateFeeDbContext>(options => options.UseOracle(lateFeeConnectionString));
builder.Services.AddScoped<IAccountRepository, AccountRepository>();
builder.Services.AddScoped<LateFeeService>();

var app = builder.Build();

// SP_CALC_LATE_FEE equivalent — see reference/extracted/sp_calc_late_fee/technical_spec.md
// for the full contract this mirrors (BR-01 through BR-04).
app.MapGet("/accounts/{accountId:int}/late-fee", async (
    int accountId,
    int daysLate,
    decimal balance,
    LateFeeService lateFeeService,
    CancellationToken cancellationToken) =>
{
    var fee = await lateFeeService.CalculateAsync(accountId, daysLate, balance, cancellationToken);

    // BR-04 — unknown account: NULL in the original function maps to
    // 404 here, since the "account's late fee" resource doesn't exist
    // for an account that doesn't exist. See business_rules.md#BR-04.
    if (fee is null)
    {
        return Results.NotFound(new { accountId, message = "Unknown account." });
    }

    return Results.Ok(new { accountId, daysLate, balance, lateFee = fee });
});

app.Run();
