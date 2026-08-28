using System.Threading;
using System.Threading.Tasks;

namespace RccMigration.LateFee;

/// <summary>
/// Lookup for the one piece of account data SP_CALC_LATE_FEE reads: the
/// hardship flag. See reference/extracted/sp_calc_late_fee/technical_spec.md
/// (Data contract — accounts table) for the underlying `accounts` table
/// definition this is backed by.
/// </summary>
public interface IAccountRepository
{
    /// <summary>
    /// Returns the account's hardship flag (true = hardship,
    /// corresponding to hardship_flag = 'Y'), or null if no account
    /// with the given id exists.
    ///
    /// A null result is Rule BR-04 (unknown account) — see
    /// reference/extracted/sp_calc_late_fee/business_rules.md#BR-04.
    /// Callers must preserve this as a distinguishable "not found"
    /// state, not collapse it to false/0.
    /// </summary>
    Task<bool?> GetHardshipFlagAsync(int accountId, CancellationToken cancellationToken = default);
}
