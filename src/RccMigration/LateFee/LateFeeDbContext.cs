using Microsoft.EntityFrameworkCore;

namespace RccMigration.LateFee;

/// <summary>
/// Minimal EF Core context for the LateFee feature. Connection
/// string/provider are supplied by the host application via
/// DbContextOptions — no connection string or credential is configured
/// here (per CLAUDE.md: no hardcoded connection strings/credentials).
/// </summary>
public class LateFeeDbContext : DbContext
{
    public LateFeeDbContext(DbContextOptions<LateFeeDbContext> options)
        : base(options)
    {
    }

    public DbSet<Account> Accounts => Set<Account>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Oracle folds unquoted DDL identifiers to uppercase (the table
        // was created as `CREATE TABLE accounts (...)`, so the actual
        // object is ACCOUNTS). EF Core's Oracle provider quotes
        // identifiers exactly as given here, so these must be uppercase
        // to match — a lowercase "accounts" would be a different,
        // nonexistent, case-sensitive identifier and fail with
        // ORA-00942 (confirmed live while testing the API).
        modelBuilder.Entity<Account>(entity =>
        {
            entity.ToTable("ACCOUNTS");
            entity.HasKey(a => a.AccountId);
            entity.Property(a => a.AccountId).HasColumnName("ACCOUNT_ID");
            entity.Property(a => a.HardshipFlag)
                .HasColumnName("HARDSHIP_FLAG")
                .HasMaxLength(1)
                .IsRequired();
        });
    }
}
