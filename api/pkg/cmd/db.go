package database

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	_ "github.com/tursodatabase/libsql-client-go/libsql"
	_ "modernc.org/sqlite"
)

// LibSQLConfig holds configuration for libSQL database
type LibSQLConfig struct {
	URL             string        // libsql://[your-database].turso.io or file:path/to/db
	AuthToken       string        // For Turso hosted instances
	MaxOpenConns    int           // Maximum open connections
	MaxIdleConns    int           // Maximum idle connections
	ConnMaxLifetime time.Duration // Maximum connection lifetime
	ConnMaxIdleTime time.Duration // Maximum idle time
	EnableWAL       bool          // Enable Write-Ahead Logging for local files
	EnableMetrics   bool          // Enable Prometheus metrics
	MigrationPath   string        // Path to migration files
}

// DefaultLibSQLConfig returns production-ready defaults per CLAUDE.md
func DefaultLibSQLConfig() LibSQLConfig {
	return LibSQLConfig{
		URL:             "file:data/app.db",
		MaxOpenConns:    25, // Conservative per CLAUDE.md
		MaxIdleConns:    5,
		ConnMaxLifetime: 5 * time.Minute,
		ConnMaxIdleTime: 1 * time.Minute,
		EnableWAL:       true,
		EnableMetrics:   true,
		MigrationPath:   "migrations",
	}
}

// LibSQLDatabase manages the libSQL database connection
type LibSQLDatabase struct {
	db      *sql.DB
	config  LibSQLConfig
	logger  *slog.Logger
	metrics *dbMetrics
	mu      sync.RWMutex
}

// dbMetrics holds Prometheus metrics for database monitoring
type dbMetrics struct {
	openConnections prometheus.Gauge
	idleConnections prometheus.Gauge
	waitCount       prometheus.Gauge
	waitDuration    prometheus.Gauge
	queryDuration   *prometheus.HistogramVec
	queryErrors     *prometheus.CounterVec
}

// NewLibSQLDatabase creates a new libSQL database instance with production settings
func NewLibSQLDatabase(cfg LibSQLConfig, logger *slog.Logger) (*LibSQLDatabase, error) {
	// Validate configuration
	if cfg.URL == "" {
		return nil, fmt.Errorf("database URL is required")
	}

	// Build connection string
	connStr := cfg.URL
	if cfg.AuthToken != "" {
		connStr = fmt.Sprintf("%s?authToken=%s", cfg.URL, cfg.AuthToken)
	}

	// Open database connection
	db, err := sql.Open("libsql", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Configure connection pool per CLAUDE.md guidelines
	db.SetMaxOpenConns(cfg.MaxOpenConns)
	db.SetMaxIdleConns(cfg.MaxIdleConns)
	db.SetConnMaxLifetime(cfg.ConnMaxLifetime)
	db.SetConnMaxIdleTime(cfg.ConnMaxIdleTime)

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	ldb := &LibSQLDatabase{
		db:     db,
		config: cfg,
		logger: logger,
	}

	// Enable WAL mode for better concurrency (local files only)
	if cfg.EnableWAL && isLocalFile(cfg.URL) {
		if err := ldb.enableWAL(ctx); err != nil {
			logger.Warn("failed to enable WAL mode", "error", err)
		}
	}

	// Setup metrics if enabled
	if cfg.EnableMetrics {
		ldb.setupMetrics()
	}

	// Start metrics collector
	go ldb.collectMetrics(context.Background())

	logger.Info("libSQL database initialized",
		"url", cfg.URL,
		"max_open_conns", cfg.MaxOpenConns,
		"wal_enabled", cfg.EnableWAL,
	)

	return ldb, nil
}

// DB returns the underlying sql.DB for direct access
func (d *LibSQLDatabase) DB() *sql.DB {
	return d.db
}

// Close gracefully closes the database connection
func (d *LibSQLDatabase) Close() error {
	d.logger.Info("closing database connection")
	return d.db.Close()
}

// Health checks database connectivity and returns status
func (d *LibSQLDatabase) Health(ctx context.Context) error {
	// Set a timeout for health check
	ctx, cancel := context.WithTimeout(ctx, 1*time.Second)
	defer cancel()

	// Ping the database
	if err := d.db.PingContext(ctx); err != nil {
		return fmt.Errorf("database ping failed: %w", err)
	}

	// Run a simple query to verify functionality
	var result int
	err := d.db.QueryRowContext(ctx, "SELECT 1").Scan(&result)
	if err != nil {
		return fmt.Errorf("health query failed: %w", err)
	}

	if result != 1 {
		return fmt.Errorf("unexpected health check result: %d", result)
	}

	return nil
}

// Stats returns database statistics for monitoring
func (d *LibSQLDatabase) Stats() sql.DBStats {
	return d.db.Stats()
}

// Transaction executes a function within a database transaction
func (d *LibSQLDatabase) Transaction(ctx context.Context, fn func(*sql.Tx) error) error {
	tx, err := d.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	defer func() {
		if p := recover(); p != nil {
			tx.Rollback()
			panic(p) // Re-panic after rollback
		}
	}()

	if err := fn(tx); err != nil {
		if rbErr := tx.Rollback(); rbErr != nil {
			d.logger.Error("failed to rollback transaction", "error", rbErr)
		}
		return err
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

// enableWAL enables Write-Ahead Logging for better concurrency
func (d *LibSQLDatabase) enableWAL(ctx context.Context) error {
	_, err := d.db.ExecContext(ctx, "PRAGMA journal_mode=WAL")
	if err != nil {
		return fmt.Errorf("failed to enable WAL: %w", err)
	}

	// Optimize WAL behavior
	pragmas := []string{
		"PRAGMA synchronous=NORMAL",      // Good balance of safety and speed
		"PRAGMA wal_autocheckpoint=1000", // Checkpoint every 1000 pages
		"PRAGMA busy_timeout=5000",       // Wait up to 5 seconds for locks
		"PRAGMA foreign_keys=ON",         // Enable foreign key constraints
	}

	for _, pragma := range pragmas {
		if _, err := d.db.ExecContext(ctx, pragma); err != nil {
			d.logger.Warn("failed to set pragma", "pragma", pragma, "error", err)
		}
	}

	return nil
}

// setupMetrics initializes Prometheus metrics
func (d *LibSQLDatabase) setupMetrics() {
	d.metrics = &dbMetrics{
		openConnections: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "database_open_connections",
			Help: "Number of open database connections",
		}),
		idleConnections: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "database_idle_connections",
			Help: "Number of idle database connections",
		}),
		waitCount: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "database_wait_count",
			Help: "Number of connections waiting",
		}),
		waitDuration: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "database_wait_duration_seconds",
			Help: "Time spent waiting for connections",
		}),
		queryDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "database_query_duration_seconds",
				Help:    "Database query duration in seconds",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"query_type"},
		),
		queryErrors: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "database_query_errors_total",
				Help: "Total number of database query errors",
			},
			[]string{"query_type"},
		),
	}

	// Register metrics
	prometheus.MustRegister(
		d.metrics.openConnections,
		d.metrics.idleConnections,
		d.metrics.waitCount,
		d.metrics.waitDuration,
		d.metrics.queryDuration,
		d.metrics.queryErrors,
	)
}

// collectMetrics periodically collects database metrics
func (d *LibSQLDatabase) collectMetrics(ctx context.Context) {
	if d.metrics == nil {
		return
	}

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			stats := d.db.Stats()
			d.metrics.openConnections.Set(float64(stats.OpenConnections))
			d.metrics.idleConnections.Set(float64(stats.Idle))
			d.metrics.waitCount.Set(float64(stats.WaitCount))
			d.metrics.waitDuration.Set(stats.WaitDuration.Seconds())
		}
	}
}

// ObserveQuery records query metrics
func (d *LibSQLDatabase) ObserveQuery(queryType string, duration time.Duration, err error) {
	if d.metrics == nil {
		return
	}

	d.metrics.queryDuration.WithLabelValues(queryType).Observe(duration.Seconds())
	if err != nil {
		d.metrics.queryErrors.WithLabelValues(queryType).Inc()
	}
}

// isLocalFile checks if the URL is a local file
func isLocalFile(url string) bool {
	return len(url) > 5 && url[:5] == "file:"
}
