using System.Threading;
using System.Threading.Tasks;

namespace RccMigration.LateFee;

/// <summary>
/// Composes <see cref="IAccountRepository"/> and
/// <see cref="LateFeeCalculator"/> into the full SP_CALC_LATE_FEE
/// return contract, including the NULL-for-unknown-account behavior —
/// see reference/extracted/sp_calc_late_fee/technical_spec.md
/// (Function signature and return contract).
/// </summary>
public class LateFeeService
{
    private readonly IAccountRepository _accountRepository;

    public LateFeeService(IAccountRepository accountRepository)
    {
        _accountRepository = accountRepository;
    }

    public async Task<decimal?> CalculateAsync(
        int accountId,
        int daysLate,
        decimal balance,
        CancellationToken cancellationToken = default)
    {
        var hardshipFlag = await _accountRepository.GetHardshipFlagAsync(accountId, cancellationToken);

        // BR-04 — unknown account: propagate the "not found" as null,
        // matching SP_CALC_LATE_FEE's NO_DATA_FOUND -> RETURN NULL path.
        if (hardshipFlag is null)
        {
            return null;
        }

        return LateFeeCalculator.Calculate(daysLate, balance, hardshipFlag.Value);
    }
}
