using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using RccMigration.LateFee;
using Xunit;

namespace RccMigration.Tests;

/// <summary>
/// Tests for SP_CALC_LATE_FEE vs. LateFeeService/LateFeeCalculator,
/// covering reference/extracted/sp_calc_late_fee/acceptance_criteria.md.
/// For BR-01, BR-02, BR-04 the expected values are REAL PROC OUTPUT
/// captured against the live Oracle instance — see
/// reference/parity-fixtures/sp_calc_late_fee_actual_outputs.md. For
/// BR-03, expected values are the *confirmed rule's* output
/// ($10/day, uncapped), which intentionally no longer matches the
/// deployed proc's real output — see business_rules.md#BR-03 and the
/// per-test comments below. Account hardship flags below (2001 = 'N',
/// 2002 = 'Y', 2003 absent) mirror
/// oracle_setup/04_late_fee_schema_and_seed.sql exactly.
/// </summary>
public class LateFeeParityTests
{
    private static LateFeeService CreateService()
    {
        var hardshipByAccountId = new Dictionary<int, bool>
        {
            [2001] = false, // hardship_flag = 'N'
            [2002] = true,  // hardship_flag = 'Y'
            // 2003 intentionally absent — unknown account
        };

        return new LateFeeService(new FakeAccountRepository(hardshipByAccountId));
    }

    // acceptance_criteria.md TC-01 — BR-03, now confirmed as $10/day,
    // uncapped, balance-independent (business_rules.md#BR-03).
    // REAL PROC OUTPUT for this exact input was 25 (the deployed proc's
    // old floor/percentage/cap formula — see
    // reference/parity-fixtures/sp_calc_late_fee_actual_outputs.md).
    // This asserts the CONFIRMED rule's value (100 = 10 * 10), not the
    // deployed proc's value — that divergence is intentional, not a bug.
    [Fact]
    public async Task TC01_Account2001_DaysLate10_Balance500_MatchesConfirmedBR03Rule()
    {
        var service = CreateService();

        var result = await service.CalculateAsync(2001, daysLate: 10, balance: 500m, CancellationToken.None);

        Assert.Equal(100m, result);
    }

    // acceptance_criteria.md TC-02 — BR-03 balance independence: same
    // daysLate as TC-01 above, wildly different balance, same result.
    [Fact]
    public async Task TC02_Account2001_DaysLate10_LargeBalance_FeeIsBalanceIndependent()
    {
        var service = CreateService();

        var result = await service.CalculateAsync(2001, daysLate: 10, balance: 50000m, CancellationToken.None);

        Assert.Equal(100m, result);
    }

    // acceptance_criteria.md TC-04 — BR-03 no cap: a very late payment
    // produces a correspondingly large fee. Under the old (deployed)
    // formula this would have been clamped to 150; the confirmed rule
    // has no ceiling.
    [Fact]
    public async Task TC04_Account2001_DaysLate100_Balance500_NoCapApplied()
    {
        var service = CreateService();

        var result = await service.CalculateAsync(2001, daysLate: 100, balance: 500m, CancellationToken.None);

        Assert.Equal(1000m, result);
    }

    // No exact TC match — BR-01, grace period, days_late = 3, not the
    // days_late = 5 boundary TC-05 tests — REAL PROC OUTPUT:
    // SP_CALC_LATE_FEE(2001, 3, 500) = 0
    [Fact]
    public async Task BR01_Account2001_DaysLate3_Balance500_MatchesRealProcOutput()
    {
        var service = CreateService();

        var result = await service.CalculateAsync(2001, daysLate: 3, balance: 500m, CancellationToken.None);

        Assert.Equal(0m, result);
    }

    // acceptance_criteria.md TC-07 — REAL PROC OUTPUT: SP_CALC_LATE_FEE(2002, 10, 500) = 0
    [Fact]
    public async Task TC07_Account2002_DaysLate10_Balance500_MatchesRealProcOutput()
    {
        var service = CreateService();

        var result = await service.CalculateAsync(2002, daysLate: 10, balance: 500m, CancellationToken.None);

        Assert.Equal(0m, result);
    }

    // acceptance_criteria.md TC-09 — REAL PROC OUTPUT: SP_CALC_LATE_FEE(2003, 10, 500) = NULL
    [Fact]
    public async Task TC09_Account2003_DaysLate10_Balance500_MatchesRealProcOutput()
    {
        var service = CreateService();

        var result = await service.CalculateAsync(2003, daysLate: 10, balance: 500m, CancellationToken.None);

        Assert.Null(result);
    }

    private sealed class FakeAccountRepository : IAccountRepository
    {
        private readonly IReadOnlyDictionary<int, bool> _hardshipByAccountId;

        public FakeAccountRepository(IReadOnlyDictionary<int, bool> hardshipByAccountId)
        {
            _hardshipByAccountId = hardshipByAccountId;
        }

        public Task<bool?> GetHardshipFlagAsync(int accountId, CancellationToken cancellationToken = default)
        {
            return Task.FromResult(_hardshipByAccountId.TryGetValue(accountId, out var flag) ? flag : (bool?)null);
        }
    }
}
