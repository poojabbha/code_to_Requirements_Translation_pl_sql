using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace RccMigration.LateFee;

/// <summary>
/// EF Core-backed implementation of <see cref="IAccountRepository"/>
/// against the `accounts` table.
/// </summary>
public class AccountRepository : IAccountRepository
{
    private readonly LateFeeDbContext _dbContext;

    public AccountRepository(LateFeeDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<bool?> GetHardshipFlagAsync(int accountId, CancellationToken cancellationToken = default)
    {
        var account = await _dbContext.Accounts
            .AsNoTracking()
            .FirstOrDefaultAsync(a => a.AccountId == accountId, cancellationToken);

        // BR-04 — unknown account: no matching row -> null.
        // reference/extracted/sp_calc_late_fee/business_rules.md#BR-04
        if (account is null)
        {
            return null;
        }

        return account.HardshipFlag == "Y";
    }
}
