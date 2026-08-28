namespace RccMigration.LateFee;

/// <summary>
/// Maps to the `accounts` table (oracle_setup/04_late_fee_schema_and_seed.sql).
/// Only the columns SP_CALC_LATE_FEE reads are modeled — see
/// reference/extracted/sp_calc_late_fee/technical_spec.md (Data contract).
/// </summary>
public class Account
{
    public int AccountId { get; set; }

    /// <summary>Raw column value ('Y'/'N'); NOT NULL, default 'N' at the schema level.</summary>
    public string HardshipFlag { get; set; } = "N";
}
