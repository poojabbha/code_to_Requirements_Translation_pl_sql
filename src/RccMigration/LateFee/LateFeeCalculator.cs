namespace RccMigration.LateFee;

/// <summary>
/// Fee-amount math ported from SP_CALC_LATE_FEE
/// (reference/procs/sp_calc_late_fee.sql). Pure — no DB access. Assumes
/// the caller has already resolved the account's hardship flag (see
/// <see cref="IAccountRepository"/>); unknown-account handling (Rule
/// BR-04) is the caller's responsibility, not this method's — see
/// reference/extracted/sp_calc_late_fee/technical_spec.md, Control Flow.
/// </summary>
public static class LateFeeCalculator
{
    private const int GracePeriodDays = 5;
    private const decimal DailyFeeRate = 10m;

    /// <summary>
    /// Cite: reference/extracted/sp_calc_late_fee/business_rules.md
    /// (BR-01, BR-02, BR-03). Rule IDs are cited inline below.
    /// </summary>
    public static decimal Calculate(int daysLate, decimal balance, bool hardshipFlag)
    {
        // BR-01 — grace period: days_late <= 5 -> no fee.
        if (daysLate <= GracePeriodDays)
        {
            return 0m;
        }

        // BR-02 — hardship flag waives the fee entirely.
        if (hardshipFlag)
        {
            return 0m;
        }

        // BR-03 — standard fee amount: $10 per day late, uncapped.
        // Confirmed 2026-08-26 (directed in-session; see
        // business_rules.md#BR-03 for the record — formal
        // business_owner_signoff in config/proc_inventory.yaml is still
        // a separate, outstanding step). This supersedes the deployed
        // PL/SQL's floor/percentage/cap formula, which is now known to
        // be OUTDATED relative to this rule — the C# is expected to no
        // longer match SP_CALC_LATE_FEE's live output for this branch;
        // see reference/parity-fixtures/sp_calc_late_fee_actual_outputs.md.
        // Computed fresh from `daysLate` on every call — no internal
        // state; accrual across real-world days happens because callers
        // re-invoke with an increasing daysLate as time passes.
        // `balance` is intentionally unused: the confirmed rule does not
        // depend on it.
        return DailyFeeRate * daysLate;
    }
}
