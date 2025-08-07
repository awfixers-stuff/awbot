package database

import (
	"fmt"
	"log/slog"
	"time"

	"sdpusecaseapi/internal/config"
)

// InitializeDatabase sets up the database connection based on configuration
func InitializeDatabase(cfg *config.DatabaseConfig, logger *slog.Logger) (*LibSQLDatabase, error) {
	// Convert config to LibSQLConfig
	dbConfig := LibSQLConfig{
		URL:             cfg.URL,
		AuthToken:       cfg.AuthToken,
		MaxOpenConns:    cfg.MaxOpenConns,
		MaxIdleConns:    cfg.MaxIdleConns,
		ConnMaxLifetime: time.Duration(cfg.ConnMaxLifetime) * time.Minute,
		ConnMaxIdleTime: time.Minute,
		EnableWAL:       cfg.EnableWAL,
		EnableMetrics:   true,
		MigrationPath:   cfg.MigrationPath,
	}

	// Validate configuration
	if dbConfig.URL == "" {
		return nil, fmt.Errorf("database URL is required")
	}

	// Set defaults if not provided
	if dbConfig.MaxOpenConns == 0 {
		dbConfig.MaxOpenConns = 25
	}
	if dbConfig.MaxIdleConns == 0 {
		dbConfig.MaxIdleConns = 5
	}
	if dbConfig.ConnMaxLifetime == 0 {
		dbConfig.ConnMaxLifetime = 5 * time.Minute
	}

	// Create database instance
	db, err := NewLibSQLDatabase(dbConfig, logger)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize database: %w", err)
	}

	return db, nil
}
