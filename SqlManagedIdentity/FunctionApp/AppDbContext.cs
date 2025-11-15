// csharp
// File: `Data/AppDbContext.cs`

using Microsoft.EntityFrameworkCore;

namespace FunctionApp
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<TodoItem> TodoItems { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TodoItem>(eb =>
            {
                eb.HasKey(e => e.Id);
                eb.Property(e => e.Title).IsRequired().HasMaxLength(200);
                eb.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
                eb.HasData(
                    new TodoItem { Id = 1, Title = "Sample Task 1", IsComplete = false },
                    new TodoItem { Id = 2, Title = "Sample Task 2", IsComplete = true }
                );
            });
        }
    }
}