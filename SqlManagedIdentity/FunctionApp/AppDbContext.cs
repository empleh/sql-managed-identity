// csharp
// File: `Data/AppDbContext.cs`

using Microsoft.EntityFrameworkCore;

namespace FunctionApp
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<TodoItem> TodoItems { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TodoItem>(eb =>
            {
                eb.HasKey(e => e.Id);
                eb.Property(e => e.Title).IsRequired().HasMaxLength(200);
                eb.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
            });
        }
    }
}
